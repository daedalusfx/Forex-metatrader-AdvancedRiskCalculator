//+------------------------------------------------------------------+
//|                                           Test_Functions.mq5 |
//|          تستر واحد برای اعتبارسنجی منطق‌های اصلی اکسپرت           |
//|    برای اجرا، این فایل را در کنار سایر فایل‌های .mqh پروژه قرار دهید |
//+------------------------------------------------------------------+
#property copyright "Unit Tester"
#property version   "1.1"

// --- 1. افزودن تمام فایل‌های مورد نیاز پروژه ---
// این فایل‌ها باید در کنار این تستر در یک پوشه باشند
#include <Trade\Trade.mqh>
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>
#include <Controls\Panel.mqh>

#include "Defines.mqh"
#include "PanelDialog.mqh"     // برای تعریف کلاس CPanelDialog
#include "SharedLogic.mqh"
#include "StateManager.mqh"
#include "Lines.mqh"
// فایل‌های زیر مستقیماً تست نمی‌شوند اما برای کامپایل شدن نیاز هستند
#include "MarketExecution.mqh"
#include "PendingExecution.mqh"
#include "DisplayCanvas.mqh"
#include "SpreadAtrAnalysis.mqh"

// --- 2. شبیه‌سازی (Mocking) متغیرها و اشیاء سراسری ---
// توابع ما به این اشیاء نیاز دارند، حتی اگر از UI آنها استفاده نکنیم.
CPanelDialog       ExtDialog;
CDisplayCanvas     g_DisplayCanvas;
CSpreadAtrAnalysis g_SpreadAtrPanel;

// تعریف متغیرهای سراسری که در فایل‌های دیگر استفاده شده‌اند
// FIX: The following variables are already defined in Defines.mqh and were causing a re-definition error. They are now removed.
// double g_sl_price = 0, g_entry_price = 0, g_tp_price = 0; 
void UpdateDisplayData(){}; // یک تابع خالی برای جلوگیری از خطای کامپایل

// --- 3. تعریف توابع تست ---
void Test_CalculateLotSize();
void Test_IsTradeRequestSafe();
void Test_InitializeMagicNumber();
void Test_StateManager();


//+------------------------------------------------------------------+
//| تابع اصلی برای اجرای تمام تست‌ها                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("--- STARTING LOGIC UNIT TESTS ---");
    Print("NOTE: Tests are running with default 'input' values from Defines.mqh.");

    // فراخوانی هر تست به ترتیب
    Test_CalculateLotSize();
    Test_IsTradeRequestSafe();
    Test_InitializeMagicNumber();
    Test_StateManager();

    Print("\n--- ALL TESTS COMPLETED ---");
    Print("Please check the results above. 'PASS' indicates expected behavior, 'FAIL' indicates a problem.");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تست تابع محاسبه حجم لات                                          |
//+------------------------------------------------------------------+
void Test_CalculateLotSize()
{
    Print("\n--- Testing Function: CalculateLotSize() ---");
    double lot_size = 0, risk_money = 0;

    // برای تست، باید حالت پنل و مقدار ریسک را به صورت ساختگی تنظیم کنیم
    ExtDialog.SetCurrentState(STATE_PREP_MARKET_BUY);
    // InpRiskPercent به طور پیش‌فرض 1.0 است

    // سناریو 1: ورودی‌های معقول
    // فرض: بالانس حساب 10,000، ریسک 1%، فاصله SL برابر 200 پوینت (20 پیپ)
    if(CalculateLotSize(1.08000, 1.07800, lot_size, risk_money))
    {
        // برای EURUSD با بالانس 10000 و ریسک 1% (100 دلار) و استاپ 200 پوینتی، لات باید حدود 0.5 باشد
        if(lot_size > 0.4 && lot_size < 0.6 && MathAbs(risk_money - 100.0) < 0.01)
        {
            Print("PASS: Test 1 (Valid Inputs) - Lot: ", lot_size, ", Risk: ", risk_money);
        }
        else
        {
            Print("FAIL: Test 1 (Valid Inputs) - Calculation is incorrect! Lot: ", lot_size, ", Risk: ", risk_money);
        }
    }
    else
    {
        Print("FAIL: Test 1 (Valid Inputs) - Function returned false unexpectedly.");
    }

    // سناریو 2: فاصله SL صفر
    if(!CalculateLotSize(1.08000, 1.08000, lot_size, risk_money))
    {
        Print("PASS: Test 2 (Zero SL Distance) - Correctly failed to calculate lot.");
    }
    else
    {
        Print("FAIL: Test 2 (Zero SL Distance) - It should have returned false.");
    }
    
    // سناریو 3: ریسک ورودی صفر
    // برای این تست، باید تابع GetRiskInput را در کلاس پنل موقتاً طوری تغییر دهیم که 0 برگرداند
    // یا یک راه ساده‌تر، فرض کنیم کاربر 0 وارد کرده است. تابع فعلی این را مدیریت می‌کند.
    // (این تست نیازمند تغییر در کد اصلی است، فعلا از آن صرف نظر می‌کنیم)
}


//+------------------------------------------------------------------+
//| تست تابع بررسی ایمنی معامله                                       |
//+------------------------------------------------------------------+
void Test_IsTradeRequestSafe()
{
    Print("\n--- Testing Function: IsTradeRequestSafe() ---");
    
    // --- بخش اول: تست مارجین ---
    Print("  -- Margin Check --");
    // سناریو 1: مارجین کافی (باید true برگرداند)
    if(IsTradeRequestSafe(0.01, ORDER_TYPE_BUY, 1.08000, 1.07800, 1.08400))
    {
        Print("PASS: Margin Test 1 (Sufficient Margin) - Correctly approved the trade.");
    }
    else
    {
        Print("FAIL: Margin Test 1 (Sufficient Margin) - Trade rejected unexpectedly. Error: ", GetLastError());
    }

    // سناریو 2: مارجین ناکافی (باید false برگرداند)
    if(!IsTradeRequestSafe(9999.0, ORDER_TYPE_BUY, 1.08000, 1.07800, 1.08400))
    {
        Print("PASS: Margin Test 2 (Insufficient Margin) - Correctly rejected the trade.");
    }
    else
    {
        Print("FAIL: Margin Test 2 (Insufficient Margin) - Trade was approved but it shouldn't have been.");
    }
    
    // --- بخش دوم: تست قوانین پراپ ---
    Print("  -- Prop Firm Rules Check --");
    // FIX: Use the global variable 'g_prop_rules_active' instead of modifying the 'input' constant.
    g_prop_rules_active = true; // فعال‌سازی قوانین برای تست
    // FIX: Cannot modify 'InpMaxDailyDrawdownPercent'. The test will use the default value (5.0) from Defines.mqh.
    
    // آماده‌سازی: فرض کنید بالانس شروع روز 10,000 بوده
    g_start_of_day_base = 10000;
    // حد ضرر روزانه 5% (مقدار پیش‌فرض) از 10,000 یعنی 500 دلار است. اکوئیتی نباید زیر 9500 برود.
    
    // سناریو 3: ریسک معامله در محدوده مجاز
    // ریسک این معامله 100 دلار است. بالانس پس از ضرر: 10000 - 100 = 9900 که بالاتر از 9500 است.
    if(IsTradeRequestSafe(0.5, ORDER_TYPE_BUY, 1.08000, 1.07800, 1.08200))
    {
        Print("PASS: Prop Rule Test 1 (Safe Risk) - Correctly approved the trade.");
    }
    else
    {
        Print("FAIL: Prop Rule Test 1 (Safe Risk) - Rejected a safe trade.");
    }
    
    // سناریو 4: ریسک معامله خارج از محدوده مجاز
    // ریسک این معامله 600 دلار است. بالانس پس از ضرر: 10000 - 600 = 9400 که پایین‌تر از 9500 است.
    if(!IsTradeRequestSafe(3.0, ORDER_TYPE_BUY, 1.08000, 1.07800, 1.08200))
    {
        Print("PASS: Prop Rule Test 2 (Unsafe Risk) - Correctly rejected the trade due to Daily DD.");
    }
    else
    {
        Print("FAIL: Prop Rule Test 2 (Unsafe Risk) - Approved a trade that violates Daily DD rule.");
    }
    
    g_prop_rules_active = false; // غیرفعال کردن برای تست‌های بعدی
}


//+------------------------------------------------------------------+
//| تست تابع مقداردهی اولیه مجیک نامبر                                |
//+------------------------------------------------------------------+
void Test_InitializeMagicNumber()
{
    Print("\n--- Testing Function: InitializeMagicNumber() ---");
    string gv_key = "AdvRiskCalc_Magic_" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" + _Symbol + "_" + (string)ChartID();

    // آماده‌سازی: ابتدا متغیر سراسری را پاک می‌کنیم تا مطمئن شویم وجود ندارد.
    GlobalVariableDel(gv_key);
    
    // سناریو 1: ساخت مجیک نامبر جدید
    g_magic_number = 0;
    InitializeMagicNumber();
    if(g_magic_number != 0 && GlobalVariableCheck(gv_key))
    {
        Print("PASS: Test 1 (Generate New) - Magic number created and saved successfully: ", g_magic_number);
    }
    else
    {
        Print("FAIL: Test 1 (Generate New) - Failed to create a new magic number.");
    }

    // سناریو 2: خواندن مجیک نامبر موجود
    long saved_magic = g_magic_number;
    g_magic_number = 0; // ریست کردن متغیر
    InitializeMagicNumber();
    if(g_magic_number == saved_magic)
    {
        Print("PASS: Test 2 (Load Existing) - Correctly loaded the existing magic number: ", g_magic_number);
    }
    else
    {
        Print("FAIL: Test 2 (Load Existing) - Did not load the correct magic number. Expected: ", saved_magic, ", Got: ", g_magic_number);
    }
}


//+------------------------------------------------------------------+
//| تست توابع ذخیره و بازیابی وضعیت                                   |
//+------------------------------------------------------------------+
void Test_StateManager()
{
    Print("\n--- Testing Functions: SaveStateToFile() & LoadStateFromFile() ---");
    
    // آماده‌سازی: مقادیر ساختگی برای ذخیره کردن
    g_initial_balance = 10000.0;
    g_peak_equity = 12500.0;
    g_current_trading_day = TimeCurrent() - 86400; // دیروز

    // FIX: Cannot modify 'InpEnablePropRules'. The test relies on its default value being 'true'.
    // The function SaveStateToFile() checks this constant.

    // سناریو: ذخیره و بازیابی
    SaveStateToFile();

    // ریست کردن متغیرها برای اطمینان از اینکه مقادیر از فایل خوانده می‌شوند
    g_initial_balance = 0;
    g_peak_equity = 0;
    g_current_trading_day = 0;

    if(LoadStateFromFile())
    {
        Print("PASS: State file loaded successfully.");
        if(g_initial_balance == 10000.0 && g_peak_equity == 12500.0)
        {
            Print("   >> VALIDATION PASS: Data integrity confirmed.");
        }
        else
        {
            Print("   >> VALIDATION FAIL: Data mismatch after loading! InitialBalance: ", g_initial_balance, ", PeakEquity: ", g_peak_equity);
        }
    }
    else
    {
        Print("FAIL: Could not load state from file. (Is 'InpEnablePropRules' set to 'true' in Defines.mqh?)");
    }
}


//+------------------------------------------------------------------+
//| توابع خالی برای جلوگیری از خطای کامپایل                          |
//| این توابع در فایل‌های دیگر تعریف شده‌اند اما در این تستر استفاده نمی‌شوند |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){}
void OnTick(){}
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam){}
