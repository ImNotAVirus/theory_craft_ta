# Checklist: Adding a new TA indicator (Parallel Workflow)

This checklist describes the steps to add a new technical indicator in parallel with other indicators using Git branches and the NIF-only architecture. Replace:
- `{INDICATOR}` = uppercase name (e.g. `SMA`, `RSI`, `ATR`)
- `{indicator}` = lowercase name (e.g. `sma`, `rsi`, `atr`)
- `{Type}` = indicator type capitalized (e.g. `Overlap`, `Oscillators`, `Volatility`, `Volume`, `Other`)
- `{type}` = indicator type lowercase (e.g. `overlap`, `oscillators`, `volatility`, `volume`, `other`)
- `{description}` = short description (e.g. "Simple Moving Average", "Relative Strength Index")
- `{ta_func}` = TA-Lib function name (e.g. `TA_SMA`, `TA_RSI`)

## Phase 0: Git Setup (for parallel work)

**CRITICAL RULES** (apply to ALL phases):
- ✅ **ALWAYS** use forward slashes `/` in ALL paths (git, file operations, etc.)
- ✅ **ALWAYS** clone to `.tmp/theory_craft_ta_{indicator}/` (NOT `../.tmp/`)
- ✅ **ALWAYS** use `.tools/run_ci.cmd` for running tests (sets up PATH correctly)

**IMPORTANT**: To enable parallel development of multiple indicators without conflicts:

1. **Clone repository in temporary directory**:
   ```bash
   git clone https://github.com/ImNotAVirus/theory_craft_ta.git .tmp/theory_craft_ta_{indicator}
   cd .tmp/theory_craft_ta_{indicator}
   ```
   - Uses HTTPS for authentication (credentials already configured)
   - Clone in `.tmp/` directory (relative to project root) to isolate work

2. **Checkout base branch and create feature branch**:
   ```bash
   git checkout dev/overlap
   git checkout -b {type}/{indicator}
   ```
   - Base branch: `dev/overlap` (not yet merged to main)
   - Feature branch naming: `{type}/{indicator}` (e.g., `overlap/sma`, `oscillators/rsi`)

3. **Verify clean state**:
   ```bash
   git status
   # Should show: "On branch {type}/{indicator}", "nothing to commit, working tree clean"
   ```

**Note**: All subsequent phases (1-14) will be executed in this isolated clone on the `{type}/{indicator}` branch.

## Phase 1: Python tests with ta-lib

Test with Python ta-lib to get reference values for **unit tests (edge cases)**:
- Normal cases with different periods (e.g., period=3, period=14)
- Edge cases (minimum period, period=1, period=0)
- Empty array
- Insufficient data (data length < period)
- Extended data (large datasets)

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

## Phase 9: Benchmarks

- Create `benchmarks/{indicator}_benchmark.exs`
- Benchmark batch calculation with different data sizes
- Follow existing benchmarks (e.g., `benchmarks/sma_benchmark.exs`)
- Create `benchmarks/{indicator}_state_benchmark.exs`
- Benchmark state-based calculation (APPEND mode)

## Phase 10: Verification

**CRITICAL RULES**:
- ✅ **ALWAYS** use forward slashes `/` in paths, **NEVER** backslashes `\`
- ✅ **ALWAYS** use `.tools/run_ci.cmd` script (sets up PATH, cargo, cmake, etc.)
- ✅ **NEVER** run `mix ci` directly (PATH won't be setup correctly)
- ✅ Work in `.tmp/theory_craft_ta_{indicator}/` (NOT `../.tmp/`)
- ⚠️ If you get "cargo not found" errors, run: `.tools/RefreshEnv.cmd && <your command>`

**Verification Steps**:
- Compile and test: `.tools/run_ci.cmd` → check 0 warnings, 0 failures
  - If errors occur, try: `.tools/RefreshEnv.cmd && .tools/run_ci.cmd`
- Run benchmarks:
  - `.tools/run_benchmark.cmd benchmarks/{indicator}_benchmark.exs`
  - `.tools/run_benchmark.cmd benchmarks/{indicator}_state_benchmark.exs`
- Record results (IPS, memory usage)

## Phase 11: Summary

Create a structured summary with:
- Number of tests passed (doctests + properties)
- Implemented files (Rust NIF, Elixir wrapper, tests, public API)
- Benchmark results (batch and state)

## Phase 12: Git Commit and Push

1. **Stage all changes**:
   ```bash
   git add .
   ```

2. **Create commit** with emoji message:
   ```bash
   git commit -m ":sparkles: Add {INDICATOR} indicator"
   ```
   - Use the `:sparkles:` emoji for new feature commits
   - Keep message concise and clear

3. **Push branch to remote**:
   ```bash
   git push origin {type}/{indicator}
   ```

## Phase 13: Create Pull Request

Create a pull request **in English** with the following template:

**Title**: `Add {INDICATOR} ({description})`

**Body**:
```markdown
## Overview

This PR adds the **{INDICATOR}** ({description}) indicator to TheoryCraftTA.

## What is {INDICATOR}?

{Detailed description of the indicator, its purpose, and common usage in technical analysis}

## Calculation

{Mathematical formula or step-by-step calculation description}

Example for SMA (Simple Moving Average):
- SMA = (P₁ + P₂ + ... + Pₙ) / n
- Where n = period, P₁ = most recent price, Pₙ = oldest price

## Implementation

### Architecture

- **NIF-only**: Uses Rust NIF via TA-Lib (no pure Elixir implementation)
- **Unified module**: Single module for both batch and state-based calculations
- **Property-based tests**: Tests verify batch/state consistency

### Files Added/Modified:
- ✅ Batch calculation (Rust NIF): `native/theory_craft_ta/src/{type}.rs`
- ✅ State-based calculation (Rust NIF): `native/theory_craft_ta/src/{type}_state.rs`
- ✅ Elixir wrapper: `lib/theory_craft_ta/{type}/{indicator}.ex`
- ✅ NIF stubs: `lib/theory_craft_ta/native.ex`
- ✅ Public API: `lib/theory_craft_ta.ex`
- ✅ Tests: `test/theory_craft_ta/{type}/{indicator}_test.exs`
- ✅ Benchmarks: `benchmarks/{indicator}_benchmark.exs`, `benchmarks/{indicator}_state_benchmark.exs`

### Test Results:
- **Doctests**: X passed
- **Properties**: Y passed
- **Total**: X+Y tests, **0 failures, 0 warnings**

## Benchmark Results

### Batch Calculation

| Data size | IPS | Memory |
|-----------|-----|--------|
| {size} elements | {X} K/s | {Y} KB |

### State-based Calculation (Streaming)

| Data size | IPS | Memory |
|-----------|-----|--------|
| {size} elements (APPEND mode) | {X} K/s | {Y} KB |

## Testing

All tests pass with no warnings:
```bash
.tools/run_ci.cmd
# Output: X doctests, Y properties, 0 failures
```

## Checklist

- [ ] All tests passing (0 failures, 0 warnings)
- [ ] Benchmarks added and results documented
- [ ] Documentation complete (@moduledoc, @doc, @spec, examples)
- [ ] Both batch and state-based modes
- [ ] Public API functions added
- [ ] Code formatted with `mix format`
- [ ] Follows project coding guidelines

## Related

- Fixes #{issue_number} (if applicable)
- Part of the Overlap/Oscillators/Volatility/Volume indicators initiative
```

**Reviewers**: Assign appropriate reviewers

**Labels**: Add labels:
- `enhancement`
- `indicator`
- `{type}` (e.g., `overlap`, `oscillators`)
- `needs-review`

## Phase 14: Cleanup

After PR is merged or closed:

1. **Return to original working directory**:
   ```bash
   cd D:/Documents/Dev/Elixir/theory_craft_ta
   ```

2. **Pull latest changes**:
   ```bash
   git checkout dev/overlap
   git pull origin dev/overlap
   ```

3. **Delete temporary clone** (optional):
   ```bash
   rm -fr .tmp/theory_craft_ta_{indicator}
   ```

## Notes for Parallel Development

- **Each indicator gets its own isolated clone** in `.tmp/` directory to avoid conflicts
- **Base branch**: `dev/overlap` (not yet merged to main)
- **Branches are named** `{type}/{indicator}` (e.g., `overlap/sma`, `oscillators/rsi`) for organization by category
- **Commit format**: `:sparkles: Add {INDICATOR} indicator` (using emoji for visual clarity)
- **PRs can be reviewed and merged independently** without blocking other indicators
- **Merge conflicts** are minimized since each indicator works in isolation
- **After merge**, pull latest `dev/overlap` to get all merged indicators before starting next indicator
