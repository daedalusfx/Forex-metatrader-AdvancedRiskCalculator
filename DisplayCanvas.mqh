//+------------------------------------------------------------------+
//|                                             DisplayCanvas.mqh |
//|          (نسخه ۷.۰) افزودن Live R:R و بهبود چیدمان نهایی         |
//+------------------------------------------------------------------+
#ifndef DISPLAYCANVAS_MQH
#define DISPLAYCANVAS_MQH

#include <Canvas\Canvas.mqh>
#include "Defines.mqh"

//--- کلاس CDisplayCanvas
class CDisplayCanvas
{
protected:
    CCanvas           m_canvas;
    long              m_chart_id;
    int               m_subwin;
    string            m_name;

    //--- توابع کمکی خصوصی
    void              DrawHeader(int y, const string risk_val, const string lot_val, const string reward_val);
    void              DrawDualColumnSection(int &y, double entry, double sl, double tp, const LiveTradeStats &stats);
    void              DrawPropRulesSection(int &y, const string title, const string value, double progress_pct, color bar_color);
    void              DrawFooterStatus(int y, const string status_msg);

public:
                      CDisplayCanvas(void);
                     ~CDisplayCanvas(void);

    bool              Create(long chart_id, string name, int subwin, int x, int y, int width, int height);
    void              Destroy(void);
    void              Update(double entry, double sl, double tp, double lot, double risk_money,
                             double daily_buffer, double daily_used_pct, color daily_color,
                             double overall_buffer, double overall_used_pct,
                             double needed_for_target, double profit_target_progress_pct,
                             double spread, string status_message,
                             const LiveTradeStats &live_stats);
};

//--- سازنده
CDisplayCanvas::CDisplayCanvas(void) : m_chart_id(0), m_subwin(0) {}

//--- مخرب
CDisplayCanvas::~CDisplayCanvas(void) {}

//--- ایجاد بوم نقاشی
bool CDisplayCanvas::Create(long chart_id, string name, int subwin, int x, int y, int width, int height)
{
    m_chart_id = chart_id;
    m_name     = name;
    m_subwin   = subwin;
    if(!m_canvas.CreateBitmapLabel(m_chart_id, m_name, m_subwin, x, y, width, height))
    {
        Print("Failed to create display canvas! Error: ", GetLastError());
        return false;
    }
    return true;
}

//--- حذف بوم نقاشی
void CDisplayCanvas::Destroy(void)
{
    m_canvas.Destroy();
}


//--- (تابع اصلی) نقاشی تمام اطلاعات روی بوم ---
void CDisplayCanvas::Update(double entry, double sl, double tp, double lot, double risk_money,
    double daily_buffer, double daily_used_pct, color daily_color,
    double overall_buffer, double overall_used_pct,
    double needed_for_target, double profit_target_progress_pct,
    double spread, string status_message,
    const LiveTradeStats &live_stats)
{
    string currency = AccountInfoString(ACCOUNT_CURRENCY);
    int panel_width = m_canvas.Width();
    int panel_height = m_canvas.Height();
    int padding = 12;
    int current_y = 0;

    m_canvas.Erase(InpModernUIPanelBg);

    // --- محاسبه مقادیر برای هدر ---
    double rr_ratio = (risk_money > 0 && tp > 0 && sl > 0 && MathAbs(sl - entry) > 0) ? MathAbs(tp - entry) / MathAbs(sl - entry) : 0.0;
    double reward_money = risk_money * rr_ratio;
    string risk_str = StringFormat("%s %.2f", currency, risk_money);
    string lot_str = StringFormat("%.2f Lot", lot);
    string reward_str = StringFormat("%s %.2f", currency, reward_money);

    // --- بخش ۱: هدر ---
    DrawHeader(padding, risk_str, lot_str, reward_str);
    current_y = 55;

    // --- بخش ۲: بخش دو ستونی ---
    DrawDualColumnSection(current_y, entry, sl, tp, live_stats);

    // --- بخش ۳: داشبورد قوانین پراپ ---
    if (g_prop_rules_active)
    {
        m_canvas.FillRectangle(padding, current_y, panel_width - padding, current_y + 1, InpModernUIBorder);
        current_y += 15;
        
        string daily_buffer_str = StringFormat("%s %.2f left", currency, daily_buffer);
        DrawPropRulesSection(current_y, "Daily Drawdown", daily_buffer_str, daily_used_pct, daily_color);

        color overall_color = (overall_buffer < 0) ? InpDangerColor : InpSafeColor;
        string overall_buffer_str = StringFormat("%s %.2f left", currency, overall_buffer);
        DrawPropRulesSection(current_y, "Max Drawdown", overall_buffer_str, overall_used_pct, overall_color);
    }
    
    // --- بخش ۴: پیام وضعیت ---
    if(status_message != "")
    {
       DrawFooterStatus(panel_height - 25, status_message);
    }

    m_canvas.Update();
    ChartRedraw();
}


//--- (تابع کمکی) رسم بخش دو ستونی (نهایی) ---
void CDisplayCanvas::DrawDualColumnSection(int &y, double entry, double sl, double tp, const LiveTradeStats &stats)
{
    if(entry <= 0 && stats.position_count == 0) return;

    int panel_width = m_canvas.Width();
    int padding = 12;
    int col_1_x = padding;
    int col_2_x = panel_width / 2 + 5;
    int initial_y = y;
    int y_left = initial_y;
    int y_right = initial_y;
    int line_height = 18;

    // --- ستون اول: جزئیات معامله ---
    if (entry > 0)
    {
        m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize, FW_BOLD);
        m_canvas.TextOut(col_1_x, y_left, "Setup Details", InpModernUITitle);
        y_left += line_height + 5;

        m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize);
        m_canvas.TextOut(col_1_x, y_left, "Entry:", InpModernUITextSecondary);
        m_canvas.TextOut(col_2_x - 15, y_left, DoubleToString(entry, _Digits), InpModernUITextPrimary);
        y_left += line_height;
        
        m_canvas.TextOut(col_1_x, y_left, "Stop Loss:", InpModernUITextSecondary);
        m_canvas.TextOut(col_2_x - 15, y_left, DoubleToString(sl, _Digits), InpModernUITextPrimary);
        y_left += line_height;

        m_canvas.TextOut(col_1_x, y_left, "Take Profit:", InpModernUITextSecondary);
        m_canvas.TextOut(col_2_x - 15, y_left, (tp > 0 ? DoubleToString(tp, _Digits) : "-"), InpModernUITextPrimary);
        y_left += line_height;
    }

    // --- ستون دوم: آمار زنده ---
    if(stats.position_count > 0)
    {
        string currency = AccountInfoString(ACCOUNT_CURRENCY);
        
        m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize, FW_BOLD);
        m_canvas.TextOut(col_2_x, y_right, "Live (" + (string)stats.position_count + ")", InpModernUITitle);
        y_right += line_height + 5;

        m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize);
        
        string pl_str = StringFormat("%s%+.2f", currency, stats.total_pl);
        m_canvas.TextOut(col_2_x, y_right, "P/L:", InpModernUITextSecondary);
        color pl_color = (stats.total_pl >= 0) ? InpProfitLineColor : InpDangerColor;
        m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(pl_str), y_right, pl_str, pl_color);
        y_right += line_height;
        
        string risk_str = StringFormat("%s %.2f", currency, stats.total_risk);
        m_canvas.TextOut(col_2_x, y_right, "Risk:", InpModernUITextSecondary);
        m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(risk_str), y_right, risk_str, InpWarningColor);
        y_right += line_height;
        
        double live_rr = (stats.total_risk > 0) ? stats.total_reward / stats.total_risk : 0.0;
        string rr_str = StringFormat("%.1f:1", live_rr);
        m_canvas.TextOut(col_2_x, y_right, "R:R:", InpModernUITextSecondary);
        m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(rr_str), y_right, rr_str, InpModernUITextPrimary);
        y_right += line_height;
    }

    y = MathMax(y_left, y_right) + 5;
}


//--- (توابع کمکی دیگر) ---
void CDisplayCanvas::DrawHeader(int y, const string risk_val, const string lot_val, const string reward_val)
{
    int panel_width = m_canvas.Width();
    int padding = 12;
    m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize);
    m_canvas.TextOut(padding, y, "Setup Risk", InpModernUITextSecondary);
    m_canvas.TextOut((panel_width - (int)m_canvas.TextWidth(lot_val)) / 2 - 10, y, "Lot Size", InpModernUITextSecondary);
    m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth("Reward"), y, "Setup Reward", InpModernUITextSecondary);
    m_canvas.FontSet("Tahoma", InpCanvasMainFontSize, FW_BOLD);
    m_canvas.TextOut(padding, y + 15, risk_val, InpDangerColor);
    m_canvas.TextOut((panel_width - (int)m_canvas.TextWidth(lot_val)) / 2, y + 15, lot_val, InpModernUITextPrimary);
    m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(reward_val), y + 15, reward_val, InpProfitLineColor);
}

void CDisplayCanvas::DrawPropRulesSection(int &y, const string title, const string value, double progress_pct, color bar_color)
{
    int panel_width = m_canvas.Width();
    int padding = 12;
    int bar_height = 5;
    m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize);
    m_canvas.TextOut(padding, y, title, InpModernUITextSecondary);
    m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(value), y, value, InpModernUITextPrimary);
    y += 20;
    progress_pct = MathMax(0, MathMin(progress_pct, 100));
    int bar_width = panel_width - 2 * padding;
    int progress_width = (int)(bar_width * progress_pct / 100.0);
    m_canvas.FillRectangle(padding, y, panel_width - padding, y + bar_height, InpModernUIProgressBg);
    m_canvas.FillRectangle(padding, y, padding + progress_width, y + bar_height, bar_color);
    y += 25;
}

void CDisplayCanvas::DrawFooterStatus(int y, const string status_msg)
{
    int panel_width = m_canvas.Width();
    int padding = 12;
    m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize, FW_BOLD);
    int text_width = (int)m_canvas.TextWidth(status_msg);
    m_canvas.FillRectangle(0, y - 5, panel_width, y + 20, InpModernUIBorder);
    m_canvas.TextOut((panel_width - text_width) / 2, y, status_msg, InpWarningColor);
}

#endif // DISPLAYCANVAS_MQH