#!/usr/bin/env python3
"""
SAR (Parabolic SAR) reference values from Python ta-lib.

SAR requires high and low prices plus two optional parameters:
- acceleration: Acceleration Factor (default 0.02)
- maximum: Maximum Acceleration Factor (default 0.20)
"""

import talib
import numpy as np

print("=" * 80)
print("SAR (Parabolic SAR) - Python ta-lib Reference Values")
print("=" * 80)

# Test 1: Simple uptrend with defaults
print("\n### Test 1: Simple uptrend (defaults: acceleration=0.02, maximum=0.20)")
high = np.array([10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0], dtype=float)
low = np.array([8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0], dtype=float)
sar_default = talib.SAR(high, low)
print(f"High: {high.tolist()}")
print(f"Low:  {low.tolist()}")
print(f"SAR:  {sar_default.tolist()}")

# Test 2: Simple downtrend with defaults
print("\n### Test 2: Simple downtrend (defaults)")
high = np.array([19.0, 18.0, 17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0], dtype=float)
low = np.array([17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0], dtype=float)
sar_default = talib.SAR(high, low)
print(f"High: {high.tolist()}")
print(f"Low:  {low.tolist()}")
print(f"SAR:  {sar_default.tolist()}")

# Test 3: Custom acceleration and maximum
print("\n### Test 3: Custom acceleration=0.03, maximum=0.25")
high = np.array([10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0], dtype=float)
low = np.array([8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0], dtype=float)
sar_custom = talib.SAR(high, low, acceleration=0.03, maximum=0.25)
print(f"High: {high.tolist()}")
print(f"Low:  {low.tolist()}")
print(f"SAR:  {sar_custom.tolist()}")

# Test 4: Edge case - minimum data (1 bar)
print("\n### Test 4: Edge case - 1 bar")
high = np.array([10.0], dtype=float)
low = np.array([8.0], dtype=float)
sar_min = talib.SAR(high, low)
print(f"High: {high.tolist()}")
print(f"Low:  {low.tolist()}")
print(f"SAR:  {sar_min.tolist()}")

# Test 5: Edge case - 2 bars
print("\n### Test 5: Edge case - 2 bars")
high = np.array([10.0, 11.0], dtype=float)
low = np.array([8.0, 9.0], dtype=float)
sar_2bars = talib.SAR(high, low)
print(f"High: {high.tolist()}")
print(f"Low:  {low.tolist()}")
print(f"SAR:  {sar_2bars.tolist()}")

# Test 6: Edge case - empty array
print("\n### Test 6: Edge case - empty array")
high = np.array([], dtype=float)
low = np.array([], dtype=float)
try:
    sar_empty = talib.SAR(high, low)
    print(f"SAR:  {sar_empty.tolist()}")
except Exception as e:
    print(f"Error: {e}")

# Test 7: Trend reversal
print("\n### Test 7: Trend reversal (uptrend then downtrend)")
high = np.array([10.0, 11.0, 12.0, 13.0, 14.0, 13.5, 12.5, 11.5, 10.5, 9.5], dtype=float)
low = np.array([8.0, 9.0, 10.0, 11.0, 12.0, 11.5, 10.5, 9.5, 8.5, 7.5], dtype=float)
sar_reversal = talib.SAR(high, low)
print(f"High: {high.tolist()}")
print(f"Low:  {low.tolist()}")
print(f"SAR:  {sar_reversal.tolist()}")

# Test 8: Real-world example with more data
print("\n### Test 8: Extended data (20 bars)")
high = np.array([
    10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0,
    18.5, 17.5, 16.5, 15.5, 14.5, 13.5, 12.5, 11.5, 10.5, 9.5
], dtype=float)
low = np.array([
    8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0,
    16.5, 15.5, 14.5, 13.5, 12.5, 11.5, 10.5, 9.5, 8.5, 7.5
], dtype=float)
sar_extended = talib.SAR(high, low)
print(f"High: {high.tolist()}")
print(f"Low:  {low.tolist()}")
print(f"SAR:  {sar_extended.tolist()}")

# Test 9: Invalid parameters - acceleration > maximum
print("\n### Test 9: Invalid parameters - acceleration > maximum")
high = np.array([10.0, 11.0, 12.0], dtype=float)
low = np.array([8.0, 9.0, 10.0], dtype=float)
try:
    sar_invalid = talib.SAR(high, low, acceleration=0.25, maximum=0.20)
    print(f"SAR:  {sar_invalid.tolist()}")
    print(f"Note: ta-lib allows acceleration > maximum")
except Exception as e:
    print(f"Error: {e}")

print("\n" + "=" * 80)
print("Reference values generation complete!")
print("=" * 80)
