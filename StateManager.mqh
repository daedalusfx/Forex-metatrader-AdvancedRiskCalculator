//+------------------------------------------------------------------+
//|                                             StateManager.mqh |
//|        توابع مربوط به ذخیره و بازیابی وضعیت اکسپرت در فایل        |
//+------------------------------------------------------------------+
#ifndef STATEMANAGER_MQH
#define STATEMANAGER_MQH

#define STATE_FILE_NAME "AdvRiskCalc_State.dat"

//+------------------------------------------------------------------+
//|               ذخیره متغیرهای حیاتی در فایل باینری                |
//+------------------------------------------------------------------+
void SaveStateToFile()
{
    // فقط اگر قوانین پراپ فعال باشند، ذخیره می‌کنیم
    if(!InpEnablePropRules) return;

    int file_handle = FileOpen(STATE_FILE_NAME, FILE_WRITE | FILE_BIN);
    if(file_handle == INVALID_HANDLE)
    {
        Print("Error opening state file for writing! Error: ", GetLastError());
        return;
    }

    // ذخیره متغیرهای اصلی
    FileWriteDouble(file_handle, g_initial_balance);
    FileWriteDouble(file_handle, g_peak_equity);
    FileWriteDouble(file_handle, g_start_of_day_base);
    FileWriteLong(file_handle, g_current_trading_day);

    // ذخیره آرایه سودهای روزانه
    int array_size = ArraySize(g_daily_profits);
    FileWriteInteger(file_handle, array_size, INT_VALUE);
    if(array_size > 0)
    {
        FileWriteArray(file_handle, g_daily_profits, 0, array_size);
    }

    FileClose(file_handle);
    // Print("EA state saved successfully."); // For debugging
}

//+------------------------------------------------------------------+
//|              بازیابی متغیرهای حیاتی از فایل باینری               |
//+------------------------------------------------------------------+
bool LoadStateFromFile()
{
    // فقط اگر قوانین پراپ فعال باشند، بازیابی می‌کنیم
    if(!InpEnablePropRules) return false;

    int file_handle = FileOpen(STATE_FILE_NAME, FILE_READ | FILE_BIN);
    if(file_handle == INVALID_HANDLE)
    {
        // فایل وجود ندارد، احتمالاً اولین اجرای اکسپرت است
        return false;
    }

    // بازیابی متغیرهای اصلی
    g_initial_balance = FileReadDouble(file_handle);
    g_peak_equity = FileReadDouble(file_handle);
    g_start_of_day_base = FileReadDouble(file_handle);
    g_current_trading_day = FileReadLong(file_handle);

    // بازیابی آرایه سودهای روزانه
    int array_size = FileReadInteger(file_handle, INT_VALUE);
    ArrayResize(g_daily_profits, array_size);
    if(array_size > 0)
    {
        FileReadArray(file_handle, g_daily_profits, 0, array_size);
    }
    
    FileClose(file_handle);
    Print("EA state loaded successfully from file.");
    return true;
}

#endif // STATEMANAGER_MQH