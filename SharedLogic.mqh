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


//+------------------------------------------------------------------+
//| (نسخه نهایی و کاملاً اصلاح شده) بررسی ایمنی معامله                 |
//+------------------------------------------------------------------+
bool IsTradeRequestSafe(double lot_size, ENUM_ORDER_TYPE order_type, double price, double sl, double tp)
{
    // --- 1. بررسی‌های اولیه (مارجین و ...) ---
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
    
    // --- 2. شبیه‌سازی بدترین حالت برای قوانین پراپ ---
    if(g_prop_rules_active)
    {
        double total_potential_loss = 0;
        
        // ابتدا ضرر بالقوه معامله جدید را اضافه می‌کنیم
        double new_trade_loss = 0;
        if(OrderCalcProfit(order_type, _Symbol, lot_size, price, sl, new_trade_loss))
        {
            total_potential_loss += MathAbs(new_trade_loss);
        }
        else
        {
            Alert("Could not calculate potential loss for the new trade. Request rejected.");
            return false;
        }

        // سپس ضرر بالقوه تمام معاملات باز فعلی با همان مجیک نامبر را اضافه می‌کنیم
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(PositionGetInteger(POSITION_MAGIC) == g_magic_number)
            {
                // (جدید) دریافت نمادِ معامله باز
                string pos_symbol = PositionGetString(POSITION_SYMBOL); 
                double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                double stop_loss = PositionGetDouble(POSITION_SL);
                double volume = PositionGetDouble(POSITION_VOLUME);
                long type = PositionGetInteger(POSITION_TYPE);
                
                double existing_trade_loss = 0;
                if(stop_loss > 0)
                {
                    // (اصلاح شده) استفاده از نماد صحیح معامله باز شده در محاسبه
                    OrderCalcProfit((ENUM_ORDER_TYPE)type, pos_symbol, volume, open_price, stop_loss, existing_trade_loss);
                    total_potential_loss += MathAbs(existing_trade_loss);
                }
            }
        }
        
        // محاسبه اکوئیتی نهایی در بدترین حالت
        // این محاسبه درست است: بالانس فعلی منهای مجموع تمام ریسک‌های تعریف شده (از نقطه ورود تا استاپ)
        double worst_case_balance = AccountInfoDouble(ACCOUNT_BALANCE) - total_potential_loss;
        
        string currency = AccountInfoString(ACCOUNT_CURRENCY);

        // بررسی قانون افت سرمایه روزانه
        double daily_dd_limit_level = g_start_of_day_base * (1 - InpMaxDailyDrawdownPercent / 100.0);
        if(worst_case_balance < daily_dd_limit_level)
        {
            Alert("TRADE REJECTED: Cumulative risk violates Daily Drawdown Rule.\n",
                  "If all SLs hit, balance would be ", StringFormat("%s %.2f", currency, worst_case_balance),
                  ", which is below the daily limit of ", StringFormat("%s %.2f", currency, daily_dd_limit_level));
            return false;
        }

        // بررسی قانون افت سرمایه کلی
        double overall_dd_base = (InpOverallDDType == DD_TYPE_STATIC) ? g_initial_balance : g_peak_equity;
        double overall_dd_limit_level = overall_dd_base * (1 - InpMaxOverallDrawdownPercent / 100.0);
        if(worst_case_balance < overall_dd_limit_level)
        {
            Alert("TRADE REJECTED: Cumulative risk violates Max Overall Drawdown Rule.\n",
                  "If all SLs hit, balance would be ", StringFormat("%s %.2f", currency, worst_case_balance),
                  ", which is below the max limit of ", StringFormat("%s %.2f", currency, overall_dd_limit_level));
            return false;
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



//+------------------------------------------------------------------+
//|    تولید/بازیابی مجیک نامبر منحصر به فرد و پایدار برای هر چارت   |
//+------------------------------------------------------------------+
void InitializeMagicNumber()
{
    // یک کلید منحصر به فرد بر اساس سیمبل و شناسه چارت می‌سازیم
    long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
    string gv_key = "AdvRiskCalc_Magic_" + (string)account_number + "_" + _Symbol + "_" + (string)ChartID();

    // آیا این متغیر سراسری قبلاً ساخته شده؟
    if(GlobalVariableCheck(gv_key))
    {
        // اگر بله، آن را می‌خوانیم
        g_magic_number = (long)GlobalVariableGet(gv_key);
        Print("Magic number for ", _Symbol, " loaded: ", g_magic_number);
    }
    else
    {
        // اگر نه (اجرای اول روی این چارت)، یک عدد جدید می‌سازیم
        MathSrand(GetTickCount() + (int)ChartID()); // مقدار اولیه برای تولید عدد تصادفی
        g_magic_number = MathRand(); 
        
        // عدد ساخته شده را در متغیرهای سراسری ترمینال ذخیره می‌کنیم
        GlobalVariableSet(gv_key, g_magic_number);
        Print("New magic number for ", _Symbol, " generated and saved: ", g_magic_number);
    }
}



#endif // SHAREDLOGIC_MQH
