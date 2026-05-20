#ifndef SMC_LIQUIDITY_DETECTOR_MQH
#define SMC_LIQUIDITY_DETECTOR_MQH

#include "SMC_EventBus.mqh"

class CSMCLiquidityDetector
{
private:
   int m_lookback;
   double m_point;
   double m_equal_tolerance_points;
   double m_min_sweep_points;

   bool IsSwingHigh(MqlRates &rates[], const int bars, const int index)
   {
      if(index - m_lookback < 1 || index + m_lookback >= bars)
         return false;

      const double candidate = rates[index].high;
      for(int offset = 1; offset <= m_lookback; offset++)
      {
         if(candidate < rates[index - offset].high)
            return false;
         if(candidate < rates[index + offset].high)
            return false;
      }
      return true;
   }

   bool IsSwingLow(MqlRates &rates[], const int bars, const int index)
   {
      if(index - m_lookback < 1 || index + m_lookback >= bars)
         return false;

      const double candidate = rates[index].low;
      for(int offset = 1; offset <= m_lookback; offset++)
      {
         if(candidate > rates[index - offset].low)
            return false;
         if(candidate > rates[index + offset].low)
            return false;
      }
      return true;
   }

   double SwingHighStrength(MqlRates &rates[], const int index)
   {
      double nearest = 0.0;
      for(int offset = 1; offset <= m_lookback; offset++)
      {
         nearest = MathMax(nearest, rates[index - offset].high);
         nearest = MathMax(nearest, rates[index + offset].high);
      }
      return SMCPriceToPoints(rates[index].high - nearest, m_point);
   }

   double SwingLowStrength(MqlRates &rates[], const int index)
   {
      double nearest = DBL_MAX;
      for(int offset = 1; offset <= m_lookback; offset++)
      {
         nearest = MathMin(nearest, rates[index - offset].low);
         nearest = MathMin(nearest, rates[index + offset].low);
      }
      return SMCPriceToPoints(nearest - rates[index].low, m_point);
   }

   void UpdateLatestSweep(SMCSweepContext &context,
                          const datetime time,
                          const double level,
                          const double close_price,
                          const ESMCDirection direction,
                          const double strength_points,
                          const string key)
   {
      if(!context.valid || time >= context.time)
      {
         context.valid = true;
         context.time = time;
         context.level = level;
         context.close_price = close_price;
         context.direction = direction;
         context.strength_points = strength_points;
         context.key = key;
      }
   }

public:
   CSMCLiquidityDetector()
   {
      m_lookback = 20;
      m_point = _Point;
      m_equal_tolerance_points = 5.0;
      m_min_sweep_points = 1.0;
   }

   void Configure(const int lookback,
                  const double point,
                  const double equal_tolerance_points,
                  const double min_sweep_points)
   {
      m_lookback = MathMax(2, lookback);
      m_point = point;
      m_equal_tolerance_points = MathMax(0.0, equal_tolerance_points);
      m_min_sweep_points = MathMax(0.0, min_sweep_points);
   }

   void Scan(const string symbol,
             MqlRates &rates[],
             const int bars,
             CSMCEventBus &bus,
             SMCSweepContext &context)
   {
      SMCResetSweepContext(context);

      if(bars < (m_lookback * 2 + 5))
         return;

      SMCSwingPoint active_high;
      SMCSwingPoint active_low;
      SMCSwingPoint previous_high;
      SMCSwingPoint previous_low;
      SMCResetSwing(active_high);
      SMCResetSwing(active_low);
      SMCResetSwing(previous_high);
      SMCResetSwing(previous_low);

      bool active_high_swept = false;
      bool active_low_swept = false;

      const int start = bars - m_lookback - 2;
      for(int i = start; i >= 1; i--)
      {
         if(active_high.valid && !active_high_swept)
         {
            const double beyond_points = SMCPriceToPoints(rates[i].close - active_high.price, m_point);
            if(rates[i].close > active_high.price && beyond_points >= m_min_sweep_points)
            {
               const string details = StringFormat("level=%.2f;close=%.2f;beyond_points=%.1f",
                                                   active_high.price, rates[i].close, beyond_points);

               SMCEvent event;
               SMCResetEvent(event);
               SMCFillEvent(event, symbol, PERIOD_M5, SMC_EVENT_LIQUIDITY_SWEEP,
                            rates[i].time, SMC_DIR_BEARISH, active_high.price,
                            rates[i].close, 0, false, "SWEEP_HIGH", details,
                            active_high.key);

               if(bus.Add(event))
                  UpdateLatestSweep(context, rates[i].time, active_high.price,
                                    rates[i].close, SMC_DIR_BEARISH,
                                    beyond_points, event.key);

               active_high_swept = true;
            }
         }

         if(active_low.valid && !active_low_swept)
         {
            const double beyond_points = SMCPriceToPoints(active_low.price - rates[i].close, m_point);
            if(rates[i].close < active_low.price && beyond_points >= m_min_sweep_points)
            {
               const string details = StringFormat("level=%.2f;close=%.2f;beyond_points=%.1f",
                                                   active_low.price, rates[i].close, beyond_points);

               SMCEvent event;
               SMCResetEvent(event);
               SMCFillEvent(event, symbol, PERIOD_M5, SMC_EVENT_LIQUIDITY_SWEEP,
                            rates[i].time, SMC_DIR_BULLISH, active_low.price,
                            rates[i].close, 0, false, "SWEEP_LOW", details,
                            active_low.key);

               if(bus.Add(event))
                  UpdateLatestSweep(context, rates[i].time, active_low.price,
                                    rates[i].close, SMC_DIR_BULLISH,
                                    beyond_points, event.key);

               active_low_swept = true;
            }
         }

         if(IsSwingHigh(rates, bars, i))
         {
            SMCSwingPoint swing;
            SMCResetSwing(swing);
            swing.valid = true;
            swing.time = rates[i].time;
            swing.price = rates[i].high;
            swing.direction = SMC_DIR_BEARISH;
            swing.index = i;
            swing.strength_points = SwingHighStrength(rates, i);
            swing.key = SMCMakeEventKey(symbol, PERIOD_M5, SMC_EVENT_SWING_HIGH,
                                        swing.time, swing.price, "HIGH");

            const string details = StringFormat("lookback=%d;strength_points=%.1f",
                                                m_lookback, swing.strength_points);
            bus.AddEvent(symbol, PERIOD_M5, SMC_EVENT_SWING_HIGH, swing.time,
                         swing.direction, swing.price, 0.0, 0, false,
                         "SWING_HIGH", details, "HIGH");

            if(previous_high.valid &&
               SMCPriceToPoints(swing.price - previous_high.price, m_point) <= m_equal_tolerance_points)
            {
               const string equal_details = StringFormat("previous=%.2f;tolerance_points=%.1f",
                                                         previous_high.price, m_equal_tolerance_points);
               bus.AddEvent(symbol, PERIOD_M5, SMC_EVENT_EQUAL_HIGH, swing.time,
                            SMC_DIR_BEARISH, swing.price, previous_high.price,
                            0, false, "EQUAL_HIGH", equal_details,
                            previous_high.key);
            }

            previous_high = swing;
            active_high = swing;
            active_high_swept = false;
         }

         if(IsSwingLow(rates, bars, i))
         {
            SMCSwingPoint swing;
            SMCResetSwing(swing);
            swing.valid = true;
            swing.time = rates[i].time;
            swing.price = rates[i].low;
            swing.direction = SMC_DIR_BULLISH;
            swing.index = i;
            swing.strength_points = SwingLowStrength(rates, i);
            swing.key = SMCMakeEventKey(symbol, PERIOD_M5, SMC_EVENT_SWING_LOW,
                                        swing.time, swing.price, "LOW");

            const string details = StringFormat("lookback=%d;strength_points=%.1f",
                                                m_lookback, swing.strength_points);
            bus.AddEvent(symbol, PERIOD_M5, SMC_EVENT_SWING_LOW, swing.time,
                         swing.direction, swing.price, 0.0, 0, false,
                         "SWING_LOW", details, "LOW");

            if(previous_low.valid &&
               SMCPriceToPoints(swing.price - previous_low.price, m_point) <= m_equal_tolerance_points)
            {
               const string equal_details = StringFormat("previous=%.2f;tolerance_points=%.1f",
                                                         previous_low.price, m_equal_tolerance_points);
               bus.AddEvent(symbol, PERIOD_M5, SMC_EVENT_EQUAL_LOW, swing.time,
                            SMC_DIR_BULLISH, swing.price, previous_low.price,
                            0, false, "EQUAL_LOW", equal_details,
                            previous_low.key);
            }

            previous_low = swing;
            active_low = swing;
            active_low_swept = false;
         }
      }
   }
};

#endif
