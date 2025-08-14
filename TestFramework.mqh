// ==================================================================
// | फाइल: TestFramework.mqh                                        |
// | विवरण: एक सरल परीक्षण ढाँचा Assertions र रिपोर्टिङको लागि        |
// ==================================================================
#ifndef TESTFRAMEWORK_MQH
#define TESTFRAMEWORK_MQH

// --- متغيرहरू परीक्षण परिणामहरू ट्र्याक गर्नका लागि ---
int g_tests_passed = 0;
int g_tests_failed = 0;

// --- Assertion प्रकार्यहरू ---

void AssertTrue(bool condition, string message)
{
    if (condition)
    {
        Print("  ✅ PASS: ", message);
        g_tests_passed++;
    }
    else
    {
        Print("  ❌ FAIL: ", message);
        g_tests_failed++;
    }
}

void AssertFalse(bool condition, string message)
{
    AssertTrue(!condition, message);
}

void AssertEquals(double expected, double actual, string message, double tolerance = 0.0001)
{
    if (MathAbs(expected - actual) <= tolerance)
    {
        Print("  ✅ PASS: ", message);
        g_tests_passed++;
    }
    else
    {
        Print("  ❌ FAIL: ", message, " | Expected: ", DoubleToString(expected), ", Got: ", DoubleToString(actual));
        g_tests_failed++;
    }
}

void AssertEquals(long expected, long actual, string message)
{
    if (expected == actual)
    {
        Print("  ✅ PASS: ", message);
        g_tests_passed++;
    }
    else
    {
        Print("  ❌ FAIL: ", message, " | Expected: ", (string)expected, ", Got: ", (string)actual);
        g_tests_failed++;
    }
}

// --- परीक्षण रिपोर्टिङ प्रकार्य ---

void PrintTestSummary()
{
    Print("\n-----------------------------------");
    Print("           TEST SUMMARY            ");
    Print("-----------------------------------");
    Print("  TOTAL TESTS: ", g_tests_passed + g_tests_failed);
    Print("  PASSED: ", g_tests_passed);
    Print("  FAILED: ", g_tests_failed);
    Print("-----------------------------------\n");

    if (g_tests_failed > 0)
    {
        Alert("TESTS FAILED: ", g_tests_failed, " out of ", g_tests_passed + g_tests_failed, " tests failed. Check the journal.");
    }
    else
    {
        Alert("ALL TESTS PASSED SUCCESSFULLY!");
    }
}

#endif // TESTFRAMEWORK_MQH