//+------------------------------------------------------------------+
//|                                           StairwayExecution.mqh |
//|        V3.0 - بازنویسی کامل با منطق سه سناریویی هوشمند           |
//+------------------------------------------------------------------+
#ifndef STAIRWAYEXECUTION_MQH
#define STAIRWAYEXECUTION_MQH

#include "SharedLogic.mqh"

// --- متغیرهای سراسری برای مدیریت وضعیت استراتژی پلکانی ---
static datetime g_stairway_breakout_candle_time = 0; // زمان کندلی که شکست در آن رخ داده
static ulong    g_stairway_step1_ticket = 0;         // تیکت سفارش پندینگ پله اول
static double   g_stairway_total_lot = 0;            // حجم لات کل محاسبه شده

// --- (بازنویسی شده) تابع آماده‌سازی ---
void SetupStairwayTrade(ETradeState newState)
{
    ExtDialog.SetCurrentState(newState);
    CreateTradeLines();
    UpdateAllLabels();
    ChartRedraw();
    Alert("Stairway Entry Armed. Drag lines to desired levels. EA is monitoring for a breakout...");
}



bool PlaceStairwayStep1_Pending()
{
    double breakout_price = GetLinePrice(LINE_ENTRY_PRICE);
    double pending_entry_price = GetLinePrice(LINE_PENDING_ENTRY);
    double sl_price = GetLinePrice(LINE_STOP_LOSS);
    double tp_price = GetLinePrice(LINE_TAKE_PROFIT);
    double risk_money = 0;

    if (!CalculateLotSize(pending_entry_price, sl_price, g_stairway_total_lot, risk_money))
    {
        Alert("Could not calculate lot size. Aborting stairway setup.");
        return false;
    }

    double lot_step1 = NormalizeDouble(g_stairway_total_lot * (InpStairwayInitialPercent / 100.0), 2);
    if(lot_step1 < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        Alert("Step 1 lot size is too small. Aborting.");
        return false;
    }
    
    bool is_buy = (ExtDialog.GetCurrentState() == STATE_PREP_STAIRWAY_BUY);
    ENUM_ORDER_TYPE order_type = is_buy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;

    double current_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if((is_buy && pending_entry_price >= current_price) || (!is_buy && pending_entry_price <= current_price))
    {
         Alert("Pending entry price is not valid for a limit order relative to current price. Please adjust lines.");
         return false;
    }

    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request); // (Corrected) Use ZeroMemory to initialize
    ZeroMemory(result);

    request.action = TRADE_ACTION_PENDING;
    request.symbol = _Symbol;
    request.volume = lot_step1;
    request.price = pending_entry_price;
    request.sl = sl_price;
    request.tp = tp_price;
    request.type = order_type;
    request.magic = g_magic_number;
    request.comment = "Stairway_Step1_Pending";

    if(OrderSend(request, result))
    {
        g_stairway_step1_ticket = result.order;
        return true;
    }
    
    Alert("Failed to place Stairway Step 1 pending order: ", GetLastError());
    return false;
}


void ManageStairwayExecution()
{
    ETradeState state = ExtDialog.GetCurrentState();

    // --- Section 1: Monitor for breakout and place the initial pending order ---
    // (Corrected) Typo fixed from STAIRway to STAIRWAY
    if (state == STATE_PREP_STAIRWAY_BUY || state == STATE_PREP_STAIRWAY_SELL)
    {
        double breakout_price = GetLinePrice(LINE_ENTRY_PRICE);
        if (breakout_price <= 0) return;
        
        // (Corrected) Typo fixed from STAIRway to STAIRWAY
        double current_price = (state == STATE_PREP_STAIRWAY_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        bool is_breakout = (state == STATE_PREP_STAIRWAY_BUY && current_price > breakout_price) ||
                           (state == STATE_PREP_STAIRWAY_SELL && current_price < breakout_price);

        if (is_breakout)
        {
            if(PlaceStairwayStep1_Pending())
            {
                g_stairway_breakout_candle_time = iTime(_Symbol, 0, 0);
                ExtDialog.SetCurrentState(STATE_STAIRWAY_WAITING_FOR_CONFIRMATION);
                Alert("Breakout Detected! Step 1 pending order placed. Waiting for pullback or candle close confirmation...");
            }
            else
            {
                ResetToIdleState();
            }
        }
    }
    // --- Section 2: Wait for pending order activation or candle close (the core logic) ---
    else if (state == STATE_STAIRWAY_WAITING_FOR_CONFIRMATION)
    {
        if (iTime(_Symbol, 0, 0) > g_stairway_breakout_candle_time)
        {
            bool is_step1_triggered = OrderSelect(g_stairway_step1_ticket) ? false : true;
            
            double breakout_candle_close = iClose(_Symbol, 0, 1);
            double breakout_price = GetLinePrice(LINE_ENTRY_PRICE);
            bool is_buy_setup = PositionSelect(_Symbol) ? (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) : (GetLinePrice(LINE_STOP_LOSS) < breakout_price);

            bool is_confirmed = (is_buy_setup && breakout_candle_close > breakout_price) ||
                                (!is_buy_setup && breakout_candle_close < breakout_price);

            if(is_confirmed)
            {
                // Scenarios from here do not contain the typo
                if(is_step1_triggered)
                {
                    Alert("Ideal Entry! Step 1 triggered and candle confirmed. Executing Step 2.");
                    double lot_step2 = NormalizeDouble(g_stairway_total_lot - PositionGetDouble(POSITION_VOLUME), 2);
                    if(lot_step2 >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
                    {
                       ENUM_ORDER_TYPE mkt_type = is_buy_setup ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
                       trade.PositionOpen(_Symbol, mkt_type, lot_step2, 0, 0, 0, "Stairway_Step2_Market");
                    }
                }
                else
                {
                    Alert("Corrective Scenario! Step 1 missed but candle confirmed. Replacing with a new 100% risk pending order.");
                    trade.OrderDelete(g_stairway_step1_ticket); 

                    MqlTradeRequest request;
                    MqlTradeResult result;
                    ZeroMemory(request);
                    ZeroMemory(result);

                    request.action = TRADE_ACTION_PENDING;
                    request.symbol = _Symbol;
                    request.volume = g_stairway_total_lot;
                    request.price = GetLinePrice(LINE_PENDING_ENTRY);
                    request.sl = GetLinePrice(LINE_STOP_LOSS);
                    request.tp = GetLinePrice(LINE_TAKE_PROFIT);
                    request.type = is_buy_setup ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
                    request.magic = g_magic_number;
                    request.comment = "Stairway_Full_Pending";

                    if(!trade.OrderSend(request, result))
                    {
                        Alert("Failed to place the new 100% pending order. Error: ", result.comment);
                    }
                    else
                    {
                        Alert("New 100% pending order placed successfully at ", DoubleToString(request.price, _Digits));
                    }
                }
            }
            else 
            {
                if(is_step1_triggered)
                {
                    Alert("Failed Pullback! Step 1 triggered but candle did not confirm. Step 2 is cancelled.");
                }
                else
                {
                    Alert("Breakout failed. Cancelling pending order.");
                    trade.OrderDelete(g_stairway_step1_ticket);
                }
            }
            
            ResetToIdleState();
        }
    }
}

// تابع مدیریت استاپ لاس مخفی (بدون تغییر باقی می‌ماند)
void ManageStairwayHiddenSL()
{
    // این تابع باید چک کند آیا معامله‌ای با مجیک نامبر ما باز است که توسط منطق پلکانی باز شده
    // و SL و TP برای آن تعریف نشده. اگر بله، قیمت را با خطوط SL/TP چک کند.
    double sl_price = GetLinePrice(LINE_STOP_LOSS);
    if (sl_price <= 0) return;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionGetInteger(POSITION_MAGIC) == g_magic_number && PositionGetDouble(POSITION_SL) == 0)
        {
            long type = PositionGetInteger(POSITION_TYPE);
            if (type == POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol, SYMBOL_BID) <= sl_price)
            {
                trade.PositionClose(PositionGetTicket(i));
            }
            else if (type == POSITION_TYPE_SELL && SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= sl_price)
            {
                trade.PositionClose(PositionGetTicket(i));
            }
        }
    }
}


#endif // STAIRWAYEXECUTION_MQH