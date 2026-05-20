#ifndef SMC_EVENT_BUS_MQH
#define SMC_EVENT_BUS_MQH

#include "SMC_Types.mqh"

class CSMCEventBus
{
private:
   SMCEvent m_events[];
   string m_keys[];
   int m_limit;

   bool KeyExists(const string key)
   {
      const int total = ArraySize(m_keys);
      for(int i = 0; i < total; i++)
      {
         if(m_keys[i] == key)
            return true;
      }
      return false;
   }

public:
   CSMCEventBus()
   {
      m_limit = 2500;
   }

   void Configure(const int limit)
   {
      m_limit = MathMax(100, limit);
   }

   void Clear()
   {
      ArrayResize(m_events, 0);
      ArrayResize(m_keys, 0);
   }

   int Count()
   {
      return ArraySize(m_events);
   }

   bool Add(SMCEvent &event)
   {
      if(event.key == "")
         return false;

      if(KeyExists(event.key))
         return false;

      const int total = ArraySize(m_events);
      if(total >= m_limit)
         return false;

      ArrayResize(m_events, total + 1);
      ArrayResize(m_keys, total + 1);

      m_events[total] = event;
      m_keys[total] = event.key;
      return true;
   }

   bool AddEvent(const string symbol,
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
      SMCEvent event;
      SMCResetEvent(event);
      SMCFillEvent(event, symbol, timeframe, type, time, direction, price, price2,
                   score, mitigated, tag, details, suffix);
      return Add(event);
   }

   bool Get(const int index, SMCEvent &event)
   {
      if(index < 0 || index >= ArraySize(m_events))
         return false;

      event = m_events[index];
      return true;
   }
};

#endif
