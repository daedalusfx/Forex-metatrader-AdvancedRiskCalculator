//+------------------------------------------------------------------+
//|                                           StairwayExecution.mqh |
//|        V3.2 - افزودن هدر برای رفع خطای کامپایلر                  |
//+------------------------------------------------------------------+
#ifndef STAIRWAYEXECUTION_MQH
#define STAIRWAYEXECUTION_MQH

#include <Trade/Trade.mqh> // <--- اصلاح کلیدی
#include "SharedLogic.mqh"

// --- متغیرهای سراسری برای مدیریت وضعیت استراتژی پلکانی ---
static datetime g_stairway_breakout_candle_time = 0;
static ulong    g_stairway_step1_ticket = 0;
static double   g_stairway_total_lot = 0;

// --- تابع آماده‌سازی (بدون تغییر) ---
void SetupStairwayTrade(ETradeState newState)
{
    ExtDialog.SetCurrentState(newState);
    CreateTradeLines(ExtDialog.GetCurrentState());
    // CreateTradeLines();
    UpdateAllLabels();
    ChartRedraw();
    Alert("Stairway Entry Armed. Drag lines to desired levels. EA is monitoring for a breakout...");
}

//+------------------------------------------------------------------+
//| تابع ارسال سفارش معلق برای پله اول (نسخه نهایی و اصلاح شده)      |
//+------------------------------------------------------------------+
bool PlaceStairwayStep1_Pending()
{
    double pending_entry_price = GetLinePrice(LINE_PENDING_ENTRY);
    double sl_price = GetLinePrice(LINE_STOP_LOSS);
    double tp_price = GetLinePrice(LINE_TAKE_PROFIT);
    double risk_money = 0;

    if (!CalculateLotSize(pending_entry_price, sl_price, g_stairway_total_lot, risk_money))
    {
        Alert("محاسبه حجم با خطا مواجه شد. عملیات متوقف شد.");
        return false;
    }

    double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double vol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double vol_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    double lot_step1_raw = g_stairway_total_lot * (InpStairwayInitialPercent / 100.0);
    double lot_step1 = floor(lot_step1_raw / vol_step) * vol_step;

    if (lot_step1 < vol_min)
    {
        Alert(StringFormat("حجم محاسبه شده برای پله اول (%.2f) کمتر از حداقل حجم مجاز (%.2f) است. عملیات لغو شد.", lot_step1, vol_min));
        return false;
    }
    if (lot_step1 > vol_max)
    {
        Alert(StringFormat("حجم محاسبه شده برای پله اول (%.2f) بیشتر از حداکثر حجم مجاز (%.2f) است. عملیات لغو شد.", lot_step1, vol_max));
        return false;
    }

    bool is_buy = (ExtDialog.GetCurrentState() == STATE_PREP_STAIRWAY_BUY);
    ENUM_ORDER_TYPE order_type = is_buy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
    double current_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if ((is_buy && pending_entry_price >= current_price) || (!is_buy && pending_entry_price <= current_price))
    {
        Alert("قیمت ورودی برای سفارش لیمیت نسبت به قیمت فعلی بازار معتبر نیست. لطفاً خطوط را جابجا کنید.");
        return false;
    }
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
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

    if (trade.OrderSend(request, result))
    {
        if (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
        {
            g_stairway_step1_ticket = result.order;
            return true;
        }
    }
    
    Alert(StringFormat("ارسال سفارش معلق پله اول با خطا مواجه شد. Retcode: %d, Comment: %s", (int)result.retcode, result.comment));
    return false;
}


//+------------------------------------------------------------------+
//| تابع اصلی مدیریت اجرای استراتژی پلکانی (نسخه نهایی بر اساس الگوریتم شما) |
//+------------------------------------------------------------------+
void ManageStairwayExecution()
{
    ETradeState state = ExtDialog.GetCurrentState();

    // فاز اول: نظارت برای شکست قیمت و ارسال پله ۱
    if (state == STATE_PREP_STAIRWAY_BUY || state == STATE_PREP_STAIRWAY_SELL)
    {
        double breakout_price = GetLinePrice(LINE_ENTRY_PRICE);
        if (breakout_price <= 0) return;
        
        double current_price = (state == STATE_PREP_STAIRWAY_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        bool is_breakout = (state == STATE_PREP_STAIRWAY_BUY && current_price > breakout_price) || (state == STATE_PREP_STAIRWAY_SELL && current_price < breakout_price);
        
        if (is_breakout)
        {
            if(PlaceStairwayStep1_Pending())
            {
                g_stairway_breakout_candle_time = iTime(_Symbol, 0, 0);
                ExtDialog.SetCurrentState(STATE_STAIRWAY_WAITING_FOR_CONFIRMATION);
                ExtDialog.UpdateStairwayPanel("Breakout! Waiting candle close...", GetLinePrice(LINE_ENTRY_PRICE), GetLinePrice(LINE_PENDING_ENTRY));
                Alert("شکست قیمت شناسایی شد! سفارش معلق پله اول ارسال شد. در انتظار بسته شدن کندل برای تایید...");
            }
            else
            {
                ResetToIdleState(); // اگر ارسال پله اول ناموفق بود، همه چیز را ریست کن
            }
        }
    }
    // فاز دوم: بررسی کلوز کندل و ارسال پله ۲
    else if (state == STATE_STAIRWAY_WAITING_FOR_CONFIRMATION)
    {
        // اگر کندل جدیدی باز شده باشد (یعنی کندل شکست بسته شده است)
        if (iTime(_Symbol, 0, 0) > g_stairway_breakout_candle_time)
        {
            bool is_step1_triggered = false;
            if (PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == g_magic_number)
            {
                is_step1_triggered = true;
            }
            
            double breakout_candle_close = iClose(_Symbol, 0, 1); // قیمت بسته شدن کندل قبلی (کندل شکست)
            double breakout_price = GetLinePrice(LINE_ENTRY_PRICE);
            
            bool is_buy_setup = (GetLinePrice(LINE_STOP_LOSS) < breakout_price);

            // شرط تایید: آیا کندل در جهت شکست بسته شده است؟
            bool is_confirmed = (is_buy_setup && breakout_candle_close > breakout_price) ||
                                (!is_buy_setup && breakout_candle_close < breakout_price);

            if(is_confirmed)
            {
                // سناریوی ۱: ورود ایده‌آل (پله ۱ فعال شده و کندل هم تایید شده)
                if(is_step1_triggered)
                {
                    Alert("ورود ایده‌آل! پله ۱ فعال و کندل تایید شد. در حال ارسال پله ۲ به صورت Pending...");
                    ExtDialog.UpdateStairwayPanel("Confirmed. Placing Step 2...", GetLinePrice(LINE_ENTRY_PRICE), GetLinePrice(LINE_PENDING_ENTRY));

                    
                    double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                    double current_pos_vol = PositionGetDouble(POSITION_VOLUME);
                    double lot_step2_raw = g_stairway_total_lot - current_pos_vol;
                    double lot_step2 = floor(lot_step2_raw / vol_step) * vol_step;

                    if(lot_step2 >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
                    {
                       // --- (کد جدید) ---
                       // به جای اجرای Market، یک سفارش Limit دیگر برای پله دوم ارسال می‌کنیم
                       MqlTradeRequest request_step2;
                       MqlTradeResult  result_step2;
                       ZeroMemory(request_step2);
                       ZeroMemory(result_step2);
                       
                       request_step2.action = TRADE_ACTION_PENDING;
                       request_step2.symbol = _Symbol;
                       request_step2.volume = lot_step2;
                       request_step2.price = GetLinePrice(LINE_PENDING_ENTRY); // همان قیمت ورود پله اول
                       request_step2.sl = GetLinePrice(LINE_STOP_LOSS);
                       request_step2.tp = GetLinePrice(LINE_TAKE_PROFIT);
                       request_step2.type = is_buy_setup ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
                       request_step2.magic = g_magic_number;
                       request_step2.comment = "Stairway_Step2_Pending";
                       
                       if(!trade.OrderSend(request_step2, result_step2))
                       {
                           Alert(StringFormat("ارسال سفارش معلق پله دوم با خطا مواجه شد. Comment: %s", result_step2.comment));
                       }
                       else
                       {
                           Alert("سفارش معلق پله دوم با موفقیت ارسال شد.");
                       }
                       // --- (پایان کد جدید) ---
                    }
                }
                // سناریوی ۲: اصلاحی (پله ۱ فعال نشده ولی کندل تایید شده)
                else
                {
                    Alert("سناریوی اصلاحی! پله ۱ فعال نشد اما کندل تایید شد. در حال جایگزینی با سفارش ۱۰۰٪.");
                    ExtDialog.UpdateStairwayPanel("Corrective. Replacing order...", GetLinePrice(LINE_ENTRY_PRICE), GetLinePrice(LINE_PENDING_ENTRY));
                    if(trade.OrderDelete(g_stairway_step1_ticket)) // حذف سفارش معلق پله ۱
                    {
                        // ارسال یک سفارش جدید با حجم کامل
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
                        request.comment = "Stairway_Full_Pending_Corrective";
                        
                        if(!trade.OrderSend(request, result))
                        {
                            Alert(StringFormat("ارسال سفارش ۱۰۰٪ جدید با خطا مواجه شد. Comment: %s", result.comment));
                            ExtDialog.UpdateStairwayPanel("Fakeout! Cancelling...", 0, 0);

                        }
                    }
                }
            }
            else // اگر کندل تایید نشد (شکست فیک)
            {
                if(is_step1_triggered)
                {
                    Alert("پولبک ناموفق! پله ۱ فعال شد اما کندل تایید نشد. پله ۲ لغو گردید. معامله با حجم کمتر ادامه می‌یابد.");
                    ExtDialog.UpdateStairwayPanel("Confirmed. Placing Step 2...", GetLinePrice(LINE_ENTRY_PRICE), GetLinePrice(LINE_PENDING_ENTRY));

                }
                else
                {
                    Alert("شکست ناموفق بود. کندل تایید نشد. در حال لغو سفارش معلق پله اول...");
                    trade.OrderDelete(g_stairway_step1_ticket);
                }
            }
            
            // در هر صورت، پس از بررسی کلوز کندل، فرآیند تمام شده و به حالت آماده برمی‌گردیم
            ResetToIdleState();
        }
    }
}


//+------------------------------------------------------------------+
//| تابع مدیریت استاپ لاس مخفی (نسخه نهایی و اصلاح شده)               |
//+------------------------------------------------------------------+
void ManageStairwayHiddenSL()
{
    double sl_price = GetLinePrice(LINE_STOP_LOSS);
    if (sl_price <= 0) return;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i); // <-- تغییر
        if (PositionSelectByTicket(ticket))   // <-- تغییر
    
        {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
                PositionGetInteger(POSITION_MAGIC) == g_magic_number &&
                PositionGetDouble(POSITION_SL) == 0)
            {
                long type = PositionGetInteger(POSITION_TYPE);
                ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);

                if (type == POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol, SYMBOL_BID) <= sl_price)
                {
                    trade.PositionClose(ticket);
                }
                else if (type == POSITION_TYPE_SELL && SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= sl_price)
                {
                    trade.PositionClose(ticket);
                }
            }
        }
    }
}

#endif // STAIRWAYEXECUTION_MQH
