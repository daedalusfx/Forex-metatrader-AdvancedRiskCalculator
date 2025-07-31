//+------------------------------------------------------------------+
//|                     SpreadAtrAnalysis.mqh                      |
//|        ماژول تحلیل اسپرد و ATR به عنوان پنل راهنما           |
//+------------------------------------------------------------------+
#ifndef SPREADATRANALYSIS_MQH
#define SPREADATRANALYSIS_MQH

class CSpreadAtrAnalysis
{
private:
    // --- متغیرهای داخلی کلاس ---
    string m_prefix;
    int    m_atr_handle;

    // --- تنظیمات پنل (برای سادگی اینجا تعریف شده‌اند) ---
    ENUM_BASE_CORNER m_panel_corner;
    int    m_x_offset;
    int    m_y_offset;
    string m_font_name;
    int    m_font_size;

    // --- رنگ‌ها ---
    color  m_panel_bg_color;
    color  m_header_bg_color;
    color  m_text_color;
    color  m_good_color;
    color  m_bad_color;

public:
    // --- توابع اصلی ---
    void Initialize(ENUM_BASE_CORNER corner, int x, int y)
    {
        // مقداردهی اولیه تنظیمات پنل
        m_panel_corner = corner;
        m_x_offset = x;
        m_y_offset = y;
        m_font_name = "Tahoma"; // می‌توانید از ورودی‌ها بگیرید
        m_font_size = 8;
        m_panel_bg_color = C'45,50,56';
        m_header_bg_color = C'34,38,41';
        m_text_color = clrWhite;
        m_good_color = C'34,177,76';
        m_bad_color = C'239,68,68';

        // ساخت پیشوند منحصر به فرد
        m_prefix = "SpreadAtrPanel_" + (string)ChartID() + "_";

        // دریافت هندل ATR
        m_atr_handle = iATR(_Symbol, _Period, 14); // دوره 14 به صورت ثابت
        if(m_atr_handle == INVALID_HANDLE)
        {
            Print("Error creating ATR indicator handle for Spread Panel.");
            return;
        }

        DrawPanel();
        Update();
    }

    void Update()
    {
        // --- دریافت اسپرد ---
        double spread_value = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

        // --- دریافت مقدار ATR ---
        double atr_buffer[];
        double atr_value = 0.0;
        if(CopyBuffer(m_atr_handle, 0, 1, 1, atr_buffer) > 0)
        {
            atr_value = atr_buffer[0];
        }

        // --- محاسبه نسبت ---
        double ratio = (atr_value > 0) ? (spread_value / atr_value) * 100.0 : 0.0;

        // --- تعیین وضعیت ---
        string status_text;
        color status_color;
        if(ratio > 15.0) // آستانه 15% به صورت ثابت
        {
            status_text = "High (Risky)";
            status_color = m_bad_color;
        }
        else
        {
            status_text = "Normal";
            status_color = m_good_color;
        }
        if(atr_value <= 0)
        {
           status_text = "Loading...";
           status_color = m_text_color;
        }

        // --- آپدیت لیبل‌ها ---
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        UpdateLabelText("SpreadValue", DoubleToString(spread_value, digits));
        UpdateLabelText("ATRValue", DoubleToString(atr_value, digits));
        UpdateLabelText("RatioValue", StringFormat("%.1f%%", ratio));
        UpdateLabelText("StatusValue", status_text);
        ObjectSetInteger(0, m_prefix + "StatusValue", OBJPROP_COLOR, status_color);
    }

    void Deinitialize()
    {
        ObjectsDeleteAll(0, m_prefix);
        if(m_atr_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_atr_handle);
        }
    }

private:
    // --- توابع کمکی برای ترسیم ---
    void DrawPanel()
    {
        int current_y = 0;
        int PANEL_WIDTH = 180;
        int PANEL_LINE_HEIGHT = 18;
        int PANEL_HEADER_HEIGHT = 25;

        CreateRect("PanelBG", 0, 0, PANEL_WIDTH, 100, m_panel_bg_color);
        CreateRect("HeaderBG", 0, 0, PANEL_WIDTH, PANEL_HEADER_HEIGHT, m_header_bg_color);
        CreateLabel("Title", "Spread vs ATR Analysis", 0, 6, PANEL_WIDTH, ALIGN_CENTER, m_font_size + 1);
        current_y += PANEL_HEADER_HEIGHT + 8;

        CreateLabel("SpreadLabel", "Spread:", 10, current_y);
        CreateLabel("SpreadValue", "...", PANEL_WIDTH - 10, current_y, 0, ALIGN_RIGHT);
        current_y += PANEL_LINE_HEIGHT;

        CreateLabel("ATRLabel", "ATR (14):", 10, current_y);
        CreateLabel("ATRValue", "...", PANEL_WIDTH - 10, current_y, 0, ALIGN_RIGHT);
        current_y += PANEL_LINE_HEIGHT;

        CreateLabel("RatioLabel", "Spread/ATR Ratio:", 10, current_y);
        CreateLabel("RatioValue", "...", PANEL_WIDTH - 10, current_y, 0, ALIGN_RIGHT);
        current_y += PANEL_LINE_HEIGHT;

        CreateLabel("StatusLabel", "Status:", 10, current_y);
        CreateLabel("StatusValue", "...", PANEL_WIDTH - 10, current_y, 0, ALIGN_RIGHT);
    }

    void CreateRect(string name, int x, int y, int w, int h, color c)
    {
        string obj_name = m_prefix + name;
        ObjectCreate(0, obj_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, obj_name, OBJPROP_CORNER, m_panel_corner);
        ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, m_x_offset + x);
        ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, m_y_offset + y);
        ObjectSetInteger(0, obj_name, OBJPROP_XSIZE, w);
        ObjectSetInteger(0, obj_name, OBJPROP_YSIZE, h);
        ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, c);
        ObjectSetInteger(0, obj_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
    }

    void CreateLabel(string name, string text, int x, int y, int width = 0, ENUM_ALIGN_MODE align = ALIGN_LEFT, int f_size = -1)
    {
        string obj_name = m_prefix + name;
        ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, obj_name, OBJPROP_CORNER, m_panel_corner);

        int x_pos = m_x_offset + x;
        if(align == ALIGN_CENTER) x_pos = m_x_offset + x + (width / 2);
        else if(align == ALIGN_RIGHT) x_pos = m_x_offset + x;

        ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x_pos);
        ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, m_y_offset + y);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, m_text_color);
        ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, f_size == -1 ? m_font_size : f_size);
        ObjectSetString(0, obj_name, OBJPROP_FONT, m_font_name);
        ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, align == ALIGN_LEFT ? ANCHOR_LEFT : (align == ALIGN_RIGHT ? ANCHOR_RIGHT : ANCHOR_CENTER));
        ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
    }

    void UpdateLabelText(string name, string text)
    {
        ObjectSetString(0, m_prefix + name, OBJPROP_TEXT, text);
    }
};

#endif // SPREADATRANALYSIS_MQH