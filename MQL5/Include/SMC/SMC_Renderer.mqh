#ifndef SMC_RENDERER_MQH
#define SMC_RENDERER_MQH

#include "SMC_ScoreEngine.mqh"

class CSMCRenderer
{
private:
   string m_prefix;
   bool m_enabled;
   double m_point;
   int m_line_extend_bars;
   int m_fvg_extend_bars;
   int m_max_render_events;
   ENUM_BASE_CORNER m_panel_corner;

   color m_bullish_color;
   color m_bearish_color;
   color m_sweep_color;
   color m_bos_color;
   color m_choch_color;
   color m_fvg_bullish_color;
   color m_fvg_bearish_color;
   color m_fvg_mitigated_color;
   color m_text_color;
   color m_panel_back_color;

   string NameFor(const string suffix)
   {
      return m_prefix + "_" + SMCObjectSafe(suffix);
   }

   color DirectionColor(const ESMCDirection direction)
   {
      if(direction == SMC_DIR_BULLISH)
         return m_bullish_color;
      if(direction == SMC_DIR_BEARISH)
         return m_bearish_color;
      return m_text_color;
   }

   color EventColor(SMCEvent &event)
   {
      if(event.type == SMC_EVENT_LIQUIDITY_SWEEP)
         return m_sweep_color;
      if(event.type == SMC_EVENT_BOS)
         return m_bos_color;
      if(event.type == SMC_EVENT_CHOCH)
         return m_choch_color;
      if(event.type == SMC_EVENT_FVG)
      {
         if(event.mitigated)
            return m_fvg_mitigated_color;
         return (event.direction == SMC_DIR_BULLISH ? m_fvg_bullish_color : m_fvg_bearish_color);
      }
      return DirectionColor(event.direction);
   }

   void CommonObjectStyle(const string name)
   {
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   void DrawRay(const string name,
                const datetime time,
                const double price,
                const color line_color,
                const ENUM_LINE_STYLE style,
                const int width)
   {
      const datetime end_time = time + (datetime)(PeriodSeconds(PERIOD_M5) * m_line_extend_bars);

      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_TREND, 0, time, price, end_time, price);

      ObjectMove(0, name, 0, time, price);
      ObjectMove(0, name, 1, end_time, price);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      CommonObjectStyle(name);
   }

   void DrawArrow(const string name,
                  const datetime time,
                  const double price,
                  const ESMCDirection direction,
                  const color arrow_color)
   {
      const int arrow_code = (direction == SMC_DIR_BEARISH ? 234 : 233);
      const double offset = (direction == SMC_DIR_BEARISH ? 25.0 * m_point : -25.0 * m_point);
      const double arrow_price = price + offset;

      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_ARROW, 0, time, arrow_price);

      ObjectMove(0, name, 0, time, arrow_price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetInteger(0, name, OBJPROP_COLOR, arrow_color);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      CommonObjectStyle(name);
   }

   void DrawText(const string name,
                 const datetime time,
                 const double price,
                 const string text,
                 const color text_color)
   {
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_TEXT, 0, time, price);

      ObjectMove(0, name, 0, time, price);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      CommonObjectStyle(name);
   }

   void DrawFVG(SMCEvent &event)
   {
      const string name = NameFor(event.key + "_BOX");
      const datetime end_time = TimeCurrent() + (datetime)(PeriodSeconds(PERIOD_M1) * m_fvg_extend_bars);
      const color zone_color = EventColor(event);

      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, event.time, event.price2, end_time, event.price);

      ObjectMove(0, name, 0, event.time, event.price2);
      ObjectMove(0, name, 1, end_time, event.price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, zone_color);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      CommonObjectStyle(name);

      const string label = (event.mitigated ? "FVG MITIGATED" : event.tag);
      DrawText(NameFor(event.key + "_TXT"), event.time, event.price2, label, zone_color);
   }

   string EventLabel(SMCEvent &event)
   {
      if(event.type == SMC_EVENT_LIQUIDITY_SWEEP)
         return event.tag;
      if(event.type == SMC_EVENT_BOS)
         return "BOS " + SMCDirectionToString(event.direction);
      if(event.type == SMC_EVENT_CHOCH)
         return "CHOCH " + SMCDirectionToString(event.direction);
      if(event.type == SMC_EVENT_DISPLACEMENT)
         return "DISP " + SMCDirectionToString(event.direction);
      if(event.type == SMC_EVENT_CONTINUATION)
         return "CONTINUATION " + IntegerToString(event.score);
      if(event.type == SMC_EVENT_MEAN_REVERSION)
         return "MEAN REVERSION " + IntegerToString(event.score);
      return event.tag;
   }

   void RenderEvent(SMCEvent &event)
   {
      if(event.type == SMC_EVENT_SCORE || event.type == SMC_EVENT_VWAP_CONTEXT)
         return;

      if(event.type == SMC_EVENT_FVG)
      {
         DrawFVG(event);
         return;
      }

      const color event_color = EventColor(event);
      const string base_name = NameFor(event.key);

      if(event.type == SMC_EVENT_SWING_HIGH ||
         event.type == SMC_EVENT_SWING_LOW ||
         event.type == SMC_EVENT_EQUAL_HIGH ||
         event.type == SMC_EVENT_EQUAL_LOW)
      {
         const ENUM_LINE_STYLE style = (event.type == SMC_EVENT_EQUAL_HIGH ||
                                        event.type == SMC_EVENT_EQUAL_LOW ? STYLE_DOT : STYLE_DASH);
         DrawRay(base_name + "_LINE", event.time, event.price, event_color, style, 1);
         DrawText(base_name + "_TXT", event.time, event.price, event.tag, event_color);
         return;
      }

      DrawArrow(base_name + "_ARW", event.time, event.price, event.direction, event_color);
      DrawText(base_name + "_TXT", event.time,
               event.price + (event.direction == SMC_DIR_BEARISH ? 35.0 * m_point : -35.0 * m_point),
               EventLabel(event), event_color);
   }

   void DrawPanelLine(const int row, const string text, const color text_color)
   {
      const string name = NameFor("PANEL_" + IntegerToString(row));
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0, name, OBJPROP_CORNER, m_panel_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 18 + row * 16);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      CommonObjectStyle(name);
   }

   void DrawCurrentVWAP(SMCVWAPState &vwap)
   {
      if(!vwap.valid)
         return;

      const string name = NameFor("CURRENT_VWAP");
      const datetime start_time = vwap.time - (datetime)(PeriodSeconds(PERIOD_M1) * 120);
      const datetime end_time = TimeCurrent() + (datetime)(PeriodSeconds(PERIOD_M1) * 60);

      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_TREND, 0, start_time, vwap.value, end_time, vwap.value);

      ObjectMove(0, name, 0, start_time, vwap.value);
      ObjectMove(0, name, 1, end_time, vwap.value);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_COLOR, m_text_color);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      CommonObjectStyle(name);
   }

public:
   CSMCRenderer()
   {
      m_prefix = "SMC_OBS";
      m_enabled = true;
      m_point = _Point;
      m_line_extend_bars = 120;
      m_fvg_extend_bars = 120;
      m_max_render_events = 350;
      m_panel_corner = CORNER_LEFT_UPPER;

      m_bullish_color = C'0,180,90';
      m_bearish_color = C'220,70,70';
      m_sweep_color = C'255,190,0';
      m_bos_color = C'0,150,255';
      m_choch_color = C'190,120,255';
      m_fvg_bullish_color = C'40,130,90';
      m_fvg_bearish_color = C'160,70,70';
      m_fvg_mitigated_color = C'120,120,120';
      m_text_color = C'235,235,235';
      m_panel_back_color = C'20,20,20';
   }

   void Configure(const string prefix,
                  const bool enabled,
                  const double point,
                  const int line_extend_bars,
                  const int fvg_extend_bars,
                  const int max_render_events,
                  const color bullish_color,
                  const color bearish_color,
                  const color sweep_color,
                  const color bos_color,
                  const color choch_color,
                  const color fvg_bullish_color,
                  const color fvg_bearish_color,
                  const color fvg_mitigated_color,
                  const color text_color)
   {
      m_prefix = prefix;
      m_enabled = enabled;
      m_point = point;
      m_line_extend_bars = MathMax(20, line_extend_bars);
      m_fvg_extend_bars = MathMax(20, fvg_extend_bars);
      m_max_render_events = MathMax(50, max_render_events);
      m_bullish_color = bullish_color;
      m_bearish_color = bearish_color;
      m_sweep_color = sweep_color;
      m_bos_color = bos_color;
      m_choch_color = choch_color;
      m_fvg_bullish_color = fvg_bullish_color;
      m_fvg_bearish_color = fvg_bearish_color;
      m_fvg_mitigated_color = fvg_mitigated_color;
      m_text_color = text_color;
   }

   void ClearAll()
   {
      const int total = ObjectsTotal(0, -1, -1);
      for(int i = total - 1; i >= 0; i--)
      {
         const string name = ObjectName(0, i, -1, -1);
         if(StringFind(name, m_prefix) == 0)
            ObjectDelete(0, name);
      }
   }

   void Render(CSMCEventBus &bus,
               SMCScoreState &score,
               SMCSweepContext &sweep,
               SMCStructureContext &structure,
               SMCVWAPState &vwap,
               SMCFVGContext &fvg)
   {
      if(!m_enabled)
         return;

      const int total = bus.Count();
      int start = total - m_max_render_events;
      if(start < 0)
         start = 0;

      for(int i = start; i < total; i++)
      {
         SMCEvent event;
         SMCResetEvent(event);
         if(bus.Get(i, event))
            RenderEvent(event);
      }

      DrawCurrentVWAP(vwap);

      const color score_color = (score.klass == SMC_SCORE_STRONG ? m_bullish_color :
                                (score.klass == SMC_SCORE_MEDIUM ? m_sweep_color :
                                (score.klass == SMC_SCORE_WEAK ? m_choch_color : m_bearish_color)));

      DrawPanelLine(0, "SMC OBSERVACIONAL WIN", m_text_color);
      DrawPanelLine(1, "Score: " + IntegerToString(score.value) + " " +
                    SMCScoreClassToString(score.klass), score_color);
      DrawPanelLine(2, "Direcao: " + SMCDirectionToString(score.direction), DirectionColor(score.direction));
      DrawPanelLine(3, "Tendencia M1: " + SMCDirectionToString(structure.trend_direction),
                    DirectionColor(structure.trend_direction));
      DrawPanelLine(4, "Sweep M5: " + (sweep.valid ? SMCDirectionToString(sweep.direction) : "NONE"),
                    (sweep.valid ? DirectionColor(sweep.direction) : m_text_color));
      DrawPanelLine(5, "FVG aberto: " + IntegerToString(fvg.total_open_zones) +
                    " | alinhado: " + SMCBoolToString(fvg.has_aligned_fvg), m_text_color);
      DrawPanelLine(6, "VWAP: " + (vwap.valid ? DoubleToString(vwap.value, 2) : "n/a") +
                    " | dist pts: " + (vwap.valid ? DoubleToString(vwap.distance_points, 1) : "n/a"),
                    m_text_color);
      DrawPanelLine(7, "Contexto: " +
                    (score.continuation ? "CONTINUATION" :
                    (score.mean_reversion ? "MEAN REVERSION" : "OBSERVATION")),
                    score_color);
   }
};

#endif
