#ifndef SMC_FVG_DETECTOR_MQH
#define SMC_FVG_DETECTOR_MQH

#include "SMC_EventBus.mqh"

class CSMCFVGDetector
{
private:
   double m_point;
   double m_min_gap_points;

   bool IsMitigated(MqlRates &rates[],
                    const int newer_index,
                    const double lower,
                    const double upper)
   {
      for(int i = newer_index - 1; i >= 1; i--)
      {
         if(rates[i].low <= upper && rates[i].high >= lower)
            return true;
      }
      return false;
   }

   void UpdateContext(SMCFVGContext &context,
                      SMCFVGZone &zone,
                      SMCSweepContext &sweep,
                      SMCStructureContext &structure)
   {
      if(!zone.valid || zone.mitigated)
         return;

      context.total_open_zones++;

      const bool after_sweep = (!sweep.valid || zone.start_time >= sweep.time);
      const bool aligned_with_sweep = (!sweep.valid || sweep.direction == zone.direction);
      const bool aligned_with_structure = (!structure.has_bos || structure.bos_direction == zone.direction);

      if(after_sweep && aligned_with_sweep && aligned_with_structure)
      {
         if(!context.has_aligned_fvg || zone.start_time >= context.latest_aligned.start_time)
         {
            context.has_aligned_fvg = true;
            context.latest_aligned = zone;
         }
      }
   }

public:
   CSMCFVGDetector()
   {
      m_point = _Point;
      m_min_gap_points = 5.0;
   }

   void Configure(const double point, const double min_gap_points)
   {
      m_point = point;
      m_min_gap_points = MathMax(0.0, min_gap_points);
   }

   void Scan(const string symbol,
             MqlRates &rates[],
             const int bars,
             SMCSweepContext &sweep,
             SMCStructureContext &structure,
             CSMCEventBus &bus,
             SMCFVGContext &context)
   {
      SMCResetFVGContext(context);

      if(bars < 5)
         return;

      for(int i = bars - 3; i >= 1; i--)
      {
         const double bullish_gap = rates[i].low - rates[i + 2].high;
         if(bullish_gap > 0.0 && SMCPriceToPoints(bullish_gap, m_point) >= m_min_gap_points)
         {
            SMCFVGZone zone;
            SMCResetFVGZone(zone);
            zone.valid = true;
            zone.start_time = rates[i + 2].time;
            zone.end_time = rates[i].time;
            zone.lower = rates[i + 2].high;
            zone.upper = rates[i].low;
            zone.direction = SMC_DIR_BULLISH;
            zone.mitigated = IsMitigated(rates, i, zone.lower, zone.upper);
            zone.key = SMCMakeEventKey(symbol, PERIOD_M1, SMC_EVENT_FVG,
                                       rates[i].time, zone.lower, "BULL");

            const string details = StringFormat("lower=%.2f;upper=%.2f;gap_points=%.1f;mitigated=%s",
                                                zone.lower, zone.upper,
                                                SMCPriceToPoints(bullish_gap, m_point),
                                                SMCBoolToString(zone.mitigated));
            bus.AddEvent(symbol, PERIOD_M1, SMC_EVENT_FVG, rates[i].time,
                         SMC_DIR_BULLISH, zone.lower, zone.upper, 0,
                         zone.mitigated, "FVG_BULLISH", details, "BULL");

            UpdateContext(context, zone, sweep, structure);
         }

         const double bearish_gap = rates[i + 2].low - rates[i].high;
         if(bearish_gap > 0.0 && SMCPriceToPoints(bearish_gap, m_point) >= m_min_gap_points)
         {
            SMCFVGZone zone;
            SMCResetFVGZone(zone);
            zone.valid = true;
            zone.start_time = rates[i + 2].time;
            zone.end_time = rates[i].time;
            zone.lower = rates[i].high;
            zone.upper = rates[i + 2].low;
            zone.direction = SMC_DIR_BEARISH;
            zone.mitigated = IsMitigated(rates, i, zone.lower, zone.upper);
            zone.key = SMCMakeEventKey(symbol, PERIOD_M1, SMC_EVENT_FVG,
                                       rates[i].time, zone.lower, "BEAR");

            const string details = StringFormat("lower=%.2f;upper=%.2f;gap_points=%.1f;mitigated=%s",
                                                zone.lower, zone.upper,
                                                SMCPriceToPoints(bearish_gap, m_point),
                                                SMCBoolToString(zone.mitigated));
            bus.AddEvent(symbol, PERIOD_M1, SMC_EVENT_FVG, rates[i].time,
                         SMC_DIR_BEARISH, zone.lower, zone.upper, 0,
                         zone.mitigated, "FVG_BEARISH", details, "BEAR");

            UpdateContext(context, zone, sweep, structure);
         }
      }
   }
};

#endif
