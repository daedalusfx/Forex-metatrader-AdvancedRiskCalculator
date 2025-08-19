//+------------------------------------------------------------------+
//|                                             StateManager.mqh |
//|        (نسخه ۲.۰) افزودن ذخیره‌سازی وضعیت معاملات پلکانی         |
//+------------------------------------------------------------------+
#ifndef STATEMANAGER_MQH
#define STATEMANAGER_MQH

//+------------------------------------------------------------------+
//|               ذخیره متغیرهای حیاتی در فایل باینری                |
//+------------------------------------------------------------------+
void SaveStateToFile()
{
    // اگر نه قوانین پراپ و نه حالت پلکانی فعال است، نیازی به ذخیره نیست
    if(!InpEnablePropRules && ExtDialog.GetCurrentState() < STATE_PREP_STAIRWAY_BUY) return;
    
    long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
    string file_name = "GriffinGuard_State_" + (string)account_number + "_" + _Symbol + ".dat";
    
    int file_handle = FileOpen(file_name, FILE_WRITE | FILE_BIN);
    if(file_handle == INVALID_HANDLE)
    {
        Print("Error opening state file for writing! Error: ", GetLastError());
        return;
    }

    // --- بخش ۱: ذخیره متغیرهای قوانین پراپ ---
    FileWriteDouble(file_handle, g_initial_balance);
    FileWriteDouble(file_handle, g_peak_equity);
    FileWriteDouble(file_handle, g_start_of_day_base);
    FileWriteLong(file_handle, (long)g_current_trading_day);
    int array_size = ArraySize(g_daily_profits);
    FileWriteInteger(file_handle, array_size, INT_VALUE);
    if(array_size > 0)
    {
        FileWriteArray(file_handle, g_daily_profits, 0, array_size);
    }
    
    // --- (کد جدید) بخش ۲: ذخیره وضعیت معامله پلکانی ---
    ETradeState current_state = ExtDialog.GetCurrentState();
    FileWriteInteger(file_handle, (int)current_state, INT_VALUE); // ذخیره وضعیت فعلی
    FileWriteLong(file_handle, (long)g_stairway_step1_ticket);
    FileWriteLong(file_handle, (long)g_stairway_breakout_candle_time);
    FileWriteDouble(file_handle, g_stairway_total_lot);

    FileClose(file_handle);
}

//+------------------------------------------------------------------+
//|               بازیابی متغیرهای حیاتی از فایل باینری               |
//+------------------------------------------------------------------+
bool LoadStateFromFile()
{
    if(!InpEnablePropRules) return false;

    long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
    string file_name = "GriffinGuard_State_" + (string)account_number + "_" + _Symbol + ".dat";
    
    int file_handle = FileOpen(file_name, FILE_READ | FILE_BIN);
    if(file_handle == INVALID_HANDLE)
    {
        return false; // فایل وجود ندارد، اولین اجراست
    }

    // --- بخش ۱: بازیابی متغیرهای قوانین پراپ ---
    g_initial_balance = FileReadDouble(file_handle);
    g_peak_equity = FileReadDouble(file_handle);
    g_start_of_day_base = FileReadDouble(file_handle);
    g_current_trading_day = FileReadLong(file_handle);
    int array_size = FileReadInteger(file_handle, INT_VALUE);
    ArrayResize(g_daily_profits, array_size);
    if(array_size > 0)
    {
        FileReadArray(file_handle, g_daily_profits, 0, array_size);
    }
    
    // --- (کد جدید) بخش ۲: بازیابی وضعیت معامله پلکانی ---
    // بررسی می‌کنیم آیا به انتهای فایل رسیده‌ایم یا نه (برای سازگاری با فایل‌های قدیمی)
    if(!FileIsEnding(file_handle))
    {
        g_stairway_restored_state = (ETradeState)FileReadInteger(file_handle, INT_VALUE);
        g_stairway_step1_ticket = (ulong)FileReadLong(file_handle);
        g_stairway_breakout_candle_time = FileReadLong(file_handle);
        g_stairway_total_lot = FileReadDouble(file_handle);
    }

    FileClose(file_handle);
    Print("EA state for account ", account_number, " on ", _Symbol, " loaded successfully.");
    return true;
}

#endif // STATEMANAGER_MQH