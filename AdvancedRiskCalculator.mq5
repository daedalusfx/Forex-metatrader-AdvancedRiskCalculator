//+------------------------------------------------------------------+
//|                                     AdvancedRiskCalculator.mq5 |
//|                                     Version 1    |
//+------------------------------------------------------------------+
#property copyright "daedalusfx"
#property link      "your.website.com"
#property version   "2.1"
#property description "نسخه ۲.۱: رفع خطاهای کامپایل مربوط به وابستگی فایل‌ها."

//--- کتابخانه‌های استاندارد

#include <Trade\Trade.mqh>

//--- فایل‌های پروژه به ترتیب وابستگی
#include "Defines.mqh"         // 1. اول تعاریف پایه
#include "PanelDialog.mqh"     // 2. سپس کلاس اصلی UI
#include "DisplayCanvas.mqh"   // 3. (جدید) کلاس پنل نمایشی
#include "StateManager.mqh"


//--- حالا که کلاس تعریف شده، متغیر سراسری آن را ایجاد می‌کنیم
CPanelDialog ExtDialog;


CDisplayCanvas g_DisplayCanvas;

//--- اکنون فایل‌های منطقی را اضافه می‌کنیم که از متغیر ExtDialog استفاده می‌کنند
#include "Lines.mqh"
#include "SharedLogic.mqh"
#include "MarketExecution.mqh"
#include "PendingExecution.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- 1. راه‌اندازی UI ---
   if(!ExtDialog.Create(0, "Advanced Risk Calculator v2.1", 0, 10, 30))
   {
      return(INIT_FAILED);
   }
   ExtDialog.Run();
   if(!g_DisplayCanvas.Create(0, "DisplayCanvas", 0, InpDisplayPanelX, InpDisplayPanelY, 220, 220))
   {
      return(INIT_FAILED);
   }

   // --- 2. مقداردهی اولیه متغیرهای اصلی ---
   InitializeMagicNumber(); // تضمین می‌کند که g_magic_number مقداردهی شده (خوانده شده یا جدید)

   if(InpEnablePropRules)
   {
      g_prop_rules_active = true;
      bool stateFileExists = LoadStateFromFile();

      // اگر فایل وضعیتی وجود نداشت، این اولین اجرای واقعی است
      if(!stateFileExists)
      {
         Print("No state file found. Initializing prop firm rules for the first time.");
         g_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
         g_peak_equity = g_initial_balance;
         g_current_trading_day = TimeTradeServer();
         g_start_of_day_base = (InpDailyDDBase == DD_FROM_BALANCE) ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
         ArrayFree(g_daily_profits); // اطمینان از خالی بودن آرایه
         SaveStateToFile();          // ذخیره وضعیت کاملاً جدید
      }
      // اگر فایل وضعیت وجود داشت، باید چک کنیم که آیا روز جدیدی شروع شده یا نه
      else
      {
         datetime server_time = TimeTradeServer();
         long current_day_index = (long)(server_time / 86400);
         long last_day_index = (long)(g_current_trading_day / 86400);

         if(current_day_index > last_day_index)
         {
            Print("New trading day detected upon initialization.");
            // منطق شروع روز جدید را اینجا هم اجرا می‌کنیم
            double end_of_day_base = (InpDailyDDBase == DD_FROM_BALANCE) ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
            double previous_day_profit = end_of_day_base - g_start_of_day_base;
            
            int new_size = ArraySize(g_daily_profits) + 1;
            ArrayResize(g_daily_profits, new_size);
            g_daily_profits[new_size - 1].date = g_current_trading_day;
            g_daily_profits[new_size - 1].profit = previous_day_profit;

            g_current_trading_day = server_time;
            g_start_of_day_base = end_of_day_base;
            
            SaveStateToFile();
         }
      }
   }

   // --- 3. به‌روزرسانی نهایی نمایشگر ---
   UpdateDisplayData();
   ChartRedraw();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- حذف تمام اشیاء ایجاد شده
   SaveStateToFile(); 
   DeleteTradeLines(); // خطوط را دستی حذف می‌کنیم
   g_DisplayCanvas.Destroy(); // (جدید) حذف پنل نمایشی
   ExtDialog.Destroy(reason);
   Comment("");
}

//+------------------------------------------------------------------+
//| OnTick - در هر تیک قیمت فراخوانی می‌شود                          |
//+------------------------------------------------------------------+
void OnTick()
{
   // ExtDialog.OnTick(); // این خط حذف شد چون دیگر وجود ندارد

   // شرط if بدون نقطه ویرگول در انتها نوشته می‌شود
   if(ExtDialog.GetCurrentState() != STATE_IDLE)
   {
      UpdateDisplayData();
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function - قلب ماشین وضعیت                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   //--- ارسال رویدادها به پنل اصلی برای مدیریت
   ExtDialog.ChartEvent(id, lparam, dparam, sparam);

   //--- رویدادهای کشیدن خط (Drag) را به صورت جداگانه مدیریت می‌کنیم
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      ExtDialog.HandleDragEvent(sparam);
   }
}
//+------------------------------------------------------------------+



// In AdvancedRiskCalculator.mq5
//+------------------------------------------------------------------+
//|   محاسبه و به‌روزرسانی آمار پراپ (FINAL UI VERSION)              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|   محاسبه و نقاشی تمام داده‌های نمایشی (نسخه نهایی Canvas)        |
//+------------------------------------------------------------------+
void UpdateDisplayData()
{
    // --- بخش ۱: جمع‌آوری داده‌های مربوط به معامله ---
    double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
    double entry_price = GetLinePrice(LINE_ENTRY_PRICE);
    double sl_price = GetLinePrice(LINE_STOP_LOSS);
    double tp_price = GetLinePrice(LINE_TAKE_PROFIT);
    double lot_size = 0, risk_in_money = 0;
    if(entry_price > 0 && sl_price > 0)
        CalculateLotSize(entry_price, sl_price, lot_size, risk_in_money);


        double overall_used_pct = 0; 
        double profit_target_progress_pct = 0;
    // --- بخش ۲: جمع‌آوری داده‌های مربوط به قوانین پراپ ---
    double daily_buffer = 0, daily_used_pct = 0, overall_buffer = 0, needed_for_target = 0;
    color daily_color = InpTextColor; // رنگ پیش‌فرض

    if(g_prop_rules_active)
    {
        // بررسی روز جدید
        long current_day_index = (long)(TimeTradeServer() / 86400);
        long last_day_index = (long)(g_current_trading_day / 86400);
      if(current_day_index > last_day_index)
{
    // --- (NEW) Calculate and log previous day's profit ---
    if(InpEnableConsistencyRule)
    {
        // The profit is the change in the base equity/balance from start to end of the day
        double end_of_day_base = (InpDailyDDBase == DD_FROM_BALANCE) ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
        double previous_day_profit = end_of_day_base - g_start_of_day_base;

        // Add to our log array
        int new_size = ArraySize(g_daily_profits) + 1;
        ArrayResize(g_daily_profits, new_size);
        g_daily_profits[new_size - 1].date = g_current_trading_day;
        g_daily_profits[new_size - 1].profit = previous_day_profit;
    }

    // --- Now, reset for the new day ---
    g_current_trading_day = TimeTradeServer();
    g_start_of_day_base = (InpDailyDDBase == DD_FROM_BALANCE) ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);

    SaveStateToFile();

   }


   if(InpOverallDDType == DD_TYPE_TRAILING)
   {
       double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
       // آیا اکوئیتی فعلی یک رکورد جدید ثبت کرده است؟
       if(current_equity > g_peak_equity)
       {
           // اگر بله، هم مقدار را آپدیت کن و هم بلافاصله وضعیت را ذخیره کن
           g_peak_equity = current_equity;
           SaveStateToFile();
       }
   }

        double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);

        // محاسبات دراودان روزانه
        double daily_dd_limit_level = g_start_of_day_base * (1 - InpMaxDailyDrawdownPercent / 100.0);
        daily_buffer = current_equity - daily_dd_limit_level;
        double daily_dd_total_allowed = g_start_of_day_base - daily_dd_limit_level;
        daily_used_pct = (daily_dd_total_allowed > 0.001) ? (1.0 - daily_buffer / daily_dd_total_allowed) * 100.0 : 0;
        
        // تنظیم رنگ پویا
        if(daily_buffer < 0) daily_color = InpDangerColor;
        else if(daily_used_pct > 85) daily_color = InpDangerColor;
        else if(daily_used_pct > 60) daily_color = InpWarningColor;
        else daily_color = InpSafeColor;

        // محاسبات دراودان کلی
        double overall_dd_base = (InpOverallDDType == DD_TYPE_STATIC) ? g_initial_balance : g_peak_equity;
        double overall_dd_limit_level = overall_dd_base * (1 - InpMaxOverallDrawdownPercent / 100.0);
        overall_buffer = current_equity - overall_dd_limit_level;

        double overall_dd_total_allowed = overall_dd_base - overall_dd_limit_level;
         overall_used_pct = (overall_dd_total_allowed > 0.001) ?
           (1.0 - overall_buffer / overall_dd_total_allowed) * 100.0 : 0;
           if(overall_buffer < 0) overall_used_pct = 100; // Ensure bar is full if limit is breached
    

        // محاسبه هدف سود
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
            profit_target_progress_pct = 100.0; // Target is reached or surpassed
         }
         // Ensure the value is between 0 and 100 for the progress bar
         profit_target_progress_pct = MathMax(0, MathMin(profit_target_progress_pct, 100));



    }
    
         g_DisplayCanvas.Update(spread, entry_price, sl_price, tp_price, lot_size, risk_in_money,
                  daily_buffer, daily_used_pct, daily_color,
                  overall_buffer, overall_used_pct, 
                  profit_target_progress_pct,
                  needed_for_target);
 
}