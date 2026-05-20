#ifndef SMC_SCORE_ENGINE_MQH
#define SMC_SCORE_ENGINE_MQH

#include "SMC_FVGDetector.mqh"
#include "SMC_VWAPContext.mqh"

class CSMCScoreEngine
{
private:
   int m_weight_sweep;
   int m_weight_bos;
   int m_weight_fvg;
   int m_weight_vwap;
   int m_weight_displacement;
   int m_weight_liquidity;
   int m_weight_trend;
   double m_strong_liquidity_points;

   ESMCScoreClass Classify(const int value)
   {
      if(value >= 75)
         return SMC_SCORE_STRONG;
      if(value >= 50)
         return SMC_SCORE_MEDIUM;
      if(value >= 25)
         return SMC_SCORE_WEAK;
      return SMC_SCORE_NOISY;
   }

   ESMCDirection ResolveDirection(SMCSweepContext &sweep,
                                  SMCStructureContext &structure,
                                  SMCVWAPState &vwap)
   {
      if(sweep.valid)
         return sweep.direction;
      if(structure.has_bos)
         return structure.bos_direction;
      if(structure.trend_direction != SMC_DIR_NONE)
         return structure.trend_direction;
      if(vwap.valid)
         return vwap.direction;
      return SMC_DIR_NONE;
   }

public:
   CSMCScoreEngine()
   {
      m_weight_sweep = 20;
      m_weight_bos = 20;
      m_weight_fvg = 15;
      m_weight_vwap = 15;
      m_weight_displacement = 10;
      m_weight_liquidity = 10;
      m_weight_trend = 10;
      m_strong_liquidity_points = 80.0;
   }

   void Configure(const int weight_sweep,
                  const int weight_bos,
                  const int weight_fvg,
                  const int weight_vwap,
                  const int weight_displacement,
                  const int weight_liquidity,
                  const int weight_trend,
                  const double strong_liquidity_points)
   {
      m_weight_sweep = MathMax(0, weight_sweep);
      m_weight_bos = MathMax(0, weight_bos);
      m_weight_fvg = MathMax(0, weight_fvg);
      m_weight_vwap = MathMax(0, weight_vwap);
      m_weight_displacement = MathMax(0, weight_displacement);
      m_weight_liquidity = MathMax(0, weight_liquidity);
      m_weight_trend = MathMax(0, weight_trend);
      m_strong_liquidity_points = MathMax(0.0, strong_liquidity_points);
   }

   void Evaluate(const string symbol,
                 SMCSweepContext &sweep,
                 SMCStructureContext &structure,
                 SMCFVGContext &fvg,
                 SMCVWAPState &vwap,
                 CSMCEventBus &bus,
                 SMCScoreState &score)
   {
      SMCResetScoreState(score);
      score.time = (vwap.valid ? vwap.time : TimeCurrent());
      score.direction = ResolveDirection(sweep, structure, vwap);

      bool sweep_ok = false;
      bool bos_ok = false;
      bool fvg_ok = false;
      bool vwap_ok = false;
      bool displacement_ok = false;
      bool liquidity_ok = false;
      bool trend_ok = false;

      if(sweep.valid)
      {
         score.value += m_weight_sweep;
         sweep_ok = true;
      }

      if(score.direction != SMC_DIR_NONE)
      {
         bos_ok = (structure.has_bos && structure.bos_aligned &&
                   structure.bos_direction == score.direction);
         if(bos_ok)
            score.value += m_weight_bos;

         fvg_ok = (fvg.has_aligned_fvg &&
                   fvg.latest_aligned.direction == score.direction);
         if(fvg_ok)
            score.value += m_weight_fvg;

         vwap_ok = (vwap.valid && vwap.direction == score.direction);
         if(vwap_ok)
            score.value += m_weight_vwap;

         displacement_ok = (structure.has_displacement &&
                            structure.displacement_direction == score.direction);
         if(displacement_ok)
            score.value += m_weight_displacement;

         liquidity_ok = (sweep.valid &&
                         sweep.strength_points >= m_strong_liquidity_points);
         if(liquidity_ok)
            score.value += m_weight_liquidity;

         trend_ok = (structure.trend_direction == score.direction);
         if(trend_ok)
            score.value += m_weight_trend;
      }

      if(score.value > 100)
         score.value = 100;

      score.klass = Classify(score.value);
      score.continuation = (score.direction != SMC_DIR_NONE &&
                            bos_ok && fvg_ok && vwap_ok && trend_ok);
      score.mean_reversion = (score.direction != SMC_DIR_NONE &&
                              sweep.valid && bos_ok && vwap.valid && !vwap_ok);

      score.notes = StringFormat("sweep=%s;bos=%s;fvg=%s;vwap=%s;displacement=%s;liquidity=%s;trend=%s",
                                 SMCBoolToString(sweep_ok),
                                 SMCBoolToString(bos_ok),
                                 SMCBoolToString(fvg_ok),
                                 SMCBoolToString(vwap_ok),
                                 SMCBoolToString(displacement_ok),
                                 SMCBoolToString(liquidity_ok),
                                 SMCBoolToString(trend_ok));

      bus.AddEvent(symbol, PERIOD_M1, SMC_EVENT_SCORE, score.time,
                   score.direction, (vwap.valid ? vwap.close_price : 0.0),
                   (vwap.valid ? vwap.value : 0.0), score.value, false,
                   SMCScoreClassToString(score.klass), score.notes,
                   IntegerToString(score.value));

      if(score.continuation)
      {
         bus.AddEvent(symbol, PERIOD_M1, SMC_EVENT_CONTINUATION, score.time,
                      score.direction, (vwap.valid ? vwap.close_price : 0.0),
                      (vwap.valid ? vwap.value : 0.0), score.value, false,
                      "CONTINUATION", score.notes, IntegerToString(score.value));
      }

      if(score.mean_reversion)
      {
         bus.AddEvent(symbol, PERIOD_M1, SMC_EVENT_MEAN_REVERSION, score.time,
                      score.direction, (vwap.valid ? vwap.close_price : 0.0),
                      (vwap.valid ? vwap.value : 0.0), score.value, false,
                      "MEAN_REVERSION", score.notes, IntegerToString(score.value));
      }
   }
};

#endif
