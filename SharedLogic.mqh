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
                        OrderCalcProfit((ENUM_ORDER_TYPE)type, pos_symbol, volume, open_price, stop_loss, existing_trade_loss);
                        total_potential_loss += MathAbs(existing_trade_loss);
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
    double entry = GetLinePrice(LINE_ENTRY_PRICE);
    double sl = GetLinePrice(LINE_STOP_LOSS);
    bool is_valid = false;
    bool isBuy = (ExtDialog.GetCurrentState() == STATE_PREP_MARKET_BUY || ExtDialog.GetCurrentState() == STATE_PREP_PENDING_BUY || ExtDialog.GetCurrentState() == STATE_PREP_STAIRWAY_BUY);
   
    if(entry > 0 && sl > 0)
    {
        if(isBuy && sl < entry) is_valid = true;
        else if(!isBuy && sl > entry) is_valid = true;
    }
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
