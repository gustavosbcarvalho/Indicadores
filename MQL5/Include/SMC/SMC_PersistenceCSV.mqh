#ifndef SMC_PERSISTENCE_CSV_MQH
#define SMC_PERSISTENCE_CSV_MQH

#include "SMC_EventBus.mqh"

class CSMCPersistenceCSV
{
private:
   bool m_enabled;
   string m_file_name;
   int m_written_count;

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

public:
   CSMCPersistenceCSV()
   {
      m_enabled = true;
      m_file_name = "SMC_Observacional_WIN.csv";
      m_written_count = 0;
   }

   void Configure(const bool enabled, const string file_name)
   {
      m_enabled = enabled;
      m_file_name = file_name;
      m_written_count = 0;
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
         WriteHeader(handle);

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
      }

      m_written_count = total;
      FileClose(handle);
   }
};

#endif
