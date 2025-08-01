//+------------------------------------------------------------------+
//|                                                  PanelDialog.mqh |
//|     کلاس اصلی برای مدیریت پنل تعاملی (با چیدمان متغیر)     |
//+------------------------------------------------------------------+
#ifndef PANELDIALOG_MQH
#define PANELDIALOG_MQH

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>
#include <Controls\Panel.mqh>

//--- Forward declarations
void ResetToIdleState();
void SetupMarketTrade(ETradeState newState);
void SetupPendingTrade(ETradeState newState);
void ExecuteMarketTrade();
void ExecutePendingTrade();
void UpdateAllLabels();
void DeleteTradeLines();
double GetLinePrice(string line_name);
void UpdateAutoTPLine();
bool CalculateLotSize(double entry, double sl, double &lot_size, double &risk_in_money);

//--- کلاس اصلی پنل
class CPanelDialog : public CAppDialog
{
private:
    //--- متغیرهای وضعیت
    ETradeState       m_current_state;
    bool              m_is_trade_logic_valid;

    //--- کنترل‌های بخش Market
    CPanel            m_panel_market;
    CLabel            m_lbl_title_market;
    CButton           m_btn_prep_market_buy;
    CButton           m_btn_prep_market_sell;
    CLabel            m_lbl_risk_market;
    CEdit             m_edit_risk_market;
    CButton           m_btn_execute_market;

    //--- کنترل‌های بخش Pending
    CPanel            m_panel_pending;
    CLabel            m_lbl_title_pending;
    CButton           m_btn_prep_pending_buy;
    CButton           m_btn_prep_pending_sell;
    CLabel            m_lbl_risk_pending;
    CEdit             m_edit_risk_pending;
    CButton           m_btn_execute_pending;

public:
                      CPanelDialog(void);
                     ~CPanelDialog(void);
    //--- ایجاد پنل
    virtual bool      Create(const long chart, const string name, const int subwin, const int x1, const int y1);
    //--- مدیریت رویدادها
    virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
    void              HandleDragEvent(const string &dragged_object);

    //--- توابع کمکی برای دسترسی به وضعیت
    ETradeState       GetCurrentState() { return m_current_state; }
    void              SetCurrentState(ETradeState new_state) { m_current_state = new_state; }
    bool              IsTradeLogicValid() { return m_is_trade_logic_valid; }
    void              SetTradeLogicValid(bool is_valid) { m_is_trade_logic_valid = is_valid; }
    string            GetRiskInput(string type);
    
    //--- توابع برای به‌روزرسانی UI از خارج کلاس
    void              ResetAllControls();
    void              SetMarketUIMode(ETradeState state);
    void              SetPendingUIMode(ETradeState state);
    void              SetExecuteButtonState();

protected:
    //--- ایجاد کنترل‌ها
    bool              CreateMarketPanel(int x, int y);
    bool              CreatePendingPanel(int x, int y);

    //--- مدیریت رویدادهای کلیک
    void              OnClickPrepMarketBuy(void);
    void              OnClickPrepMarketSell(void);
    void              OnClickExecuteMarket(void);
    void              OnClickPrepPendingBuy(void);
    void              OnClickPrepPendingSell(void);
    void              OnClickExecutePending(void);
    void              OnRiskEditChange(void);
};

//--- نقشه رویدادها
EVENT_MAP_BEGIN(CPanelDialog)
    ON_EVENT(ON_CLICK, m_btn_prep_market_buy, OnClickPrepMarketBuy)
    ON_EVENT(ON_CLICK, m_btn_prep_market_sell, OnClickPrepMarketSell)
    ON_EVENT(ON_CLICK, m_btn_execute_market, OnClickExecuteMarket)
    ON_EVENT(ON_CLICK, m_btn_prep_pending_buy, OnClickPrepPendingBuy)
    ON_EVENT(ON_CLICK, m_btn_prep_pending_sell, OnClickPrepPendingSell)
    ON_EVENT(ON_CLICK, m_btn_execute_pending, OnClickExecutePending)
    ON_EVENT(ON_CHANGE, m_edit_risk_market, OnRiskEditChange)
    ON_EVENT(ON_CHANGE, m_edit_risk_pending, OnRiskEditChange)
EVENT_MAP_END(CAppDialog)

//--- سازنده
CPanelDialog::CPanelDialog(void) : m_current_state(STATE_IDLE), m_is_trade_logic_valid(false)
{
}
//--- مخرب
CPanelDialog::~CPanelDialog(void)
{
}

//--- ایجاد پنل اصلی
bool CPanelDialog::Create(const long chart, const string name, const int subwin, const int x1, const int y1)
{
    if(!CAppDialog::Create(chart, name, subwin, x1, y1, x1 + 240, y1 + 205))
        return(false);

    ObjectSetInteger(m_chart_id, m_name + "_background", OBJPROP_BGCOLOR, InpPanelBackgroundColor);

    if(!CreateMarketPanel(10, 10)) return(false);
    if(!CreatePendingPanel(10, 105)) return(false);

    ResetAllControls();
    return(true);
}

//--- (بازنویسی شده) ایجاد پنل Market با لیبل ریسک پویا
bool CPanelDialog::CreateMarketPanel(int x, int y)
{
    if(!m_panel_market.Create(m_chart_id, "MarketPanel", m_subwin, x, y, x + 220, y + 85)) return false;
    m_panel_market.ColorBackground(InpPanelBackgroundColor);
    if(!Add(m_panel_market)) return false;
    
    if(!m_lbl_title_market.Create(m_chart_id, "MarketTitle", m_subwin, x+10, y+5, x+210, y+25)) return false;
    m_lbl_title_market.Text("Market Execution");
    if(!Add(m_lbl_title_market)) return false;


    int current_x = x + 10;
    int y_pos = y + 30;


    // ردیف دکمه‌ها
    if(!m_btn_prep_market_buy.Create(m_chart_id, "PrepMarketBuy", m_subwin, x+10, y+30, x+70, y+55)) return false;
    if(!Add(m_btn_prep_market_buy)) return false;
    if(!m_btn_prep_market_sell.Create(m_chart_id, "PrepMarketSell", m_subwin, x+75, y+30, x+135, y+55)) return false;
    if(!Add(m_btn_prep_market_sell)) return false;
    if(!m_btn_execute_market.Create(m_chart_id, "ExecuteMarket", m_subwin, x+140, y+30, x+210, y+55)) return false;
    if(!Add(m_btn_execute_market)) return false;
    
    y_pos += InpButtonHeight + 10;
    if(!m_lbl_risk_market.Create(m_chart_id, "RiskMarketLbl", m_subwin, x+10, y_pos, x+60, y_pos+20)) return false;
    
    // --- (کد جدید) تنظیم متن لیبل بر اساس حالت انتخابی ---
    string risk_label_text = (InpRiskMode == RISK_PERCENT) ? "Risk %:" : "Risk " + AccountInfoString(ACCOUNT_CURRENCY) + ":";
    m_lbl_risk_market.Text(risk_label_text);
    // --- (پایان کد جدید) ---

    if(!Add(m_lbl_risk_market)) return false;
    if(!m_edit_risk_market.Create(m_chart_id, "RiskMarketEdit", m_subwin, x+70, y_pos-2, x+130, y_pos+23)) return false;
    if(!Add(m_edit_risk_market)) return false;
    
    return true;
}

//--- (بازنویسی شده) ایجاد پنل Pending با لیبل ریسک پویا
bool CPanelDialog::CreatePendingPanel(int x, int y)
{
    if(!m_panel_pending.Create(m_chart_id, "PendingPanel", m_subwin, x, y, x + 220, y + 85)) return false;
    m_panel_pending.ColorBackground(InpPanelBackgroundColor);
    if(!Add(m_panel_pending)) return false;
    
    if(!m_lbl_title_pending.Create(m_chart_id, "PendingTitle", m_subwin, x+10, y+5, x+210, y+25)) return false;
    m_lbl_title_pending.Text("Pending Order");
    if(!Add(m_lbl_title_pending)) return false;
    int current_x = x + 10;
    int y_pos = y + 30;

    // ردیف دکمه‌ها
    if(!m_btn_prep_pending_buy.Create(m_chart_id, "PrepPendingBuy", m_subwin, x+10, y+30, x+70, y+55)) return false;
    if(!Add(m_btn_prep_pending_buy)) return false;
    if(!m_btn_prep_pending_sell.Create(m_chart_id, "PrepPendingSell", m_subwin, x+75, y+30, x+135, y+55)) return false;
    if(!Add(m_btn_prep_pending_sell)) return false;
    if(!m_btn_execute_pending.Create(m_chart_id, "ExecutePending", m_subwin, x+140, y+30, x+210, y+55)) return false;
    if(!Add(m_btn_execute_pending)) return false;

    y_pos += InpButtonHeight + 10;
    if(!m_lbl_risk_pending.Create(m_chart_id, "RiskPendingLbl", m_subwin, x+10, y_pos, x+60, y_pos+20)) return false;
    
    // --- (کد جدید) تنظیم متن لیبل بر اساس حالت انتخابی ---
    string risk_label_text = (InpRiskMode == RISK_PERCENT) ? "Risk %:" : "Risk " + AccountInfoString(ACCOUNT_CURRENCY) + ":";
    m_lbl_risk_pending.Text(risk_label_text);
    // --- (پایان کد جدید) ---

    if(!Add(m_lbl_risk_pending)) return false;
    if(!m_edit_risk_pending.Create(m_chart_id, "RiskPendingEdit", m_subwin, x+70, y_pos-2, x+130, y_pos+23)) return false;
    if(!Add(m_edit_risk_pending)) return false;

    return true;
}

//--- مدیریت کشیدن خطوط
void CPanelDialog::HandleDragEvent(const string &dragged_object)
{
    if(m_current_state == STATE_IDLE) return;
    
    if(InpAutoEntryPending && (m_current_state == STATE_PREP_PENDING_BUY || m_current_state == STATE_PREP_PENDING_SELL) && dragged_object == LINE_STOP_LOSS)
    {
        // منطق حرکت ساختار ثابت (در صورت نیاز اضافه شود)
    }
    else if(!InpAutoEntryPending && InpTPMode == TP_RR_RATIO && (dragged_object == LINE_ENTRY_PRICE || dragged_object == LINE_STOP_LOSS))
    {
        UpdateAutoTPLine();
    }
    UpdateAllLabels();
}

//--- بازنشانی تمام کنترل‌ها به حالت اولیه
void CPanelDialog::ResetAllControls()
{
    m_current_state = STATE_IDLE;
    m_is_trade_logic_valid = false;
    DeleteTradeLines();

        // --- (کد جدید) تنظیم مقدار پیش‌فرض هوشمند برای فیلد ریسک ---
        string default_risk_text;
        if(InpRiskMode == RISK_PERCENT)
        {
            // اگر حالت درصد است، مقدار پیش‌فرض را از ورودی بخوان
            default_risk_text = DoubleToString(InpRiskPercent, 1);
        }
        else // InpRiskMode == RISK_MONEY
        {
            // اگر حالت پول است، درصد پیش‌فرض را به معادل پولی آن تبدیل کن
            double default_money_risk = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
            default_risk_text = DoubleToString(default_money_risk, 2);
        }
        // --- (پایان کد جدید) ---


    //--- بازنشانی بخش Market
    m_btn_prep_market_buy.Text("Market Buy");
    m_btn_prep_market_buy.ColorBackground(InpBuyButtonColor);
    m_btn_prep_market_sell.Text("Market Sell");
    m_btn_prep_market_sell.ColorBackground(InpSellButtonColor);
    m_btn_execute_market.Text("Execute");
    m_btn_execute_market.ColorBackground(InpDisabledButtonColor);
    m_edit_risk_market.Text(default_risk_text); // استفاده از مقدار پیش‌فرض هوشمند


    //--- بازنشانی بخش Pending
    m_btn_prep_pending_buy.Text("Pending Buy");
    m_btn_prep_pending_buy.ColorBackground(InpBuyButtonColor);
    m_btn_prep_pending_sell.Text("Pending Sell");
    m_btn_prep_pending_sell.ColorBackground(InpSellButtonColor);
    m_btn_execute_pending.Text("Place");
    m_btn_execute_pending.ColorBackground(InpDisabledButtonColor);
    m_edit_risk_pending.Text(default_risk_text); // استفاده از مقدار پیش‌فرض هوشمند

    
    ChartRedraw();
}

//--- دریافت مقدار ریسک از فیلد ورودی
string CPanelDialog::GetRiskInput(string type)
{
    if(type == "market") return m_edit_risk_market.Text();
    if(type == "pending") return m_edit_risk_pending.Text();
    return "0";
}

//--- تنظیم UI برای حالت Market
void CPanelDialog::SetMarketUIMode(ETradeState state)
{
    if(state == STATE_PREP_MARKET_BUY)
    {
        m_btn_prep_market_buy.Text("Cancel");
        m_btn_prep_market_buy.ColorBackground(InpCancelButtonColor);
        m_btn_prep_market_sell.Text("Market Sell");
        m_btn_prep_market_sell.ColorBackground(InpSellButtonColor);
    }
    else if(state == STATE_PREP_MARKET_SELL)
    {
        m_btn_prep_market_sell.Text("Cancel");
        m_btn_prep_market_sell.ColorBackground(InpCancelButtonColor);
        m_btn_prep_market_buy.Text("Market Buy");
        m_btn_prep_market_buy.ColorBackground(InpBuyButtonColor);
    }
}

//--- تنظیم UI برای حالت Pending
void CPanelDialog::SetPendingUIMode(ETradeState state)
{
    if(state == STATE_PREP_PENDING_BUY)
    {
        m_btn_prep_pending_buy.Text("Cancel");
        m_btn_prep_pending_buy.ColorBackground(InpCancelButtonColor);
        m_btn_prep_pending_sell.Text("Pending Sell");
        m_btn_prep_pending_sell.ColorBackground(InpSellButtonColor);
    }
    else if(state == STATE_PREP_PENDING_SELL)
    {
        m_btn_prep_pending_sell.Text("Cancel");
        m_btn_prep_pending_sell.ColorBackground(InpCancelButtonColor);
        m_btn_prep_pending_buy.Text("Pending Buy");
        m_btn_prep_pending_buy.ColorBackground(InpBuyButtonColor);
    }
}

//--- تنظیم وضعیت دکمه اجرا
void CPanelDialog::SetExecuteButtonState()
{
    bool is_valid = m_is_trade_logic_valid;
    color btn_color = InpDisabledButtonColor;
    
    if(is_valid)
    {
        switch(m_current_state)
        {
            case STATE_PREP_MARKET_BUY:   btn_color = InpExecuteBuyColor; break;
            case STATE_PREP_MARKET_SELL:  btn_color = InpExecuteSellColor; break;
            case STATE_PREP_PENDING_BUY:
            case STATE_PREP_PENDING_SELL: btn_color = InpOrderButtonColor; break;
        }
    }
    
    if(m_current_state == STATE_PREP_MARKET_BUY || m_current_state == STATE_PREP_MARKET_SELL)
        m_btn_execute_market.ColorBackground(btn_color);
    else
        m_btn_execute_pending.ColorBackground(btn_color);
}

//--- مدیریت رویدادهای کلیک
void CPanelDialog::OnClickPrepMarketBuy(void) {
    if(m_current_state == STATE_PREP_MARKET_BUY || m_current_state == STATE_PREP_MARKET_SELL) { ResetToIdleState(); return; }
    SetupMarketTrade(STATE_PREP_MARKET_BUY);
}
void CPanelDialog::OnClickPrepMarketSell(void) {
    if(m_current_state == STATE_PREP_MARKET_BUY || m_current_state == STATE_PREP_MARKET_SELL) { ResetToIdleState(); return; }
    SetupMarketTrade(STATE_PREP_MARKET_SELL);
}
void CPanelDialog::OnClickExecuteMarket(void) {
    if(m_is_trade_logic_valid) ExecuteMarketTrade();
}
void CPanelDialog::OnClickPrepPendingBuy(void) {
    if(m_current_state == STATE_PREP_PENDING_BUY || m_current_state == STATE_PREP_PENDING_SELL) { ResetToIdleState(); return; }
    SetupPendingTrade(STATE_PREP_PENDING_BUY);
}
void CPanelDialog::OnClickPrepPendingSell(void) {
    if(m_current_state == STATE_PREP_PENDING_BUY || m_current_state == STATE_PREP_PENDING_SELL) { ResetToIdleState(); return; }
    SetupPendingTrade(STATE_PREP_PENDING_SELL);
}
void CPanelDialog::OnClickExecutePending(void) {
    if(m_is_trade_logic_valid) ExecutePendingTrade();
}
void CPanelDialog::OnRiskEditChange(void) {
    if(m_current_state != STATE_IDLE) UpdateAllLabels();
}

#endif // PANELDIALOG_MQH
