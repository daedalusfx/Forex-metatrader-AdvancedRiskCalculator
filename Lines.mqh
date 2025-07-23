//+------------------------------------------------------------------+
//|                                                     Lines.mqh |
//|         V2.1 - توابع مدیریت خطوط با لیبل‌های بهبودیافته        |
//+------------------------------------------------------------------+
#ifndef LINES_MQH
#define LINES_MQH

//--- ایجاد خط افقی
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

//--- ایجاد لیبل‌های استایل‌دار
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
        ObjectSetInteger(0, label_name, OBJPROP_BACK, false);
    }
    ObjectSetString(0, label_name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, label_name, OBJPROP_BGCOLOR, bg_color);
    ObjectSetInteger(0, label_name, OBJPROP_COLOR, text_color);
    ObjectMove(0, label_name, 0, time, price);
}

//--- حذف خطوط
void DeleteTradeLines()
{
   ObjectDelete(0, LINE_ENTRY_PRICE);
   ObjectDelete(0, LINE_STOP_LOSS);
   ObjectDelete(0, LINE_TAKE_PROFIT);
   ObjectDelete(0, LINE_ENTRY_PRICE + "_label");
   ObjectDelete(0, LINE_STOP_LOSS + "_label");
   ObjectDelete(0, LINE_TAKE_PROFIT + "_label");
}

//--- دریافت قیمت خط
double GetLinePrice(string line_name)
{
   if(ObjectFind(0, line_name) != -1)
      return ObjectGetDouble(0, line_name, OBJPROP_PRICE, 0);
   return 0;
}

//--- ایجاد مجموعه اولیه خطوط
void CreateTradeLines()
{
   DeleteTradeLines();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pip_value = GetPipValue();
   bool is_pending = CurrentStateIsPending();
   bool isBuy = (ExtDialog.GetCurrentState() == STATE_PREP_MARKET_BUY || ExtDialog.GetCurrentState() == STATE_PREP_PENDING_BUY);

   double initial_sl_pips = 20.0;
   double initial_pending_distance_pips = 50.0;
   double sl_distance_points = initial_sl_pips * pip_value;
   double pending_distance_points = initial_pending_distance_pips * pip_value;
   
   g_entry_price = is_pending ? (isBuy ? ask + pending_distance_points : bid - pending_distance_points) : (isBuy ? ask : bid);
   g_sl_price = isBuy ? g_entry_price - sl_distance_points : g_entry_price + sl_distance_points;
   double rr_sl_distance = MathAbs(g_entry_price - g_sl_price);
   g_tp_price = isBuy ? g_entry_price + (rr_sl_distance * InpTP_RR_Value) : g_entry_price - (rr_sl_distance * InpTP_RR_Value);

   CreateLine(LINE_ENTRY_PRICE, "", g_entry_price, InpEntryLineColor);
   CreateLine(LINE_STOP_LOSS, "", g_sl_price, InpStopLineColor);
   CreateLine(LINE_TAKE_PROFIT, "", g_tp_price, InpProfitLineColor);
}

//--- به‌روزرسانی لیبل‌های اطلاعاتی خطوط
void UpdateLineInfoLabels()
{
   if (ExtDialog.GetCurrentState() == STATE_IDLE) return;
   
   double entry_price = GetLinePrice(LINE_ENTRY_PRICE);
   double sl_price = GetLinePrice(LINE_STOP_LOSS);
   double tp_price = GetLinePrice(LINE_TAKE_PROFIT);
   if(entry_price == 0) return;

   double lot_size = 0, risk_in_money = 0;
   if(sl_price > 0)
     CalculateLotSize(entry_price, sl_price, lot_size, risk_in_money);

   datetime time_pos = TimeCurrent() + (PeriodSeconds() * 15); 
   double pip_value = GetPipValue();
   
   string entry_text = StringFormat("ENTRY | %.5f", entry_price);
   CreateStyledLabel(LINE_ENTRY_PRICE, entry_text, time_pos, entry_price, InpPanelBackgroundColor, InpTextColor);

   if(sl_price > 0)
   {
      double sl_pips = (pip_value > 0) ? MathAbs(sl_price - entry_price) / pip_value : 0;
      string sl_text = StringFormat("SL | %.5f | %.1f Pips | -$%.2f", sl_price, sl_pips, risk_in_money);
      CreateStyledLabel(LINE_STOP_LOSS, sl_text, time_pos, sl_price, InpStopLineColor, C'255,255,255');

      if(tp_price > 0)
      {
         double tp_pips = (pip_value > 0) ? MathAbs(tp_price - entry_price) / pip_value : 0;
         double rr_ratio = (sl_pips > 0) ? tp_pips / sl_pips : 0;
         double reward_in_money = (risk_in_money > 0 && rr_ratio > 0) ? risk_in_money * rr_ratio : 0;
         string tp_text = StringFormat("TP | %.5f | %.1f Pips | +$%.2f | R:R %.2f", tp_price, tp_pips, reward_in_money, rr_ratio);
         CreateStyledLabel(LINE_TAKE_PROFIT, tp_text, time_pos, tp_price, InpProfitLineColor, C'255,255,255');
      }
   }
}

//--- به‌روزرسانی خودکار خط TP
void UpdateAutoTPLine()
{
    if(ExtDialog.GetCurrentState() == STATE_IDLE || InpTPMode != TP_RR_RATIO) return;
    double entry_price = GetLinePrice(LINE_ENTRY_PRICE);
    double sl_price = GetLinePrice(LINE_STOP_LOSS);
    if(entry_price <= 0 || sl_price <= 0 || InpTP_RR_Value <= 0) return;
    bool is_buy = (sl_price < entry_price);
    double sl_distance = MathAbs(entry_price - sl_price);
    double tp_price = is_buy ? entry_price + (sl_distance * InpTP_RR_Value) : entry_price - (sl_distance * InpTP_RR_Value);
    if(tp_price > 0) ObjectMove(0, LINE_TAKE_PROFIT, 0, 0, tp_price);
}

#endif // LINES_MQH