//+------------------------------------------------------------------+
//|                                                  QtBridge.mqh |
//|        A Reusable Module for Qt Panel Communication (v1.0)       |
//|                                     Created by Gemini & User       |
//+------------------------------------------------------------------+
#ifndef QT_BRIDGE_MQH
#define QT_BRIDGE_MQH

/*
    =================================================================
    === مستندات ماژول QtBridge ===
    =================================================================
    این ماژول یک پل ارتباطی کامل برای اتصال هر اکسپرت به یک پنل Qt است.

    **نیازمندی‌ها برای اکسپرتی که از این ماژول استفاده می‌کند:**

    1.  **متغیرهای گلوبال:** اکسپرت باید متغیرهای زیر را تعریف کرده باشد:
        - CTrade trade;
        - long g_magic_number;
        - ulong g_slTickets[];
        - double g_slValues[];
        - string SL_Backup_File;

    2.  **توابع ضروری:** اکسپرت باید توابع زیر را پیاده‌سازی کرده باشد:
        - LiveTradeStats CalculateLiveTradeStats();
        - void SaveOriginalSLs();

    3.  **فراخوانی‌ها:**
        - در OnInit(): فراخوانی ShowPanel() و EventSetTimer(1).
        - در OnDeinit(): فراخوانی ClosePanel() و EventKillTimer().
*/

// ==================================================================
// === بخش ۱: وارد کردن توابع DLL ===
// ==================================================================
#import "GriffinATM\\libGriffinATM.dll"
void ShowPanel();
void ClosePanel();
void SendDataToUI(char& data[]);
int GetNextCommand(char &data[], int max_len);
void SendFeedbackToUI(string jsonData);
#import




ulong g_slTickets[];
double g_slValues[];
string SL_Backup_File;

// ==================================================================
// === بخش ۲: توابع کمکی (Helper Functions) ===
// ==================================================================
// این توابع کمکی فقط در این ماژول استفاده می‌شوند
namespace QtBridge_Helpers
{
    string GetJsonString(string json,string key){string sk="\""+key+"\":\"";int sp=StringFind(json,sk);if(sp<0)return"";sp+=StringLen(sk);int ep=StringFind(json,"\"",sp);if(ep<0)return"";return StringSubstr(json,sp,ep-sp);}
    ulong GetJsonUlong(string json, string key){string sk="\""+key+"\":";int sp=StringFind(json,sk);if(sp<0)return 0;sp+=StringLen(sk);int ep=StringFind(json,",",sp);if(ep<0)ep=StringFind(json,"}",sp);if(ep<0)return 0;return(ulong)StringToInteger(StringSubstr(json,sp,ep-sp));}
    int FindSLIndex(ulong ticket){for(int i=0;i<ArraySize(g_slTickets);i++)if(g_slTickets[i]==ticket)return i;return -1;}
    void StoreOriginalSL(ulong ticket,double sl_value){if(sl_value==0.0)return;int index=FindSLIndex(ticket);if(index==-1){int size=ArraySize(g_slTickets);ArrayResize(g_slTickets,size+1);ArrayResize(g_slValues,size+1);g_slTickets[size]=ticket;g_slValues[size]=sl_value;}else{g_slValues[index]=sl_value;}SaveOriginalSLs();}
}
// Using namespace to avoid function name collisions
using namespace QtBridge_Helpers;

// ==================================================================
// === بخش ۳: هسته اصلی ارتباط (OnTimer و توابع مرتبط) ===
// ==================================================================

//+------------------------------------------------------------------+
//| ارسال بازخورد به پنل Qt
//+------------------------------------------------------------------+
void SendFeedbackToQt(string status, string message, ulong ticket = 0)
{
    string payload = StringFormat("{\"status\":\"%s\",\"message\":\"%s\",\"ticket\":%s}", status, message, (string)ticket);
    SendFeedbackToUI(payload);
}

//+------------------------------------------------------------------+
//| پردازش دستورات دریافتی از پنل Qt
//+------------------------------------------------------------------+
void ProcessQtCommand(string command)
{
    Print("Command from Qt UI: ", command);
    string action = GetJsonString(command, "action");
    ulong ticket = GetJsonUlong(command, "ticket");

    if(action == "close" && ticket != 0) {
        if(!trade.PositionClose(ticket)) SendFeedbackToQt("error", "خطا در بستن معامله. کد: " + (string)GetLastError(), ticket);
        else SendFeedbackToQt("success", "معامله با موفقیت بسته شد.", ticket);
    }
    else if(action == "breakeven" && ticket != 0)
    {
        if(PositionSelectByTicket(ticket) && PositionGetDouble(POSITION_PROFIT) > 0) {
            StoreOriginalSL(ticket, PositionGetDouble(POSITION_SL));
            if(!trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_TP))) SendFeedbackToQt("error", "خطا در ریسک-فری کردن. کد: " + (string)GetLastError(), ticket);
            else SendFeedbackToQt("success", "معامله با موفقیت ریسک-فری شد.", ticket);
        }
    }
    else if(action == "restore_breakeven" && ticket != 0)
    {
        int sl_index = FindSLIndex(ticket);
        if(sl_index != -1 && PositionSelectByTicket(ticket)) {
            if(!trade.PositionModify(ticket, g_slValues[sl_index], PositionGetDouble(POSITION_TP))) SendFeedbackToQt("error", "خطا در بازگرداندن حد ضرر. کد: " + (string)GetLastError(), ticket);
            else {
                SendFeedbackToQt("success", "حد ضرر با موفقیت بازگردانده شد.", ticket);
                ArrayRemove(g_slTickets, sl_index, 1);
                ArrayRemove(g_slValues, sl_index, 1);
                SaveOriginalSLs();
            }
        } else SendFeedbackToQt("warning", "حد ضرر اولیه برای بازگرداندن یافت نشد.", ticket);
    }
    else if(action == "close_all")
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--) if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == g_magic_number) trade.PositionClose(PositionGetTicket(i));
        SendFeedbackToQt("success", "دستور بستن همه معاملات ارسال شد.", 0);
    }
    else if(action == "close_profits")
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--) if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == g_magic_number && PositionGetDouble(POSITION_PROFIT) > 0) trade.PositionClose(PositionGetTicket(i));
        SendFeedbackToQt("success", "دستور بستن معاملات سودده ارسال شد.", 0);
    }
    else if(action == "close_losses")
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--) if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == g_magic_number && PositionGetDouble(POSITION_PROFIT) < 0) trade.PositionClose(PositionGetTicket(i));
        SendFeedbackToQt("success", "دستور بستن معاملات ضررده ارسال شد.", 0);
    }
}

//+------------------------------------------------------------------+
//| ساخت JSON مخصوص پنل Qt
//+------------------------------------------------------------------+
string GenerateQtPanelJSON()
{
    LiveTradeStats live_stats = CalculateLiveTradeStats();
    string trades_json_array = "";
    int trade_count = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC) != g_magic_number) continue;
        
        if(trade_count > 0) { trades_json_array += ","; }
        
        string type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
        bool is_be = (PositionGetDouble(POSITION_SL) == PositionGetDouble(POSITION_PRICE_OPEN));
        
        string single_trade_json = StringFormat(
            "{\"ticket\":%s,\"symbol\":\"%s\",\"type\":\"%s\",\"volume\":%.2f,\"profit\":%.2f,\"is_breakeven\":%s, \"atm_enabled\":%s}",
            (string)ticket, PositionGetString(POSITION_SYMBOL), type, PositionGetDouble(POSITION_VOLUME),
            PositionGetDouble(POSITION_PROFIT), is_be ? "true" : "false", "false"
        );
        trades_json_array += single_trade_json;
        trade_count++;
    }

    string payload = StringFormat("{\"total_pl\":%.2f, \"trades\":[%s]}", live_stats.total_pl, trades_json_array);
    return payload;
}

//+------------------------------------------------------------------+
//| OnTimer - مرکز ارتباط
//+------------------------------------------------------------------+
void OnTimer()
{
    string jsonData = GenerateQtPanelJSON();
    char jsonDataAnsi[];
    int len = StringToCharArray(jsonData, jsonDataAnsi, 0, WHOLE_ARRAY, CP_ACP);
    if (len > 0) SendDataToUI(jsonDataAnsi);
    
    char command_buffer[1024];
    int command_len;
    while((command_len = GetNextCommand(command_buffer, 1024)) > 0)
    {
        string command = CharArrayToString(command_buffer, 0, command_len, CP_ACP);
        ProcessQtCommand(command);
    }
}

#endif // QT_BRIDGE_MQH
