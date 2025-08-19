//+------------------------------------------------------------------+
//|                                                     Lines.mqh |
//|        V5.1 - نسخه کامل با تمام حالت‌های معاملاتی (نهایی)           |
//+------------------------------------------------------------------+
#include "Defines.mqh"

#ifndef LINES_MQH
#define LINES_MQH

//--- توابع پایه‌ای (بدون تغییر) ---
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
   ObjectDelete(0, LINE_BREAKOUT_LEVEL); // (کد جدید) حذف خط شکست
   ObjectDelete(0, LINE_ENTRY_PRICE);
   ObjectDelete(0, LINE_STOP_LOSS);
   ObjectDelete(0, LINE_TAKE_PROFIT);
   ObjectDelete(0, LINE_PENDING_ENTRY);
   ObjectDelete(0, LINE_ENTRY_PRICE + "_label");
   ObjectDelete(0, LINE_STOP_LOSS + "_label");
   ObjectDelete(0, LINE_TAKE_PROFIT + "_label");
   ObjectDelete(0, LINE_PENDING_ENTRY + "_label");
   ObjectDelete(0, LINE_BREAKOUT_LEVEL + "_label"); // (کد جدید) حذف لیبل خط شکست
}

double GetLinePrice(string line_name)
{
   if(ObjectFind(0, line_name) != -1)
      return ObjectGetDouble(0, line_name, OBJPROP_PRICE, 0);
   return 0;
}

//+------------------------------------------------------------------+
//| (کامل) محاسبه خودکار TP بر اساس حالت‌های مختلف                    |
//+------------------------------------------------------------------+
void UpdateDynamicLines()
{
    ETradeState state = ExtDialog.GetCurrentState();
    if (state == STATE_IDLE || InpTPMode != TP_RR_RATIO) return;

    if (state == STATE_PREP_STAIRWAY_BUY || state == STATE_PREP_STAIRWAY_SELL)
    {
        // --- منطق جدید "ترکیبی": Entry و SL دستی هستند، TP محاسبه می‌شود ---
        double entry_price = GetLinePrice(LINE_PENDING_ENTRY);
        double sl_price = GetLinePrice(LINE_STOP_LOSS);

        if(entry_price <= 0 || sl_price <= 0) return;

        bool is_buy = (sl_price < entry_price);
        double risk_distance = MathAbs(entry_price - sl_price);
        
        // محاسبه و جابجایی خودکار خط حد سود
        double tp_price = is_buy ? entry_price + (risk_distance * InpTP_RR_Value) : entry_price - (risk_distance * InpTP_RR_Value);
        ObjectMove(0, LINE_TAKE_PROFIT, 0, 0, tp_price);
    }
    else
    {
        // --- منطق قدیمی برای Market/Pending: Entry و SL دستی، TP محاسبه می‌شود ---
        double entry_price = GetLinePrice(LINE_ENTRY_PRICE);
        double sl_price = GetLinePrice(LINE_STOP_LOSS);

        if(entry_price <= 0 || sl_price <= 0) return;

        bool is_buy = (sl_price < entry_price);
        double risk_distance = MathAbs(entry_price - sl_price);

        // محاسبه و جابجایی خودکار خط حد سود
        double tp_price = is_buy ? entry_price + (risk_distance * InpTP_RR_Value) : entry_price - (risk_distance * InpTP_RR_Value);
        ObjectMove(0, LINE_TAKE_PROFIT, 0, 0, tp_price);
    }

    // به‌روزرسانی تمام لیبل‌ها
    UpdateAllLabels();
}
//+------------------------------------------------------------------+
//| (کامل) ایجاد خطوط برای تمام استراتژی‌ها                           |
//+------------------------------------------------------------------+
void CreateTradeLines()
{
    DeleteTradeLines();
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double pip_value = GetPipValue();
    ETradeState state = ExtDialog.GetCurrentState();
    bool is_buy = (state == STATE_PREP_MARKET_BUY || state == STATE_PREP_PENDING_BUY || state == STATE_PREP_STAIRWAY_BUY);
    if (state == STATE_PREP_STAIRWAY_BUY || state == STATE_PREP_STAIRWAY_SELL)
    {
        double initial_pips = 20.0;
        double breakout_price = is_buy ? ask + (initial_pips * pip_value) : bid - (initial_pips * pip_value);
        double pending_entry_price = is_buy ? ask + (initial_pips / 2 * pip_value) : bid - (initial_pips / 2 * pip_value);
        double sl_price = is_buy ? pending_entry_price - (initial_pips * pip_value) : pending_entry_price + (initial_pips * pip_value);

        // اینجا از شناسه جدید برای خط شکست استفاده شده است
        CreateLine(LINE_BREAKOUT_LEVEL, "", breakout_price, InpWarningColor, true); // خط شکست
        CreateLine(LINE_PENDING_ENTRY, "", pending_entry_price, InpEntryLineColor, true); // خط ورود دستی
        CreateLine(LINE_STOP_LOSS, "", sl_price, InpStopLineColor, true); // خط حد ضرر
        CreateLine(LINE_TAKE_PROFIT, "", 0, InpProfitLineColor, false);
        UpdateDynamicLines();
    }
    else
    {
        double initial_sl_pips = 20.0;
        double initial_distance_pips = 50.0;
        double entry_price_base = is_buy ? ask + (initial_distance_pips * pip_value) : bid - (initial_distance_pips * pip_value);
        double sl_price_base = is_buy ? entry_price_base - (initial_sl_pips * pip_value) : entry_price_base + (initial_sl_pips * pip_value);
        bool is_pending = CurrentStateIsPending();
        double entry_price = is_pending ? entry_price_base : (is_buy ? ask : bid);
        bool is_entry_selectable = is_pending;
        CreateLine(LINE_ENTRY_PRICE, "", entry_price, InpEntryLineColor, is_entry_selectable);
        CreateLine(LINE_STOP_LOSS, "", sl_price_base, InpStopLineColor, true);
        bool is_tp_selectable = (InpTPMode == TP_MANUAL);
        double risk_dist = MathAbs(entry_price - sl_price_base);
        double tp_price = is_buy ? entry_price + (risk_dist * InpTP_RR_Value) : entry_price - (risk_dist * InpTP_RR_Value);
        CreateLine(LINE_TAKE_PROFIT, "", tp_price, InpProfitLineColor, is_tp_selectable);
    }
}
//+------------------------------------------------------------------+
//| (کامل) به‌روزرسانی لیبل‌ها برای تمام حالت‌ها                      |
//+------------------------------------------------------------------+
void UpdateLineInfoLabels()
{
   if (ExtDialog.GetCurrentState() == STATE_IDLE) return;
   ETradeState state = ExtDialog.GetCurrentState();
   bool is_stairway = (state == STATE_PREP_STAIRWAY_BUY || state == STATE_PREP_STAIRWAY_SELL);
   double sl_price = GetLinePrice(LINE_STOP_LOSS);
   double tp_price = GetLinePrice(LINE_TAKE_PROFIT);
   double entry_for_calc = 0;

   if (is_stairway)
   {
        // اینجا قیمت از خط شکست جدید خوانده می‌شود
        double breakout_price = GetLinePrice(LINE_BREAKOUT_LEVEL);
        double pending_entry_price = GetLinePrice(LINE_PENDING_ENTRY);
        entry_for_calc = pending_entry_price;
        if(breakout_price == 0 || pending_entry_price == 0 || sl_price == 0) return;
        datetime time_pos = TimeCurrent() + (PeriodSeconds() * 15);

        // و لیبل برای خط شکست جدید ساخته می‌شود
        string breakout_text = StringFormat("BREAKOUT TRIGGER | %.5f", breakout_price);
        CreateStyledLabel(LINE_BREAKOUT_LEVEL, breakout_text, time_pos, breakout_price, InpWarningColor, C'255,255,255');
        string pending_text = StringFormat("MANUAL ENTRY | %.5f", pending_entry_price);
        CreateStyledLabel(LINE_PENDING_ENTRY, pending_text, time_pos, pending_entry_price, InpBuyButtonColor, C'255,255,255');
   }
   else
   {
        double entry_price = GetLinePrice(LINE_ENTRY_PRICE);
        entry_for_calc = entry_price;
        if(entry_price == 0 || sl_price == 0) return;
   }

   double lot_size = 0, risk_in_money = 0;
   CalculateLotSize(entry_for_calc, sl_price, lot_size, risk_in_money);
   datetime time_pos = TimeCurrent() + (PeriodSeconds() * 15);
   double pip_value = GetPipValue();
   double sl_pips = (pip_value > 0) ? MathAbs(sl_price - entry_for_calc) / pip_value : 0;
   string sl_text = StringFormat("STOP LOSS | Risk $%.2f (%.1f Pips)", risk_in_money, sl_pips);
   CreateStyledLabel(LINE_STOP_LOSS, sl_text, time_pos, sl_price, InpStopLineColor, C'255,255,255');
   if(tp_price > 0)
   {
      double tp_pips = (pip_value > 0) ? MathAbs(tp_price - entry_for_calc) / pip_value : 0;
      double rr_ratio = (sl_pips > 0.1) ? tp_pips / sl_pips : 0;
      string tp_text = StringFormat("TAKE PROFIT (Auto) | R:R %.1f:1", rr_ratio);
      CreateStyledLabel(LINE_TAKE_PROFIT, tp_text, time_pos, tp_price, InpProfitLineColor, C'255,255,255');
   }
}
#endif // LINES_MQH