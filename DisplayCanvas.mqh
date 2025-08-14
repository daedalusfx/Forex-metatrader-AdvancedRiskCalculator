//+------------------------------------------------------------------+
//|                                             DisplayCanvas.mqh |
//|          (نسخه نهایی) پیاده‌سازی طرح شماره ۱: فشرده و مدرن        |
//+------------------------------------------------------------------+
#ifndef DISPLAYCANVAS_MQH
#define DISPLAYCANVAS_MQH

#include <Canvas\Canvas.mqh>

//--- کلاس CDisplayCanvas
class CDisplayCanvas
{
protected:
    CCanvas           m_canvas;
    long              m_chart_id;
    int               m_subwin;
    string            m_name;
public:
                      CDisplayCanvas(void);
                     ~CDisplayCanvas(void);

    bool              Create(long chart_id, string name, int subwin, int x, int y, int width, int height);
    void              Destroy(void);
    void              Update(double entry, double sl, double tp, double lot, double risk_money,
                             double daily_buffer, double daily_used_pct, color daily_color,
                             double overall_buffer,
                             double overall_used_pct,
                             double needed_for_target, double profit_target_progress_pct,
                             double spread,string status_message = "");
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

//--- (پیاده‌سازی طرح جدید) تابع اصلی برای نقاشی تمام اطلاعات روی بوم
void CDisplayCanvas::Update(double entry, double sl, double tp, double lot, double risk_money,
    double daily_buffer, double daily_used_pct, color daily_color,
    double overall_buffer, double overall_used_pct,
    double needed_for_target, double profit_target_progress_pct,
    double spread,string status_message = "")
{
    string currency = AccountInfoString(ACCOUNT_CURRENCY);
    int panel_width = m_canvas.Width();
    int panel_height = m_canvas.Height();
    int padding = 10;
    int font_size = 8;
    int current_y = padding;

    // پاک کردن کامل بوم با رنگ پس‌زمینه اصلی
    m_canvas.Erase(InpModernUIPanelBg);
    m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize);

    // --- بخش ۱: هدر پنل ---
    m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize + 1, FW_BOLD);
    m_canvas.TextOut(padding, current_y, "Trade Setup", InpModernUITitle);

    m_canvas.FontSet("Tahoma", InpCanvasMainFontSize);
    string lot_text = "Lot: " + DoubleToString(lot, 2);
    m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(lot_text), current_y - 2, lot_text, InpModernUITextSecondary);
    string spread_text = "Spread: " + DoubleToString(spread, 1);
    m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(spread_text), current_y + 10, spread_text, InpModernUITextSecondary);
    
    current_y += 28;
    m_canvas.FillRectangle(padding, current_y, panel_width - padding, current_y + 1, InpModernUIBorder);
    current_y += 12;

    // --- بخش ۲: اطلاعات معامله (دو ستونی) ---
    int col1_x = padding;
    int col2_x = panel_width / 2 + padding/2;

    // محاسبه مقادیر مورد نیاز
    double rr_ratio = (risk_money > 0 && tp > 0 && sl > 0 && MathAbs(sl - entry) > 0) ? MathAbs(tp - entry) / MathAbs(sl - entry) : 0.0;
    double reward_money = risk_money * rr_ratio;
    
    // ستون اول
    m_canvas.TextOut(col1_x, current_y, "Entry:", InpModernUITextSecondary);
    m_canvas.TextOut(col1_x, current_y + 15, "Stop Loss:", InpModernUITextSecondary);
    m_canvas.TextOut(col1_x, current_y + 30, "Take Profit:", InpModernUITextSecondary);

    string entry_val = (entry > 0) ? DoubleToString(entry, _Digits) : "-";
    m_canvas.TextOut(col2_x - (int)m_canvas.TextWidth(entry_val), current_y, entry_val, InpModernUITextPrimary);
    string sl_val = (sl > 0) ? DoubleToString(sl, _Digits) : "-";
    m_canvas.TextOut(col2_x - (int)m_canvas.TextWidth(sl_val), current_y + 15, sl_val, InpModernUITextPrimary);
    string tp_val = (tp > 0) ? DoubleToString(tp, _Digits) : "-";
    m_canvas.TextOut(col2_x - (int)m_canvas.TextWidth(tp_val), current_y + 30, tp_val, InpModernUITextPrimary);
    
    // ستون دوم
    m_canvas.TextOut(col2_x + 5, current_y, "Risk:", InpModernUITextSecondary);
    m_canvas.TextOut(col2_x + 5, current_y + 15, "Reward:", InpModernUITextSecondary);
    m_canvas.TextOut(col2_x + 5, current_y + 30, "R:R:", InpModernUITextSecondary);
    
    string risk_val = StringFormat("%s%.2f", currency, risk_money);
    m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(risk_val), current_y, risk_val, InpDangerColor);
    string reward_val = StringFormat("%s%.2f", currency, reward_money);
    m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(reward_val), current_y + 15, reward_val, InpProfitLineColor);
    string rr_val = DoubleToString(rr_ratio, 1);
    m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(rr_val), current_y + 30, rr_val, InpModernUITextPrimary);
    
    // --- بخش ۳: قوانین پراپ فرم (در پایین پنل) ---
    current_y = panel_height - 65;
    int bar_height = 4;

    // افت روزانه
    m_canvas.TextOut(padding, current_y, "Daily Room", InpModernUITextSecondary);
    string daily_val = StringFormat("%s %.0f", currency, daily_buffer);

    m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(daily_val), current_y, daily_val, daily_color);
    current_y += 15;
    m_canvas.FillRectangle(padding, current_y, panel_width - padding, current_y + bar_height, InpModernUIProgressBg);
    m_canvas.FillRectangle(padding, current_y, padding + (int)((panel_width - 2*padding) * daily_used_pct / 100.0), current_y + bar_height, daily_color);
    current_y += 18;

    // افت کلی
    color overall_color = (overall_buffer < 0) ? InpDangerColor : InpWarningColor;
    m_canvas.TextOut(padding, current_y, "Max Room", InpModernUITextSecondary);
    string overall_val = StringFormat("%s %.0f", currency, overall_buffer);
    m_canvas.TextOut(panel_width - padding - (int)m_canvas.TextWidth(overall_val), current_y, overall_val, overall_color);
    current_y += 15;
    m_canvas.FillRectangle(padding, current_y, panel_width - padding, current_y + bar_height, InpModernUIProgressBg);
    m_canvas.FillRectangle(padding, current_y, padding + (int)((panel_width - 2*padding) * overall_used_pct / 100.0), current_y + bar_height, overall_color);
    

    if(status_message != "")
    {
        m_canvas.FontSet("Tahoma", InpCanvasMainFontSize, FW_BOLD);
        // محاسبه موقعیت برای نمایش در وسط
        int text_w = (int)m_canvas.TextWidth(status_message);
        m_canvas.TextOut((panel_width - text_w) / 2, 60, status_message, InpWarningColor);
    }


    // آپدیت نهایی بوم
    m_canvas.Update();
    ChartRedraw();
}
#endif // DISPLAYCANVAS_MQH
