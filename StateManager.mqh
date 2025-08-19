//+------------------------------------------------------------------+
//|                                             StateManager.mqh |
//|        (نسخه ۳.۰) افزودن ذخیره‌سازی قیمت خطوط معاملاتی          |
//+------------------------------------------------------------------+
#ifndef STATEMANAGER_MQH
#define STATEMANAGER_MQH

//+------------------------------------------------------------------+
//|               ذخیره متغیرهای حیاتی در فایل باینری                |
//+------------------------------------------------------------------+
void SaveStateToFile()
{
    if(!InpEnablePropRules && ExtDialog.GetCurrentState() < STATE_PREP_STAIRWAY_BUY) return;
    
    long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
    string file_name = "GriffinGuard_State_" + (string)account_number + "_" + _Symbol + ".dat";
    
    int file_handle = FileOpen(file_name, FILE_WRITE | FILE_BIN);
    if(file_handle == INVALID_HANDLE)
    {
        Print("Error opening state file for writing! Error: ", GetLastError());
        return;
    }

    // --- Section 1: Save Prop Firm Rules Variables ---
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
    
    // --- Section 2: Save Stairway Trade State ---
    ETradeState current_state = ExtDialog.GetCurrentState();
    FileWriteInteger(file_handle, (int)current_state, INT_VALUE);
    FileWriteLong(file_handle, (long)g_stairway_step1_ticket);
    FileWriteLong(file_handle, (long)g_stairway_breakout_candle_time);
    FileWriteDouble(file_handle, g_stairway_total_lot);
    
    // --- Section 3: Save Line Prices ---
    if(current_state >= STATE_PREP_STAIRWAY_BUY)
    {
        FileWriteDouble(file_handle, GetLinePrice(LINE_ENTRY_PRICE));      // Breakout level price
        FileWriteDouble(file_handle, GetLinePrice(LINE_PENDING_ENTRY));    // Pending entry price
        FileWriteDouble(file_handle, GetLinePrice(LINE_STOP_LOSS));
        FileWriteDouble(file_handle, GetLinePrice(LINE_TAKE_PROFIT));
    }

    FileClose(file_handle);
}

//+------------------------------------------------------------------+
//|               Restore vital variables from binary file           |
//+------------------------------------------------------------------+
bool LoadStateFromFile()
{
    if(!InpEnablePropRules) return false;

    long account_number = AccountInfoInteger(ACCOUNT_LOGIN);
    string file_name = "GriffinGuard_State_" + (string)account_number + "_" + _Symbol + ".dat";
    
    int file_handle = FileOpen(file_name, FILE_READ | FILE_BIN);
    if(file_handle == INVALID_HANDLE)
    {
        return false; 
    }

    // --- Section 1: Restore Prop Firm Rules Variables ---
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
    
    // --- Section 2: Restore Stairway Trade State ---
    if(!FileIsEnding(file_handle))
    {
        g_stairway_restored_state = (ETradeState)FileReadInteger(file_handle, INT_VALUE);
        g_stairway_step1_ticket = (ulong)FileReadLong(file_handle);
        g_stairway_breakout_candle_time = FileReadLong(file_handle);
        g_stairway_total_lot = FileReadDouble(file_handle);
        
        // --- Section 3: Restore Line Prices ---
        if(g_stairway_restored_state >= STATE_PREP_STAIRWAY_BUY && !FileIsEnding(file_handle))
        {
            // This is the corrected block
            g_stairway_restored_breakout_price = FileReadDouble(file_handle);
            g_stairway_restored_pending_entry_price = FileReadDouble(file_handle);
            g_stairway_restored_sl_price = FileReadDouble(file_handle);
            g_stairway_restored_tp_price = FileReadDouble(file_handle);
        }
    }

    FileClose(file_handle);
    Print("EA state for account ", account_number, " on ", _Symbol, " loaded successfully.");
    return true;
}

#endif // STATEMANAGER_MQH