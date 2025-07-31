//+------------------------------------------------------------------+
//|                                           MarketExecution.mqh |
//|         V2.1 - منطق اجرای معاملات Market با ارجاع به کلاس پنل    |
//+------------------------------------------------------------------+
#ifndef MARKETEXECUTION_MQH
#define MARKETEXECUTION_MQH

void SetupMarketTrade(ETradeState newState)
{
   ExtDialog.SetCurrentState(newState);
   ExtDialog.SetMarketUIMode(newState);
   CreateTradeLines();

   double marketPrice = (newState == STATE_PREP_MARKET_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ObjectMove(0, LINE_ENTRY_PRICE, 0, 0, marketPrice);
   ObjectSetInteger(0, LINE_ENTRY_PRICE, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, LINE_TAKE_PROFIT, OBJPROP_SELECTABLE, InpTPMode == TP_MANUAL);
   
   if(InpTPMode == TP_RR_RATIO) UpdateAutoTPLine();

   UpdateAllLabels();
   ChartRedraw();
}

void ExecuteMarketTrade()
{
   double sl = GetLinePrice(LINE_STOP_LOSS);
   double tp = GetLinePrice(LINE_TAKE_PROFIT);
   if(sl <= 0) { Alert("Error: Stop Loss line must be set."); return; }

   double lot_size = 0, risk_in_money = 0;
   ENUM_ORDER_TYPE order_type = (ExtDialog.GetCurrentState() == STATE_PREP_MARKET_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(!CalculateLotSize(price, sl, lot_size, risk_in_money)) 
   { 
      Alert("Could not calculate lot size. Check inputs and SL distance."); 
      return; 
   }
   if(tp <= 0) tp = 0;

   if(!IsTradeRequestSafe(lot_size, order_type, price, sl, tp)) return;
   
   trade.SetExpertMagicNumber(g_magic_number);
   trade.SetMarginMode();
   trade.SetDeviationInPoints(InpSlippage);

   if(trade.PositionOpen(_Symbol, order_type, lot_size, price, sl, tp, "Trade by AdvRiskCalc v2.1"))
   {
      Alert("Market order sent successfully!");
      ResetToIdleState();
   }
   else
   {
      Alert("Market Order Failed! Reason: ", trade.ResultRetcode(), " - ", trade.ResultComment());
   }
}

#endif // MARKETEXECUTION_MQH