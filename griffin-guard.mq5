//+------------------------------------------------------------------+
//|                                     AdvancedRiskCalculator.mq5 |
//|                                     Version 2.1 - Final UI     |
//+------------------------------------------------------------------+
#property copyright "daedalusfx"
#property link      "your.website.com"
#property version   "2.1"
#property description "نسخه ۲.۱: UI نهایی با نمایش آمار معاملات باز."

//--- کتابخانه‌های استاندارد
#include <Trade\Trade.mqh>

//--- فایل‌های پروژه به ترتیب وابستگی
#include "Defines.mqh"
#include "PanelDialog.mqh"
#include "DisplayCanvas.mqh"
#include "StateManager.mqh"
#include "SpreadAtrAnalysis.mqh"

//--- متغیرهای سراسری
CPanelDialog ExtDialog;
CDisplayCanvas g_DisplayCanvas;
CSpreadAtrAnalysis g_SpreadAtrPanel;

//--- فایل‌های منطقی
#include "Lines.mqh"
#include "SharedLogic.mqh"
#include "MarketExecution.mqh"
#include "PendingExecution.mqh"
#include "StairwayExecution.mqh"
#include "QtBridge.mqh" // ماژول جدید ATM و پنل Qt


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{

   if(!ExtDialog.Create(0, "griffin-guard-beta", 0, 10, 30))
   {
      return(INIT_FAILED);
   }
   ExtDialog.Run();
   if(!g_DisplayCanvas.Create(0, "DisplayCanvas", 0, InpDisplayPanelX, InpDisplayPanelY, InpDisplayPanelW, InpDisplayPanelH))
   {
      return(INIT_FAILED);
   }
   g_SpreadAtrPanel.Initialize(CORNER_RIGHT_UPPER, 15, 30);

   InitializeMagicNumber();
   trade.SetExpertMagicNumber(g_magic_number);
   if(InpEnablePropRules)
   {
      g_prop_rules_active = true;
      bool stateFileExists = LoadStateFromFile();
      if(!stateFileExists)
      {
         Print("No state file found. Initializing prop firm rules for the first time.");
         g_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
         g_peak_equity = g_initial_balance;
         g_current_trading_day = TimeTradeServer();
         g_start_of_day_base = (InpDailyDDBase == DD_FROM_BALANCE) ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
         ArrayFree(g_daily_profits);
         SaveStateToFile();
      }
      else
      {
         datetime server_time = TimeTradeServer();
         long current_day_index = (long)(server_time / 86400);
         long last_day_index = (long)(g_current_trading_day / 86400);
         if(current_day_index > last_day_index)
         {
            Print("New trading day detected upon initialization.");
            double end_of_day_base = (InpDailyDDBase == DD_FROM_BALANCE) ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
            double previous_day_profit = end_of_day_base - g_start_of_day_base;
            
            if(InpEnableConsistencyRule)
            {
               int new_size = ArraySize(g_daily_profits) + 1;
               ArrayResize(g_daily_profits, new_size);
               g_daily_profits[new_size - 1].date = g_current_trading_day;
               g_daily_profits[new_size - 1].profit = previous_day_profit;
            }
            
            g_current_trading_day = server_time;
            g_start_of_day_base = end_of_day_base;
            SaveStateToFile();
         }
      }
   }

   // --- (کد نهایی) بازگردانی کامل وضعیت پلکانی ---
   if(g_stairway_restored_state >= STATE_PREP_STAIRWAY_BUY)
   {
       Print("OnInit --> ورود به بلوک بازیابی وضعیت پلکانی.");

       // ۱. (اصلاح شد) ابتدا وضعیت پنل را بازیابی می‌کنیم
       // این کار باعث می‌شود GetCurrentState() وضعیت صحیح را برگرداند
       ExtDialog.RestoreUIFromState(g_stairway_restored_state);
       
       // ۲. (اصلاح شد) حالا که پنل وضعیت صحیح را می‌داند، خطوط را ایجاد می‌کنیم
       CreateTradeLines(); 
       
       Print("OnInit --> قیمت خط شکست قبل از جابجایی: ", g_stairway_restored_breakout_price);
       if(g_stairway_restored_breakout_price > 0)
       {
           if(ObjectFind(0, LINE_BREAKOUT_LEVEL) != -1)
           {
               ObjectMove(0, LINE_BREAKOUT_LEVEL, 0, 0, g_stairway_restored_breakout_price);
               Print("OnInit --> دستور ObjectMove برای خط شکست اجرا شد.");
           }
           else
           {
               Print("OnInit --> خطا: شیء LINE_BREAKOUT_LEVEL روی چارت پیدا نشد! (این خطا دیگر نباید رخ دهد)");
           }
       }
       
       if(g_stairway_restored_pending_entry_price > 0) ObjectMove(0, LINE_PENDING_ENTRY, 0, 0, g_stairway_restored_pending_entry_price);
       if(g_stairway_restored_sl_price > 0) ObjectMove(0, LINE_STOP_LOSS, 0, 0, g_stairway_restored_sl_price);
       if(g_stairway_restored_tp_price > 0) ObjectMove(0, LINE_TAKE_PROFIT, 0, 0, g_stairway_restored_tp_price);
       
       // ۳. آپدیت نهایی لیبل‌ها
       UpdateAllLabels();
       Print("OnInit --> بازیابی حالت پلکانی و خطوط با موفقیت انجام شد.");
   }
   
   UpdateDisplayData();
   ChartRedraw();
       // --- راه‌اندازی ماژول ATM و پنل Qt ---
       SL_Backup_File = MQLInfoString(MQL_PROGRAM_NAME) + "_" + (string)ChartID() + "_SL_Backup.dat";
       LoadOriginalSLs(); // این تابع باید در SharedLogic.mqh باشد
      InitializeService();
      EventSetTimer(1);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // --- پاک‌سازی‌های عمومی ---
   DeleteTradeLines();
   g_SpreadAtrPanel.Deinitialize();
   g_DisplayCanvas.Destroy();
   ExtDialog.Destroy(reason);
   Comment("");
   
   // فقط زمانی ترد گرافیکی را به طور کامل می‌بندیم که اکسپرت به
   // دلایل دائمی در حال حذف شدن باشد (مثل بستن چارت یا حذف اکسپرت)
   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE || reason == REASON_CLOSE)
   {
      Print("Permanent deinitialization detected. Finalizing GUI thread.");
      FinalizeService(); // ترد و اپلیکیشن گرافیکی را به درستی خاتمه می‌دهد
   }
   else
   {
      Print("Temporary deinitialization (reason: ", reason, "). GUI thread will remain active.");
   }
   SaveOriginalSLs();
   EventKillTimer();
   SaveStateToFile();
}

//+------------------------------------------------------------------+
//| OnTick - در هر تیک قیمت فراخوانی می‌شود                          |
//+------------------------------------------------------------------+
void OnTick()
{
   ETradeState current_state = ExtDialog.GetCurrentState();
   if(current_state >= STATE_PREP_STAIRWAY_BUY && current_state <= STATE_STAIRWAY_WAITING_FOR_CONFIRMATION)
   {
      ManageStairwayExecution();
   }

   ManageStairwayHiddenSL();
   g_SpreadAtrPanel.Update();
   
   // نمایشگر فقط زمانی آپدیت می‌شود که نیاز باشد (در حالت آماده‌باش یا وقتی معامله باز است)
   if(ExtDialog.GetCurrentState() != STATE_IDLE || PositionsTotal() > 0)
   {
      UpdateDisplayData();
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function - قلب ماشین وضعیت                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   ExtDialog.ChartEvent(id, lparam, dparam, sparam);
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      ExtDialog.HandleDragEvent(sparam);
   }
}


//+------------------------------------------------------------------+
//|   محاسبه و نقاشی تمام داده‌های نمایشی (نسخه کامل و صحیح)         |
//+------------------------------------------------------------------+
void UpdateDisplayData()
{
    // --- بخش ۱: جمع‌آوری داده‌های مربوط به معامله جدید ---
    double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
    double entry_price = GetLinePrice(LINE_ENTRY_PRICE);
    double sl_price = GetLinePrice(LINE_STOP_LOSS);
    double tp_price = GetLinePrice(LINE_TAKE_PROFIT);
    double lot_size = 0, risk_in_money = 0;

    // --- متغیرهای جدید برای محاسبه ریسک به ریوارد ---
    string rr_string = "R/R: N/A"; // مقدار پیش‌فرض

    if(entry_price > 0 && sl_price > 0)
    {
        CalculateLotSize(entry_price, sl_price, lot_size, risk_in_money);

        // --- محاسبه ریوارد و نسبت R:R در صورتی که حد سود تعیین شده باشد ---
        if(tp_price > 0 && lot_size > 0 && risk_in_money > 0)
        {
            bool isBuy = (sl_price < entry_price);
            // اطمینان از منطقی بودن حد سود
            if ((isBuy && tp_price > entry_price) || (!isBuy && tp_price < entry_price))
            {
                ENUM_ORDER_TYPE order_type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
                double reward_in_money = 0;
                
                // محاسبه سود بالقوه (ریوارد)
                if(OrderCalcProfit(order_type, _Symbol, lot_size, entry_price, tp_price, reward_in_money))
                {
                    double rr_ratio = MathAbs(reward_in_money) / risk_in_money;
                    rr_string = "R/R: 1:" + DoubleToString(rr_ratio, 2);
                }
                else
                {
                    rr_string = "R/R: Calc Error";
                }
            }
            else
            {
                rr_string = "R/R: Invalid TP"; // اگر حد سود در جای نامناسبی باشد
            }
        }
    }
    
    // محاسبه آمار معاملات باز
    LiveTradeStats live_stats = CalculateLiveTradeStats();
    
    // --- بخش ۲: جمع‌آوری داده‌های مربوط به قوانین پراپ ---
    double daily_buffer = 0, daily_used_pct = 0, overall_buffer = 0, needed_for_target = 0;
    double overall_used_pct = 0, profit_target_progress_pct = 0;
    color daily_color = InpTextColor;
    if(g_prop_rules_active)
    {
        // بررسی روز جدید
        long current_day_index = (long)(TimeTradeServer() / 86400);
        long last_day_index = (long)(g_current_trading_day / 86400);
        if(current_day_index > last_day_index)
        {
            double end_of_day_base = (InpDailyDDBase == DD_FROM_BALANCE) ?
            AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
            double previous_day_profit = end_of_day_base - g_start_of_day_base;

            if(InpEnableConsistencyRule)
            {
               int new_size = ArraySize(g_daily_profits) + 1;
               ArrayResize(g_daily_profits, new_size);
               g_daily_profits[new_size - 1].date = g_current_trading_day;
               g_daily_profits[new_size - 1].profit = previous_day_profit;
            }

            g_current_trading_day = TimeTradeServer();
            g_start_of_day_base = end_of_day_base;
            SaveStateToFile();
        }

        // بررسی و به‌روزرسانی بالاترین اکوئیتی (برای دراودان شناور)
        if(InpOverallDDType == DD_TYPE_TRAILING)
        {
            double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
            if(current_equity > g_peak_equity)
            {
                g_peak_equity = current_equity;
                SaveStateToFile();
            }
        }
        
        // محاسبات دراودان و هدف سود
        double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double daily_dd_limit_level = g_start_of_day_base * (1 - InpMaxDailyDrawdownPercent / 100.0);
        daily_buffer = current_equity - daily_dd_limit_level;
        double daily_dd_total_allowed = g_start_of_day_base - daily_dd_limit_level;
        daily_used_pct = (daily_dd_total_allowed > 0.001) ?
        (1.0 - daily_buffer / daily_dd_total_allowed) * 100.0 : 0;
        
        if(daily_buffer < 0) daily_color = InpDangerColor;
        else if(daily_used_pct > 85) daily_color = InpDangerColor;
        else if(daily_used_pct > 60) daily_color = InpWarningColor;
        else daily_color = InpSafeColor;
        double overall_dd_base = (InpOverallDDType == DD_TYPE_STATIC) ? g_initial_balance : g_peak_equity;
        double overall_dd_limit_level = overall_dd_base * (1 - InpMaxOverallDrawdownPercent / 100.0);
        overall_buffer = current_equity - overall_dd_limit_level;
        double overall_dd_total_allowed = overall_dd_base - overall_dd_limit_level;
        overall_used_pct = (overall_dd_total_allowed > 0.001) ?
        (1.0 - overall_buffer / overall_dd_total_allowed) * 100.0 : 0;
        if(overall_buffer < 0) overall_used_pct = 100;
        double profit_target_level = g_initial_balance * (1 + InpProfitTargetPercent / 100.0);
        needed_for_target = profit_target_level - AccountInfoDouble(ACCOUNT_BALANCE);
        if(needed_for_target > 0)
        {
            double total_profit_needed_from_start = g_initial_balance * (InpProfitTargetPercent / 100.0);
            double current_profit = AccountInfoDouble(ACCOUNT_BALANCE) - g_initial_balance;
            if(total_profit_needed_from_start > 0)
               profit_target_progress_pct = (current_profit / total_profit_needed_from_start) * 100.0;
        } 
        else 
        {
            profit_target_progress_pct = 100.0;
        }
        profit_target_progress_pct = MathMax(0, MathMin(profit_target_progress_pct, 100));
    }

    // پیام وضعیت
    string status_msg = "";
    if(ExtDialog.GetCurrentState() == STATE_STAIRWAY_WAITING_FOR_CLOSE)
    {
        status_msg = "Waiting for Candle Close...";
    }
    
    // ترکیب پیام وضعیت با نسبت R/R
    string final_display_status = rr_string + " | " + status_msg;
    
    // --- بخش ۳: ارسال تمام داده‌ها به پنل نمایشی ---
    g_DisplayCanvas.Update(entry_price, sl_price, tp_price, lot_size, risk_in_money,
                           daily_buffer, daily_used_pct, daily_color,
                           overall_buffer, overall_used_pct,
                           needed_for_target, profit_target_progress_pct,
                           spread, final_display_status,
                           live_stats);
}

//+------------------------------------------------------------------+
//|    محاسبه آمار لحظه‌ای تمام معاملات باز (نسخه نهایی و اصلاح شده)   |
//+------------------------------------------------------------------+

LiveTradeStats CalculateLiveTradeStats()
{
    LiveTradeStats stats;
    stats.total_pl = 0;
    stats.total_risk = 0;
    stats.total_reward = 0;
    stats.position_count = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
            // سپس بررسی می‌کنیم که آیا متعلق به این اکسپرت است یا خیر
            if(PositionGetInteger(POSITION_MAGIC) == g_magic_number)
            {
                stats.total_pl += PositionGetDouble(POSITION_PROFIT);
                stats.position_count++;

                double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                double sl_price = PositionGetDouble(POSITION_SL);
                double tp_price = PositionGetDouble(POSITION_TP);
                double volume = PositionGetDouble(POSITION_VOLUME);
                string symbol = PositionGetString(POSITION_SYMBOL);
                ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);

                // محاسبه ریسک بالقوه (فاصله تا SL)
                if(sl_price > 0)
                {
                    double potential_loss = 0;
                    if(OrderCalcProfit(order_type, symbol, volume, open_price, sl_price, potential_loss))
                    {
                        stats.total_risk += MathAbs(potential_loss);
                    }
                }
                
                // محاسبه پاداش بالقوه (فاصله تا TP)
                if(tp_price > 0)
                {
                    double potential_profit = 0;
                    if(OrderCalcProfit(order_type, symbol, volume, open_price, tp_price, potential_profit))
                    {
                        stats.total_reward += MathAbs(potential_profit);
                    }
                }
            }
        }
    }
    return stats;
}
