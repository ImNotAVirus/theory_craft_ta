# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TheoryCraftTA is an Elixir library that extends TheoryCraft with technical analysis indicators and tools. It is designed to work within the TheoryCraft streaming pipeline architecture, providing processors for calculating technical indicators from market data.

This project is in early development stages. It depends on the parent `theory_craft` project located at `../theorycraft`.

## Common Commands

### Testing
```bash
# Run all tests
mix test

# Run a specific test file
mix test test/theory_craft_ta_test.exs

# Run tests with specific line number
mix test test/theory_craft_ta_test.exs:5
```

### Development
```bash
# Get dependencies
mix deps.get

# Compile the project
mix compile

# Format code
mix format

# Run in interactive shell
iex -S mix

# Start Tidewave MCP server (for Claude Code integration)
mix tidewave
```

### Code Quality
```bash
# Format all Elixir files
mix format

# Format specific file
mix format lib/theory_craft_ta.ex
```

### Benchmarking
```bash
# Run SMA benchmark (compares Native vs Elixir backends)
mix run benchmarks/sma_benchmark.exs

# Create a benchmark file (example structure)
# benchmarks/sma_benchmark.exs
```

### Rust/Native Development
```bash
# Build Rust NIF
mix rust.build

# Clean Rust build artifacts
mix rust.clean

# Run Rust tests
mix rust.test

# Format Rust code
mix rust.fmt

# Run Rust linter
mix rust.clippy

# Build ta-lib from source (Windows)
tools\build_talib.cmd

# Build ta-lib from source (Linux/Mac)
tools/build_talib.sh
```

**Windows Disk Space Issue**: If you encounter "Espace insuffisant sur le disque" errors during Rust compilation, set `TMPDIR` to a drive with more space:
```bash
set TMPDIR=D:\temp
```

## Architecture

### Relationship to TheoryCraft

TheoryCraftTA extends TheoryCraft's streaming pipeline architecture by providing:
- **Technical Analysis Processors**: Implementations of the `TheoryCraft.Processor` behaviour for TA indicators
- **Native Performance**: Uses Rustler for performance-critical indicator calculations (planned)

### Integration with TheoryCraft Pipeline

Technical analysis indicators fit into TheoryCraft's data flow:

**Data Source** → **DataFeed** → **MarketEvent Stream** → **TA Processors** → **Strategy/Output**

Each TA indicator is implemented as a `Processor` that:
1. Receives `MarketEvent` structs containing `Tick` or `Candle` data
2. Calculates indicator values (e.g., SMA, RSI, MACD)
3. Enriches the `MarketEvent` with calculated indicator values
4. Passes the enriched event downstream

### Native Components (Rustler)

TheoryCraftTA uses Rustler NIFs for performance-critical calculations with ta-lib:

**Architecture**:
- **Dual Backend System**: Both Native (Rust NIF) and Pure Elixir implementations
- **Backend Selection**: Configured at compile-time via `config/*.exs`
- **Rust NIF**: Wraps ta-lib C library for high performance
- **Pure Elixir**: Fallback implementation, useful for testing and development

**TA-Lib Integration**:
- ta-lib is built from source (not a system dependency)
- Build script downloads ta-lib 0.6.4 from GitHub
- Uses CMake to configure and build static library
- Conditional compilation: NIF compiles with or without ta-lib
- If ta-lib is missing, Native backend returns error suggesting Elixir backend

**Key Files**:
- `native/theory_craft_ta/src/overlap.rs` - Rust NIF implementations
- `native/theory_craft_ta/build.rs` - Build script for linking ta-lib
- `lib/theory_craft_ta/native/overlap.ex` - Native backend Elixir API
- `lib/theory_craft_ta/elixir/overlap.ex` - Pure Elixir backend
- `lib/theory_craft_ta/helpers.ex` - Type conversion utilities

**Environment Variables**:
- `THEORY_CRAFT_TA_BUILD=1` - Force local Rust compilation
- `TMPDIR` - Set temporary directory for Rust compiler (useful on Windows with low C: drive space)

## Dependencies

### Required
- `theory_craft`: Parent library providing core data structures and streaming architecture (path dependency)
- `rustler_precompiled`: For distributing precompiled native binaries

### Optional
- `rustler`: For compiling native Rust code during development

### Dev Only
- `tidewave`: MCP server for Claude Code integration
- `bandit`: Web server for Tidewave
- `benchee`: Benchmarking library for performance testing

## Coding Guidelines

Follow the same coding guidelines as the parent TheoryCraft project. Key points:

### Module Structure
- Follow consistent module structure: `use` → `require` → `import` → `alias`
- Never use multiline tuples; assign to variables first
- Add blank lines to separate logical blocks

### Documentation
- All public modules must have `@moduledoc`
- All public functions must have `@doc`, `@spec`, and examples
- End documentation examples with a blank line

### DateTime/Struct Handling
- Preserve microsecond precision dynamically (never hardcode `{0, 6}`)
- Use explicit struct types for updates (e.g., `%DateTime{...}` not `%{...}`)
- Pattern match multiple fields in function body, not header (unless needed for guards)

### Testing
- Use `## Setup` and `## Tests` section comments
- Extract large data structures into private helper functions
- Keep calls to module being tested visible in test functions
- Only extract dependency setup into helpers

### Formatting
- Always run `mix format` on modified `.ex` and `.exs` files
- Never run `mix format` on non-Elixir files

## Project Configuration

### Mix Project Settings
- Elixir version: `~> 1.15`
- Version format: `"0.1.0-dev"` (development) or `"0.1.0"` (release)
- Compiler warnings treated as errors (`warnings_as_errors: true`)
- Test support files in `test/support` (added to compile paths in test env)

### Mix Aliases
- `mix tidewave`: Starts the Tidewave MCP server on port 4002
- `mix rust.build`: Build Rust NIF
- `mix rust.clean`: Clean Rust build artifacts
- `mix rust.test`: Run Rust tests
- `mix rust.fmt`: Format Rust code
- `mix rust.clippy`: Run Rust linter

### Backend Configuration

TheoryCraftTA uses a compile-time backend selection system:

**Configuration Files**:
- `config/config.exs` - Base config, defaults to Native backend
- `config/dev.exs` - Development config
- `config/test.exs` - Test config (uses Elixir backend to avoid Rust compilation)
- `config/prod.exs` - Production config

**Example**:
```elixir
# config/test.exs
import Config

config :theory_craft_ta,
  default_backend: TheoryCraftTA.Elixir
```

**Testing**:
- Most tests use the configured backend (Elixir in test env)
- Property-based tests comparing Native vs Elixir are tagged with `:native_backend`
- Run tests excluding native backend: `mix test --exclude native_backend`
- Native backend tests require ta-lib to be built

### Input/Output Types

All indicator functions support three input types:
- `list(float())` - Simple list of floats
- `TheoryCraft.DataSeries.t()` - DataSeries struct
- `TheoryCraft.TimeSeries.t()` - TimeSeries struct (with DateTime keys)

**Important**: DataSeries and TimeSeries store data in **newest-first** order, but ta-lib expects **oldest-first**. TheoryCraftTA handles this automatically:
1. Input is reversed before calculation
2. Result is reconstructed in the original type and order

## Coding Guidelines

### Elixir Best Practices

#### Module Structure and Organization

1. **Follow consistent module structure**
   - Every module must follow this format with proper ordering and spacing
   - Order: `use` → `require` → `import` → `alias`
   - Separate sections with comments and blank lines
   - Example:
     ```elixir
     defmodule KinoTheoryCraft.TheoryCraftCell do
       @moduledoc """
       Smart cell implementation for TheoryCraft integration.

       Provides an interactive UI for configuring and executing
       TheoryCraft data processing tasks in Livebook.
       """

       use Kino.JS, assets_path: "lib/assets/theory_craft_cell", entrypoint: "build/main.js"
       use Kino.JS.Live
       use Kino.SmartCell, name: "TheoryCraft"

       require Logger

       import TheoryCraft.TimeFrame

       alias TheoryCraft.MarketSimulator
       alias TheoryCraft.Processor

       ## Module attributes

       @task_groups [...]

       ## Public API

       @doc """
       Initializes the smart cell state from saved attributes.
       """
       @spec init(map(), Kino.JS.Live.Context.t()) :: {:ok, Kino.JS.Live.Context.t()}
       def init(attrs, ctx) do
         # ...
       end

       ## Internal use ONLY

       @doc false
       @spec field_defaults_for(String.t()) :: map()
       def field_defaults_for(task_id) do
         # ...
       end

       ## Private functions

       defp task_groups(), do: @task_groups

       defp tasks(), do: Enum.flat_map(task_groups(), & &1.tasks)
     end
     ```

2. **Never use multiline tuples**
   - Tuples should always be on a single line
   - For complex return values, assign to a variable first, then return
   - This improves readability and makes the return value explicit
   - Example:
     ```elixir
     # ❌ Bad - multiline tuple
     def handle_connect(ctx) do
       {:ok,
        %{
          fields: ctx.assigns.fields,
          task_groups: task_groups(),
          input_variables: ctx.assigns.input_variables
        }, ctx}
     end

     # ✅ Good - assign to variable first
     def handle_connect(ctx) do
       payload = %{
         fields: ctx.assigns.fields,
         task_groups: task_groups(),
         input_variables: ctx.assigns.input_variables
       }

       {:ok, payload, ctx}
     end
     ```

     ```elixir
     # ❌ Bad - multiline tuple in init
     def init(attrs, ctx) do
       {:ok,
        assign(ctx,
          fields: fields,
          input_variables: [],
          task_groups: task_groups()
        )}
     end

     # ✅ Good - assign to variable first
     def init(attrs, ctx) do
       new_ctx = assign(ctx,
         fields: fields,
         input_variables: [],
         task_groups: task_groups()
       )

       {:ok, new_ctx}
     end
     ```

#### DateTime and Struct Manipulation

1. **Preserve microsecond precision dynamically**
   - Never hardcode microsecond precision (e.g., `{0, 6}`)
   - Always extract and preserve the precision from the input datetime
   - Example:
     ```elixir
     # ❌ Bad - hardcoded precision
     %DateTime{datetime | second: new_second, microsecond: {0, 6}}

     # ✅ Good - preserve input precision
     %DateTime{microsecond: {_value, precision}} = datetime
     %DateTime{datetime | second: new_second, microsecond: {0, precision}}
     ```

2. **Use explicit struct types for updates**
   - Always specify the struct type when updating fields
   - Never use generic map syntax `%{...}` for struct updates
   - Example:
     ```elixir
     # ❌ Bad - generic map update
     %{datetime | hour: new_hour}
     %{date | day: 1}

     # ✅ Good - explicit struct type
     %DateTime{datetime | hour: new_hour}
     %Date{date | day: 1}
     ```

3. **Use pattern matching for multiple field access**
   - When a function uses multiple fields from the same struct, use pattern matching instead of dot access
   - This makes the code more explicit about which fields are being used
   - Example:
     ```elixir
     # ❌ Bad - multiple dot accesses
     defp process_datetime(datetime) do
       year = datetime.year
       month = datetime.month
       day = datetime.day
       # ...
     end

     # ✅ Good - pattern matching in function body
     defp process_datetime(datetime) do
       %DateTime{year: year, month: month, day: day} = datetime
       # ...
     end
     ```

4. **Pattern match only execution flow fields in function headers**
   - In function headers, only pattern match fields needed for execution flow (guards, clause dispatch)
   - Pattern match other fields inside the function body
   - This keeps function signatures focused on what determines execution path
   - Example:
     ```elixir
     # ❌ Bad - pattern matching all fields in header
     def function(%Structure{field1: field1, field2: field2, field3: :toto} = struct)
         when field2 in [1, 2, 3] do
       # field1 is only used in body, not in guard
       # ...
     end

     # ✅ Good - only flow-critical fields in header
     def function(%Structure{field2: field2, field3: :toto} = struct)
         when field2 in [1, 2, 3] do
       # Pattern match other fields in body when needed
       %Structure{field1: field1} = struct
       # ...
     end
     ```

5. **Add blank line before return value in functions with more than 3 lines**
   - If a function has more than 3 lines and returns a value, add a blank line before the return
   - This visually separates the function logic from its result
   - Example:
     ```elixir
     # ❌ Bad - no blank line before return
     defp align_time(datetime, {"M", _mult}, %{market_open: market_open}) do
       %DateTime{microsecond: {_value, precision}, time_zone: time_zone} = datetime
       date = DateTime.to_date(datetime)
       first_of_month = %Date{date | day: 1}
       {:ok, naive} = NaiveDateTime.new(first_of_month, market_open)
       result = DateTime.from_naive!(naive, time_zone)
       %DateTime{result | microsecond: {0, precision}}
     end

     # ✅ Good - blank line before return
     defp align_time(datetime, {"M", _mult}, %{market_open: market_open}) do
       %DateTime{microsecond: {_value, precision}, time_zone: time_zone} = datetime
       date = DateTime.to_date(datetime)
       first_of_month = %Date{date | day: 1}
       {:ok, naive} = NaiveDateTime.new(first_of_month, market_open)
       result = DateTime.from_naive!(naive, time_zone)

       %DateTime{result | microsecond: {0, precision}}
     end
     ```

6. **Separate logical blocks with blank lines**
   - Avoid large blocks of code without visual separation
   - Group related operations and separate them with blank lines
   - Typical grouping: variable extraction → computation → result
   - Example:
     ```elixir
     # ❌ Bad - no logical separation
     defp add_timeframe(datetime, {"M", mult}) do
       %DateTime{year: year, month: month, day: day, hour: hour, minute: minute, second: second, microsecond: microsecond, time_zone: time_zone} = datetime
       new_month = month + mult
       {new_year, final_month} = if new_month > 12 do
         years_to_add = div(new_month - 1, 12)
         {year + years_to_add, rem(new_month - 1, 12) + 1}
       else
         {year, new_month}
       end
       days_in_new_month = Date.days_in_month(Date.new!(new_year, final_month, 1))
       final_day = min(day, days_in_new_month)
       new_date = Date.new!(new_year, final_month, final_day)
       {:ok, time} = Time.new(hour, minute, second, microsecond)
       {:ok, naive} = NaiveDateTime.new(new_date, time)
       DateTime.from_naive!(naive, time_zone)
     end

     # ✅ Good - logical blocks separated
     defp add_timeframe(datetime, {"M", mult}) do
       # Extract fields from datetime
       %DateTime{
         year: year,
         month: month,
         day: day,
         hour: hour,
         minute: minute,
         second: second,
         microsecond: microsecond,
         time_zone: time_zone
       } = datetime

       # Calculate new month and year
       new_month = month + mult

       {new_year, final_month} =
         if new_month > 12 do
           years_to_add = div(new_month - 1, 12)
           {year + years_to_add, rem(new_month - 1, 12) + 1}
         else
           {year, new_month}
         end

       # Adjust day for month overflow
       days_in_new_month = Date.days_in_month(Date.new!(new_year, final_month, 1))
       final_day = min(day, days_in_new_month)

       # Build new datetime
       new_date = Date.new!(new_year, final_month, final_day)
       {:ok, time} = Time.new(hour, minute, second, microsecond)
       {:ok, naive} = NaiveDateTime.new(new_date, time)

       DateTime.from_naive!(naive, time_zone)
     end
     ```

7. **Only add comments for complex or non-obvious logic**
   - Do not add comments to describe what the code does if it's already clear from the code itself
   - Blank lines are sufficient to separate logical blocks
   - Add comments only when the logic is particularly complex or non-intuitive
   - Example:
     ```elixir
     # ❌ Bad - unnecessary comments
     defp add_timeframe(datetime, {"D", mult}) do
       # Extract fields from datetime
       %DateTime{...} = datetime

       # Add days to date
       date = Date.new!(year, month, day)
       new_date = Date.add(date, mult)

       # Build new datetime
       {:ok, time} = Time.new(hour, minute, second, microsecond)
       ...
     end

     # ✅ Good - no comments needed, code is self-explanatory
     defp add_timeframe(datetime, {"D", mult}) do
       %DateTime{...} = datetime

       date = Date.new!(year, month, day)
       new_date = Date.add(date, mult)

       {:ok, time} = Time.new(hour, minute, second, microsecond)
       ...
     end

     # ✅ Good - comment explains non-obvious logic
     defp add_timeframe(datetime, {"M", mult}) do
       %DateTime{...} = datetime

       # Calculate new month handling year overflow
       # If new_month > 12, we need to increment year and wrap month
       new_month = month + mult
       {new_year, final_month} =
         if new_month > 12 do
           years_to_add = div(new_month - 1, 12)
           {year + years_to_add, rem(new_month - 1, 12) + 1}
         else
           {year, new_month}
         end
       ...
     end
     ```

8. **Document all public modules and functions**
   - Every public module MUST have a `@moduledoc` with a clear description
   - Every public function MUST have explicit documentation including:
     - `@doc` description of what the function does
     - `@spec` type specification with arguments and return types
     - Examples of usage (using `## Examples` section with doctest format)
   - Private modules should have `@moduledoc false` followed by comments explaining the module's purpose
   - Example:
     ```elixir
     # ❌ Bad - public module without documentation
     defmodule TheoryCraft.TimeFrame do
       def parse(timeframe) do
         # ...
       end
     end

     # ✅ Good - public module with full documentation
     defmodule TheoryCraft.TimeFrame do
       @moduledoc """
       Helpers for working with time frames.

       Provides functions to parse and validate timeframe strings like "m5" (5 minutes),
       "h1" (1 hour), or "D" (daily).
       """

       @type unit :: String.t()
       @type multiplier :: non_neg_integer()
       @type t :: {unit(), multiplier()}

       @doc """
       Parses a timeframe string into a tuple.

       ## Parameters
         - `timeframe` - A string representing a timeframe (e.g., "m5", "h1", "D")

       ## Returns
         - `{:ok, {unit, multiplier}}` on success
         - `:error` if the timeframe is invalid

       ## Examples
           iex> TheoryCraft.TimeFrame.parse("m5")
           {:ok, {"m", 5}}

           iex> TheoryCraft.TimeFrame.parse("h1")
           {:ok, {"h", 1}}

           iex> TheoryCraft.TimeFrame.parse("invalid")
           :error
       """
       @spec parse(String.t()) :: {:ok, t()} | :error
       def parse(timeframe) do
         # ...
       end
     end

     # ✅ Good - private module with @moduledoc false and comments
     defmodule TheoryCraft.Internal.Helper do
       @moduledoc false

       # This module provides internal helper functions for date manipulation.
       # It should not be used outside of TheoryCraft.TimeFrame.
       #
       # Functions in this module assume valid input and may raise on invalid data.

       def internal_helper(value) do
         # ...
       end
     end
     ```

9. **End documentation examples with a blank line**
   - When `@doc` or `@moduledoc` blocks end with examples (code snippets or `iex>` blocks), always add a blank line before the closing `"""`
   - This improves visual separation and readability
   - Example:
     ```elixir
     # ❌ Bad - no blank line before closing
     @doc """
     Processes a market event.

     ## Examples

         iex> process(event)
         {:ok, result}
     """

     # ✅ Good - blank line before closing
     @doc """
     Processes a market event.

     ## Examples

         iex> process(event)
         {:ok, result}

     """
     ```

     ```elixir
     # Note: if examples are NOT at the end, no blank line is needed
     @doc """
     Processes a market event.

     ## Examples

         iex> process(event)
         {:ok, result}

     ## Additional Notes

     This function handles errors gracefully.
     """
     ```

### Test Organization and Readability

1. **Follow consistent test module structure**
   - Test modules must follow a consistent structure with section comments
   - Use `## Setup` for the setup/setup_all section
   - Use `## Tests` for the test section
   - Example:
     ```elixir
     defmodule TheoryCraft.SomeModuleTest do
       use ExUnit.Case, async: true

       alias TheoryCraft.SomeModule

       ## Setup

       setup do
         # Setup code
         {:ok, some_data: data}
       end

       ## Tests

       describe "some functionality" do
         test "does something", %{some_data: data} do
           # Test code
         end
       end

       ## Private helper functions

       defp build_test_data do
         # Helper code
       end
     end
     ```

2. **Extract large data structures into private helper functions**
   - Tests must be clear and readable
   - Large lists, complex structs, or repeated test data should be extracted into private helper functions
   - This keeps the test body focused on the actual test logic
   - Example:
     ```elixir
     # ❌ Bad - large list clutters the setup
     setup do
       ticks = [
         %Tick{
           time: ~U[2024-01-01 00:00:00.000000Z],
           ask: 2500.0,
           bid: 2499.0,
           ask_volume: 100.0,
           bid_volume: 150.0
         },
         %Tick{
           time: ~U[2024-01-01 00:01:00.000000Z],
           ask: 2501.0,
           bid: 2500.0,
           ask_volume: 100.0,
           bid_volume: 150.0
         },
         # ... 20 more ticks ...
       ]

       {:ok, ticks: ticks}
     end

     # ✅ Good - extracted to private helper function
     setup do
       ticks = build_test_ticks()
       {:ok, ticks: ticks}
     end

     # Private helper functions

     defp build_test_ticks do
       [
         %Tick{
           time: ~U[2024-01-01 00:00:00.000000Z],
           ask: 2500.0,
           bid: 2499.0,
           ask_volume: 100.0,
           bid_volume: 150.0
         },
         %Tick{
           time: ~U[2024-01-01 00:01:00.000000Z],
           ask: 2501.0,
           bid: 2500.0,
           ask_volume: 100.0,
           bid_volume: 150.0
         },
         # ... 20 more ticks ...
       ]
     end
     ```

   - This also allows reusing the same data in multiple test files
   - For very common test data, consider creating a test support module (e.g., `test/support/fixtures.ex`)

3. **Refactor repeated code into private helper functions**
   - Tests must be clear and concise
   - When the same code pattern is repeated multiple times in tests, extract it into a private helper function
   - **IMPORTANT**: NEVER refactor calls to the module being tested - always keep these in the test functions themselves
   - Only refactor calls to other modules (dependencies, setup code, etc.)
   - This makes tests easier to read and maintain while keeping the tested functionality visible
   - Example:
     ```elixir
     # In ProcessorStageTest - testing ProcessorStage module

     # ❌ Bad - refactoring calls to the module being tested
     test "test 1" do
       processor = start_processor_stage(opts)  # ❌ Don't extract ProcessorStage calls
       # ...
     end

     # ✅ Good - keep calls to module being tested in the test
     test "test 1" do
       producer = start_producer(tick_feed)  # ✅ Helper for DataFeedStage (dependency)

       {:ok, processor} =
         ProcessorStage.start_link(  # ✅ Direct call to module being tested
           {TickToCandleProcessor, [data: "xauusd", timeframe: "m5", name: "xauusd"]},
           subscribe_to: [producer]
         )
       # ...
     end

     ## Private functions

     # ✅ Good - helper for dependency module
     defp start_producer(feed, name \\ "xauusd") do
       {:ok, producer} = DataFeedStage.start_link({MemoryDataFeed, [from: feed]}, name: name)
       producer
     end
     ```

     ```elixir
     # In DataFeedStageTest - testing DataFeedStage module

     # ❌ Bad - refactoring calls to the module being tested
     defp start_data_feed_stage(feed) do
       {:ok, stage} = DataFeedStage.start_link({MemoryDataFeed, [from: feed]}, name: "xauusd")
       stage
     end

     # ✅ Good - keep DataFeedStage calls directly in tests
     test "test 1" do
       {:ok, stage} = DataFeedStage.start_link({MemoryDataFeed, [from: feed]}, name: "xauusd")
       # ...
     end
     ```

### Code Formatting

**Always run `mix format` on modified Elixir files when finished**
- After completing all modifications, always format the changed `.ex` and `.exs` files
- `mix format` only works on Elixir source files (`.ex` and `.exs`)
- Do NOT run `mix format` on other files like `.md`, `.txt`, etc.
- This ensures consistent code style across the project
- Example workflow:
  ```bash
  # After modifying Elixir files
  mix format lib/theory_craft/processors/tick_to_candle_processor.ex
  mix format test/theory_craft/processors/tick_to_candle_processor_test.exs

  # Or format all Elixir files in the project
  mix format
  ```
