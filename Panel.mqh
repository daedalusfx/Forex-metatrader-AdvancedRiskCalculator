//+------------------------------------------------------------------+
//|                                                    Panel.mqh |
//|              Functions for creating and managing the UI          |
//+------------------------------------------------------------------+
#ifndef PANEL_MQH
#define PANEL_MQH
#include "Defines.mqh"
//+------------------------------------------------------------------+
//|                      UI PRIMITIVE FUNCTIONS                    |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr=clrNONE, int font_size=0, bool is_bold=false) { if(clr==clrNONE)clr=InpTextColor; if(font_size==0) font_size=InpPanelFontSize; ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0); ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y); ObjectSetInteger(0, name, OBJPROP_COLOR, clr); ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER); ObjectSetString(0, name, OBJPROP_FONT, is_bold ? "Tahoma Bold" : "Tahoma"); ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size); ObjectSetInteger(0, name, OBJPROP_BACK, false); }
void CreateInput(string name, int x, int y, string text, int w=100, int h=20) { ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0); ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y); ObjectSetInteger(0, name, OBJPROP_XSIZE, w); ObjectSetInteger(0, name, OBJPROP_YSIZE, h); ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'80,80,80'); ObjectSetInteger(0, name, OBJPROP_COLOR, InpTextColor); ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT); ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER); ObjectSetInteger(0, name, OBJPROP_BACK, false); }
void CreateButton(string name, string text, int x, int y, int w, int h, color bg=clrGray) { ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0); ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y); ObjectSetInteger(0, name, OBJPROP_XSIZE, w); ObjectSetInteger(0, name, OBJPROP_YSIZE, h); ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg); ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite); ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpPanelFontSize); ObjectSetString(0, name, OBJPROP_FONT, "Tahoma Bold"); ObjectSetInteger(0, name, OBJPROP_BACK, false); }
void CreateSeparator(string name, int y, int width) { ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 15); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y); ObjectSetInteger(0, name, OBJPROP_XSIZE, width - 30); ObjectSetInteger(0, name, OBJPROP_YSIZE, 1); ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'99,110,114'); ObjectSetInteger(0, name, OBJPROP_BACK, false); }

//+------------------------------------------------------------------+
//|                      PANEL CREATION & MGMT                       |
//+------------------------------------------------------------------+
void CreateMainPanel()
{
   int x_start = 15;
   int x_padding = 5;
   int y_padding = 5;

   ObjectCreate(0, PANEL_MAIN_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PANEL_MAIN_BG, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, PANEL_MAIN_BG, OBJPROP_YDISTANCE, mainPanelYPos);
   ObjectSetInteger(0, PANEL_MAIN_BG, OBJPROP_XSIZE, mainPanelWidth);
   ObjectSetInteger(0, PANEL_MAIN_BG, OBJPROP_YSIZE, mainPanelHeight);
   ObjectSetInteger(0, PANEL_MAIN_BG, OBJPROP_BGCOLOR, InpPanelBackgroundColor);
   ObjectSetInteger(0, PANEL_MAIN_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_MAIN_BG, OBJPROP_BACK, false);

   CreateButton(BTN_MINIMIZE, "_", mainPanelWidth - 28, mainPanelYPos + y_padding, 20, 20, C'99,110,114');

   int yPos = mainPanelYPos + y_padding + 25;

   CreateLabel(LABEL_SPREAD, x_start, yPos, "Spread: -", InpTextColor, 10, true);
   yPos += 20;
   CreateSeparator(PREFIX_MAIN+"_Sep1", yPos, mainPanelWidth);
   yPos += 15;

   CreateLabel(PREFIX_MAIN+"_PendTitle", x_start, yPos, "Pending Order", InpTextColor, 10, true);
   yPos += 25;
   CreateButton(BTN_PREP_PENDING_BUY, "Buy", x_start, yPos, 60, 25, InpBuyButtonColor);
   CreateButton(BTN_PREP_PENDING_SELL, "Sell", x_start + 60 + x_padding, yPos, 60, 25, InpSellButtonColor);
   CreateButton(BTN_EXECUTE_PENDING, "Place", x_start + 130, yPos, 65, 25, InpOrderButtonColor);
   yPos += 35;
   CreateLabel(PREFIX_MAIN+"_RiskPLbl", x_start, yPos, "Risk %:");
   CreateInput(INPUT_RISK_PENDING, x_start + 70, yPos - 3, "1.0", 50, 22);
   yPos += 30;
   CreateSeparator(PREFIX_MAIN+"_Sep2", yPos, mainPanelWidth);
   yPos += 15;

   CreateLabel(PREFIX_MAIN+"_MarketTitle", x_start, yPos, "Market Execution", InpTextColor, 10, true);
   yPos += 25;
   CreateButton(BTN_PREP_MARKET_BUY, "Buy", x_start, yPos, 60, 25, InpBuyButtonColor);
   CreateButton(BTN_PREP_MARKET_SELL, "Sell", x_start + 60 + x_padding, yPos, 60, 25, InpSellButtonColor);
   CreateButton(BTN_EXECUTE_MARKET, "Execute", x_start + 130, yPos, 65, 25);
   yPos += 35;
   CreateLabel(PREFIX_MAIN+"_RiskMLbl", x_start, yPos, "Risk %:");
   CreateInput(INPUT_RISK_MARKET, x_start + 70, yPos - 3, "1.0", 50, 22);
   yPos += 30;
   CreateSeparator(PREFIX_MAIN+"_Sep3", yPos, mainPanelWidth);
   yPos += 12;

   int col2_x = x_start + 110;
   CreateLabel(LABEL_ENTRY, x_start, yPos, "Entry: -");
   CreateLabel(LABEL_SL, col2_x, yPos, "SL: -");
   yPos += 20;
   CreateLabel(LABEL_TP, x_start, yPos, "TP: -");
   CreateLabel(LABEL_LOT, col2_x, yPos, "Lot: 0.00");
   yPos += 20;
   CreateLabel(LABEL_RISK_VALUE, x_start, yPos, "Risk Value: $0.00");

   ChartRedraw();
}

void TogglePanelVisibility()
{
   bool hide = isPanelMinimized;
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PREFIX_MAIN) == 0 && name != PANEL_MAIN_BG && name != BTN_MINIMIZE)
      {
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, hide);
      }
   }

   ObjectSetInteger(0, PANEL_MAIN_BG, OBJPROP_YSIZE, hide ? 35 : mainPanelHeight);
   ChartRedraw();
}

void UpdateSpreadLabel()
{
    if(isPanelMinimized) return;
    double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    ObjectSetString(0, LABEL_SPREAD, OBJPROP_TEXT, "Spread: " + DoubleToString(spread, 1));
}

#endif // PANEL_MQH