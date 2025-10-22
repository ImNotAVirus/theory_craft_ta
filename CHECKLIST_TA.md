# Checklist: Adding a new TA indicator

This checklist describes the steps to add a new technical indicator using the NIF-only architecture. Replace:
- `{INDICATOR}` = uppercase name (e.g. `SMA`, `RSI`, `ATR`)
- `{indicator}` = lowercase name (e.g. `sma`, `rsi`, `atr`)
- `{Type}` = indicator type capitalized (e.g. `Overlap`, `Oscillators`, `Volatility`, `Volume`, `Other`)
- `{type}` = indicator type lowercase (e.g. `overlap`, `oscillators`, `volatility`, `volume`, `other`)
- `{description}` = short description (e.g. "Simple Moving Average", "Relative Strength Index")
- `{ta_func}` = TA-Lib function name (e.g. `TA_SMA`, `TA_RSI`)

## Phase 1: Python tests with ta-lib

Test with Python ta-lib to get reference values for **unit tests (edge cases)**:
- Normal cases with different periods (e.g., period=3, period=14)
- Edge cases (minimum period, period=1, period=0)
- Empty array
- Insufficient data (data length < period)
- Extended data (large datasets)
- **NaN at beginning** (warmup scenario): `[nan, nan, nan, 4.0, 5.0, 6.0, ...]`
- **NaN in middle** (invalid data scenario): `[1.0, 2.0, 3.0, nan, 5.0, 6.0, ...]`

**Record all results** for Elixir unit tests (edge case verification).

Example:
```bash
python -c "import talib; import numpy as np; data = np.array([1.0, 2.0, 3.0, 4.0, 5.0]); print(talib.{ta_func}(data, timeperiod=3))"
# Output: [nan nan 2. 3. 4.]  → Use as expected result in tests
```

## Phase 2: Tests (TDD - Write tests FIRST!)

- Create `test/theory_craft_ta/{type}/{indicator}_test.exs`
- Structure with comment sections:
  - `## Batch calculation tests` section
  - `## State initialization tests` section (if needed)
  - `## Property-based tests` section
- Include both unit tests and property-based tests:

  **Unit tests (edge cases with ta-lib values)**:
  - Test with valid period (use Python ta-lib values from Phase 1)
  - Test with minimum period
  - Test with insufficient data (should return appropriate values/nils)
  - Test with empty data
  - Test with DataSeries and TimeSeries (verify type preservation)

  **Property-based tests**:
  - Property: APPEND mode matches batch calculation
  - Property: UPDATE mode behaves correctly

- Follow existing test structure (e.g., `test/theory_craft_ta/overlap/sma_test.exs`)
- Format: `mix format test/theory_craft_ta/{type}/{indicator}_test.exs`
- **Note**: Tests will fail until implementation is complete - this is expected in TDD!

## Phase 3: Unified Elixir wrapper

- Create `lib/theory_craft_ta/{type}/{indicator}.ex`
- Define module `TheoryCraftTA.{Type}.{INDICATOR}` with:
  - `@moduledoc` - Description and calculation formula
  - `alias TheoryCraftTA.{Native, Helpers}`
  - `@type t :: reference()` - No @typedoc needed
  - `## Public API` comment section
  - `{indicator}/N` function - Batch calculation with @doc, @spec, examples
  - `init/N` function - Initialize state with @doc, @spec, examples
  - `next/3` function - Streaming calculation with @doc, @spec, examples
- Follow existing wrappers (e.g., `lib/theory_craft_ta/overlap/sma.ex`)
- Format: `mix format lib/theory_craft_ta/{type}/{indicator}.ex`

## Phase 4: Native Elixir stubs

- Add NIF stubs in `lib/theory_craft_ta/native.ex` (under `## NIF stubs` section):
  - Batch function: `def {type}_{indicator}(_data, _period), do: error()`
  - State init: `def {type}_{indicator}_state_init(_period), do: error()`
  - State next: `def {type}_{indicator}_state_next(_state, _value, _is_new_bar), do: error()`
- Note: `error()` is a private function that calls `:erlang.nif_error(:nif_not_loaded)`

## Phase 5: Rust NIF batch implementation

- Add FFI in `native/theory_craft_ta/src/{type}_ffi.rs` (create if doesn't exist)
  - Declare {ta_func} function with appropriate ta-lib parameters
  - Declare {ta_func}_Lookback function
- Add `{type}_{indicator}` function in `native/theory_craft_ta/src/{type}.rs` (create if doesn't exist)
  - Include #[cfg(has_talib)] implementation and #[cfg(not(has_talib))] stub
  - Parameters depend on the indicator (data + indicator-specific parameters)
- Follow existing functions (e.g., overlap_sma, overlap_ema)

## Phase 6: Rust NIF state implementation

- Add `{INDICATOR}State` struct in `native/theory_craft_ta/src/{type}_state.rs` (create if doesn't exist)
  - Include fields specific to the indicator (period, buffer, lookback_count, etc.)
- Add `{type}_{indicator}_state_init` (parameters depend on the indicator)
- Add `{type}_{indicator}_state_next` (always: state, value, is_new_bar)
- Include stubs for both functions when ta-lib is not available
- Follow existing State implementations (SMAState, EMAState, WMAState)
- Register ResourceArc in `native/theory_craft_ta/src/lib.rs`: `rustler::resource!({type}_state::{INDICATOR}State, env)`

## Phase 7: Tests verification

- Run tests: `mix test test/theory_craft_ta/{type}/{indicator}_test.exs`
- **All tests should now pass** (batch tests, state tests, property tests)
- Fix any failing tests by adjusting implementation in Rust NIF
- Verify doctests pass: check examples in `lib/theory_craft_ta/{type}/{indicator}.ex`

## Phase 8: Public API

- Edit `lib/theory_craft_ta.ex`
- Add to **Batch indicators - Delegates** section:
  - `defdelegate {indicator}(data, period), to: TheoryCraftTA.{Type}.{INDICATOR}`
- Add to **State indicators - Delegates** section:
  - `defdelegate {indicator}_state_init(period), to: TheoryCraftTA.{Type}.{INDICATOR}, as: :init`
  - `defdelegate {indicator}_state_next(value, is_new_bar, state), to: TheoryCraftTA.{Type}.{INDICATOR}, as: :next`
- Add to **Batch indicators - Bang functions** section:
  - `{indicator}!/N` with minimal @doc referencing `{indicator}/N`
- Add to **State indicators - Bang functions** section:
  - `{indicator}_state_init!/N` with minimal @doc referencing `{indicator}_state_init/N`
  - `{indicator}_state_next!/3` with minimal @doc referencing `{indicator}_state_next/3`
- Format: `mix format lib/theory_craft_ta.ex`

## Phase 8b: TA macro (syntactic sugar)

- Edit `lib/theory_craft_ta/ta.ex`
- Add macro for the indicator in the appropriate section (e.g., `## Overlap indicators`)
- Signature depends on indicator parameters:
  - Single parameter: `defmacro {indicator}(data_or_accessor, period, opts \\ [])`
  - Multiple parameters (e.g., T3): `defmacro {indicator}(data_or_accessor, period, param2, opts \\ [])`
- Macro should:
  - Parse `data_or_accessor` with `parse_data_accessor/1` to extract data name and optional source
  - Build base options: `[period: period, data: data]` (+ additional params if any)
  - Add source to options only if not nil: `if source, do: base_opts ++ [source: source], else: base_opts`
  - Merge with user opts: `keyword_list = base_opts ++ opts`
  - Return spec: `{TheoryCraftTA.{Type}.{INDICATOR}, unquote(keyword_list)}`
- Add tests in `test/theory_craft_ta/ta_test.exs`:
  - Test with accessor syntax: `TA.{indicator}(eurusd[:close], period, name: "{indicator}14")`
  - Test without accessor: `TA.{indicator}("eurusd", period, name: "{indicator}14")`
  - Test with additional options (e.g., `bar_name`)
- Format: `mix format lib/theory_craft_ta/ta.ex test/theory_craft_ta/ta_test.exs`

## Phase 9: Benchmarks

- Create `benchmarks/{indicator}_benchmark.exs`
- Benchmark batch calculation with different data sizes
- Follow existing benchmarks (e.g., `benchmarks/sma_benchmark.exs`)
- Create `benchmarks/{indicator}_state_benchmark.exs`
- Benchmark state-based calculation (APPEND mode)

## Phase 10: Verification

**IMPORTANT**: Always use forward slashes `/` in paths, NEVER backslashes `\`.

- Compile and test: `.tools/run_ci.cmd` → check 0 warnings, 0 failures
- Run benchmarks:
  - `.tools/run_benchmark.cmd benchmarks/{indicator}_benchmark.exs`
  - `.tools/run_benchmark.cmd benchmarks/{indicator}_state_benchmark.exs`
- Record results (IPS, memory usage)

## Phase 11: Summary

Create a structured summary with:
- Number of tests passed (doctests + properties)
- Implemented files (Rust NIF, Elixir wrapper, tests, public API)
- Benchmark results (batch and state)
