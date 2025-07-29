//+------------------------------------------------------------------+
//|                                     AdvancedRiskCalculator.mq5 |
//|                                     Version 1    |
//+------------------------------------------------------------------+
#property copyright "Your Name / Gemini"
#property link      "your.website.com"
#property version   "2.1"
#property description "نسخه ۲.۱: رفع خطاهای کامپایل مربوط به وابستگی فایل‌ها."

//--- کتابخانه‌های استاندارد

#include <Trade\Trade.mqh>

//--- فایل‌های پروژه به ترتیب وابستگی
#include "Defines.mqh"         // 1. اول تعاریف پایه
#include "PanelDialog.mqh"     // 2. سپس کلاس اصلی UI

//--- حالا که کلاس تعریف شده، متغیر سراسری آن را ایجاد می‌کنیم
CPanelDialog ExtDialog;

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
   //--- ایجاد و اجرای پنل اصلی
   if(!ExtDialog.Create(0, "Advanced Risk Calculator v2.1", 0, 10, 30))
   {
      return(INIT_FAILED);
   }
   ExtDialog.Run();


      // --- مقداردهی اولیه برای قوانین پراپ (NEW) ---
      if(InpEnablePropRules)
      {
          g_prop_rules_active = true;
          g_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
          g_peak_equity = g_initial_balance; // در ابتدا برابر با بالانس اولیه است
          g_current_trading_day = TimeTradeServer();
          
          // تعیین مبنای محاسبه دراودان روزانه
          g_start_of_day_base = (InpDailyDDBase == DD_FROM_BALANCE) ? g_initial_balance : AccountInfoDouble(ACCOUNT_EQUITY);
      }



   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- حذف تمام اشیاء ایجاد شده
   DeleteTradeLines(); // خطوط را دستی حذف می‌کنیم
   ExtDialog.Destroy(reason);
   Comment("");
}

//+------------------------------------------------------------------+
//| OnTick - در هر تیک قیمت فراخوانی می‌شود                          |
//+------------------------------------------------------------------+
void OnTick()
{
   ExtDialog.OnTick(); // رویداد تیک را به پنل ارسال می‌کنیم


      // --- به‌روزرسانی آمار پراپ در هر تیک (NEW) ---
   UpdatePropStats();

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
void UpdatePropStats()
{
    if(!g_prop_rules_active) return;

    long current_day_index = (long)(TimeTradeServer() / 86400);
    long last_day_index = (long)(g_current_trading_day / 86400);
    if(current_day_index > last_day_index)
    {
        g_current_trading_day = TimeTradeServer();
        g_start_of_day_base = (InpDailyDDBase == DD_FROM_BALANCE) ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
    }

    if(InpOverallDDType == DD_TYPE_TRAILING)
    {
        g_peak_equity = MathMax(g_peak_equity, AccountInfoDouble(ACCOUNT_EQUITY));
    }

    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    string currency = AccountInfoString(ACCOUNT_CURRENCY);

    // --- Daily Drawdown Calculation ---
    double daily_dd_limit_level = g_start_of_day_base * (1 - InpMaxDailyDrawdownPercent / 100.0);
    double daily_buffer = current_equity - daily_dd_limit_level;
    double daily_dd_total_allowed = g_start_of_day_base - daily_dd_limit_level;
    double daily_dd_used_percent = (daily_dd_total_allowed > 0.001) ? (1.0 - daily_buffer / daily_dd_total_allowed) * 100.0 : 0;
    
    color daily_color =   C'238, 238, 238';  // Default Text Color
    if(daily_buffer < 0) daily_color =   C'238, 238, 238';  // Red if violated
    else if(daily_dd_used_percent > 85) daily_color  = C'238, 238, 238'; // Red
    else if(daily_dd_used_percent > 60) daily_color =   C'238, 238, 238';  // Orange
    
    string daily_dd_text = StringFormat("Daily Room: %s %.2f", currency, daily_buffer);

    // --- Overall Drawdown Calculation ---
    double overall_dd_base = (InpOverallDDType == DD_TYPE_STATIC) ? g_initial_balance : g_peak_equity;
    double overall_dd_limit_level = overall_dd_base - (overall_dd_base * InpMaxOverallDrawdownPercent / 100.0);
    double overall_buffer = current_equity - overall_dd_limit_level;
    string overall_dd_text = StringFormat("Max Room: %s %.2f", currency, overall_buffer);

    // --- Profit Target Calculation ---
    double profit_target_level = g_initial_balance * (1 + InpProfitTargetPercent / 100.0);
    double needed_for_target = profit_target_level - AccountInfoDouble(ACCOUNT_BALANCE);
    string profit_target_text = (needed_for_target > 0) ? StringFormat("Target Need: %s %.2f", currency, needed_for_target) : "TARGET REACHED!";

    // --- Update the Panel UI with color ---
    ExtDialog.UpdatePropPanel(daily_dd_text, overall_dd_text, profit_target_text, daily_color);
}