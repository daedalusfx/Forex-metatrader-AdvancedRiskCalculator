//+------------------------------------------------------------------+
//|                                                  QtBridge.mqh |
//|         A Reusable Module for Qt Panel Communication (v1.0)      |
//+------------------------------------------------------------------+
#ifndef QT_BRIDGE_MQH
#define QT_BRIDGE_MQH

/*
    =================================================================
    === مستندات ماژول QtBridge ===
    =================================================================
    این ماژول یک پل ارتباطی کامل برای اتصال هر اکسپرت به پنل ATM Qt است.
    اکسپرتی که از این ماژول استفاده می‌کند باید فایل Defines.mqh را include کرده باشد
    و توابع کمکی مانند CalculateLiveTradeStats و SaveOriginalSLs را پیاده‌سازی کرده باشد.
*/


#include "Defines.mqh"
#include "SharedLogic.mqh"



// --- وارد کردن توابع DLL
#import "GriffinATM\\libGriffinATM.dll"
void InitializeService();
void FinalizeService();
void ShowGUIPanel();
void HideGUIPanel();
void SendDataToService(char& data[]);
int GetNextCommand(char &data[], int max_len);
void BroadcastFeedback(string jsonData); // تابع جدید را اینجا اضافه کنید
void SendFeedbackToUI(string jsonData);
#import

// --- Forward declarations for functions defined later in this file
void ProcessQtCommand(string command);
string GenerateQtPanelJSON();
void ProcessAutoManagement();



void OnTimer()
{
    string jsonData = GenerateQtPanelJSON();
    char jsonDataAnsi[];
    // --- START: DEBUG CODE ---
Print("OnTimer event fired! Preparing to send data.");
Print("Generated JSON: ", jsonData);
// --- END: DEBUG CODE ---
    if(StringToCharArray(jsonData, jsonDataAnsi, 0, WHOLE_ARRAY, CP_ACP) > 0) SendDataToService(jsonDataAnsi);
    
    char cmd_buffer[1024];
    int cmd_len;
    while((cmd_len = GetNextCommand(cmd_buffer, 1024)) > 0)
    {
        ProcessQtCommand(CharArrayToString(cmd_buffer, 0, cmd_len, CP_ACP));
    }
    
    ProcessAutoManagement(); // اجرای منطق ATM
}


void SendFeedbackToQt(string status, string message, ulong ticket=0)
{
    string feedback_data = StringFormat("{\"status\":\"%s\",\"message\":\"%s\",\"ticket\":%s}", status, message, (string)ticket);
    string final_json = StringFormat("{\"type\":\"feedback\",\"data\":%s}", feedback_data);
    BroadcastFeedback(final_json);
}
string GenerateQtPanelJSON()
{
    LiveTradeStats live_stats = CalculateLiveTradeStats();
    string trades_json = "";
    int count = 0;
    for(int i=PositionsTotal()-1; i>=0; i--)
    {
        ulong ticket=PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC)!=g_magic_number) continue;
        if(count>0) trades_json+=",";
        string type=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?"BUY":"SELL";
        bool is_be=(PositionGetDouble(POSITION_SL)==PositionGetDouble(POSITION_PRICE_OPEN));
        trades_json+=StringFormat("{\"ticket\":%s,\"symbol\":\"%s\",\"type\":\"%s\",\"volume\":%.2f,\"profit\":%.2f,\"is_breakeven\":%s,\"atm_enabled\":%s}",
            (string)ticket,PositionGetString(POSITION_SYMBOL),type,PositionGetDouble(POSITION_VOLUME),
            PositionGetDouble(POSITION_PROFIT),is_be?"true":"false",IsAtmEnabled(ticket)?"true":"false");
        count++;
    }
    // تنظیمات را به صورت رشته JSON بسازید
string settings_json = StringFormat("{\"triggerPercent\":%.1f,\"closePercent\":%.1f,\"moveToBE\":%s}",
    g_tradeRule.triggerPercent, 
    g_tradeRule.closePercent, 
    g_tradeRule.moveToBE ? "true" : "false");

// داده نهایی را در ساختار جدید بسته‌بندی کنید
string data_json = StringFormat("{\"total_pl\":%.2f,\"symbol\":\"%s\",\"trades\":[%s],\"settings\":%s}",
live_stats.total_pl,
_Symbol, // نام نماد هم اینجا اضافه می‌شود
trades_json,
settings_json);

// پیام نهایی را با فیلد type بسازید
return StringFormat("{\"type\":\"trade_data\",\"data\":%s}", data_json);
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
    else if(action == "toggle_atm_trade")
    {
        bool atm_state = GetJsonBool(command, "atm_trade_state");
        ToggleAtmForTicket(ticket, atm_state);
        string state_text = atm_state ? "فعال" : "غیرفعال";
        SendFeedbackToQt("success", "مدیریت خودکار برای معامله " + (string)ticket + " " + state_text + " شد.", ticket);
    }
}


void ProcessAutoManagement()
{
    if(!g_tradeRule.auto_trading_enabled || g_tradeRule.triggerPercent <= 0) return;
    for(int i=PositionsTotal()-1; i>=0; i--)
    {
        ulong ticket=PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL)!=_Symbol || WasRuleApplied(ticket) || !IsAtmEnabled(ticket)) continue;
        double tp=PositionGetDouble(POSITION_TP);
        if(tp==0.0) continue;
        double entry=PositionGetDouble(POSITION_PRICE_OPEN);
        double sl=PositionGetDouble(POSITION_SL);
        double dist=MathAbs(tp-entry);
        if(dist<=_Point*5) continue;
        double trigger_dist=dist*(g_tradeRule.triggerPercent/100.0);
        bool triggered=false;
        if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol,SYMBOL_BID)>=entry+trigger_dist) triggered=true;
        if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL && SymbolInfoDouble(_Symbol,SYMBOL_ASK)<=entry-trigger_dist) triggered=true;
        if(triggered)
        {
            bool success=true;
            if(g_tradeRule.closePercent>0 && g_tradeRule.closePercent<100)
            {
                double vol=PositionGetDouble(POSITION_VOLUME);
                double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
                int digits=VolumeDigits(_Symbol);
                double close_vol=floor(vol*(g_tradeRule.closePercent/100.0)/step)*step;
                if(close_vol>=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))
                    if(!trade.PositionClosePartial(ticket,close_vol)) success=false;
            }
            if(success && g_tradeRule.moveToBE && PositionGetDouble(POSITION_SL)!=entry)
            {
                StoreOriginalSL(ticket,sl);
                if(!trade.PositionModify(ticket,entry,tp)) success=false;
            }
            if(success) MarkRuleAsApplied(ticket);
        }
    }
}

#endif // QT_BRIDGE_MQH
