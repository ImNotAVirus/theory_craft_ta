alias TheoryCraft.DataSeries
alias TheoryCraftTA.Native.Overlap, as: NativeTA
alias TheoryCraftTA.Elixir.Overlap, as: ElixirTA

# Generate test data of various sizes
small_data = Enum.map(1..100, &(&1 * 1.0))
medium_data = Enum.map(1..1_000, &(&1 * 1.0))
large_data = Enum.map(1..10_000, &(&1 * 1.0))

# Create DataSeries variants
small_ds = Enum.reduce(small_data, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

medium_ds =
  Enum.reduce(medium_data, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

large_ds = Enum.reduce(large_data, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

# Prepare data for sma_next benchmarks (append mode)
small_prev_data = Enum.take(small_data, 99)
medium_prev_data = Enum.take(medium_data, 999)
large_prev_data = Enum.take(large_data, 9999)

{:ok, small_prev_native} = NativeTA.sma(small_prev_data, 10)
{:ok, small_prev_elixir} = ElixirTA.sma(small_prev_data, 10)
{:ok, medium_prev_native} = NativeTA.sma(medium_prev_data, 10)
{:ok, medium_prev_elixir} = ElixirTA.sma(medium_prev_data, 10)
{:ok, large_prev_native} = NativeTA.sma(large_prev_data, 10)
{:ok, large_prev_elixir} = ElixirTA.sma(large_prev_data, 10)

# Prepare data for sma_next benchmarks (update mode)
small_updated_data = List.replace_at(small_data, -1, 999.0)
medium_updated_data = List.replace_at(medium_data, -1, 999.0)
large_updated_data = List.replace_at(large_data, -1, 999.0)

{:ok, small_current_native} = NativeTA.sma(small_data, 10)
{:ok, small_current_elixir} = ElixirTA.sma(small_data, 10)
{:ok, medium_current_native} = NativeTA.sma(medium_data, 10)
{:ok, medium_current_elixir} = ElixirTA.sma(medium_data, 10)
{:ok, large_current_native} = NativeTA.sma(large_data, 10)
{:ok, large_current_elixir} = ElixirTA.sma(large_data, 10)

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

IO.puts("\n=== SMA_NEXT - Small Dataset (100 items) - APPEND MODE ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma_next(small_data, 10, small_prev_native) end,
    "Elixir List" => fn -> ElixirTA.sma_next(small_data, 10, small_prev_elixir) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA_NEXT - Medium Dataset (1K items) - APPEND MODE ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma_next(medium_data, 10, medium_prev_native) end,
    "Elixir List" => fn -> ElixirTA.sma_next(medium_data, 10, medium_prev_elixir) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA_NEXT - Large Dataset (10K items) - APPEND MODE ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma_next(large_data, 10, large_prev_native) end,
    "Elixir List" => fn -> ElixirTA.sma_next(large_data, 10, large_prev_elixir) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA_NEXT - Small Dataset (100 items) - UPDATE MODE ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma_next(small_updated_data, 10, small_current_native) end,
    "Elixir List" => fn -> ElixirTA.sma_next(small_updated_data, 10, small_current_elixir) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA_NEXT - Medium Dataset (1K items) - UPDATE MODE ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma_next(medium_updated_data, 10, medium_current_native) end,
    "Elixir List" => fn -> ElixirTA.sma_next(medium_updated_data, 10, medium_current_elixir) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA_NEXT - Large Dataset (10K items) - UPDATE MODE ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma_next(large_updated_data, 10, large_current_native) end,
    "Elixir List" => fn -> ElixirTA.sma_next(large_updated_data, 10, large_current_elixir) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)
