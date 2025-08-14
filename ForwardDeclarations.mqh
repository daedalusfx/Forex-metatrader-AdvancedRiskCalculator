//+------------------------------------------------------------------+
//|                                       ForwardDeclarations.mqh |
//|        اعلان توابع برای شکستن وابستگی‌های چرخه‌ای (Circular)       |
//+------------------------------------------------------------------+
#ifndef FORWARDDECLARATIONS_MQH
#define FORWARDDECLARATIONS_MQH

//--- اعلان توابع از فایل‌های Execution ---
// این به PanelDialog اجازه می‌دهد تا این توابع را بشناسد
// قبل از اینکه فایل‌های کامل آنها include شوند.

void SetupMarketTrade(ETradeState newState);
void SetupPendingTrade(ETradeState newState);
void SetupStairwayTrade(ETradeState newState);

#endif // FORWARDDECLARATIONS_MQH