//+------------------------------------------------------------------+
//|                                             DisplayCanvas.mqh |
//|        کلاس اختصاصی برای مدیریت پنل نمایشی مبتنی بر Canvas        |
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
    void              Update(double spread, double entry, double sl, double tp, double lot, double risk_money,
                             double daily_buffer, double daily_used_pct, color daily_color,
                             double overall_buffer, double needed_for_target);
};

//--- سازنده
CDisplayCanvas::CDisplayCanvas(void) : m_chart_id(0), m_subwin(0)
{
}

//--- مخرب
CDisplayCanvas::~CDisplayCanvas(void)
{
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

//--- تابع اصلی برای نقاشی تمام اطلاعات روی بوم
void CDisplayCanvas::Update(double spread, double entry, double sl, double tp, double lot, double risk_money,
                              double daily_buffer, double daily_used_pct, color daily_color,
                              double overall_buffer, double needed_for_target)
{
    // پاک کردن کامل بوم قبل از هر نقاشی جدید
    m_canvas.Erase(InpPanelSectionColor);

    string currency = AccountInfoString(ACCOUNT_CURRENCY);

    // --- بخش اطلاعات عمومی ---
    m_canvas.FontSet("Tahoma", 11, FW_BOLD);
    m_canvas.TextOut(10, 5, "Spread: " + DoubleToString(spread, 1), InpTextColor);
    m_canvas.TextOut(120, 5, "Lot: " + DoubleToString(lot, 2), InpTextColor);
    m_canvas.TextOut(10, 25, "Entry: " + (entry > 0 ? DoubleToString(entry, _Digits) : "-"), InpTextColor);
    m_canvas.TextOut(120, 25, "SL: " + (sl > 0 ? DoubleToString(sl, _Digits) : "-"), InpTextColor);
    m_canvas.TextOut(10, 45, "TP: " + (tp > 0 ? DoubleToString(tp, _Digits) : "-"), InpTextColor);
    m_canvas.TextOut(10, 65, StringFormat("Risk: %s %.2f", currency, risk_money), InpTextColor);
    // --- بخش پراپ فرم ---
    m_canvas.FontSet("Tahoma", 12, FW_BOLD);
    m_canvas.TextOut(10, 95, "Prop Firm Compliance", InpOrderButtonColor);

    // --- نوار پیشرفت برای Daily Drawdown ---
    m_canvas.FontSet("Tahoma", 10);
    m_canvas.TextOut(10, 118, "Daily Room:", daily_color);
    m_canvas.TextOut(150, 118, StringFormat("%s %.2f", currency, daily_buffer), daily_color);
    m_canvas.FillRectangle(10, 133, 210, 143, C'55,65,81'); // پس زمینه نوار
    int bar_width = (int)(200 * daily_used_pct / 100.0);
    if(daily_buffer < 0) bar_width = 200;
    m_canvas.FillRectangle(10, 133, 10 + bar_width, 143, daily_color); // بخش پر شده نوار

    // --- اطلاعات متنی دیگر ---
    m_canvas.FontSet("Tahoma", 10);
    m_canvas.TextOut(10, 153, StringFormat("Max Room: %s %.2f", currency, overall_buffer), InpTextColor);
    string target_text = (needed_for_target > 0) ? StringFormat("Target Need: %s %.2f", currency, needed_for_target) : "TARGET REACHED!";
    m_canvas.TextOut(10, 170, target_text, InpProfitLineColor);

    // آپدیت نهایی بوم و بازрисов چارت
    m_canvas.Update();
    ChartRedraw(m_chart_id);
}

#endif // DISPLAYCANVAS_MQH
