//+------------------------------------------------------------------+
//|                                           Test_Functions.mq5 |
//|          تستر واحد برای اعتبارسنجی منطق‌های اصلی اکسپرت           |
//|    برای اجرا، این فایل را در کنار سایر فایل‌های .mqh پروژه قرار دهید |
//+------------------------------------------------------------------+
#property copyright "Unit Tester"
#property version   "1.3"
// FIX: Removed invalid property 'tester_symbol' to fix compilation error.

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
    Print("--- INITIALIZING TEST ENVIRONMENT ---");
    // FIX: Initialize the mock dialog to set default values like risk percentage.
    if(!ExtDialog.Create(0, "MockDialog", 0, 0, 0))
    {
        Print("FATAL: Could not create mock dialog. Tests cannot run.");
        return(INIT_FAILED);
    }
    ExtDialog.ResetAllControls(); // This sets the default risk percentage text in the edit box.
    Print("Mock dialog initialized. Default risk is set via ResetAllControls().");


    Print("\n--- STARTING LOGIC UNIT TESTS ---");
    Print("NOTE: Tests are running with default 'input' values from Defines.mqh on symbol ", _Symbol);

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

    ExtDialog.SetCurrentState(STATE_PREP_MARKET_BUY);

    // FIX: Use dynamic prices based on the current symbol to make the test universal.
    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double valid_entry = current_ask;
    double valid_sl = valid_entry - 200 * point; // 20 pips SL for any symbol

    // سناریو 1: ورودی‌های معقول
    if(CalculateLotSize(valid_entry, valid_sl, lot_size, risk_money))
    {
        // FIX: Generic validation. Lot size must be positive, and risk amount must be correct.
        double expected_risk = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
        if(lot_size > 0 && MathAbs(risk_money - expected_risk) < 0.01)
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
    if(!CalculateLotSize(valid_entry, valid_entry, lot_size, risk_money))
    {
        Print("PASS: Test 2 (Zero SL Distance) - Correctly failed to calculate lot.");
    }
    else
    {
        Print("FAIL: Test 2 (Zero SL Distance) - It should have returned false.");
    }
}


//+------------------------------------------------------------------+
//| تست تابع بررسی ایمنی معامله                                       |
//+------------------------------------------------------------------+
void Test_IsTradeRequestSafe()
{
    Print("\n--- Testing Function: IsTradeRequestSafe() ---");
    
    // FIX: Use dynamic prices for all test cases.
    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double entry = current_ask;
    double sl = entry - 200 * point;
    double tp = entry + 400 * point;
    
    // --- بخش اول: تست مارجین ---
    Print("  -- Margin Check --");
    if(IsTradeRequestSafe(0.01, ORDER_TYPE_BUY, entry, sl, tp))
    {
        Print("PASS: Margin Test 1 (Sufficient Margin) - Correctly approved the trade.");
    }
    else
    {
        Print("FAIL: Margin Test 1 (Sufficient Margin) - Trade rejected unexpectedly. Error: ", GetLastError());
    }

    if(!IsTradeRequestSafe(9999.0, ORDER_TYPE_BUY, entry, sl, tp))
    {
        Print("PASS: Margin Test 2 (Insufficient Margin) - Correctly rejected the trade.");
    }
    else
    {
        Print("FAIL: Margin Test 2 (Insufficient Margin) - Trade was approved but it shouldn't have been.");
    }
    
    // --- بخش دوم: تست قوانین پراپ ---
    Print("  -- Prop Firm Rules Check --");
    g_prop_rules_active = true; // فعال‌سازی قوانین برای تست
    g_start_of_day_base = 10000;
    // حد ضرر روزانه 5% (مقدار پیش‌فرض) از 10,000 یعنی 500 دلار است. اکوئیتی نباید زیر 9500 برود.
    
    // سناریو 3: ریسک معامله در محدوده مجاز
    double safe_lot = 0, safe_risk = 0;
    CalculateLotSize(entry, sl, safe_lot, safe_risk); // Calculate lot for 1% risk
    if(safe_lot > 0 && IsTradeRequestSafe(safe_lot, ORDER_TYPE_BUY, entry, sl, tp))
    {
        Print("PASS: Prop Rule Test 1 (Safe Risk) - Correctly approved the trade with lot ", safe_lot);
    }
    else
    {
        Print("FAIL: Prop Rule Test 1 (Safe Risk) - Rejected a safe trade. Lot was ", safe_lot);
    }
    
    // سناریو 4: ریسک معامله خارج از محدوده مجاز
    double unsafe_lot = safe_lot * 6; // Approx 6% risk, should violate the 5% DD rule
    if(unsafe_lot > 0 && !IsTradeRequestSafe(unsafe_lot, ORDER_TYPE_BUY, entry, sl, tp))
    {
        Print("PASS: Prop Rule Test 2 (Unsafe Risk) - Correctly rejected the trade due to Daily DD with lot ", unsafe_lot);
    }
    else
    {
        Print("FAIL: Prop Rule Test 2 (Unsafe Risk) - Approved a trade that violates Daily DD rule. Lot was ", unsafe_lot);
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

    // The function SaveStateToFile() internally checks 'InpEnablePropRules'.
    // The test relies on its default value being 'true' in Defines.mqh.

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
