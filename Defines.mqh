//+------------------------------------------------------------------+
//|                                                  Defines.mqh |
//|          V2.1 - Global Definitions, Enums, and Inputs (Corrected) |
//+------------------------------------------------------------------+
#ifndef DEFINES_MQH
#define DEFINES_MQH

//--- Enums
enum ETakeProfitMode { TP_MANUAL, TP_RR_RATIO };
enum ETradeState {
    STATE_IDLE,
    STATE_PREP_MARKET_BUY,
     STATE_PREP_MARKET_SELL,
     STATE_PREP_PENDING_BUY,
     STATE_PREP_PENDING_SELL,
  // --- حالت‌های جدید برای ورود پلکانی ---
  STATE_PREP_STAIRWAY_BUY,
  STATE_PREP_STAIRWAY_SELL,
  STATE_STAIRWAY_WAITING_FOR_CONFIRMATION, // (جدید) حالتی که منتظر فعال شدن پولبک یا کلوز کندل هستیم
  STATE_STAIRWAY_WAITING_FOR_CLOSE // این حالت را برای سازگاری نگه می‌داریم ولی از حالت جدید استفاده می‌کنیم
};
enum ENUM_Risk_Mode { RISK_PERCENT, RISK_MONEY };



// --- (کد جدید) ورودی‌های مربوط به استراتژی پلکانی ---
input group "تنظیمات ورود پلکانی (Stairway Entry)"
input string InpStairwayLevelName = "Breakout_Level"; // نام خط افقی برای تشخیص شکست
input double InpStairwayInitialPercent = 30.0;       // [Stairway] درصد حجم پله اول: چه درصدی از حجم کل در پولبک اولیه وارد شود؟

//--- Input Settings (User-Customizable)
input group "تنظیمات ریسک و ایمنی"
input ENUM_Risk_Mode InpRiskMode = RISK_PERCENT;       // مبنای محاسبه ریسک: درصدی از بالانس (RISK_PERCENT) یا مبلغ ثابت (RISK_MONEY)
input double InpRiskPercent = 1.0;                     // [درصد ریسک] میزان ریسک به درصد (اگر حالت بالا درصدی باشد)
input double InpMaxMarginUsagePercent = 90.0;          // حداکثر مارجین مجاز: برای جلوگیری از خطا، معامله‌ای که بیش از این درصد از مارجین آزاد را اشغال کند باز نمی‌شود
input ulong  InpSlippage    = 10;                        // حداکثر لغزش (Slippage) مجاز برای معاملات Market (به پوینت)


input group "تنظیمات حد سود (Take Profit)"
input ETakeProfitMode InpTPMode = TP_RR_RATIO;         // حالت حد سود: دستی (TP_MANUAL) یا بر اساس نسبت ریسک به ریوارد (TP_RR_RATIO)
input double InpTP_RR_Value = 2.0;                     // [نسبت R:R] مقدار نسبت ریسک به ریوارد (مثلا 2.0 برای 1:2)

input group "تنظیمات سفارشات Pending"
input bool InpAutoEntryPending = false;                // حرکت هماهنگ خطوط: اگر فعال باشد، با جابجایی خط SL، خطوط Entry و TP نیز به صورت هماهنگ حرکت می‌کنند

input group "ابعاد و چیدمان پنل اصلی"
input int PanelWidth = 240;                            // عرض پنل اصلی
input int PanelHigth = 350;                            // ارتفاع پنل اصلی
input int InpButtonWidth   = 70;                       // عرض دکمه‌ها
input int InpButtonHeight  = 25;                       // ارتفاع دکمه‌ها
input int InpButtonPadding = 8;                        // فاصله کنترل‌ها از لبه پنل
input int InpButtonGap     = 5;                        // فاصله بین دکمه‌ها

input group "رنگ‌بندی پنل اصلی"
input color InpPanelBackgroundColor= C'245, 245, 245'; // پس‌زمینه اصلی پنل (سفید دودی)
input color InpSubPanelColor = C'30, 34, 43';          // رنگ پنل‌های داخلی (Market, Pending, ...)
input color InpTextColor           = C'229, 231, 235'; // رنگ متن اصلی
input color InpBuyButtonColor      = C'30, 144, 255';  // رنگ دکمه خرید
input color InpSellButtonColor     = C'255, 69, 0';    // رنگ دکمه فروش
input color InpExecuteBuyColor     = C'0, 191, 255';   // رنگ دکمه اجرای خرید
input color InpExecuteSellColor    = C'255, 0, 0';     // رنگ دکمه اجرای فروش
input color InpOrderButtonColor    = C'30, 144, 255';  // رنگ دکمه ثبت سفارش
input color InpCancelButtonColor   = C'255, 165, 0';   // رنگ دکمه لغو
input color InpDisabledButtonColor = C'220, 220, 220'; // رنگ دکمه غیرفعال

//--- رنگ‌های فیلد ورودی
input color InpInputBgColor        = C'255, 255, 255';
// پس‌زمینه فیلد ورودی (سفید)
input color InpInputBorderColor    = C'211, 211, 211';
// رنگ حاشیه (خاکستری روشن)

input group "تنظیمات ظاهری خطوط معاملاتی"
input color InpEntryLineColor      = C'238, 238, 238'; // رنگ خط ورود
input color InpStopLineColor       = C'252, 57, 57';   // رنگ خط حد ضرر
input color InpProfitLineColor     = C'32, 201, 151';  // رنگ خط حد سود
input ENUM_LINE_STYLE InpLineStyle = STYLE_DASHDOT;     // استایل خطوط
input int   InpLineWidth         = 1;                 // ضخامت خطوط

//--- UI Element Names for Lines
#define LINE_ENTRY_PRICE         "RiskCalc_EntryLine"
#define LINE_STOP_LOSS           "RiskCalc_StopLossLine"
#define LINE_TAKE_PROFIT         "RiskCalc_TakeProfitLine"
#define LINE_PENDING_ENTRY       "RiskCalc_PendingEntryLine"

//--- Global Variables
CTrade          trade;
double          g_sl_price = 0;
// برای حالت حرکت ثابت خطوط استفاده می‌شود
double          g_entry_price = 0;
double          g_tp_price = 0;
long g_magic_number = 0;

// --- Prop Firm Rules (NEW) ---
input group "محافظ پراپ فرم (Prop Firm Guardian)"
input bool   InpEnablePropRules        = true;              // [فعالسازی] آیا محافظ پراپ فعال باشد؟
input double InpMaxDailyDrawdownPercent  = 5.0;             // حداکثر افت سرمایه روزانه (درصد)
input double InpMaxOverallDrawdownPercent= 10.0;            // حداکثر افت سرمایه کلی (درصد)
input double InpProfitTargetPercent      = 8.0;             // هدف سود چالش (درصد)
input bool   InpEnableConsistencyRule  = true;              // [قانون ثبات] آیا قانون ثبات فعال باشد؟
input double InpConsistencyRulePercent = 40.0;              // [قانون ثبات] حداکثر سهم سود یک روز از کل سود (درصد)


// نوع محاسبه دراودان روزانه
enum ENUM_Daily_DD_Base { DD_FROM_BALANCE, DD_FROM_EQUITY };
input ENUM_Daily_DD_Base InpDailyDDBase = DD_FROM_BALANCE; // مبنای محاسبه دراودان روزانه: بالانس (DD_FROM_BALANCE) یا اکوییتی (DD_FROM_EQUITY) در شروع روز

// نوع محاسبه دراودان کلی
enum ENUM_Overall_DD_Type { DD_TYPE_STATIC, DD_TYPE_TRAILING };
input ENUM_Overall_DD_Type InpOverallDDType = DD_TYPE_STATIC; // نوع محاسبه دراودان کلی: ثابت بر اساس بالانس اولیه (DD_TYPE_STATIC) یا شناور بر اساس بالاترین اکوییتی (DD_TYPE_TRAILING)

input group "پنل نمایش اطلاعات (Display Canvas)"
input int InpDisplayPanelX = 260;                      // موقعیت افقی پنل (X)
input int InpDisplayPanelY = 30;                       // موقعیت عمودی پنل (Y)
input int InpDisplayPanelW = 250;                      // عرض پنل
input int InpDisplayPanelH = 280;                      // ارتفاع پنل
input int InpCanvasMainFontSize = 14;                  // سایز فونت اصلی
input int InpCanvasSmallFontSize = 12;                 // سایز فونت کوچک

input group "رنگ‌بندی پنل نمایش اطلاعات"
// --- رنگ‌های طرح جدید (مدرن و تیره) ---
input color InpModernUIPanelBg      = C'31, 41, 55';
// پس‌زمینه اصلی پنل (سرمه‌ای تیره)
input color InpModernUITextPrimary  = C'229, 231, 235';
// رنگ متن اصلی (خاکستری روشن)
input color InpModernUITextSecondary= C'156, 163, 175';
// رنگ متن ثانویه (خاکستری)
input color InpModernUITitle        = C'34, 211, 238';
// رنگ عنوان (فیروزه‌ای)
input color InpModernUIBorder       = C'75, 85, 99';
// رنگ جداکننده
input color InpModernUIProgressBg   = C'55, 65, 81';
// پس‌زمینه خالی نوارهای پیشرفت
input color InpSafeColor           = C'52, 211, 153';  // رنگ حالت امن (سبز)
input color InpWarningColor        = C'251, 146, 60';  // رنگ حالت هشدار (نارنجی)
input color InpDangerColor         = C'248, 113, 113';  // رنگ حالت خطر (قرمز)

// --- Global variables for Prop Logic (NEW) ---
bool     g_prop_rules_active = false;      // وضعیت فعال بودن قوانین پراپ در لحظه
double   g_initial_balance = 0;            // بالانس اولیه حساب
double   g_peak_equity = 0;                // بالاترین اکوییتی ثبت شده (برای دراودان شناور)
double   g_start_of_day_base = 0;          // سطح مبنا در شروع روز (بالانس یا اکوییتی)
datetime g_current_trading_day = 0;        // برای تشخیص روز جدید


// --- Consistency Rule Logic (NEW) ---
struct DailyProfitLog
{
    datetime date;
// تاریخ روز معاملاتی
    double   profit;    // سود ثبت شده برای آن روز
};
DailyProfitLog g_daily_profits[];
// آرایه داینامیک برای نگهداری تاریخچه سود


struct LiveTradeStats
{
    double   total_pl;
    double   total_reward;
    double   total_risk;
    int      position_count;
};

#endif // DEFINES_MQH