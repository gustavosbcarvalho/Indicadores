#property copyright "Indicadores MT5"
#property link      "https://github.com/gustavosbcarvalho/Indicadores"
#property version   "1.000"
#property indicator_chart_window
#property indicator_plots 0
#property indicator_buffers 0

#include <SMC/SMC_LiquidityDetector.mqh>
#include <SMC/SMC_StructureDetector.mqh>
#include <SMC/SMC_Renderer.mqh>
#include <SMC/SMC_PersistenceCSV.mqh>

input int InpM5HistoryBars = 360;
input int InpM1HistoryBars = 1200;
input int InpRefreshSeconds = 2;
input bool InpProcessEveryTick = false;

input int InpLiquidityLookbackM5 = 20;
input double InpEqualTolerancePoints = 5.0;
input double InpMinSweepCloseBeyondPoints = 1.0;

input int InpStructureLookbackM1 = 3;
input double InpMinBreakPoints = 2.0;
input int InpDisplacementATRPeriod = 14;
input double InpDisplacementATRMultiplier = 1.8;

input double InpFVGMinGapPoints = 5.0;
input double InpStrongLiquidityPoints = 80.0;

input int InpWeightSweep = 20;
input int InpWeightBOS = 20;
input int InpWeightFVG = 15;
input int InpWeightVWAP = 15;
input int InpWeightDisplacement = 10;
input int InpWeightLiquidity = 10;
input int InpWeightTrend = 10;

input bool InpRenderVisual = true;
input bool InpClearObjectsOnInit = true;
input bool InpRemoveObjectsOnDeinit = false;
input string InpObjectPrefix = "SMC_OBS";
input int InpLineExtendBars = 120;
input int InpFVGExtendBars = 120;
input int InpMaxRenderEvents = 350;

input color InpBullishColor = C'0,180,90';
input color InpBearishColor = C'220,70,70';
input color InpSweepColor = C'255,190,0';
input color InpBOSColor = C'0,150,255';
input color InpCHOCHColor = C'190,120,255';
input color InpFVGBullishColor = C'40,130,90';
input color InpFVGBearishColor = C'160,70,70';
input color InpFVGMitigatedColor = C'120,120,120';
input color InpTextColor = C'235,235,235';

input bool InpPersistCSV = true;
input string InpCSVFileName = "SMC_Observacional_WIN.csv";
input int InpMaxEventsInMemory = 2500;

CSMCEventBus g_event_bus;
CSMCLiquidityDetector g_liquidity_detector;
CSMCStructureDetector g_structure_detector;
CSMCFVGDetector g_fvg_detector;
CSMCVWAPContext g_vwap_context;
CSMCScoreEngine g_score_engine;
CSMCRenderer g_renderer;
CSMCPersistenceCSV g_persistence;

SMCSweepContext g_sweep_context;
SMCStructureContext g_structure_context;
SMCFVGContext g_fvg_context;
SMCVWAPState g_vwap_state;
SMCScoreState g_score_state;

datetime g_last_m1_closed = 0;
datetime g_last_m5_closed = 0;

bool CopyRatesSeries(const ENUM_TIMEFRAMES timeframe,
                     const int requested_bars,
                     MqlRates &rates[],
                     int &copied_bars)
{
   ArraySetAsSeries(rates, true);
   ResetLastError();
   copied_bars = CopyRates(_Symbol, timeframe, 0, requested_bars, rates);
   ArraySetAsSeries(rates, true);

   if(copied_bars <= 0)
   {
      Print("SMC: CopyRates falhou em ", SMCTimeframeToString(timeframe),
            " erro=", GetLastError());
      return false;
   }

   return true;
}

bool ShouldRefresh()
{
   if(InpProcessEveryTick)
      return true;

   const datetime m1_closed = iTime(_Symbol, PERIOD_M1, 1);
   const datetime m5_closed = iTime(_Symbol, PERIOD_M5, 1);

   if(m1_closed == 0 || m5_closed == 0)
      return true;

   if(m1_closed != g_last_m1_closed || m5_closed != g_last_m5_closed)
      return true;

   return false;
}

void ConfigureModules()
{
   const double point = _Point;

   g_event_bus.Configure(InpMaxEventsInMemory);

   g_liquidity_detector.Configure(InpLiquidityLookbackM5,
                                  point,
                                  InpEqualTolerancePoints,
                                  InpMinSweepCloseBeyondPoints);

   g_structure_detector.Configure(InpStructureLookbackM1,
                                  point,
                                  InpMinBreakPoints,
                                  InpDisplacementATRPeriod,
                                  InpDisplacementATRMultiplier);

   g_fvg_detector.Configure(point, InpFVGMinGapPoints);
   g_vwap_context.Configure(point);

   g_score_engine.Configure(InpWeightSweep,
                            InpWeightBOS,
                            InpWeightFVG,
                            InpWeightVWAP,
                            InpWeightDisplacement,
                            InpWeightLiquidity,
                            InpWeightTrend,
                            InpStrongLiquidityPoints);

   g_renderer.Configure(InpObjectPrefix,
                        InpRenderVisual,
                        point,
                        InpLineExtendBars,
                        InpFVGExtendBars,
                        InpMaxRenderEvents,
                        InpBullishColor,
                        InpBearishColor,
                        InpSweepColor,
                        InpBOSColor,
                        InpCHOCHColor,
                        InpFVGBullishColor,
                        InpFVGBearishColor,
                        InpFVGMitigatedColor,
                        InpTextColor);

   g_persistence.Configure(InpPersistCSV, InpCSVFileName);
}

void RefreshSMC(const bool force)
{
   if(!force && !ShouldRefresh())
      return;

   MqlRates m5_rates[];
   MqlRates m1_rates[];
   int m5_bars = 0;
   int m1_bars = 0;

   const int requested_m5 = MathMax(InpM5HistoryBars, InpLiquidityLookbackM5 * 3 + 30);
   const int requested_m1 = MathMax(InpM1HistoryBars,
                                    InpDisplacementATRPeriod + InpStructureLookbackM1 * 4 + 120);

   if(!CopyRatesSeries(PERIOD_M5, requested_m5, m5_rates, m5_bars))
      return;
   if(!CopyRatesSeries(PERIOD_M1, requested_m1, m1_rates, m1_bars))
      return;

   if(m1_bars > 1)
      g_last_m1_closed = m1_rates[1].time;
   if(m5_bars > 1)
      g_last_m5_closed = m5_rates[1].time;

   g_liquidity_detector.Scan(_Symbol, m5_rates, m5_bars, g_event_bus, g_sweep_context);
   g_structure_detector.Scan(_Symbol, m1_rates, m1_bars, g_sweep_context,
                             g_event_bus, g_structure_context);
   g_fvg_detector.Scan(_Symbol, m1_rates, m1_bars, g_sweep_context,
                       g_structure_context, g_event_bus, g_fvg_context);
   g_vwap_context.Calculate(_Symbol, m1_rates, m1_bars, g_event_bus, g_vwap_state);
   g_score_engine.Evaluate(_Symbol, g_sweep_context, g_structure_context,
                           g_fvg_context, g_vwap_state, g_event_bus,
                           g_score_state);

   g_persistence.PersistNewEvents(g_event_bus);
   g_renderer.Render(g_event_bus, g_score_state, g_sweep_context,
                     g_structure_context, g_vwap_state, g_fvg_context);

   ChartRedraw(0);
}

int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "SMC Observacional WIN");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   ConfigureModules();

   if(InpClearObjectsOnInit)
      g_renderer.ClearAll();

   g_persistence.Initialize();

   const int timer_seconds = MathMax(1, InpRefreshSeconds);
   EventSetTimer(timer_seconds);

   RefreshSMC(true);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   if(InpRemoveObjectsOnDeinit)
      g_renderer.ClearAll();
}

void OnTimer()
{
   RefreshSMC(false);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   RefreshSMC(false);
   return rates_total;
}
