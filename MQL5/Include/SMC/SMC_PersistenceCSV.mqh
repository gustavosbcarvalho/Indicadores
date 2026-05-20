#ifndef SMC_PERSISTENCE_CSV_MQH
#define SMC_PERSISTENCE_CSV_MQH

#include "SMC_EventBus.mqh"

class CSMCPersistenceCSV
{
private:
   bool m_enabled;
   bool m_debug_logs;
   string m_file_name;
   int m_written_count;
   string m_persisted_keys[];

   bool KeyExists(const string key)
   {
      const int total = ArraySize(m_persisted_keys);
      for(int i = 0; i < total; i++)
      {
         if(m_persisted_keys[i] == key)
            return true;
      }
      return false;
   }

   void RememberKey(const string key)
   {
      if(key == "" || KeyExists(key))
         return;

      const int total = ArraySize(m_persisted_keys);
      ArrayResize(m_persisted_keys, total + 1);
      m_persisted_keys[total] = key;
   }

   void WriteHeader(const int handle)
   {
      FileWrite(handle,
                "timestamp",
                "symbol",
                "timeframe",
                "event_type",
                "direction",
                "price",
                "price2",
                "score",
                "mitigated",
                "tag",
                "details",
                "key");
   }

   void LoadExistingKeys(const int handle)
   {
      ArrayResize(m_persisted_keys, 0);
      FileSeek(handle, 0, SEEK_SET);

      bool first_row = true;
      while(!FileIsEnding(handle))
      {
         string timestamp = FileReadString(handle);
         string symbol = FileReadString(handle);
         string timeframe = FileReadString(handle);
         string event_type = FileReadString(handle);
         string direction = FileReadString(handle);
         string price = FileReadString(handle);
         string price2 = FileReadString(handle);
         string score = FileReadString(handle);
         string mitigated = FileReadString(handle);
         string tag = FileReadString(handle);
         string details = FileReadString(handle);
         string key = FileReadString(handle);

         if(first_row)
         {
            first_row = false;
            if(timestamp == "timestamp" && key == "key")
               continue;
         }

         if(key != "")
            RememberKey(key);
      }
   }

   void DebugLog(const string message)
   {
      if(m_debug_logs)
         Print(message);
   }

public:
   CSMCPersistenceCSV()
   {
      m_enabled = true;
      m_debug_logs = false;
      m_file_name = "SMC_Observacional_WIN.csv";
      m_written_count = 0;
   }

   void Configure(const bool enabled, const string file_name, const bool debug_logs)
   {
      m_enabled = enabled;
      m_debug_logs = debug_logs;
      m_file_name = file_name;
      m_written_count = 0;
      ArrayResize(m_persisted_keys, 0);
   }

   bool Initialize()
   {
      if(!m_enabled)
         return true;

      const bool exists = FileIsExist(m_file_name);
      const int handle = FileOpen(m_file_name,
                                  FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ,
                                  ';');
      if(handle == INVALID_HANDLE)
      {
         Print("SMC CSV: nao foi possivel abrir arquivo: ", m_file_name,
               " erro=", GetLastError());
         return false;
      }

      if(!exists || FileSize(handle) == 0)
      {
         WriteHeader(handle);
         DebugLog("SMC CSV: header criado em " + m_file_name);
      }
      else
      {
         LoadExistingKeys(handle);
         DebugLog("SMC CSV: chaves carregadas de " + m_file_name +
                  " total=" + IntegerToString(ArraySize(m_persisted_keys)));
      }

      FileClose(handle);
      return true;
   }

   void PersistNewEvents(CSMCEventBus &bus)
   {
      if(!m_enabled)
         return;

      const int total = bus.Count();
      if(total <= m_written_count)
         return;

      const int handle = FileOpen(m_file_name,
                                  FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ,
                                  ';');
      if(handle == INVALID_HANDLE)
      {
         Print("SMC CSV: falha ao persistir eventos: ", m_file_name,
               " erro=", GetLastError());
         return;
      }

      FileSeek(handle, 0, SEEK_END);

      for(int i = m_written_count; i < total; i++)
      {
         SMCEvent event;
         SMCResetEvent(event);
         if(!bus.Get(i, event))
            continue;

         if(KeyExists(event.key))
            continue;

         FileWrite(handle,
                   TimeToString(event.time, TIME_DATE | TIME_SECONDS),
                   event.symbol,
                   SMCTimeframeToString(event.timeframe),
                   SMCEventTypeToString(event.type),
                   SMCDirectionToString(event.direction),
                   DoubleToString(event.price, 2),
                   DoubleToString(event.price2, 2),
                   event.score,
                   SMCBoolToString(event.mitigated),
                   event.tag,
                   event.details,
                   event.key);

         RememberKey(event.key);
      }

      m_written_count = total;
      FileClose(handle);
   }
};

#endif
