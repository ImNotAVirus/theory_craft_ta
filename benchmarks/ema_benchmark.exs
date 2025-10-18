alias TheoryCraft.{DataSeries, TimeSeries}
alias TheoryCraftTA.Native.Overlap.EMA, as: NativeEMA
alias TheoryCraftTA.Elixir.Overlap.EMA, as: ElixirEMA

# Generate test data of various sizes
small_data = Enum.map(1..100, &(&1 * 1.0))
medium_data = Enum.map(1..1_000, &(&1 * 1.0))
large_data = Enum.map(1..10_000, &(&1 * 1.0))

# Create DataSeries variants
small_ds = Enum.reduce(small_data, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

medium_ds =
  Enum.reduce(medium_data, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

large_ds = Enum.reduce(large_data, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

# Create TimeSeries variants
base_time = ~U[2024-01-01 00:00:00.000000Z]

small_ts =
  Enum.with_index(small_data)
  |> Enum.reduce(TimeSeries.new(), fn {val, idx}, acc ->
    TimeSeries.add(acc, DateTime.add(base_time, idx, :second), val)
  end)

medium_ts =
  Enum.with_index(medium_data)
  |> Enum.reduce(TimeSeries.new(), fn {val, idx}, acc ->
    TimeSeries.add(acc, DateTime.add(base_time, idx, :second), val)
  end)

large_ts =
  Enum.with_index(large_data)
  |> Enum.reduce(TimeSeries.new(), fn {val, idx}, acc ->
    TimeSeries.add(acc, DateTime.add(base_time, idx, :second), val)
  end)

IO.puts("\n=== Small Dataset (100 items) ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeEMA.ema(small_data, 10) end,
    "Elixir List" => fn -> ElixirEMA.ema(small_data, 10) end,
    "Native DataSeries" => fn -> NativeEMA.ema(small_ds, 10) end,
    "Elixir DataSeries" => fn -> ElixirEMA.ema(small_ds, 10) end,
    "Native TimeSeries" => fn -> NativeEMA.ema(small_ts, 10) end,
    "Elixir TimeSeries" => fn -> ElixirEMA.ema(small_ts, 10) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== Medium Dataset (1K items) ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeEMA.ema(medium_data, 10) end,
    "Elixir List" => fn -> ElixirEMA.ema(medium_data, 10) end,
    "Native DataSeries" => fn -> NativeEMA.ema(medium_ds, 10) end,
    "Elixir DataSeries" => fn -> ElixirEMA.ema(medium_ds, 10) end,
    "Native TimeSeries" => fn -> NativeEMA.ema(medium_ts, 10) end,
    "Elixir TimeSeries" => fn -> ElixirEMA.ema(medium_ts, 10) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== Large Dataset (10K items) ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeEMA.ema(large_data, 10) end,
    "Elixir List" => fn -> ElixirEMA.ema(large_data, 10) end,
    "Native DataSeries" => fn -> NativeEMA.ema(large_ds, 10) end,
    "Elixir DataSeries" => fn -> ElixirEMA.ema(large_ds, 10) end,
    "Native TimeSeries" => fn -> NativeEMA.ema(large_ts, 10) end,
    "Elixir TimeSeries" => fn -> ElixirEMA.ema(large_ts, 10) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)
