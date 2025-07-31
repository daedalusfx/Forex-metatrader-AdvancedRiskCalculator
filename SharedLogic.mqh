//+------------------------------------------------------------------+
//|                                                SharedLogic.mqh |
//|         V2.1 - توابع مشترک با ارجاع به کلاس پنل جدید          |
//+------------------------------------------------------------------+
#ifndef SHAREDLOGIC_MQH
#define SHAREDLOGIC_MQH
void UpdateDisplayData();

//--- محاسبه حجم لات
bool CalculateLotSize(double entry, double sl, double &lot_size, double &risk_in_money)
{
    lot_size = 0;
    risk_in_money = 0;
    string risk_input_str = (ExtDialog.GetCurrentState() == STATE_PREP_MARKET_BUY || ExtDialog.GetCurrentState() == STATE_PREP_MARKET_SELL) ? 
                            ExtDialog.GetRiskInput("market") : ExtDialog.GetRiskInput("pending");
    double risk_pct = StringToDouble(risk_input_str);
    if(risk_pct <= 0) return false;

    risk_in_money = AccountInfoDouble(ACCOUNT_BALANCE) * (risk_pct / 100.0);
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

//--- بررسی ایمنی معامله
bool IsTradeRequestSafe(double lot_size, ENUM_ORDER_TYPE order_type, double price, double sl, double tp)
{
    // 1. بررسی مارجین آزاد
    double required_margin = 0;
    if(!OrderCalcMargin(order_type, _Symbol, lot_size, price, required_margin))
    {
        Alert("Margin calculation failed. Error: ", GetLastError());
        return false;
    }
    double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    if(required_margin > free_margin * (InpMaxMarginUsagePercent / 100.0))
    {
        Alert("Not enough free margin. Required: ", DoubleToString(required_margin, 2), ", Available: ", DoubleToString(free_margin, 2));
        return false;
    }

    // 2. بررسی سطح توقف (Stops Level)
    double stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    if(order_type >= ORDER_TYPE_BUY_LIMIT && order_type <= ORDER_TYPE_SELL_STOP_LIMIT)
    {
        if(MathAbs(price - sl) <= stops_level)
        {
             Alert("Stop Loss is too close to the entry price. Min distance: ", DoubleToString(stops_level, _Digits));
             return false;
        }
        if(tp > 0 && MathAbs(price - tp) <= stops_level)
        {
             Alert("Take Profit is too close to the entry price. Min distance: ", DoubleToString(stops_level, _Digits));
             return false;
        }
    }
    
    // --- 3. بررسی قوانین پراپ ---
    if(g_prop_rules_active)
    {
        double potential_loss_on_trade = 0;
        if(!OrderCalcProfit(order_type, _Symbol, lot_size, price, sl, potential_loss_on_trade))
        {
            Alert("Could not calculate potential loss for prop firm check. Error: ", GetLastError());
            return false;
        }
        potential_loss_on_trade = MathAbs(potential_loss_on_trade);
        double potential_equity_on_loss = AccountInfoDouble(ACCOUNT_EQUITY) - potential_loss_on_trade;
        string currency = AccountInfoString(ACCOUNT_CURRENCY);

        // بررسی قانون افت سرمایه روزانه
        double daily_dd_limit_level = g_start_of_day_base * (1 - InpMaxDailyDrawdownPercent / 100.0);
        if(potential_equity_on_loss < daily_dd_limit_level)
        {
            Alert("TRADE REJECTED: Violates Daily Drawdown Rule.\n",
                  "If SL hits, equity would be ", StringFormat("%s %.2f", currency, potential_equity_on_loss),
                  ", which is below the daily limit of ", StringFormat("%s %.2f", currency, daily_dd_limit_level));
            return false;
        }

        // بررسی قانون افت سرمایه کلی
        double overall_dd_base = (InpOverallDDType == DD_TYPE_STATIC) ? g_initial_balance : g_peak_equity;
        double overall_dd_limit_level = overall_dd_base * (1 - InpMaxOverallDrawdownPercent / 100.0);
        if(potential_equity_on_loss < overall_dd_limit_level)
        {
            Alert("TRADE REJECTED: Violates Max Overall Drawdown Rule.\n",
                  "If SL hits, equity would be ", StringFormat("%s %.2f", currency, potential_equity_on_loss),
                  ", which is below the max limit of ", StringFormat("%s %.2f", currency, overall_dd_limit_level));
            return false;
        }
    }

// --- 4. بررسی قانون ثبات (Consistency Rule) ---
if(g_prop_rules_active && InpEnableConsistencyRule)
{
    // محاسبه سود امروز بر اساس اکوئیتی فعلی
    double todays_profit = AccountInfoDouble(ACCOUNT_EQUITY) - g_start_of_day_base;
    if(todays_profit <= 0) // اگر امروز سودی نکرده‌ایم، نیازی به بررسی نیست
    {
        // Do nothing, no need to check
    }
    else
    {
        // محاسبه کل سود ثبت شده در روزهای گذشته
        double total_past_profit = 0;
        for(int i = 0; i < ArraySize(g_daily_profits); i++)
        {
            if(g_daily_profits[i].profit > 0)
                total_past_profit += g_daily_profits[i].profit;
        }

        // کل سود = سود روزهای گذشته + سود امروز
        double total_profit = total_past_profit + todays_profit;
        if(total_profit > 0)
        {
            double today_contribution_pct = (todays_profit / total_profit) * 100.0;

            // اگر سهم سود امروز از حد مجاز بیشتر شود، معامله جدید را مسدود کن
            if(today_contribution_pct > InpConsistencyRulePercent)
            {
                Alert("TRADE REJECTED: Violates Consistency Rule.\n",
                      "Today's profit contribution (", DoubleToString(today_contribution_pct, 1),
                      "%) exceeds the allowed limit of ", DoubleToString(InpConsistencyRulePercent, 1), "%.");
                return false;
            }
        }
    }
}

    
    return true;
}

//--- اعتبارسنجی منطق معامله و به‌روزرسانی UI
void ValidateTradeLogicAndUpdateUI()
{
    if(ExtDialog.GetCurrentState() == STATE_IDLE) return;
    double entry = GetLinePrice(LINE_ENTRY_PRICE);
    double sl = GetLinePrice(LINE_STOP_LOSS);
    bool is_valid = false;
    bool isBuy = (ExtDialog.GetCurrentState() == STATE_PREP_MARKET_BUY || ExtDialog.GetCurrentState() == STATE_PREP_PENDING_BUY);
   
    if(entry > 0 && sl > 0)
    {
        if(isBuy && sl < entry) is_valid = true;
        else if(!isBuy && sl > entry) is_valid = true;
    }
    ExtDialog.SetTradeLogicValid(is_valid);
    ExtDialog.SetExecuteButtonState();
}

//--- (اصلاح شده) به‌روزرسانی تمام بخش‌های نمایشی
void UpdateAllLabels()
{
   if(ExtDialog.GetCurrentState() == STATE_IDLE) return;
   
   UpdateDisplayData();      // آپدیت پنل Canvas
   UpdateLineInfoLabels();   // (بازگردانده شده) آپدیت لیبل‌های روی خطوط قیمت
   ValidateTradeLogicAndUpdateUI(); // آپدیت وضعیت دکمه‌ها
}

//--- تابع کمکی برای بررسی حالت Pending
bool CurrentStateIsPending()
{
    ETradeState state = ExtDialog.GetCurrentState();
    return (state == STATE_PREP_PENDING_BUY || state == STATE_PREP_PENDING_SELL);
}

//--- تابع کمکی برای دریافت مقدار پیپ
double GetPipValue()
{
    return SymbolInfoDouble(_Symbol, SYMBOL_POINT) * (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) % 2 != 0 ? 10 : 1);
}

//--- بازنشانی به حالت اولیه
void ResetToIdleState()
{
    ExtDialog.ResetAllControls();
}

#endif // SHAREDLOGIC_MQH
