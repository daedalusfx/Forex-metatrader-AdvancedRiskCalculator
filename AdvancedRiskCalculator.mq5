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
