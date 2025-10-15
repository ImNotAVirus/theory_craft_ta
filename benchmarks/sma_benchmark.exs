alias TheoryCraft.DataSeries
alias TheoryCraftTA.Native.Overlap, as: NativeTA
alias TheoryCraftTA.Elixir.Overlap, as: ElixirTA

# Generate test data of various sizes
small_data = Enum.map(1..100, &(&1 * 1.0))
medium_data = Enum.map(1..1_000, &(&1 * 1.0))
large_data = Enum.map(1..10_000, &(&1 * 1.0))

# Create DataSeries variants
small_ds = Enum.reduce(small_data, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)
medium_ds = Enum.reduce(medium_data, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)
large_ds = Enum.reduce(large_data, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

IO.puts("\n=== Small Dataset (100 items) ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma(small_data, 10) end,
    "Elixir List" => fn -> ElixirTA.sma(small_data, 10) end,
    "Native DataSeries" => fn -> NativeTA.sma(small_ds, 10) end,
    "Elixir DataSeries" => fn -> ElixirTA.sma(small_ds, 10) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== Medium Dataset (1K items) ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma(medium_data, 10) end,
    "Elixir List" => fn -> ElixirTA.sma(medium_data, 10) end,
    "Native DataSeries" => fn -> NativeTA.sma(medium_ds, 10) end,
    "Elixir DataSeries" => fn -> ElixirTA.sma(medium_ds, 10) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== Large Dataset (10K items) ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma(large_data, 10) end,
    "Elixir List" => fn -> ElixirTA.sma(large_data, 10) end,
    "Native DataSeries" => fn -> NativeTA.sma(large_ds, 10) end,
    "Elixir DataSeries" => fn -> ElixirTA.sma(large_ds, 10) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)
