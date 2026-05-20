#ifndef SMC_STRUCTURE_DETECTOR_MQH
#define SMC_STRUCTURE_DETECTOR_MQH

#include "SMC_EventBus.mqh"

class CSMCStructureDetector
{
private:
   int m_swing_lookback;
   int m_atr_period;
   double m_point;
   double m_min_break_points;
   double m_displacement_atr_multiplier;

   bool IsSwingHigh(MqlRates &rates[], const int bars, const int index)
   {
      if(index - m_swing_lookback < 1 || index + m_swing_lookback >= bars)
         return false;

      const double candidate = rates[index].high;
      for(int offset = 1; offset <= m_swing_lookback; offset++)
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
      if(index - m_swing_lookback < 1 || index + m_swing_lookback >= bars)
         return false;

      const double candidate = rates[index].low;
      for(int offset = 1; offset <= m_swing_lookback; offset++)
      {
         if(candidate > rates[index - offset].low)
            return false;
         if(candidate > rates[index + offset].low)
            return false;
      }
      return true;
   }

   double TrueRangePoints(MqlRates &rates[], const int index)
   {
      const double high_low = rates[index].high - rates[index].low;
      const double high_close = MathAbs(rates[index].high - rates[index + 1].close);
      const double low_close = MathAbs(rates[index].low - rates[index + 1].close);
      return SMCPriceToPoints(MathMax(high_low, MathMax(high_close, low_close)), m_point);
   }

   double AverageTrueRangePoints(MqlRates &rates[], const int bars, const int index)
   {
      if(index + m_atr_period + 1 >= bars)
         return 0.0;

      double sum = 0.0;
      for(int i = index; i < index + m_atr_period; i++)
         sum += TrueRangePoints(rates, i);

      return sum / (double)m_atr_period;
   }

   void UpdateBreakContext(SMCStructureContext &context,
                           const ESMCEventType type,
                           const datetime time,
                           const ESMCDirection direction,
                           const bool aligned)
   {
      if(type == SMC_EVENT_BOS)
      {
         if(!context.has_bos || time >= context.bos_time)
         {
            context.has_bos = true;
            context.bos_time = time;
            context.bos_direction = direction;
            context.bos_aligned = aligned;
         }
      }
      else if(type == SMC_EVENT_CHOCH)
      {
         if(!context.has_choch || time >= context.choch_time)
         {
            context.has_choch = true;
            context.choch_time = time;
            context.choch_direction = direction;
         }
      }
   }

public:
   CSMCStructureDetector()
   {
      m_swing_lookback = 3;
      m_atr_period = 14;
      m_point = _Point;
      m_min_break_points = 2.0;
      m_displacement_atr_multiplier = 1.8;
   }

   void Configure(const int swing_lookback,
                  const double point,
                  const double min_break_points,
                  const int atr_period,
                  const double displacement_atr_multiplier)
   {
      m_swing_lookback = MathMax(1, swing_lookback);
      m_point = point;
      m_min_break_points = MathMax(0.0, min_break_points);
      m_atr_period = MathMax(3, atr_period);
      m_displacement_atr_multiplier = MathMax(0.5, displacement_atr_multiplier);
   }

   void Scan(const string symbol,
             MqlRates &rates[],
             const int bars,
             SMCSweepContext &sweep,
             CSMCEventBus &bus,
             SMCStructureContext &context)
   {
      SMCResetStructureContext(context);

      if(bars < (m_swing_lookback * 2 + m_atr_period + 5))
         return;

      SMCSwingPoint active_high;
      SMCSwingPoint active_low;
      SMCResetSwing(active_high);
      SMCResetSwing(active_low);

      bool active_high_broken = false;
      bool active_low_broken = false;
      ESMCDirection trend = SMC_DIR_NONE;

      const int start = bars - m_swing_lookback - m_atr_period - 2;
      for(int i = start; i >= 1; i--)
      {
         const bool after_sweep = (!sweep.valid || rates[i].time >= sweep.time);

         if(active_high.valid && !active_high_broken)
         {
            const double break_points = SMCPriceToPoints(rates[i].close - active_high.price, m_point);
            if(rates[i].close > active_high.price && break_points >= m_min_break_points)
            {
               const ESMCEventType event_type = (trend == SMC_DIR_BEARISH ? SMC_EVENT_CHOCH : SMC_EVENT_BOS);
               const bool aligned = (sweep.valid && after_sweep && sweep.direction == SMC_DIR_BULLISH);
               const string tag = (event_type == SMC_EVENT_CHOCH ? "CHOCH_BULLISH" : "BOS_BULLISH");
               const string details = StringFormat("level=%.2f;close=%.2f;break_points=%.1f;after_sweep=%s",
                                                   active_high.price, rates[i].close, break_points,
                                                   SMCBoolToString(after_sweep));

               bus.AddEvent(symbol, PERIOD_M1, event_type, rates[i].time,
                            SMC_DIR_BULLISH, active_high.price, rates[i].close,
                            0, false, tag, details, active_high.key);

               UpdateBreakContext(context, event_type, rates[i].time,
                                  SMC_DIR_BULLISH, aligned);
               trend = SMC_DIR_BULLISH;
               active_high_broken = true;
            }
         }

         if(active_low.valid && !active_low_broken)
         {
            const double break_points = SMCPriceToPoints(active_low.price - rates[i].close, m_point);
            if(rates[i].close < active_low.price && break_points >= m_min_break_points)
            {
               const ESMCEventType event_type = (trend == SMC_DIR_BULLISH ? SMC_EVENT_CHOCH : SMC_EVENT_BOS);
               const bool aligned = (sweep.valid && after_sweep && sweep.direction == SMC_DIR_BEARISH);
               const string tag = (event_type == SMC_EVENT_CHOCH ? "CHOCH_BEARISH" : "BOS_BEARISH");
               const string details = StringFormat("level=%.2f;close=%.2f;break_points=%.1f;after_sweep=%s",
                                                   active_low.price, rates[i].close, break_points,
                                                   SMCBoolToString(after_sweep));

               bus.AddEvent(symbol, PERIOD_M1, event_type, rates[i].time,
                            SMC_DIR_BEARISH, active_low.price, rates[i].close,
                            0, false, tag, details, active_low.key);

               UpdateBreakContext(context, event_type, rates[i].time,
                                  SMC_DIR_BEARISH, aligned);
               trend = SMC_DIR_BEARISH;
               active_low_broken = true;
            }
         }

         const double atr_points = AverageTrueRangePoints(rates, bars, i);
         const double body_points = SMCPriceToPoints(rates[i].close - rates[i].open, m_point);
         if(atr_points > 0.0 && body_points >= (atr_points * m_displacement_atr_multiplier))
         {
            const ESMCDirection direction = (rates[i].close >= rates[i].open ? SMC_DIR_BULLISH : SMC_DIR_BEARISH);
            const double ratio = body_points / atr_points;
            const string details = StringFormat("body_points=%.1f;atr_points=%.1f;ratio=%.2f",
                                                body_points, atr_points, ratio);

            bus.AddEvent(symbol, PERIOD_M1, SMC_EVENT_DISPLACEMENT, rates[i].time,
                         direction, rates[i].close, rates[i].open, 0, false,
                         "DISPLACEMENT", details, DoubleToString(ratio, 2));

            if(after_sweep && (!context.has_displacement || rates[i].time >= context.displacement_time))
            {
               context.has_displacement = true;
               context.displacement_time = rates[i].time;
               context.displacement_direction = direction;
               context.displacement_ratio = ratio;
            }
         }

         if(IsSwingHigh(rates, bars, i))
         {
            active_high.valid = true;
            active_high.time = rates[i].time;
            active_high.price = rates[i].high;
            active_high.direction = SMC_DIR_BEARISH;
            active_high.index = i;
            active_high.key = SMCMakeEventKey(symbol, PERIOD_M1, SMC_EVENT_SWING_HIGH,
                                              rates[i].time, rates[i].high, "M1_HIGH");
            active_high_broken = false;
         }

         if(IsSwingLow(rates, bars, i))
         {
            active_low.valid = true;
            active_low.time = rates[i].time;
            active_low.price = rates[i].low;
            active_low.direction = SMC_DIR_BULLISH;
            active_low.index = i;
            active_low.key = SMCMakeEventKey(symbol, PERIOD_M1, SMC_EVENT_SWING_LOW,
                                             rates[i].time, rates[i].low, "M1_LOW");
            active_low_broken = false;
         }
      }

      context.trend_direction = trend;
   }
};

#endif
