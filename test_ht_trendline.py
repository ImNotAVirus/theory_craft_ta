#!/usr/bin/env python3
"""
Generate reference test data for HT_TRENDLINE using ta-lib.
HT_TRENDLINE requires minimum 63 data points (lookback).
"""

import numpy as np
import talib

# Set random seed for reproducibility
np.random.seed(42)

# Generate test data (100 points, range 50-150)
data = np.random.uniform(50, 150, 100)

print("=== Input Data (first 10) ===")
for i in range(10):
    print(f"data[{i}] = {data[i]:.15f}")

print("\n=== Input Data (last 10) ===")
for i in range(90, 100):
    print(f"data[{i}] = {data[i]:.15f}")

# Calculate HT_TRENDLINE
result = talib.HT_TRENDLINE(data)

print("\n=== HT_TRENDLINE Results ===")
print(f"Total data points: {len(data)}")
# Count actual NaN values
nan_count = np.sum(np.isnan(result))
print(f"Actual NaN count: {nan_count}")

print("\n=== First 70 results (showing NaN period + first valid values) ===")
for i in range(70):
    if np.isnan(result[i]):
        print(f"result[{i}] = NaN")
    else:
        print(f"result[{i}] = {result[i]:.15f}")

print("\n=== Last 10 results ===")
for i in range(90, 100):
    if np.isnan(result[i]):
        print(f"result[{i}] = NaN")
    else:
        print(f"result[{i}] = {result[i]:.15f}")

# Save all data to file for reference
with open('ht_trendline_reference.txt', 'w') as f:
    f.write("=== 100 Point Test Data ===\n")
    f.write("Input:\n")
    for i, val in enumerate(data):
        f.write(f"{i}: {val:.15f}\n")

    f.write("\nOutput:\n")
    for i, val in enumerate(result):
        if np.isnan(val):
            f.write(f"{i}: NaN\n")
        else:
            f.write(f"{i}: {val:.15f}\n")

print("\n\nReference data saved to ht_trendline_reference.txt")
