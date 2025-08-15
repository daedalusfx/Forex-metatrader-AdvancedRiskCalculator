//+------------------------------------------------------------------+
//|                                                  TestRunner.mq5 |
//|        (نسخه ۳.۰) تستر واحد با ساختار نهایی و بدون خطا           |
//+------------------------------------------------------------------+
#property copyright "Unit Tester"
#property version   "3.0"

// --- ۱. افزودن کتابخانه‌های استاندارد و تعاریف پایه ---
#include <Trade\Trade.mqh>
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>
#include <Controls\Panel.mqh>
#include <Canvas\Canvas.mqh> // <-- (مهم) اضافه شد برای CCanvas
#include <Trade\AccountInfo.mqh> // برای دسترسی به اطلاعات حساب
#include <Trade\PositionInfo.mqh> // برای دسترسی به اطلاعات پوزیشن
#include <Trade\OrderInfo.mqh> // برای دسترسی به اطلاعات اردر

#include "Defines.mqh"

// --- ۲. (مهم) افزودن فایل‌های تعریف کلاس‌ها ---
// کامپایلر باید قبل از ساخت متغیر، کلاس را بشناسد
#include "DisplayCanvas.mqh"
#include "SpreadAtrAnalysis.mqh"
#include "PanelDialog.mqh"

// --- ۳. اعلان‌های پیشاپیش برای شکستن وابستگی چرخه‌ای ---
#include "ForwardDeclarations.mqh"

// --- ۴. متغیرهای سراسری و شبیه‌سازی‌ها ---
CPanelDialog       ExtDialog;
CDisplayCanvas     g_DisplayCanvas;
CSpreadAtrAnalysis g_SpreadAtrPanel;
void UpdateDisplayData(){}; // تابع خالی برای جلوگیری از خطا

// --- ۵. فایل‌های منطقی که از متغیرهای بالا استفاده می‌کنند ---
#include "Lines.mqh"
#include "SharedLogic.mqh"
#include "StateManager.mqh"
#include "MarketExecution.mqh"
#include "PendingExecution.mqh"
#include "StairwayExecution.mqh"

// --- ۶. فریم‌ورک تست ---
#include "TestFramework.mqh"


// --- تعریف توابع تست ---
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
    if(!ExtDialog.Create(0, "MockDialog", 0, 0, 0))
    {
        Print("FATAL: Could not create mock dialog.");
        return(INIT_FAILED);
    }
    ExtDialog.ResetAllControls();
    Print("Mock dialog initialized. Default inputs from Defines.mqh will be used.");

    Print("\n--- STARTING LOGIC UNIT TESTS ---\n");

    // فراخوانی هر تست به ترتیب
    Test_CalculateLotSize();
    Test_IsTradeRequestSafe();
    Test_InitializeMagicNumber();
    Test_StateManager();
    Test_Stairway_Setup();

    // چاپ گزارش نهایی
    PrintTestSummary();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تست تابع محاسبه حجم لات                                          |
//+------------------------------------------------------------------+
void Test_CalculateLotSize()
{
    Print("--- Testing Function: CalculateLotSize() ---");
    
    // تست ۱: ورودی‌های معقول (حالت درصد)
    // Arrange
    double lot_size = 0, risk_money = 0;
    ExtDialog.SetCurrentState(STATE_PREP_MARKET_BUY);
    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double valid_entry = current_ask;
    double valid_sl = valid_entry - 200 * point;
    double expected_risk = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
    
    // Act
    bool result1 = CalculateLotSize(valid_entry, valid_sl, lot_size, risk_money);
    
    // Assert
    AssertTrue(result1, "Test 1.1 (Valid Inputs) - Should return true");
    AssertTrue(lot_size > 0, "Test 1.2 (Valid Inputs) - Lot size should be positive");
    AssertEquals(expected_risk, risk_money, "Test 1.3 (Valid Inputs) - Risk money should be calculated correctly");

    // تست ۲: فاصله SL صفر
    // Arrange
    lot_size = 0; risk_money = 0;
    
    // Act
    bool result2 = CalculateLotSize(valid_entry, valid_entry, lot_size, risk_money);
    
    // Assert
    AssertFalse(result2, "Test 2 (Zero SL Distance) - Should return false");
}


//+------------------------------------------------------------------+
//| تست تابع بررسی ایمنی معامله                                       |
//+------------------------------------------------------------------+
void Test_IsTradeRequestSafe()
{
    Print("\n--- Testing Function: IsTradeRequestSafe() ---");
    
    // Arrange
    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double entry = current_ask;
    double sl = entry - 200 * point;
    double tp = entry + 400 * point;

    // تست ۱: مارجین کافی
    AssertTrue(IsTradeRequestSafe(0.01, ORDER_TYPE_BUY, entry, sl, tp), "Test 1 (Sufficient Margin) - Should approve small trade");

    // تست ۲: مارجین ناکافی
    AssertFalse(IsTradeRequestSafe(9999.0, ORDER_TYPE_BUY, entry, sl, tp), "Test 2 (Insufficient Margin) - Should reject huge trade");
    
    // تست ۳: قوانین پراپ - ریسک امن
    // Arrange
    g_prop_rules_active = true;
    g_start_of_day_base = AccountInfoDouble(ACCOUNT_BALANCE);
    double safe_lot = 0, safe_risk = 0;
    if(CalculateLotSize(entry, sl, safe_lot, safe_risk))
    {
       // Act & Assert
       AssertTrue(IsTradeRequestSafe(safe_lot, ORDER_TYPE_BUY, entry, sl, tp), "Test 3 (Prop Rule - Safe Risk) - Should approve trade within DD limits");
    }
    
    // تست ۴: قوانین پراپ - ریسک ناامن
    // Arrange
    double unsafe_lot = safe_lot > 0 ? safe_lot * 10 : 1.0; // ریسک ۱۰٪، باید قانون ۵٪ را نقض کند
    
    // Act & Assert
    AssertFalse(IsTradeRequestSafe(unsafe_lot, ORDER_TYPE_BUY, entry, sl, tp), "Test 4 (Prop Rule - Unsafe Risk) - Should reject trade violating DD limits");
    
    g_prop_rules_active = false; // ریست برای تست‌های بعدی
}


//+------------------------------------------------------------------+
//| تست تابع مقداردهی اولیه مجیک نامبر                                |
//+------------------------------------------------------------------+
void Test_InitializeMagicNumber()
{
    Print("\n--- Testing Function: InitializeMagicNumber() ---");
    
    // Arrange
    string gv_key = "AdvRiskCalc_Magic_" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" + _Symbol + "_" + (string)ChartID();
    GlobalVariableDel(gv_key);
    
    // تست ۱: ساخت مجیک نامبر جدید
    // Act
    g_magic_number = 0;
    InitializeMagicNumber();
    long first_magic = g_magic_number;
    
    // Assert
    AssertTrue(first_magic != 0, "Test 1.1 (Generate New) - Magic number should be non-zero");
    AssertTrue(GlobalVariableCheck(gv_key), "Test 1.2 (Generate New) - Global variable should be created");

    // تست ۲: خواندن مجیک نامبر موجود
    // Act
    g_magic_number = 0; // ریست
    InitializeMagicNumber();
    
    // Assert
    AssertEquals(first_magic, g_magic_number, "Test 2 (Load Existing) - Should load the same magic number");
}


//+------------------------------------------------------------------+
//| تست توابع ذخیره و بازیابی وضعیت                                   |
//+------------------------------------------------------------------+
void Test_StateManager()
{
    Print("\n--- Testing Functions: SaveStateToFile() & LoadStateFromFile() ---");
    
    // Arrange
    g_initial_balance = 10000.0;
    g_peak_equity = 12500.0;
    g_current_trading_day = (datetime)(TimeCurrent() - 86400);
    
    // Act
    SaveStateToFile();
    
    // ریست متغیرها
    double saved_balance = g_initial_balance;
    double saved_equity = g_peak_equity;
    g_initial_balance = 0;
    g_peak_equity = 0;
    bool loaded = LoadStateFromFile();

    // Assert
    AssertTrue(loaded, "Test 1 (Load) - State file should be loaded successfully");
    AssertEquals(saved_balance, g_initial_balance, "Test 2 (Data Integrity) - Initial balance should match");
    AssertEquals(saved_equity, g_peak_equity, "Test 3 (Data Integrity) - Peak equity should match");
}


void Test_Stairway_Setup()
{
    Print("\n--- Testing Function: Stairway Setup ---");
    
    // Arrange: همه چیز را به حالت اولیه برگردانید
    ResetToIdleState();
    ExtDialog.SetCurrentState(STATE_IDLE);

    // Act: تابع آماده‌سازی استراتژی پلکانی را فراخوانی کنید (مثل کلیک روی دکمه)
    SetupStairwayTrade(STATE_PREP_STAIRWAY_BUY);

    // Assert: نتایج را بررسی کنید
    ETradeState current_state = ExtDialog.GetCurrentState();
    bool entry_line_exists = (ObjectFind(0, LINE_ENTRY_PRICE) != -1);
    bool pending_line_exists = (ObjectFind(0, LINE_PENDING_ENTRY) != -1);

    AssertEquals(STATE_PREP_STAIRWAY_BUY, (long)current_state, "Test 1.1 (Setup) - State should be PREP_STAIRWAY_BUY");
    AssertTrue(entry_line_exists, "Test 1.2 (Setup) - Breakout entry line should be created");
    AssertTrue(pending_line_exists, "Test 1.3 (Setup) - Manual pending entry line should be created");

    // پاکسازی برای تست بعدی
    ResetToIdleState();
}

//+------------------------------------------------------------------+
//| توابع خالی برای جلوگیری از خطای کامپایل                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){}
void OnTick(){}
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam){}
