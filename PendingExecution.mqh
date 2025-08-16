//+------------------------------------------------------------------+
//|                                          PendingExecution.mqh |
//|         V2.1 - منطق اجرای معاملات Pending با ارجاع به کلاس پنل   |
//+------------------------------------------------------------------+
#ifndef PENDINGEXECUTION_MQH
#define PENDINGEXECUTION_MQH

void SetupPendingTrade(ETradeState newState)
{
   ExtDialog.SetCurrentState(newState);
   ExtDialog.SetPendingUIMode(newState);
   CreateTradeLines();

   if(InpAutoEntryPending)
   {
       ObjectSetInteger(0, LINE_STOP_LOSS,   OBJPROP_SELECTABLE, true);
       ObjectSetInteger(0, LINE_ENTRY_PRICE, OBJPROP_SELECTABLE, false);
       ObjectSetInteger(0, LINE_TAKE_PROFIT, OBJPROP_SELECTABLE, false);
   }
   else
   {
       ObjectSetInteger(0, LINE_ENTRY_PRICE, OBJPROP_SELECTABLE, true);
       ObjectSetInteger(0, LINE_STOP_LOSS,   OBJPROP_SELECTABLE, true);
       ObjectSetInteger(0, LINE_TAKE_PROFIT, OBJPROP_SELECTABLE, true);
       if(InpTPMode == TP_RR_RATIO)
       {
          ObjectSetInteger(0, LINE_TAKE_PROFIT, OBJPROP_SELECTABLE, false);
          UpdateDynamicLines();
       }
   }

   UpdateAllLabels();
   ChartRedraw();
}

void ExecutePendingTrade()
{
   double entry = GetLinePrice(LINE_ENTRY_PRICE);
   double sl = GetLinePrice(LINE_STOP_LOSS);
   double tp = GetLinePrice(LINE_TAKE_PROFIT);
   if(entry <= 0 || sl <= 0) { Alert("Error: Entry and Stop Loss lines must be set."); return; }

   double lot_size = 0, risk_in_money = 0;
   if(!CalculateLotSize(entry, sl, lot_size, risk_in_money)) 
   { 
      Alert("Could not calculate lot size. Check inputs and SL distance."); 
      return; 
   }
   if(tp <= 0) tp = 0;

   ENUM_ORDER_TYPE order_type;
   if(ExtDialog.GetCurrentState() == STATE_PREP_PENDING_BUY)
      order_type = (entry > SymbolInfoDouble(_Symbol, SYMBOL_ASK)) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_BUY_LIMIT;
   else
      order_type = (entry < SymbolInfoDouble(_Symbol, SYMBOL_BID)) ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_SELL_LIMIT;
      
   if(!IsTradeRequestSafe(lot_size, order_type, entry, sl, tp)) return;

   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action   = TRADE_ACTION_PENDING;
   request.symbol   = _Symbol;
   request.volume   = lot_size;
   request.price    = NormalizeDouble(entry, _Digits);
   request.sl       = NormalizeDouble(sl, _Digits);
   request.tp       = NormalizeDouble(tp, _Digits);
   request.type     = order_type;
   request.type_time = ORDER_TIME_GTC;
   request.magic = g_magic_number;
   request.comment  = "Trade by AdvRiskCalc v2.1";
   
   if(OrderSend(request, result))
   {
      Alert("Pending order sent successfully!");
      ResetToIdleState();
   }
   else
   {
      Alert("Pending Order Failed! Reason: ", (string)result.retcode, " - ", result.comment);
      ResetToIdleState();

   }
}

#endif // PENDINGEXECUTION_MQH
