#ifndef SMC_VWAP_CONTEXT_MQH
#define SMC_VWAP_CONTEXT_MQH

#include "SMC_EventBus.mqh"

class CSMCVWAPContext
{
private:
   double m_point;

   bool SameTradingDay(const datetime left, const datetime right)
   {
      MqlDateTime a;
      MqlDateTime b;
      TimeToStruct(left, a);
      TimeToStruct(right, b);
      return (a.year == b.year && a.mon == b.mon && a.day == b.day);
   }

public:
   CSMCVWAPContext()
   {
      m_point = _Point;
   }

   void Configure(const double point)
   {
      m_point = point;
   }

   bool Calculate(const string symbol,
                  MqlRates &rates[],
                  const int bars,
                  CSMCEventBus &bus,
                  SMCVWAPState &state)
   {
      SMCResetVWAPState(state);

      if(bars < 3)
         return false;

      const datetime target_day = rates[1].time;
      double sum_pv = 0.0;
      double sum_volume = 0.0;

      for(int i = bars - 1; i >= 1; i--)
      {
         if(!SameTradingDay(rates[i].time, target_day))
            continue;

         const double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
         double volume = (double)rates[i].tick_volume;
         if(volume <= 0.0)
            volume = 1.0;

         sum_pv += typical * volume;
         sum_volume += volume;
      }

      if(sum_volume <= 0.0)
         return false;

      state.valid = true;
      state.time = rates[1].time;
      state.value = sum_pv / sum_volume;
      state.close_price = rates[1].close;
      state.direction = (state.close_price >= state.value ? SMC_DIR_BULLISH : SMC_DIR_BEARISH);
      state.distance_points = SMCPriceToPoints(state.close_price - state.value, m_point);

      const string details = StringFormat("vwap=%.2f;close=%.2f;distance_points=%.1f",
                                          state.value, state.close_price,
                                          state.distance_points);
      bus.AddEvent(symbol, PERIOD_M1, SMC_EVENT_VWAP_CONTEXT, state.time,
                   state.direction, state.value, state.close_price, 0,
                   false, "VWAP", details, "INTRADAY");

      return true;
   }
};

#endif
