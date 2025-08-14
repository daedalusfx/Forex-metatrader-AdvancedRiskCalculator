//+------------------------------------------------------------------+
//|                                           StairwayExecution.mqh |
//|        منطق اجرای معاملات پلکانی با استاپ لاس مخفی             |
//+------------------------------------------------------------------+
#ifndef STAIRWAYEXECUTION_MQH
#define STAIRWAYEXECUTION_MQH

#include "SharedLogic.mqh"

// متغیرهای وضعیت داخلی برای این ماژول
static ulong    g_stairway_step1_ticket = 0;
static datetime g_stairway_breakout_candle_time = 0;
static double   g_stairway_lot_step2 = 0;

// تابع آماده‌سازی (فراخوانی با کلیک روی دکمه)
// In StairwayExecution.mqh -> Replace the entire SetupStairwayTrade function with this
void SetupStairwayTrade(ETradeState newState)
{
    ExtDialog.SetCurrentState(newState);
    CreateTradeLines(); // This function now creates all necessary lines
    UpdateAllLabels();  // Update their labels immediately
    ChartRedraw();
    Alert("Stairway Entry Armed. Drag the main line to the desired breakout price.");
}
// تابع اصلی مدیریت که از OnTick فراخوانی می‌شود
// In StairwayExecution.mqh -> Replace the entire ManageStairwayExecution function with this
void ManageStairwayExecution()
{
    ETradeState state = ExtDialog.GetCurrentState();
    // --- 1. اگر در حالت آماده‌باش برای شکست هستیم ---
    if (state == STATE_PREP_STAIRWAY_BUY || state == STATE_PREP_STAIRWAY_SELL)
    {
        // Get price from the Entry Line, not a fixed-name object
        double level_price = GetLinePrice(LINE_ENTRY_PRICE); 
        if (level_price <= 0) return; // Line does not exist

        double sl_price = GetLinePrice(LINE_STOP_LOSS);
        if (sl_price <= 0) return; // Stop loss is mandatory

        double current_price_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double current_price_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

        bool is_breakout = false;
        if (state == STATE_PREP_STAIRWAY_BUY && current_price_ask > level_price && iLow(_Symbol, 0, 1) < level_price)
        {
            is_breakout = true;
        }
        else if (state == STATE_PREP_STAIRWAY_SELL && current_price_bid < level_price && iHigh(_Symbol, 0, 1) > level_price)
        {
            is_breakout = true;
        }

        if (is_breakout)
        {
            double total_lot = 0, risk_money = 0;
            // Entry price for calculation is the level price itself
            if (!CalculateLotSize(level_price, sl_price, total_lot, risk_money))
            {
                Alert("Stairway: Could not calculate lot size. Aborting.");
                ResetToIdleState();
                return;
            }

            double lot_step1 = NormalizeDouble(total_lot * (InpStairwayInitialPercent / 100.0), 2);
            g_stairway_lot_step2 = NormalizeDouble(total_lot - lot_step1, 2);

            if (lot_step1 <= 0)
            {
                 Alert("Stairway: Initial lot size is zero. Aborting.");
                 ResetToIdleState();
                 return;
            }

            ENUM_ORDER_TYPE order_type = (state == STATE_PREP_STAIRWAY_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            double entry_price_live = (order_type == ORDER_TYPE_BUY) ? current_price_ask : current_price_bid;

            // ارسال اردر اول بدون SL/TP (استاپ مخفی)
            if (trade.PositionOpen(_Symbol, order_type, lot_step1, entry_price_live, 0, 0, "Stairway Step 1"))
            {
                g_stairway_step1_ticket = trade.ResultDeal();
                g_stairway_breakout_candle_time = iTime(_Symbol, 0, 0);
                ExtDialog.SetCurrentState(STATE_STAIRWAY_WAITING_FOR_CLOSE);
                Alert("Stairway Step 1 executed. Waiting for candle close.");
            }
            else
            {
                Alert("Stairway Step 1 failed: ", trade.ResultComment());
                ResetToIdleState();
            }
        }
    }
    // --- 2. اگر منتظر بسته شدن کندل برای پله دوم هستیم ---
    else if (state == STATE_STAIRWAY_WAITING_FOR_CLOSE)
    {
        if (iTime(_Symbol, 0, 0) > g_stairway_breakout_candle_time)
        {
            // The logic for the second entry remains the same
            if(PositionsTotal() > 0) // Ensure a position is still open
            {
                long pos_type = PositionGetInteger(POSITION_TYPE);
                ENUM_ORDER_TYPE order_type = (pos_type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
                double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
                
                if (g_stairway_lot_step2 > 0)
                {
                     if(trade.PositionOpen(_Symbol, order_type, g_stairway_lot_step2, price, 0, 0, "Stairway Step 2"))
                     {
                        Alert("Stairway Step 2 executed successfully.");
                     }
                     else
                     {
                        Alert("Stairway Step 2 failed: ", trade.ResultComment());
                     }
                }
            }
            // Reset state and global variables regardless of success
            g_stairway_step1_ticket = 0;
            g_stairway_breakout_candle_time = 0;
            g_stairway_lot_step2 = 0;
            ResetToIdleState(); // Go back to idle state
        }
    }
}
// تابع مدیریت استاپ لاس مخفی
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