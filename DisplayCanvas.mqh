//+------------------------------------------------------------------+
//|                                             DisplayCanvas.mqh |
//|        (نسخه نهایی و اصلاح شده) کلاس مدیریت پنل نمایشی        |
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
    // (اصلاح شده) تابع اصلی آپدیت با تمام پارامترها
    void              Update(double entry, double sl, double tp, double lot, double risk_money,
                             double daily_buffer, double daily_used_pct, color daily_color,
                             double overall_buffer, double overall_used_pct,
                             double needed_for_target, double profit_target_progress_pct);
    // (اصلاح شده) تابع جدید برای آپدیت اسپرد به صورت جداگانه
    void              UpdateSpread(double spread);
};

//--- سازنده
CDisplayCanvas::CDisplayCanvas(void) : m_chart_id(0), m_subwin(0)
{
}

//--- مخرب
CDisplayCanvas::~CDisplayCanvas(void)
{
}

//--- (جدید) تابع اختصاصی برای آپدیت اسپرد
void CDisplayCanvas::UpdateSpread(double spread)
{
    // فقط بخش مربوط به اسپرد را پاک کرده و دوباره می‌نویسیم
    m_canvas.FillRectangle(5, 5, 115, 20, InpSubPanelColor); // از رنگ جدید پنل داخلی استفاده می‌کنیم
    m_canvas.FontSet("Tahoma", InpCanvasMainFontSize, FW_BOLD);
    m_canvas.TextOut(10, 5, "Spread: " + DoubleToString(spread, 1), InpTextColor);
    m_canvas.Update();
}

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

//--- (اصلاح شده) تابع اصلی برای نقاشی تمام اطلاعات روی بوم
void CDisplayCanvas::Update(double entry, double sl, double tp, double lot, double risk_money,
                              double daily_buffer, double daily_used_pct, color daily_color,
                              double overall_buffer, double overall_used_pct,
                              double needed_for_target, double profit_target_progress_pct)
{
    // پاک کردن کامل بوم قبل از هر نقاشی جدید
    m_canvas.Erase(InpPanelSectionColor);

    string currency = AccountInfoString(ACCOUNT_CURRENCY);
    // --- بخش اطلاعات عمومی ---
    m_canvas.FontSet("Tahoma", InpCanvasMainFontSize, FW_BOLD);
    m_canvas.TextOut(120, 5, "Lot: " + DoubleToString(lot, 2), InpTextColor);
    m_canvas.TextOut(10, 25, "Entry: " + (entry > 0 ? DoubleToString(entry, _Digits) : "-"), InpTextColor);
    m_canvas.TextOut(120, 25, "SL: " + (sl > 0 ? DoubleToString(sl, _Digits) : "-"), InpTextColor);
    m_canvas.TextOut(10, 45, "TP: " + (tp > 0 ? DoubleToString(tp, _Digits) : "-"), InpTextColor);
    m_canvas.TextOut(10, 65, StringFormat("Risk: %s %.2f", currency, risk_money), InpTextColor);

    // افزودن خط جداکننده
    m_canvas.FillRectangle(10, 85, 210, 86, C'99,110,114');

    // --- بخش پراپ فرم ---
    m_canvas.FontSet("Tahoma", 12, FW_BOLD); // سایز عنوان بخش
    m_canvas.TextOut(10, 95, "Prop Firm Compliance", InpOrderButtonColor);

    // --- نوار پیشرفت برای Daily Drawdown ---
    m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize);
    m_canvas.TextOut(10, 118, "Daily Room:", daily_color);
    m_canvas.TextOut(150, 118, StringFormat("%s %.2f", currency, daily_buffer), daily_color);
    m_canvas.FillRectangle(10, 133, 210, 143, C'55,65,81'); // پس زمینه نوار
    int daily_bar_width = (int)(200 * daily_used_pct / 100.0);
    if(daily_buffer < 0) daily_bar_width = 200;
    m_canvas.FillRectangle(10, 133, 10 + daily_bar_width, 143, daily_color); // بخش پر شده نوار

    // --- نوار پیشرفت برای Max Drawdown ---
    m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize);
    color overall_color = (overall_buffer < 0) ? InpDangerColor : InpTextColor;
    m_canvas.TextOut(10, 150, "Max Room:", overall_color);
    m_canvas.TextOut(150, 150, StringFormat("%s %.2f", currency, overall_buffer), overall_color);
    m_canvas.FillRectangle(10, 165, 210, 175, C'55,65,81'); // پس زمینه نوار
    int overall_bar_width = (int)(200 * overall_used_pct / 100.0);
    if(overall_buffer < 0) overall_bar_width = 200;
    m_canvas.FillRectangle(10, 165, 10 + overall_bar_width, 175, InpWarningColor); // بخش پر شده نوار

    // --- نوار پیشرفت برای Profit Target ---
    m_canvas.FontSet("Tahoma", InpCanvasSmallFontSize);
    string target_label_text = (needed_for_target > 0) ? "Profit Target:" : "TARGET REACHED!";
    m_canvas.TextOut(10, 182, target_label_text, InpProfitLineColor);
    if(needed_for_target > 0)
    {
       string target_value_text = StringFormat("%s %.2f left", currency, needed_for_target);
       int text_width = m_canvas.TextWidth(target_value_text);
       m_canvas.TextOut(210 - text_width, 182, target_value_text, InpProfitLineColor);
    }
    m_canvas.FillRectangle(10, 197, 210, 207, C'55,65,81'); // پس زمینه نوار
    int profit_bar_width = (int)(200 * profit_target_progress_pct / 100.0);
    m_canvas.FillRectangle(10, 197, 10 + profit_bar_width, 207, InpProfitLineColor); // بخش پر شده نوار

    // آپدیت نهایی بوم و بازрисов چارت
    m_canvas.Update();
    ChartRedraw(m_chart_id);
}

#endif // DISPLAYCANVAS_MQH