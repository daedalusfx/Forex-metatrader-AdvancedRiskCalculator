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

#endif // DEFINES_MQH
