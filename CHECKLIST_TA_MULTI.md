# Checklist: Adding a new TA indicator (Parallel Workflow)

This checklist describes the steps to add a new technical indicator in parallel with other indicators using Git branches. Replace:
- `{INDICATOR}` = uppercase name (e.g. `WMA`, `RSI`, `ATR`)
- `{indicator}` = lowercase name (e.g. `wma`, `rsi`, `atr`)
- `{Type}` = indicator type capitalized (e.g. `Overlap`, `Oscillators`, `Volatility`, `Volume`, `Other`)
- `{type}` = indicator type lowercase (e.g. `overlap`, `oscillators`, `volatility`, `volume`, `other`)
- `{description}` = short description (e.g. "Weighted Moving Average", "Relative Strength Index")
- `{ta_func}` = TA-Lib function name (e.g. `TA_WMA`, `TA_RSI`)

## Phase 0: Git Setup (NEW - for parallel work)

**IMPORTANT**: To enable parallel development of multiple indicators without conflicts:

1. **Clone repository in temporary directory**:
   ```bash
   git clone https://github.com/ImNotAVirus/theory_craft_ta.git .tmp/theory_craft_ta_{indicator}
   cd .tmp/theory_craft_ta_{indicator}
   ```
   - Uses HTTPS for authentication (credentials already configured)
   - Clone in `.tmp/` directory to isolate work

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

**Note**: All subsequent phases (1-12) will be executed in this isolated clone on the `{type}/{indicator}` branch.

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

## Phase 13: Git Commit and Push (NEW - for parallel work)

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

## Phase 14: Create Pull Request (NEW - for parallel work)

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

Example for WMA (Weighted Moving Average):
- WMA = (n×P₁ + (n-1)×P₂ + ... + 1×Pₙ) / (n + (n-1) + ... + 1)
- Where n = period, P₁ = most recent price, Pₙ = oldest price

## Implementation

### Files Added/Modified:
- ✅ Batch calculation (Elixir): `lib/theory_craft_ta/elixir/{type}/{indicator}.ex`
- ✅ Batch calculation (Rust NIF): `native/theory_craft_ta/src/{type}.rs`
- ✅ State-based calculation (Elixir): `lib/theory_craft_ta/elixir/{type}/{indicator}_state.ex`
- ✅ State-based calculation (Rust NIF): `native/theory_craft_ta/src/{type}_state.rs`
- ✅ Native wrappers: `lib/theory_craft_ta/native/{type}/{indicator}.ex`, `lib/theory_craft_ta/native/{type}/{indicator}_state.ex`
- ✅ Public API: `lib/theory_craft_ta.ex`
- ✅ Tests: `test/theory_craft_ta/{type}/{indicator}_test.exs`, `test/theory_craft_ta/{type}/{indicator}_state_test.exs`
- ✅ Benchmarks: `benchmarks/{indicator}_benchmark.exs`, `benchmarks/{indicator}_state_benchmark.exs`

### Test Results:
- **Doctests**: X passed
- **Properties**: Y passed
- **Unit tests**: Z passed
- **Total**: X+Y+Z tests, **0 failures, 0 warnings**

## Benchmark Results

### Batch Calculation

| Implementation | IPS | Relative | Memory |
|----------------|-----|----------|--------|
| Native (Rust)  | {X} K/s | 1.0x | {Y} KB |
| Elixir         | {Z} K/s | {ratio}x slower | {W} KB |

**Data size**: {size} elements

### State-based Calculation (Streaming)

| Implementation | IPS | Relative | Memory |
|----------------|-----|----------|--------|
| Native (Rust)  | {X} K/s | 1.0x | {Y} KB |
| Elixir         | {Z} K/s | {ratio}x slower | {W} KB |

**Data size**: {size} elements, APPEND mode

## Testing

All tests pass with no warnings:
```bash
.tools/run_ci.cmd
# Output: X doctests, Y properties, Z tests, 0 failures
```

## Checklist

- [ ] All tests passing (0 failures, 0 warnings)
- [ ] Benchmarks added and results documented
- [ ] Documentation complete (@moduledoc, @doc, @spec, examples)
- [ ] Both Elixir and Rust implementations
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

## Phase 15: Cleanup (NEW - for parallel work)

After PR is merged or closed:

1. **Return to original working directory**:
   ```bash
   cd D:\Documents\Dev\Elixir\theory_craft_ta
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
