# Checklist: Adding a new TA indicator

This checklist describes the steps to add a new technical indicator. Replace:
- `{INDICATOR}` = uppercase name (e.g. `WMA`, `RSI`, `ATR`)
- `{indicator}` = lowercase name (e.g. `wma`, `rsi`, `atr`)
- `{Type}` = indicator type capitalized (e.g. `Overlap`, `Oscillators`, `Volatility`, `Volume`, `Other`)
- `{type}` = indicator type lowercase (e.g. `overlap`, `oscillators`, `volatility`, `volume`, `other`)
- `{description}` = short description (e.g. "Weighted Moving Average", "Relative Strength Index")
- `{ta_func}` = TA-Lib function name (e.g. `TA_WMA`, `TA_RSI`)

## Phase 1: Python tests with ta-lib

Test with Python ta-lib to get reference values:
- Normal cases with different periods
- Edge cases (minimum, invalid periods depending on the indicator)
- Empty array
- Insufficient data
- Extended data

**Record all results** for Elixir tests.

Example:
```bash
python -c "import talib; import numpy as np; data = np.array([1.0, 2.0, 3.0, 4.0, 5.0]); print(talib.{ta_func}(data, timeperiod=3))"
```

## Phase 2: Batch tests

- Create `test/theory_craft_ta/{type}/{indicator}_test.exs`
- Follow structure from existing tests (e.g. `test/theory_craft_ta/overlap/wma_test.exs`)
- Update backends to use `TheoryCraftTA.Native.{Type}.{INDICATOR}` and `TheoryCraftTA.Elixir.{Type}.{INDICATOR}`
- Add tests for each Python case (list, DataSeries, TimeSeries)
- Add property-based tests comparing Native vs Elixir

## Phase 3: State tests

- Create `test/theory_craft_ta/{type}/{indicator}_state_test.exs`
- Follow structure from existing tests (e.g. `test/theory_craft_ta/overlap/wma_state_test.exs`)
- Test init (valid/invalid periods)
- Test APPEND mode (warmup, correct calculation)
- Test UPDATE mode (update last value)
- Property tests (APPEND = batch, UPDATE recalculates correctly)

## Phase 4: Elixir batch implementation

- Create `lib/theory_craft_ta/elixir/{type}/{indicator}.ex`
- Define module `TheoryCraftTA.Elixir.{Type}.{INDICATOR}` with @moduledoc
- Add `{indicator}/N` function with @doc and @spec (where N = number of parameters)
- Add private `calculate_{indicator}` function for the algorithm
- Follow existing implementations (e.g. `lib/theory_craft_ta/elixir/overlap/wma.ex`)
- Format: `mix format lib/theory_craft_ta/elixir/{type}/{indicator}.ex`

## Phase 5: Elixir state implementation

- Create `lib/theory_craft_ta/elixir/{type}/{indicator}_state.ex`
- Follow structure from existing state implementations (e.g. `lib/theory_craft_ta/elixir/overlap/wma_state.ex`)
- Define module `TheoryCraftTA.Elixir.{Type}.{INDICATOR}State` with @moduledoc
- Define struct with necessary fields (period, buffer, lookback_count, etc.)
- Implement `init` with parameters specific to the indicator
- Implement `next/3` (state, value, is_new_bar) with APPEND/UPDATE logic
- Format: `mix format lib/theory_craft_ta/elixir/{type}/{indicator}_state.ex`

## Phase 6: Rust NIF batch implementation

- Add FFI in `native/theory_craft_ta/src/{type}_ffi.rs` (create if doesn't exist)
  - Declare {ta_func} function with appropriate ta-lib parameters
  - Declare {ta_func}_Lookback function
- Add `{type}_{indicator}` function in `native/theory_craft_ta/src/{type}.rs` (create if doesn't exist)
  - Include #[cfg(has_talib)] implementation and #[cfg(not(has_talib))] stub
  - Parameters depend on the indicator (data + indicator-specific parameters)
- Follow existing functions in the same category or overlap_sma, overlap_ema, overlap_wma

## Phase 7: Rust NIF state implementation

- Add `{INDICATOR}State` struct in `native/theory_craft_ta/src/{type}_state.rs` (create if doesn't exist)
  - Include fields specific to the indicator (period, buffer, lookback_count, etc.)
- Add `{type}_{indicator}_state_init` (parameters depend on the indicator)
- Add `{type}_{indicator}_state_next` (always: state, value, is_new_bar)
- Include stubs for both functions when ta-lib is not available
- Follow existing State implementations (SMAState, EMAState, WMAState)
- Register ResourceArc in `native/theory_craft_ta/src/lib.rs`: `rustler::resource!({type}_state::{INDICATOR}State, env)`

## Phase 8: Native Elixir wrappers

- Add stubs in `lib/theory_craft_ta/native.ex`:
  - `def {type}_{indicator}(...)` with appropriate parameters, `do: error()`
  - `def {type}_{indicator}_state_init(...)` with appropriate parameters, `do: error()`
  - `def {type}_{indicator}_state_next(_state, _value, _is_new_bar), do: error()`
- Create `lib/theory_craft_ta/native/{type}/{indicator}.ex` (follow existing wrappers like `lib/theory_craft_ta/native/overlap/wma.ex`)
  - Define module `TheoryCraftTA.Native.{Type}.{INDICATOR}` with @moduledoc
  - Add wrapper function that calls `Native.{type}_{indicator}` and uses `Helpers.rebuild_same_type`
- Create `lib/theory_craft_ta/native/{type}/{indicator}_state.ex` (follow existing state wrappers like `lib/theory_craft_ta/native/overlap/wma_state.ex`)
  - Define module `TheoryCraftTA.Native.{Type}.{INDICATOR}State` with @moduledoc
- Format modified files

## Phase 9: Public API

- Edit `lib/theory_craft_ta.ex`
- Add batch functions in appropriate section (e.g. `## {Type} Indicators`):
  - `{indicator}/N` (normal version)
  - `{indicator}!/N` (bang version)
- Add state functions in `## State-based Indicators` section:
  - `{indicator}_state_init` (with parameters specific to the indicator)
  - `{indicator}_state_init!` (bang version)
  - `{indicator}_state_next/3`
  - `{indicator}_state_next!/3`
- Use `Module.concat([@backend, {Type}, {INDICATOR}])` for batch delegation
- Use `Module.concat([@backend, {Type}, {INDICATOR}State])` for state delegation
- Follow existing functions
- Format: `mix format lib/theory_craft_ta.ex`

## Phase 10: Benchmarks

- Create `benchmarks/{indicator}_benchmark.exs` (follow existing benchmarks like `wma_benchmark.exs`)
- Update aliases to use `TheoryCraftTA.Native.{Type}.{INDICATOR}` and `TheoryCraftTA.Elixir.{Type}.{INDICATOR}`
  - Example: `alias TheoryCraftTA.Native.Overlap.WMA, as: NativeWMA`
- Create `benchmarks/{indicator}_state_benchmark.exs` (follow existing state benchmarks like `wma_state_benchmark.exs`)
- Update state aliases to use `TheoryCraftTA.Native.{Type}.{INDICATOR}State` and `TheoryCraftTA.Elixir.{Type}.{INDICATOR}State`
  - Example: `alias TheoryCraftTA.Native.Overlap.WMAState, as: NativeWMA`

## Phase 11: Verification

**IMPORTANT**: Always use forward slashes `/` in paths, NEVER backslashes `\`.

- Compile and test: `.tools/run_ci.cmd` → check 0 warnings, 0 failures
- Run benchmarks:
  - `.tools/run_benchmark.cmd benchmarks/{indicator}_benchmark.exs`
  - `.tools/run_benchmark.cmd benchmarks/{indicator}_state_benchmark.exs`
- Record results (IPS, Native/Elixir comparisons, memory)

## Phase 12: Summary

Create a structured summary with:
- Number of tests passed (doctests + properties + unit tests)
- Implemented files (Elixir batch/state, Rust batch/state, public API)
- Benchmark results (batch and state, with Native/Elixir comparisons)
