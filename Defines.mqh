//+------------------------------------------------------------------+
//|                                                  Defines.mqh |
//|          V2.0 - Global Definitions, Enums, and Inputs            |
//+------------------------------------------------------------------+
#ifndef DEFINES_MQH
#define DEFINES_MQH

//--- Enums
enum ETakeProfitMode { TP_MANUAL, TP_RR_RATIO };
enum ETradeState { STATE_IDLE, STATE_PREP_MARKET_BUY, STATE_PREP_MARKET_SELL, STATE_PREP_PENDING_BUY, STATE_PREP_PENDING_SELL };

//--- Input Settings (User-Customizable)
input group "Risk & Safety Settings"
input double InpRiskPercent = 1.0;          // Risk % of Account Balance
input ulong  InpSlippage    = 10;           // Max slippage for market orders (in points)
input double InpMaxMarginUsagePercent = 90.0; // Max % of Free Margin to use for a trade

input group "Take Profit Settings"
input ETakeProfitMode InpTPMode = TP_RR_RATIO;    // Take Profit Mode
input double InpTP_RR_Value = 2.0;                // R:R Ratio (if mode is R:R)

input group "Pending Order Settings"
input bool InpAutoEntryPending = false; // Enable rigid SL/Entry/TP movement

input group "Panel & Button Colors"
input color InpPanelBackgroundColor= C'40, 45, 60';      // #282d3c
input color InpTextColor           = C'238, 238, 238';   // #eeeeee
input color InpBuyButtonColor      = C'34, 166, 179';    // #22a6b3
input color InpSellButtonColor     = C'235, 77, 75';     // #eb4d4b
input color InpExecuteBuyColor     = C'32, 201, 151';    // #20c997
input color InpExecuteSellColor    = C'255, 107, 107';   // #ff6b6b
input color InpOrderButtonColor    = C'255, 165, 2';     // #ffa502
input color InpCancelButtonColor   = C'99, 110, 114';    // #636e72
input color InpDisabledButtonColor = C'83, 92, 104';     // #535c68
input color InpSubPanelColor = C'30, 34, 43'; // (جدید) رنگ پنل‌های داخلی

// --- (کد جدید) رنگ‌های Canvas و هشدارهای پویا ---
input color InpPanelSectionColor   = C'30, 34, 43';    // رنگ پس‌زمینه بخش اطلاعات
input color InpSafeColor           = C'52, 211, 153';   // رنگ حالت امن (سبز)
input color InpWarningColor        = C'251, 146, 60';  // رنگ حالت هشدار (نارنجی)
input color InpDangerColor         = C'248, 113, 113';  // رنگ حالت خطر (قرمز)



input group "Trade Lines Settings"
input color InpEntryLineColor      = C'238, 238, 238';
input color InpStopLineColor       = C'252, 57, 57';
input color InpProfitLineColor     = C'32, 201, 151';
input ENUM_LINE_STYLE InpLineStyle = STYLE_DASHDOT;
input int   InpLineWidth         = 1;

//--- UI Element Names for Lines
#define LINE_ENTRY_PRICE         "RiskCalc_EntryLine"
#define LINE_STOP_LOSS           "RiskCalc_StopLossLine"
#define LINE_TAKE_PROFIT         "RiskCalc_TakeProfitLine"

//--- Global Variables
CTrade          trade;
double          g_sl_price = 0; // برای حالت حرکت ثابت خطوط استفاده می‌شود
double          g_entry_price = 0;
double          g_tp_price = 0;
long g_magic_number = 0;


// --- Prop Firm Rules (NEW) ---
input group "Prop Firm Rules"
input bool   InpEnablePropRules        = true;            // فعال‌سازی قوانین پراپ
input double InpMaxDailyDrawdownPercent  = 5.0;             // حداکثر افت سرمایه روزانه (درصد)
input double InpMaxOverallDrawdownPercent= 10.0;            // حداکثر افت سرمایه کلی (درصد)
input double InpProfitTargetPercent      = 8.0;             // هدف سود (درصد)
input bool   InpEnableConsistencyRule  = true;            // فعال‌سازی قانون ثبات
input double InpConsistencyRulePercent = 40.0;            // حداکثر سهم سود یک روز (درصد)


// نوع محاسبه دراودان روزانه
enum ENUM_Daily_DD_Base { DD_FROM_BALANCE, DD_FROM_EQUITY };
input ENUM_Daily_DD_Base InpDailyDDBase = DD_FROM_BALANCE; // مبنای محاسبه: بالانس یا اکوییتی اول روز

// نوع محاسبه دراودان کلی
enum ENUM_Overall_DD_Type { DD_TYPE_STATIC, DD_TYPE_TRAILING };
input ENUM_Overall_DD_Type InpOverallDDType = DD_TYPE_STATIC; // نوع محاسبه: ثابت یا شناور

// --- Global variables for Prop Logic (NEW) ---
bool   g_prop_rules_active = false;      // وضعیت فعال بودن قوانین پراپ در لحظه
double g_initial_balance = 0;          // بالانس اولیه حساب
double g_peak_equity = 0;              // بالاترین اکوییتی ثبت شده (برای دراودان شناور)
double g_start_of_day_base = 0;      // سطح مبنا در شروع روز (بالانس یا اکوییتی)
datetime g_current_trading_day = 0;      // برای تشخیص روز جدید

input group "Display Panel Settings"
input int InpDisplayPanelX = 260; // موقعیت X پنل نمایش
input int InpDisplayPanelY = 30;  // موقعیت Y پنل نمایش
input int InpCanvasMainFontSize = 11;     //  سایز فونت اصلی کنواس
input int InpCanvasSmallFontSize = 10;    //  سایز فونت کوچک کنواس

input group "UI Layout Settings"
input int InpButtonWidth   = 90; // عرض دکمه‌ها
input int InpButtonHeight  = 25; // ارتفاع دکمه‌ها
input int InpButtonPadding = 8;  // فاصله بین دکمه‌ها




// --- Consistency Rule Logic (NEW) ---
struct DailyProfitLog
{
    datetime date;      // تاریخ روز معاملاتی
    double   profit;    // سود ثبت شده برای آن روز
};
DailyProfitLog g_daily_profits[]; // آرایه داینامیک برای نگهداری تاریخچه سود


#endif // DEFINES_MQH
