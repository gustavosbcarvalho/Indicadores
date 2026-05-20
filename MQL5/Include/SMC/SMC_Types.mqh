#ifndef SMC_TYPES_MQH
#define SMC_TYPES_MQH

enum ESMCDirection
{
   SMC_DIR_BEARISH = -1,
   SMC_DIR_NONE = 0,
   SMC_DIR_BULLISH = 1
};

enum ESMCEventType
{
   SMC_EVENT_SWING_HIGH = 1,
   SMC_EVENT_SWING_LOW = 2,
   SMC_EVENT_LIQUIDITY_SWEEP = 3,
   SMC_EVENT_BOS = 4,
   SMC_EVENT_CHOCH = 5,
   SMC_EVENT_FVG = 6,
   SMC_EVENT_EQUAL_HIGH = 7,
   SMC_EVENT_EQUAL_LOW = 8,
   SMC_EVENT_DISPLACEMENT = 9,
   SMC_EVENT_VWAP_CONTEXT = 10,
   SMC_EVENT_CONTINUATION = 11,
   SMC_EVENT_MEAN_REVERSION = 12,
   SMC_EVENT_SCORE = 13
};

enum ESMCScoreClass
{
   SMC_SCORE_NOISY = 0,
   SMC_SCORE_WEAK = 1,
   SMC_SCORE_MEDIUM = 2,
   SMC_SCORE_STRONG = 3
};

struct SMCSwingPoint
{
   bool valid;
   datetime time;
   double price;
   ESMCDirection direction;
   int index;
   double strength_points;
   string key;
};

struct SMCSweepContext
{
   bool valid;
   datetime time;
   double level;
   double close_price;
   ESMCDirection direction;
   double strength_points;
   string key;
};

struct SMCStructureContext
{
   bool has_bos;
   bool has_choch;
   bool bos_aligned;
   bool has_displacement;
   datetime bos_time;
   datetime choch_time;
   datetime displacement_time;
   ESMCDirection bos_direction;
   ESMCDirection choch_direction;
   ESMCDirection displacement_direction;
   ESMCDirection trend_direction;
   double displacement_ratio;
};

struct SMCFVGZone
{
   bool valid;
   datetime start_time;
   datetime end_time;
   double lower;
   double upper;
   ESMCDirection direction;
   bool mitigated;
   string key;
};

struct SMCFVGContext
{
   bool has_aligned_fvg;
   int total_open_zones;
   SMCFVGZone latest_aligned;
};

struct SMCVWAPState
{
   bool valid;
   datetime time;
   double value;
   double close_price;
   ESMCDirection direction;
   double distance_points;
};

struct SMCScoreState
{
   datetime time;
   int value;
   ESMCScoreClass klass;
   ESMCDirection direction;
   bool continuation;
   bool mean_reversion;
   string notes;
};

struct SMCEvent
{
   string key;
   datetime time;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   ESMCEventType type;
   ESMCDirection direction;
   double price;
   double price2;
   int score;
   bool mitigated;
   string tag;
   string details;
};

void SMCResetSwing(SMCSwingPoint &swing)
{
   swing.valid = false;
   swing.time = 0;
   swing.price = 0.0;
   swing.direction = SMC_DIR_NONE;
   swing.index = -1;
   swing.strength_points = 0.0;
   swing.key = "";
}

void SMCResetSweepContext(SMCSweepContext &context)
{
   context.valid = false;
   context.time = 0;
   context.level = 0.0;
   context.close_price = 0.0;
   context.direction = SMC_DIR_NONE;
   context.strength_points = 0.0;
   context.key = "";
}

void SMCResetStructureContext(SMCStructureContext &context)
{
   context.has_bos = false;
   context.has_choch = false;
   context.bos_aligned = false;
   context.has_displacement = false;
   context.bos_time = 0;
   context.choch_time = 0;
   context.displacement_time = 0;
   context.bos_direction = SMC_DIR_NONE;
   context.choch_direction = SMC_DIR_NONE;
   context.displacement_direction = SMC_DIR_NONE;
   context.trend_direction = SMC_DIR_NONE;
   context.displacement_ratio = 0.0;
}

void SMCResetFVGZone(SMCFVGZone &zone)
{
   zone.valid = false;
   zone.start_time = 0;
   zone.end_time = 0;
   zone.lower = 0.0;
   zone.upper = 0.0;
   zone.direction = SMC_DIR_NONE;
   zone.mitigated = false;
   zone.key = "";
}

void SMCResetFVGContext(SMCFVGContext &context)
{
   context.has_aligned_fvg = false;
   context.total_open_zones = 0;
   SMCResetFVGZone(context.latest_aligned);
}

void SMCResetVWAPState(SMCVWAPState &state)
{
   state.valid = false;
   state.time = 0;
   state.value = 0.0;
   state.close_price = 0.0;
   state.direction = SMC_DIR_NONE;
   state.distance_points = 0.0;
}

void SMCResetScoreState(SMCScoreState &state)
{
   state.time = 0;
   state.value = 0;
   state.klass = SMC_SCORE_NOISY;
   state.direction = SMC_DIR_NONE;
   state.continuation = false;
   state.mean_reversion = false;
   state.notes = "";
}

void SMCResetEvent(SMCEvent &event)
{
   event.key = "";
   event.time = 0;
   event.symbol = "";
   event.timeframe = PERIOD_CURRENT;
   event.type = SMC_EVENT_SCORE;
   event.direction = SMC_DIR_NONE;
   event.price = 0.0;
   event.price2 = 0.0;
   event.score = 0;
   event.mitigated = false;
   event.tag = "";
   event.details = "";
}

string SMCDirectionToString(const ESMCDirection direction)
{
   if(direction == SMC_DIR_BULLISH)
      return "BULLISH";
   if(direction == SMC_DIR_BEARISH)
      return "BEARISH";
   return "NONE";
}

string SMCEventTypeToString(const ESMCEventType type)
{
   switch(type)
   {
      case SMC_EVENT_SWING_HIGH: return "SWING_HIGH";
      case SMC_EVENT_SWING_LOW: return "SWING_LOW";
      case SMC_EVENT_LIQUIDITY_SWEEP: return "LIQUIDITY_SWEEP";
      case SMC_EVENT_BOS: return "BOS";
      case SMC_EVENT_CHOCH: return "CHOCH";
      case SMC_EVENT_FVG: return "FVG";
      case SMC_EVENT_EQUAL_HIGH: return "EQUAL_HIGH";
      case SMC_EVENT_EQUAL_LOW: return "EQUAL_LOW";
      case SMC_EVENT_DISPLACEMENT: return "DISPLACEMENT";
      case SMC_EVENT_VWAP_CONTEXT: return "VWAP_CONTEXT";
      case SMC_EVENT_CONTINUATION: return "CONTINUATION";
      case SMC_EVENT_MEAN_REVERSION: return "MEAN_REVERSION";
      case SMC_EVENT_SCORE: return "SCORE";
   }
   return "UNKNOWN";
}

string SMCScoreClassToString(const ESMCScoreClass klass)
{
   if(klass == SMC_SCORE_STRONG)
      return "STRONG";
   if(klass == SMC_SCORE_MEDIUM)
      return "MEDIUM";
   if(klass == SMC_SCORE_WEAK)
      return "WEAK";
   return "NOISY";
}

string SMCTimeframeToString(const ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      default: return EnumToString(timeframe);
   }
}

string SMCBoolToString(const bool value)
{
   return (value ? "true" : "false");
}

double SMCPriceToPoints(const double price_delta, const double point)
{
   if(point <= 0.0)
      return 0.0;
   return MathAbs(price_delta) / point;
}

string SMCTimeToKey(const datetime value)
{
   return IntegerToString((long)value);
}

string SMCObjectSafe(string value)
{
   StringReplace(value, " ", "_");
   StringReplace(value, ":", "_");
   StringReplace(value, ".", "_");
   StringReplace(value, "-", "_");
   StringReplace(value, "/", "_");
   return value;
}

string SMCMakeEventKey(const string symbol,
                       const ENUM_TIMEFRAMES timeframe,
                       const ESMCEventType type,
                       const datetime time,
                       const double price,
                       const string suffix)
{
   string key = symbol + "_" + SMCTimeframeToString(timeframe) + "_" +
                SMCEventTypeToString(type) + "_" + SMCTimeToKey(time) + "_" +
                DoubleToString(price, 2);

   if(suffix != "")
      key += "_" + suffix;

   return SMCObjectSafe(key);
}

void SMCFillEvent(SMCEvent &event,
                  const string symbol,
                  const ENUM_TIMEFRAMES timeframe,
                  const ESMCEventType type,
                  const datetime time,
                  const ESMCDirection direction,
                  const double price,
                  const double price2,
                  const int score,
                  const bool mitigated,
                  const string tag,
                  const string details,
                  const string suffix = "")
{
   event.symbol = symbol;
   event.timeframe = timeframe;
   event.type = type;
   event.time = time;
   event.direction = direction;
   event.price = price;
   event.price2 = price2;
   event.score = score;
   event.mitigated = mitigated;
   event.tag = tag;
   event.details = details;
   event.key = SMCMakeEventKey(symbol, timeframe, type, time, price, suffix);
}

#endif
