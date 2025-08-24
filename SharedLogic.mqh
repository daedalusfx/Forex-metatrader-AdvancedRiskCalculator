//+------------------------------------------------------------------+
//|                                                SharedLogic.mqh |
//|         V2.2 - اصلاح حلقه بررسی پوزیشن‌ها در تابع ایمنی          |
//+------------------------------------------------------------------+
#ifndef SHAREDLOGIC_MQH
#define SHAREDLOGIC_MQH
#include <Trade/Trade.mqh> // <--- اصلاح کلیدی
// Forward declaration
void UpdateDisplayData();

//--- محاسبه حجم لات (بدون تغییر)
bool CalculateLotSize(double entry, double sl, double &lot_size, double &risk_in_money)
{
    lot_size = 0;
    risk_in_money = 0;
    string risk_input_str = (ExtDialog.GetCurrentState() == STATE_PREP_MARKET_BUY || ExtDialog.GetCurrentState() == STATE_PREP_MARKET_SELL) ? 
                            ExtDialog.GetRiskInput("market") : ExtDialog.GetRiskInput("pending");

    double risk_value = StringToDouble(risk_input_str);
    if(risk_value <= 0) return false;

    if(InpRiskMode == RISK_PERCENT)
    {
        risk_in_money = AccountInfoDouble(ACCOUNT_BALANCE) * (risk_value / 100.0);
    }
    else
    {
        risk_in_money = risk_value;
    }

    if(risk_in_money <= 0) return false;

    ENUM_ORDER_TYPE order_type = (sl < entry) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    double loss_for_one_lot = 0;
    if(!OrderCalcProfit(order_type, _Symbol, 1.0, entry, sl, loss_for_one_lot))
    {
        Print("OrderCalcProfit() failed. Error: ", GetLastError());
        return false;
    }
    
    loss_for_one_lot = MathAbs(loss_for_one_lot);
    if(loss_for_one_lot <= 0.00001) return false;
    
    lot_size = risk_in_money / loss_for_one_lot;

    double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    lot_size = MathFloor(lot_size / vol_step) * vol_step;
    if(lot_size < min_vol) lot_size = 0;
    lot_size = MathMin(lot_size, max_vol);

    return (lot_size > 0);
}


//+------------------------------------------------------------------+
//| (نسخه نهایی و کاملاً اصلاح شده) بررسی ایمنی معامله                 |
//+------------------------------------------------------------------+
bool IsTradeRequestSafe(double lot_size, ENUM_ORDER_TYPE order_type, double price, double sl, double tp)
{
    // --- 1. بررسی‌های اولیه ---
    double required_margin = 0;
    if(!OrderCalcMargin(order_type, _Symbol, lot_size, price, required_margin))
    {
        Alert("Margin calculation failed. Error: ", GetLastError());
        return false;
    }
    if(required_margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE) * (InpMaxMarginUsagePercent / 100.0))
    {
        Alert("Not enough free margin.");
        return false;
    }
    
    // --- 2. شبیه‌سازی بدترین حالت برای قوانین پراپ ---
    if(g_prop_rules_active)
    {
        double total_potential_loss = 0;
        
        double new_trade_loss = 0;
        if(sl > 0 && OrderCalcProfit(order_type, _Symbol, lot_size, price, sl, new_trade_loss))
        {
            total_potential_loss += MathAbs(new_trade_loss);
        }
        else if (sl > 0)
        {
            Alert("Could not calculate potential loss for the new trade. Request rejected.");
            return false;
        }

        // --- حلقه اصلاح شده ---
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {

            ulong ticket = PositionGetTicket(i); // <-- تغییر
            if(PositionSelectByTicket(ticket))   // <<<<<<< اصلاح کلیدی
            {
                if(PositionGetInteger(POSITION_MAGIC) == g_magic_number)
                {
                    string pos_symbol = PositionGetString(POSITION_SYMBOL); 
                    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                    double stop_loss = PositionGetDouble(POSITION_SL);
                    double volume = PositionGetDouble(POSITION_VOLUME);
                    long type = PositionGetInteger(POSITION_TYPE);
                    
                    double existing_trade_loss = 0;
                    if(stop_loss > 0)
                    {
                        if(OrderCalcProfit((ENUM_ORDER_TYPE)type, pos_symbol, volume, open_price, stop_loss, existing_trade_loss))
                        {
                            total_potential_loss += MathAbs(existing_trade_loss);
                        }
                    }
                }
            }
        }
        
        double worst_case_balance = AccountInfoDouble(ACCOUNT_BALANCE) - total_potential_loss;
        string currency = AccountInfoString(ACCOUNT_CURRENCY);

        double daily_dd_limit_level = g_start_of_day_base * (1 - InpMaxDailyDrawdownPercent / 100.0);
        if(worst_case_balance < daily_dd_limit_level)
        {
            Alert(StringFormat("TRADE REJECTED: Daily Drawdown Breach.\nWorst Balance: %s %.2f\nLimit: %s %.2f", 
                  currency, worst_case_balance, currency, daily_dd_limit_level));
            return false;
        }

        double overall_dd_base = (InpOverallDDType == DD_TYPE_STATIC) ? g_initial_balance : g_peak_equity;
        double overall_dd_limit_level = overall_dd_base * (1 - InpMaxOverallDrawdownPercent / 100.0);
        if(worst_case_balance < overall_dd_limit_level)
        {
            Alert(StringFormat("TRADE REJECTED: Max Drawdown Breach.\nWorst Balance: %s %.2f\nLimit: %s %.2f", 
                  currency, worst_case_balance, currency, overall_dd_limit_level));
            return false;
        }
    }
    
    return true;
}

// --- سایر توابع (بدون تغییر) ---
void ValidateTradeLogicAndUpdateUI()
{
    if(ExtDialog.GetCurrentState() == STATE_IDLE) return;

    // --- بخش ۱: تعیین متغیرهای ورودی بر اساس وضعیت فعلی ---
    ETradeState state = ExtDialog.GetCurrentState();
    double entry_for_calc = 0;
    double sl = GetLinePrice(LINE_STOP_LOSS);
    string current_panel = ""; // برای ارسال به تابع نمایش پیام

    if (state == STATE_PREP_STAIRWAY_BUY || state == STATE_PREP_STAIRWAY_SELL)
    {
        entry_for_calc = GetLinePrice(LINE_PENDING_ENTRY);
        current_panel = "stairway";
    }
    else if (state == STATE_PREP_MARKET_BUY || state == STATE_PREP_MARKET_SELL)
    {
        entry_for_calc = GetLinePrice(LINE_ENTRY_PRICE);
        current_panel = "market";
    }
    else // Pending
    {
        entry_for_calc = GetLinePrice(LINE_ENTRY_PRICE);
        current_panel = "pending";
    }

    // --- بخش ۲: اعتبارسنجی اولیه (وجود خطوط و موقعیت SL) ---
    bool is_valid = false;
    bool isBuy = (state == STATE_PREP_MARKET_BUY || state == STATE_PREP_PENDING_BUY || state == STATE_PREP_STAIRWAY_BUY);
    if(entry_for_calc > 0 && sl > 0)
    {
        if((isBuy && sl < entry_for_calc) || (!isBuy && sl > entry_for_calc))
        {
            is_valid = true;
        }
        else
        {
            ExtDialog.SetStatusMessage("Invalid SL Position", current_panel, InpDangerColor);
        }
    }

    // --- بخش ۳: اعتبارسنجی حجم لات (فقط اگر بخش ۲ معتبر بود) ---
    if(is_valid)
    {
        double lot_size = 0, risk_in_money = 0;
        // اگر محاسبه لات موفقیت‌آمیز نبود یا حجم صفر بود، معامله نامعتبر است
        if(!CalculateLotSize(entry_for_calc, sl, lot_size, risk_in_money) || lot_size <= 0)
        {
            is_valid = false;
            ExtDialog.SetStatusMessage("Lot Size Too Small", current_panel, InpDangerColor);
        }
        else
        {
            // اگر همه چیز درست بود، پیام "آماده" را نمایش بده
            ExtDialog.SetStatusMessage("Ready", current_panel, InpSafeColor);
        }
    }

    // --- بخش نهایی: به‌روزرسانی وضعیت و دکمه اجرا ---
    ExtDialog.SetTradeLogicValid(is_valid);
    ExtDialog.SetExecuteButtonState();
}

void UpdateAllLabels()
{
   if(ExtDialog.GetCurrentState() == STATE_IDLE) return;
   UpdateDisplayData();
   UpdateLineInfoLabels();
   ValidateTradeLogicAndUpdateUI();
}

bool CurrentStateIsPending()
{
    ETradeState state = ExtDialog.GetCurrentState();
    return (state == STATE_PREP_PENDING_BUY || state == STATE_PREP_PENDING_SELL);
}

double GetPipValue()
{
    return SymbolInfoDouble(_Symbol, SYMBOL_POINT) * (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) % 2 != 0 ? 10 : 1);
}

void ResetToIdleState()
{
    if(g_stairway_step1_ticket > 0)
    {
        if(OrderSelect(g_stairway_step1_ticket))
        {
            trade.OrderDelete(g_stairway_step1_ticket);
            Alert("Stairway process cancelled by user. Pending order deleted.");
        }
        g_stairway_step1_ticket = 0;
    }
    ExtDialog.ResetAllControls();
}



// ==================================================================
// === بخش ۱: توابع کمکی برای مدیریت وضعیت ATM ===
// ==================================================================
bool WasRuleApplied(ulong ticket){for(int i=0;i<ArraySize(g_appliedRulesTickets);i++)if(g_appliedRulesTickets[i]==ticket)return true;return false;}
void MarkRuleAsApplied(ulong ticket){if(WasRuleApplied(ticket))return;int size=ArraySize(g_appliedRulesTickets);ArrayResize(g_appliedRulesTickets,size+1);g_appliedRulesTickets[size]=ticket;}
//bool IsAtmEnabled(ulong ticket){for(int i=0; i<ArraySize(g_atmEnabledTickets); i++)if(g_atmEnabledTickets[i] == ticket) return true;return false;}
int FindSLIndex(ulong ticket){for(int i=0;i<ArraySize(g_slTickets);i++)if(g_slTickets[i]==ticket)return i;return -1;}




bool IsAtmEnabled(ulong ticket)
{
    for(int i=0; i<ArraySize(g_atmEnabledTickets); i++)
        if(g_atmEnabledTickets[i] == ticket) return true;
    return false;
}

void ToggleAtmForTicket(ulong ticket, bool enable)
{
    bool exists = IsAtmEnabled(ticket);
    if(enable && !exists)
    {
        int size = ArraySize(g_atmEnabledTickets);
        ArrayResize(g_atmEnabledTickets, size + 1);
        g_atmEnabledTickets[size] = ticket;
    }
    else if(!enable && exists)
    {
        for(int i=0; i<ArraySize(g_atmEnabledTickets); i++)
        {
            if(g_atmEnabledTickets[i] == ticket)
            {
                ArrayRemove(g_atmEnabledTickets, i, 1);
                break;
            }
        }
    }
}

// ==================================================================
// === بخش ۲: توابع مدیریت فایل و ذخیره‌سازی ===
// ==================================================================
void SaveOriginalSLs(){int h=FileOpen(SL_Backup_File,FILE_WRITE|FILE_BIN);if(h==INVALID_HANDLE)return;int c=ArraySize(g_slTickets);FileWriteInteger(h,c);if(c>0){FileWriteArray(h,g_slTickets,0,c);FileWriteArray(h,g_slValues,0,c);}FileClose(h);}
void LoadOriginalSLs(){ArrayFree(g_slTickets);ArrayFree(g_slValues);int h=FileOpen(SL_Backup_File,FILE_READ|FILE_BIN);if(h==INVALID_HANDLE)return;int c=FileReadInteger(h);if(c>0){ArrayResize(g_slTickets,c);ArrayResize(g_slValues,c);FileReadArray(h,g_slTickets,0,c);FileReadArray(h,g_slValues,0,c);}FileClose(h);}
void StoreOriginalSL(ulong ticket,double sl){if(sl==0.0)return;int i=FindSLIndex(ticket);if(i==-1){int s=ArraySize(g_slTickets);ArrayResize(g_slTickets,s+1);ArrayResize(g_slValues,s+1);g_slTickets[s]=ticket;g_slValues[s]=sl;}else{g_slValues[i]=sl;}SaveOriginalSLs();}

// ==================================================================
// === بخش ۳: توابع کمکی عمومی و解析 JSON ===
// ==================================================================
int VolumeDigits(string s){double st=SymbolInfoDouble(s,SYMBOL_VOLUME_STEP);if(st==1.0)return 0;string str=DoubleToString(st);int p=StringFind(str,".");if(p<0)return 0;return StringLen(str)-p-1;}
string GetJsonString(string j,string k){string s="\""+k+"\":\"";int sp=StringFind(j,s);if(sp<0)return"";sp+=StringLen(s);int ep=StringFind(j,"\"",sp);if(ep<0)return"";return StringSubstr(j,sp,ep-sp);}
ulong GetJsonUlong(string j,string k){string s="\""+k+"\":";int sp=StringFind(j,s);if(sp<0)return 0;sp+=StringLen(s);int ep=StringFind(j,",",sp);if(ep<0)ep=StringFind(j,"}",sp);if(ep<0)return 0;return(ulong)StringToInteger(StringSubstr(j,sp,ep-sp));}
double GetJsonDouble(string j,string k){string s="\""+k+"\":";int sp=StringFind(j,s);if(sp<0)return 0.0;sp+=StringLen(s);int ep=StringFind(j,",",sp);if(ep<0)ep=StringFind(j,"}",sp);if(ep<0)return 0.0;return StringToDouble(StringSubstr(j,sp,ep-sp));}
bool GetJsonBool(string j,string k){string s="\""+k+"\":";int sp=StringFind(j,s);if(sp<0)return false;sp+=StringLen(s);int ep=StringFind(j,",",sp);if(ep<0)ep=StringFind(j,"}",sp);if(ep<0)return false;string v=StringSubstr(j,sp,ep-sp);StringTrimRight(v);StringTrimLeft(v);return(v=="true");}





void InitializeMagicNumber()
{
    long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
    string gv_key = "AdvRiskCalc_Magic_" + (string)account_number + "_" + _Symbol + "_" + (string)ChartID();

    if(GlobalVariableCheck(gv_key))
    {
        g_magic_number = (long)GlobalVariableGet(gv_key);
        Print("Magic number for ", _Symbol, " loaded: ", g_magic_number);
    }
    else
    {
        MathSrand(GetTickCount() + (int)ChartID());
        g_magic_number = MathRand(); 
        GlobalVariableSet(gv_key, g_magic_number);
        Print("New magic number for ", _Symbol, " generated and saved: ", g_magic_number);
    }
}

#endif // SHAREDLOGIC_MQH
