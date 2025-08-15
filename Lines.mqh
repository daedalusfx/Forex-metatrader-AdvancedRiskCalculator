//+------------------------------------------------------------------+
//|                                                     Lines.mqh |
//|        V3.0 - بازنویسی کامل برای پشتیبانی از حالت‌های دستی و خودکار |
//+------------------------------------------------------------------+
#ifndef LINES_MQH
#define LINES_MQH

//--- توابع قدیمی (بدون تغییر) ---
void CreateLine(string name, string text, double price, color clr, bool selectable = true)
{
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, InpLineStyle);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, InpLineWidth);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, selectable);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectMove(0, name, 0, 0, price);
}

void CreateStyledLabel(string name, string text, datetime time, double price, color bg_color, color text_color)
{
    string label_name = name + "_label";
    if(ObjectFind(0, label_name) < 0)
    {
        ObjectCreate(0, label_name, OBJ_BUTTON, 0, time, price);
        ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, label_name, OBJPROP_STATE, true);
        ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, label_name, OBJPROP_XSIZE, 240);
        ObjectSetInteger(0, label_name, OBJPROP_YSIZE, 20);
        ObjectSetString(0, label_name, OBJPROP_FONT, "Tahoma Bold");
        ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, label_name, OBJPROP_BACK, true);
    }
    ObjectSetString(0, label_name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, label_name, OBJPROP_BGCOLOR, bg_color);
    ObjectSetInteger(0, label_name, OBJPROP_COLOR, text_color);
    ObjectMove(0, label_name, 0, time, price);
}

void DeleteTradeLines()
{
   ObjectDelete(0, LINE_ENTRY_PRICE);
   ObjectDelete(0, LINE_STOP_LOSS);
   ObjectDelete(0, LINE_TAKE_PROFIT);
   ObjectDelete(0, LINE_PENDING_ENTRY);
   ObjectDelete(0, LINE_ENTRY_PRICE + "_label");
   ObjectDelete(0, LINE_STOP_LOSS + "_label");
   ObjectDelete(0, LINE_TAKE_PROFIT + "_label");
   ObjectDelete(0, LINE_PENDING_ENTRY + "_label");
}

double GetLinePrice(string line_name)
{
   if(ObjectFind(0, line_name) != -1)
      return ObjectGetDouble(0, line_name, OBJPROP_PRICE, 0);
   return 0;
}

// --- (جدید) تابع اصلی برای به‌روزرسانی هماهنگ خطوط در حالت خودکار ---
void UpdateDynamicLines()
{
    // این تابع فقط در حالت خودکار و استراتژی پلکانی کار می‌کند
    if(ExtDialog.GetCurrentState() < STATE_PREP_STAIRWAY_BUY || InpTPMode != TP_RR_RATIO) return;

    // ۱. قیمت‌های اصلی را بخوان (سطح شکست و استاپ)
    double breakout_price = GetLinePrice(LINE_ENTRY_PRICE);
    double sl_price = GetLinePrice(LINE_STOP_LOSS);
    if(breakout_price <= 0 || sl_price <= 0) return;

    bool is_buy = (sl_price < breakout_price);
    double pip_value = GetPipValue();

    // ۲. نقطه ورود پولبک را بر اساس قانون ثابت محاسبه کن
    double pending_entry_price = is_buy ?
        breakout_price - (15 * pip_value) : breakout_price + (15 * pip_value);
    ObjectMove(0, LINE_PENDING_ENTRY, 0, 0, pending_entry_price);

    // ۳. حد سود را بر اساس نقطه ورود جدید و R:R محاسبه کن
    double risk_distance = MathAbs(pending_entry_price - sl_price);
    double tp_price = is_buy ?
        pending_entry_price + (risk_distance * InpTP_RR_Value) : pending_entry_price - (risk_distance * InpTP_RR_Value);
    ObjectMove(0, LINE_TAKE_PROFIT, 0, 0, tp_price);
    
    // در نهایت، تمام لیبل‌ها را آپدیت کن
    UpdateAllLabels();
}


// --- (بازنویسی شده) تابع هوشمند برای ایجاد اولیه خطوط ---
void CreateTradeLines()
{
    DeleteTradeLines();
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double pip_value = GetPipValue();
    ETradeState state = ExtDialog.GetCurrentState();
    bool is_stairway = (state == STATE_PREP_STAIRWAY_BUY || state == STATE_PREP_STAIRWAY_SELL);
    bool is_buy = (state == STATE_PREP_MARKET_BUY || state == STATE_PREP_PENDING_BUY || state == STATE_PREP_STAIRWAY_BUY);

    // --- قیمت‌های پیش‌فرض ---
    double initial_sl_pips = 20.0;
    double initial_distance_pips = 50.0;
    
    // سطح شکست (Breakout Level)
    double breakout_price = is_buy ? ask + (initial_distance_pips * pip_value) : bid - (initial_distance_pips * pip_value);
    // حد ضرر (Stop Loss)
    double sl_price = is_buy ? breakout_price - (initial_sl_pips * pip_value) : breakout_price + (initial_sl_pips * pip_value);

    // --- منطق اصلی بر اساس حالت دستی یا خودکار ---
    if(is_stairway && InpTPMode == TP_RR_RATIO) // حالت خودکار (ورود هوشمند)
    {
        // کاربر فقط SL و سطح شکست را می‌تواند جابجا کند
        CreateLine(LINE_ENTRY_PRICE, "", breakout_price, InpWarningColor, true); // سطح شکست
        CreateLine(LINE_STOP_LOSS, "", sl_price, InpStopLineColor, true);       // حد ضرر

        // نقطه ورود و TP بر اساس دو خط بالا محاسبه و "قفل" می‌شوند
        double pending_entry_price = is_buy ? breakout_price - (15 * pip_value) : breakout_price + (15 * pip_value);
        double risk_distance = MathAbs(pending_entry_price - sl_price);
        double tp_price = is_buy ? pending_entry_price + (risk_distance * InpTP_RR_Value) : pending_entry_price - (risk_distance * InpTP_RR_Value);
        
        CreateLine(LINE_PENDING_ENTRY, "", pending_entry_price, InpEntryLineColor, false); // نقطه ورود (غیرقابل انتخاب)
        CreateLine(LINE_TAKE_PROFIT, "", tp_price, InpProfitLineColor, false);        // حد سود (غیرقابل انتخاب)
    }
    else // حالت دستی (برای Market, Pending معمولی و Stairway دستی)
    {
        // تمام خطوط توسط کاربر قابل جابجایی هستند
        bool is_pending = CurrentStateIsPending();
        bool is_entry_selectable = (is_pending || is_stairway);

        double entry_price = is_pending || is_stairway ? breakout_price : (is_buy ? ask : bid);
        if(is_stairway) // اگر پلکانی دستی بود، ۴ خط ایجاد کن
        {
             CreateLine(LINE_ENTRY_PRICE, "", entry_price, InpWarningColor, true); // سطح شکست
             double pending_entry_price = is_buy ? entry_price - (15 * pip_value) : entry_price + (15 * pip_value);
             CreateLine(LINE_PENDING_ENTRY, "", pending_entry_price, InpEntryLineColor, true); // ورود
        }
        else // برای حالت‌های دیگر
        {
             CreateLine(LINE_ENTRY_PRICE, "", entry_price, InpEntryLineColor, is_entry_selectable);
        }

        CreateLine(LINE_STOP_LOSS, "", sl_price, InpStopLineColor, true);
        double tp_price = is_buy ? entry_price + (MathAbs(entry_price-sl_price) * InpTP_RR_Value) : entry_price - (MathAbs(entry_price-sl_price) * InpTP_RR_Value);
        CreateLine(LINE_TAKE_PROFIT, "", tp_price, InpProfitLineColor, true);
    }
}


// --- (اصلاح شده) تابع به‌روزرسانی لیبل‌ها ---
// این تابع باید منطق جدید را منعکس کند
void UpdateLineInfoLabels()
{
   if (ExtDialog.GetCurrentState() == STATE_IDLE) return;
   
   double breakout_price = GetLinePrice(LINE_ENTRY_PRICE);
   double sl_price = GetLinePrice(LINE_STOP_LOSS);
   double tp_price = GetLinePrice(LINE_TAKE_PROFIT);
   double pending_entry_price = GetLinePrice(LINE_PENDING_ENTRY);
   
   if(breakout_price == 0) return;
   
   double lot_size = 0, risk_in_money = 0;
   ETradeState state = ExtDialog.GetCurrentState();
   bool is_stairway = (state == STATE_PREP_STAIRWAY_BUY || state == STATE_PREP_STAIRWAY_SELL);
   
   // مبنای محاسبه ریسک همیشه فاصله ورود پولبک تا استاپ است
   double risk_calc_entry = is_stairway ? pending_entry_price : breakout_price;
   if(sl_price > 0 && risk_calc_entry > 0)
     CalculateLotSize(risk_calc_entry, sl_price, lot_size, risk_in_money);

   datetime time_pos = TimeCurrent() + (PeriodSeconds() * 15);
   double pip_value = GetPipValue();

   // لیبل سطح شکست
   string breakout_text = StringFormat("BREAKOUT | %.5f", breakout_price);
   CreateStyledLabel(LINE_ENTRY_PRICE, breakout_text, time_pos, breakout_price, InpWarningColor, C'255,255,255');
      
   // لیبل خط ورود پولبک
   string pending_text = StringFormat("PENDING ENTRY | %.5f", pending_entry_price);
   CreateStyledLabel(LINE_PENDING_ENTRY, pending_text, time_pos, pending_entry_price, InpBuyButtonColor, C'255,255,255');

   // لیبل‌های SL و TP
   if(sl_price > 0)
   {
      double sl_pips = (pip_value > 0) ? MathAbs(sl_price - risk_calc_entry) / pip_value : 0;
      string sl_text = StringFormat("STOP LOSS | Risk $%.2f", risk_in_money);
      CreateStyledLabel(LINE_STOP_LOSS, sl_text, time_pos, sl_price, InpStopLineColor, C'255,255,255');

      if(tp_price > 0)
      {
         double tp_pips = (pip_value > 0) ? MathAbs(tp_price - risk_calc_entry) / pip_value : 0;
         double rr_ratio = (sl_pips > 0.1) ? tp_pips / sl_pips : 0;
         string tp_text = StringFormat("TAKE PROFIT | R:R %.1f:1", rr_ratio);
         CreateStyledLabel(LINE_TAKE_PROFIT, tp_text, time_pos, tp_price, InpProfitLineColor, C'255,255,255');
      }
   }
}

// این تابع در کد اصلی برنامه، در بخش مدیریت رویداد Drag، جایگزین UpdateAutoTPLine خواهد شد
#define UpdateAutoTPLine UpdateDynamicLines

#endif // LINES_MQH