//+------------------------------------------------------------------+
//|                                                  Defines.mqh |
//|          Version 3.0 - Refactored, Organized, and Fully Commented |
//+------------------------------------------------------------------+
#ifndef DEFINES_MQH
#define DEFINES_MQH

//+------------------------------------------------------------------+
//| 1. Core Enumerations & Global States                             |
//+------------------------------------------------------------------+

// --- Defines the method for setting the Take Profit level.
enum ETakeProfitMode 
{
    TP_MANUAL,      // User sets the TP line manually on the chart.
    TP_RR_RATIO     // TP is calculated automatically based on the Risk-to-Reward ratio.
};

// --- Defines the current operational state of the Expert Advisor.
enum ETradeState 
{
    STATE_IDLE,                     // EA is waiting for user action.
    STATE_PREP_MARKET_BUY,          // Preparing for a market buy order.
    STATE_PREP_MARKET_SELL,         // Preparing for a market sell order.
    STATE_PREP_PENDING_BUY,         // Preparing for a pending buy order.
    STATE_PREP_PENDING_SELL,        // Preparing for a pending sell order.
    STATE_PREP_STAIRWAY_BUY,        // Armed for a stairway buy entry.
    STATE_PREP_STAIRWAY_SELL,       // Armed for a stairway sell entry.
    STATE_STAIRWAY_WAITING_FOR_CONFIRMATION // Breakout detected, waiting for candle close confirmation.
};

// --- Defines the basis for risk calculation.
enum ENUM_Risk_Mode 
{
    RISK_PERCENT,   // Risk is calculated as a percentage of the account balance.
    RISK_MONEY      // Risk is a fixed monetary amount.
};

// --- Defines the basis for Daily Drawdown calculation.
enum ENUM_Daily_DD_Base 
{
    DD_FROM_BALANCE, // Daily DD is calculated from the balance at the start of the day.
    DD_FROM_EQUITY   // Daily DD is calculated from the equity at the start of the day.
};

// --- Defines the type of Maximum Drawdown calculation.
enum ENUM_Overall_DD_Type 
{
    DD_TYPE_STATIC,     // Max DD is a fixed level based on the initial account balance.
    DD_TYPE_TRAILING    // Max DD is a trailing value based on the highest recorded account equity.
};


//+------------------------------------------------------------------+
//| 2. User Input Parameters                                         |
//+------------------------------------------------------------------+
// The following 'input' variables are configurable by the user in the EA's settings window.

// ======================= RISK & TRADE SETTINGS =======================
input group "Risk & Trade Settings"
sinput ENUM_Risk_Mode InpRiskMode = RISK_PERCENT;                   // Risk Calculation Mode: Choose between percentage or fixed money risk.
sinput double InpRiskPercent = 1.0;                                 // Risk per Trade (%): If using percentage mode, specifies the % of account balance to risk.
sinput ETakeProfitMode InpTPMode = TP_RR_RATIO;                      // Take Profit Mode: Set TP manually or based on a Risk:Reward ratio.
sinput double InpTP_RR_Value = 2.0;                                 // Risk:Reward Ratio: If using R:R mode, sets the desired ratio (e.g., 2.0 for 1:2).
sinput ulong  InpSlippage = 10;                                     // Max Slippage (in points): The maximum allowed price deviation for market orders.

// ======================= PROP FIRM GUARDIAN =======================
input group "Prop Firm Guardian"
sinput bool   InpEnablePropRules = true;                            // Enable Prop Firm Guardian: Set to 'true' to activate all prop firm rule checks.
sinput double InpMaxDailyDrawdownPercent = 5.0;                     // Max Daily Drawdown (%): The maximum allowed loss for the current trading day.
sinput double InpMaxOverallDrawdownPercent = 10.0;                  // Max Overall Drawdown (%): The maximum allowed total loss for the account.
sinput ENUM_Daily_DD_Base InpDailyDDBase = DD_FROM_BALANCE;         // Daily DD Calculation Base: Choose if daily DD is based on start-of-day balance or equity.
sinput ENUM_Overall_DD_Type InpOverallDDType = DD_TYPE_STATIC;      // Overall DD Type: Choose if max DD is static (from initial balance) or trailing (from peak equity).

// ======================= STAIRWAY ENTRY STRATEGY =======================
input group "Stairway Entry Strategy"
sinput double InpStairwayInitialPercent = 30.0;                     // Initial Entry Size (%): The percentage of the total lot size to use for the first step of the stairway entry.

// ======================= VISUALS - TRADE LINES =======================
input group "Visuals - Trade Lines"
sinput color InpEntryLineColor  = C'238, 238, 238';                 // Entry Line Color
sinput color InpStopLineColor   = C'252, 57, 57';                   // Stop Loss Line Color
sinput color InpProfitLineColor = C'32, 201, 151';                  // Take Profit Line Color
sinput ENUM_LINE_STYLE InpLineStyle = STYLE_DASHDOT;                // Line Style: The visual style of the trade lines on the chart.
sinput int   InpLineWidth     = 1;                                 // Line Width: The thickness of the trade lines.

// ======================= VISUALS - CONTROL PANEL =======================
input group "Visuals - Control Panel"
sinput int PanelWidth = 240;                                        // Panel Width (pixels)
sinput int PanelHeight = 350;                                       // Panel Height (pixels)
sinput color InpSubPanelColor       = C'30, 34, 43';                // Inner Panels Background Color
sinput color InpPanelBackgroundColor= C'245, 245, 245';              // Main Panel Background Color (Legacy)
sinput color InpTextColor           = C'229, 231, 235';              // Primary Text Color (on inner panels)
sinput color InpBuyButtonColor      = C'30, 144, 255';               // Buy / Arm Buy Button Color
sinput color InpSellButtonColor     = C'255, 69, 0';                 // Sell / Arm Sell Button Color
sinput color InpExecuteBuyColor     = C'0, 191, 255';                // Execute Buy Button Color
sinput color InpExecuteSellColor    = C'255, 0, 0';                  // Execute Sell Button Color
sinput color InpCancelButtonColor   = C'255, 165, 0';                // Cancel Button Color

// ======================= VISUALS - DISPLAY CANVAS =======================
input group "Visuals - Display Canvas"
sinput int InpDisplayPanelX = 260;                                  // Display Canvas X Position: Horizontal distance from the left edge of the chart.
sinput int InpDisplayPanelY = 30;                                   // Display Canvas Y Position: Vertical distance from the top edge of the chart.
sinput int InpDisplayPanelW = 250;                                  // Display Canvas Width
sinput int InpDisplayPanelH = 250;                                  // Display Canvas Height
sinput color InpModernUIPanelBg      = C'31, 41, 55';                // Background Color
sinput color InpModernUITextPrimary  = C'229, 231, 235';             // Primary Text Color
sinput color InpModernUITextSecondary= C'156, 163, 175';             // Secondary Text Color
sinput color InpModernUITitle        = C'34, 211, 238';              // Title Text Color (e.g., "Setup Details")
sinput color InpModernUIBorder       = C'75, 85, 99';                // Separator Line Color
sinput color InpModernUIProgressBg   = C'55, 65, 81';                // Progress Bar Background Color
sinput color InpSafeColor           = C'52, 211, 153';               // Progress Bar Color (Safe State)
sinput color InpWarningColor        = C'251, 146, 60';               // Progress Bar Color (Warning State)
sinput color InpDangerColor         = C'248, 113, 113';              // Progress Bar Color (Danger State)


//+------------------------------------------------------------------+
//| 3. Internal Constants & Definitions                              |
//+------------------------------------------------------------------+

// --- Internal object names for chart lines. Do not change.
#define LINE_ENTRY_PRICE         "RiskCalc_EntryLine"
#define LINE_STOP_LOSS           "RiskCalc_StopLossLine"
#define LINE_TAKE_PROFIT         "RiskCalc_TakeProfitLine"
#define LINE_PENDING_ENTRY       "RiskCalc_PendingEntryLine"


//+------------------------------------------------------------------+
//| 4. Global Variables & Structures                                 |
//+------------------------------------------------------------------+

// --- System-wide trade object
CTrade          trade;

// --- Unique identifier for trades placed by this EA instance
long g_magic_number = 0;

// --- Prop Firm Guardian state variables
bool     g_prop_rules_active = false;
double   g_initial_balance = 0;
double   g_peak_equity = 0;
double   g_start_of_day_base = 0;
datetime g_current_trading_day = 0;

// --- Structure to hold live trade statistics
struct LiveTradeStats
{
    double   total_pl;
    double   total_reward;
    double   total_risk;
    int      position_count;
};

// --- Structure and array for consistency rule (if implemented in future)
struct DailyProfitLog
{
    datetime date;
    double   profit;
};
DailyProfitLog g_daily_profits[];


#endif // DEFINES_MQH
