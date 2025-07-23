//+------------------------------------------------------------------+
//|                                               TradeLogic.mqh |
//|          Core trading logic, calculations, and state management  |
//+------------------------------------------------------------------+
#ifndef TRADELOGIC_MQH
#define TRADELOGIC_MQH

// Forward declarations to resolve dependencies
void UpdateAllLabels();
void CreateTradeLines();
void UpdateAutoTPLine();
void UpdateAutoEntryLine();
double GetLinePrice(string line_name);
void DeleteTradeLines();

//+------------------------------------------------------------------+
//|                        MAIN LOGIC FUNCTIONS                      |
//+------------------------------------------------------------------+
void SetupTrade(ETradeState newState)
{
   CurrentState = newState;
   CreateTradeLines(); // Create lines first

   bool isMarketOrder = (newState == STATE_PREP_MARKET_BUY || newState == STATE_PREP_MARKET_SELL);

   // --- Set button states ---
   switch(newState)
   {
      case STATE_PREP_MARKET_BUY:
         ObjectSetString(0, BTN_EXECUTE_MARKET, OBJPROP_TEXT, "EXECUTE BUY");
         ObjectSetString(0, BTN_PREP_MARKET_SELL, OBJPROP_TEXT, "Cancel");
         ObjectSetInteger(0, BTN_PREP_MARKET_SELL, OBJPROP_BGCOLOR, InpCancelButtonColor);
         break;
      case STATE_PREP_MARKET_SELL:
         ObjectSetString(0, BTN_EXECUTE_MARKET, OBJPROP_TEXT, "EXECUTE SELL");
         ObjectSetString(0, BTN_PREP_MARKET_BUY, OBJPROP_TEXT, "Cancel");
         ObjectSetInteger(0, BTN_PREP_MARKET_BUY, OBJPROP_BGCOLOR, InpCancelButtonColor);
         break;
      case STATE_PREP_PENDING_BUY:
         ObjectSetString(0, BTN_EXECUTE_PENDING, OBJPROP_TEXT, "PLACE BUY");
         ObjectSetString(0, BTN_PREP_PENDING_SELL, OBJPROP_TEXT, "Cancel");
         ObjectSetInteger(0, BTN_PREP_PENDING_SELL, OBJPROP_BGCOLOR, InpCancelButtonColor);
         break;
      case STATE_PREP_PENDING_SELL:
         ObjectSetString(0, BTN_EXECUTE_PENDING, OBJPROP_TEXT, "PLACE SELL");
         ObjectSetString(0, BTN_PREP_PENDING_BUY, OBJPROP_TEXT, "Cancel");
         ObjectSetInteger(0, BTN_PREP_PENDING_BUY, OBJPROP_BGCOLOR, InpCancelButtonColor);
         break;
   }

   // --- Handle line logic ---
   if(isMarketOrder)
   {
       double marketPrice = (newState == STATE_PREP_MARKET_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
       ObjectMove(0, LINE_ENTRY_PRICE, 0, 0, marketPrice);
       ObjectSetInteger(0, LINE_ENTRY_PRICE, OBJPROP_SELECTABLE, false);
       ObjectSetInteger(0, LINE_TAKE_PROFIT, OBJPROP_SELECTABLE, InpTPMode == TP_MANUAL);
       if(InpTPMode == TP_RR_RATIO) UpdateAutoTPLine();
   }
   else if(CurrentStateIsPending())
   {
       if(InpAutoEntryPending) // Auto Entry Mode
       {
           ObjectSetInteger(0, LINE_ENTRY_PRICE, OBJPROP_SELECTABLE, false);
           ObjectSetInteger(0, LINE_TAKE_PROFIT, OBJPROP_SELECTABLE, true); // User must control TP
           UpdateAutoEntryLine();
       }
       else // Manual Entry Mode
       {
           ObjectSetInteger(0, LINE_ENTRY_PRICE, OBJPROP_SELECTABLE, true);
           ObjectSetInteger(0, LINE_TAKE_PROFIT, OBJPROP_SELECTABLE, InpTPMode == TP_MANUAL);
           if(InpTPMode == TP_RR_RATIO) UpdateAutoTPLine();
       }
   }

   UpdateAllLabels();
   ChartRedraw();
}

void ResetToIdleState()
{
   CurrentState = STATE_IDLE;
   isTradeLogicValid = false;
   DeleteTradeLines();

   // Reset Market buttons
   ObjectSetString(0, BTN_PREP_MARKET_BUY, OBJPROP_TEXT, "Market Buy");
   ObjectSetInteger(0, BTN_PREP_MARKET_BUY, OBJPROP_BGCOLOR, InpBuyButtonColor);
   ObjectSetString(0, BTN_PREP_MARKET_SELL, OBJPROP_TEXT, "Market Sell");
   ObjectSetInteger(0, BTN_PREP_MARKET_SELL, OBJPROP_BGCOLOR, InpSellButtonColor);
   ObjectSetString(0, BTN_EXECUTE_MARKET, OBJPROP_TEXT, "Execute");
   ObjectSetInteger(0, BTN_EXECUTE_MARKET, OBJPROP_BGCOLOR, InpDisabledButtonColor);
   ObjectSetString(0, INPUT_RISK_MARKET, OBJPROP_TEXT, DoubleToString(InpRiskPercent, 1));

   // Reset Pending buttons
   ObjectSetString(0, BTN_PREP_PENDING_BUY, OBJPROP_TEXT, "Pending Buy");
   ObjectSetInteger(0, BTN_PREP_PENDING_BUY, OBJPROP_BGCOLOR, InpBuyButtonColor);
   ObjectSetString(0, BTN_PREP_PENDING_SELL, OBJPROP_TEXT, "Pending Sell");
   ObjectSetInteger(0, BTN_PREP_PENDING_SELL, OBJPROP_BGCOLOR, InpSellButtonColor);
   ObjectSetString(0, BTN_EXECUTE_PENDING, OBJPROP_TEXT, "Place");
   ObjectSetInteger(0, BTN_EXECUTE_PENDING, OBJPROP_BGCOLOR, InpDisabledButtonColor);
   ObjectSetString(0, INPUT_RISK_PENDING, OBJPROP_TEXT, DoubleToString(InpRiskPercent, 1));

   // Reset info labels
   ObjectSetString(0, LABEL_ENTRY, OBJPROP_TEXT, "Entry: -");
   ObjectSetString(0, LABEL_SL, OBJPROP_TEXT, "SL: -");
   ObjectSetString(0, LABEL_TP, OBJPROP_TEXT, "TP: -");
   ObjectSetString(0, LABEL_LOT, OBJPROP_TEXT, "Lot: 0.00");
   ObjectSetString(0, LABEL_RISK_VALUE, OBJPROP_TEXT, "Risk Value: $0.00");

   ChartRedraw();
}

void ExecuteTrade()
{
   double entry = GetLinePrice(LINE_ENTRY_PRICE);
   double sl = GetLinePrice(LINE_STOP_LOSS);
   double tp = GetLinePrice(LINE_TAKE_PROFIT);

   if(entry <= 0 || sl <= 0) { Alert("Error: Entry and Stop Loss lines must be set."); return; }

   double lot_size = 0, risk_in_money = 0;
   if(!CalculateLotSize(entry, sl, lot_size, risk_in_money)) { Alert("Could not calculate lot size. Check risk inputs and SL distance."); return; }
   if(tp <= 0) tp = 0; // TP is optional

   bool success = false;
   string comment = "Trade by AdvRiskCalc v13.2";
   string symbol = _Symbol;

   if(CurrentState == STATE_PREP_MARKET_BUY || CurrentState == STATE_PREP_MARKET_SELL)
   {
      ENUM_ORDER_TYPE order_type = (CurrentState == STATE_PREP_MARKET_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double marketPrice = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
      success = trade.PositionOpen(symbol, order_type, lot_size, marketPrice, sl, tp, comment);
   }
   else if(CurrentStateIsPending())
   {
      ENUM_ORDER_TYPE order_type;
      double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);

      if(CurrentState == STATE_PREP_PENDING_BUY)
      {
         order_type = (entry > current_ask) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_BUY_LIMIT;
      }
      else // STATE_PREP_PENDING_SELL
      {
         order_type = (entry < current_bid) ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_SELL_LIMIT;
      }

      // Using the Place* functions for simplicity
      switch(order_type)
      {
       case ORDER_TYPE_BUY_STOP:  success = trade.BuyStop(lot_size, entry, symbol, sl, tp, ORDER_TIME_GTC, 0, comment); break;
       case ORDER_TYPE_BUY_LIMIT: success = trade.BuyLimit(lot_size, entry, symbol, sl, tp, ORDER_TIME_GTC, 0, comment); break;
       case ORDER_TYPE_SELL_STOP: success = trade.SellStop(lot_size, entry, symbol, sl, tp, ORDER_TIME_GTC, 0, comment); break;
       case ORDER_TYPE_SELL_LIMIT:success = trade.SellLimit(lot_size, entry, symbol, sl, tp, ORDER_TIME_GTC, 0, comment); break;
      }
   }

   if(success)
   {
      Alert("Order sent successfully!");
      ResetToIdleState();
   }
   else
   {
      Alert("Order Failed! Reason: ", trade.ResultRetcode(), " - ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//|                      CALCULATION & VALIDATION                    |
//+------------------------------------------------------------------+
bool CalculateLotSize(double entry, double sl, double &lot_size, double &risk_in_money)
{
   lot_size = 0;
   risk_in_money = 0;

   string risk_input_obj = (CurrentState == STATE_PREP_MARKET_BUY || CurrentState == STATE_PREP_MARKET_SELL) ? INPUT_RISK_MARKET : INPUT_RISK_PENDING;
   double risk_pct = StringToDouble(ObjectGetString(0, risk_input_obj, OBJPROP_TEXT));
   if(risk_pct <= 0) return false;

   risk_in_money = AccountInfoDouble(ACCOUNT_BALANCE) * (risk_pct / 100.0);

   string symbol = _Symbol;
   double point_size = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if (point_size <= 0) return false;
   
   double sl_points = MathAbs(entry - sl) / point_size;
   if(sl_points < 1) return false;

   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0) return false;

   double value_per_point = tick_value / tick_size;
   double total_risk_per_lot = sl_points * value_per_point;
   if(total_risk_per_lot <= 0) return false;

   lot_size = risk_in_money / total_risk_per_lot;

   // Normalize lot size
   double vol_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lot_size = MathFloor(lot_size / vol_step) * vol_step;

   // Check against min/max volume
   double min_vol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_vol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(lot_size < min_vol) lot_size = 0; // invalid lot size
   lot_size = MathMin(lot_size, max_vol);

   return(lot_size > 0);
}

void ValidateTradeLogicAndUpdateUI()
{
   if(CurrentState == STATE_IDLE) return;
   double entry = GetLinePrice(LINE_ENTRY_PRICE);
   double sl = GetLinePrice(LINE_STOP_LOSS);
   isTradeLogicValid = false;

   bool isBuy = (CurrentState == STATE_PREP_MARKET_BUY || CurrentState == STATE_PREP_PENDING_BUY);
   bool isSell = (CurrentState == STATE_PREP_MARKET_SELL || CurrentState == STATE_PREP_PENDING_SELL);

   if(entry > 0 && sl > 0)
   {
      if(isBuy && sl < entry) isTradeLogicValid = true;
      else if(isSell && sl > entry) isTradeLogicValid = true;
   }
   
   // Update execute button color based on validity
   if(CurrentState == STATE_PREP_MARKET_BUY)
      ObjectSetInteger(0, BTN_EXECUTE_MARKET, OBJPROP_BGCOLOR, isTradeLogicValid ? InpExecuteBuyColor : InpDisabledButtonColor);
   else if(CurrentState == STATE_PREP_MARKET_SELL)
      ObjectSetInteger(0, BTN_EXECUTE_MARKET, OBJPROP_BGCOLOR, isTradeLogicValid ? InpExecuteSellColor : InpDisabledButtonColor);
   else if(CurrentState == STATE_PREP_PENDING_BUY)
      ObjectSetInteger(0, BTN_EXECUTE_PENDING, OBJPROP_BGCOLOR, isTradeLogicValid ? InpOrderButtonColor : InpDisabledButtonColor);
   else if(CurrentState == STATE_PREP_PENDING_SELL)
      ObjectSetInteger(0, BTN_EXECUTE_PENDING, OBJPROP_BGCOLOR, isTradeLogicValid ? InpOrderButtonColor : InpDisabledButtonColor);
}

void UpdatePanelCalculations()
{
   double entry = GetLinePrice(LINE_ENTRY_PRICE);
   double sl = GetLinePrice(LINE_STOP_LOSS);
   double tp = GetLinePrice(LINE_TAKE_PROFIT);
   ObjectSetString(0, LABEL_ENTRY, OBJPROP_TEXT, "Entry: " + (entry > 0 ? DoubleToString(entry, _Digits) : "-"));
   ObjectSetString(0, LABEL_SL, OBJPROP_TEXT, "SL: " + (sl > 0 ? DoubleToString(sl, _Digits) : "-"));
   ObjectSetString(0, LABEL_TP, OBJPROP_TEXT, "TP: " + (tp > 0 ? DoubleToString(tp, _Digits) : "-"));
   double lot_size = 0, risk_in_money = 0;
   if(entry > 0 && sl > 0)
     CalculateLotSize(entry, sl, lot_size, risk_in_money);
   ObjectSetString(0, LABEL_RISK_VALUE, OBJPROP_TEXT, "Risk Value: $" + DoubleToString(risk_in_money, 2));
   ObjectSetString(0, LABEL_LOT, OBJPROP_TEXT, "Lot: " + DoubleToString(lot_size, 2));
   ChartRedraw(0);
}

void UpdateAllLabels()
{
   if(CurrentState == STATE_IDLE) return;
   UpdatePanelCalculations();
   UpdateLineInfoLabels();
   ValidateTradeLogicAndUpdateUI();
}

//+------------------------------------------------------------------+
//|                          HELPER FUNCTIONS                        |
//+------------------------------------------------------------------+
bool CurrentStateIsPending()
{
    return (CurrentState == STATE_PREP_PENDING_BUY || CurrentState == STATE_PREP_PENDING_SELL);
}

double GetPipValue()
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    // For 3 and 5 digit brokers, a pip is 10 points
    if (digits == 3 || digits == 5)
    {
        return 10 * point;
    }
    // For 2 and 4 digit brokers, a pip is 1 point
    return point;
}

#endif // TRADELOGIC_MQH