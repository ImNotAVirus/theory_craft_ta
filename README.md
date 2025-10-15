# TheoryCraftTA

Technical Analysis library for Elixir, providing 200+ indicators through TA-Lib integration.

## Features

- **Dual Backend System**: Native (Rust/TA-Lib) and Pure Elixir implementations
- **Multiple Input Types**: Works with lists, DataSeries, and TimeSeries
- **Type Preservation**: Returns the same type as input
- **High Performance**: Rust NIF with static TA-Lib linking
- **Zero Dependencies**: TA-Lib built from source, no system installation required

## Installation

Add `theory_craft_ta` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:theory_craft_ta, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# With a list
TheoryCraftTA.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
{:ok, [nil, nil, 2.0, 3.0, 4.0]}

# With DataSeries
alias TheoryCraft.DataSeries

ds = DataSeries.new()
  |> DataSeries.add(1.0)
  |> DataSeries.add(2.0)
  |> DataSeries.add(3.0)

{:ok, result} = TheoryCraftTA.sma(ds, 2)
```

## Backend Configuration

Configure the backend at compile-time in your `config/config.exs`:

```elixir
config :theory_craft_ta,
  default_backend: TheoryCraftTA.Native  # or TheoryCraftTA.Elixir
```

## Available Indicators

### Overlap Studies
- `sma/2` - Simple Moving Average

More indicators coming soon!

## Development

```bash
# Run tests
mix test

# Run benchmarks
mix run benchmarks/sma_benchmark.exs

# Build Rust NIF
mix rust.build

# Build TA-Lib manually
tools/build_talib.cmd  # Windows
tools/build_talib.sh   # Linux/Mac
```

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.
