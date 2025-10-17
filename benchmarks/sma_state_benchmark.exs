alias TheoryCraftTA.Elixir.State.SMA, as: ElixirSMA
alias TheoryCraftTA.Native.State.SMA, as: NativeSMA

# Generate test data of various sizes
small_data = Enum.map(1..100, &(&1 * 1.0))
medium_data = Enum.map(1..1_000, &(&1 * 1.0))
large_data = Enum.map(1..10_000, &(&1 * 1.0))

period = 10

# Helper function to build state through APPEND operations
build_state = fn backend, data, period ->
  {:ok, initial_state} = backend.init(period)

  {final_state, _results} =
    Enum.reduce(data, {initial_state, []}, fn value, {state, results} ->
      {:ok, sma_value, new_state} = backend.next(state, value, true)
      {new_state, [sma_value | results]}
    end)

  final_state
end

# Prepare states for UPDATE benchmarks
small_native_state = build_state.(NativeSMA, small_data, period)
small_elixir_state = build_state.(ElixirSMA, small_data, period)
medium_native_state = build_state.(NativeSMA, medium_data, period)
medium_elixir_state = build_state.(ElixirSMA, medium_data, period)
large_native_state = build_state.(NativeSMA, large_data, period)
large_elixir_state = build_state.(ElixirSMA, large_data, period)

IO.puts("\n=== SMA State - APPEND Mode - Small Dataset (100 items) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeSMA.init(period)

      Enum.reduce(small_data, state, fn value, st ->
        {:ok, _sma, new_state} = NativeSMA.next(st, value, true)
        new_state
      end)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirSMA.init(period)

      Enum.reduce(small_data, state, fn value, st ->
        {:ok, _sma, new_state} = ElixirSMA.next(st, value, true)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA State - APPEND Mode - Medium Dataset (1K items) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeSMA.init(period)

      Enum.reduce(medium_data, state, fn value, st ->
        {:ok, _sma, new_state} = NativeSMA.next(st, value, true)
        new_state
      end)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirSMA.init(period)

      Enum.reduce(medium_data, state, fn value, st ->
        {:ok, _sma, new_state} = ElixirSMA.next(st, value, true)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA State - APPEND Mode - Large Dataset (10K items) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeSMA.init(period)

      Enum.reduce(large_data, state, fn value, st ->
        {:ok, _sma, new_state} = NativeSMA.next(st, value, true)
        new_state
      end)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirSMA.init(period)

      Enum.reduce(large_data, state, fn value, st ->
        {:ok, _sma, new_state} = ElixirSMA.next(st, value, true)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA State - UPDATE Mode - Small Dataset (100 updates) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      Enum.reduce(small_data, small_native_state, fn value, st ->
        {:ok, _sma, new_state} = NativeSMA.next(st, value, false)
        new_state
      end)
    end,
    "Elixir" => fn ->
      Enum.reduce(small_data, small_elixir_state, fn value, st ->
        {:ok, _sma, new_state} = ElixirSMA.next(st, value, false)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA State - UPDATE Mode - Medium Dataset (1K updates) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      Enum.reduce(medium_data, medium_native_state, fn value, st ->
        {:ok, _sma, new_state} = NativeSMA.next(st, value, false)
        new_state
      end)
    end,
    "Elixir" => fn ->
      Enum.reduce(medium_data, medium_elixir_state, fn value, st ->
        {:ok, _sma, new_state} = ElixirSMA.next(st, value, false)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA State - UPDATE Mode - Large Dataset (10K updates) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      Enum.reduce(large_data, large_native_state, fn value, st ->
        {:ok, _sma, new_state} = NativeSMA.next(st, value, false)
        new_state
      end)
    end,
    "Elixir" => fn ->
      Enum.reduce(large_data, large_elixir_state, fn value, st ->
        {:ok, _sma, new_state} = ElixirSMA.next(st, value, false)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA State - Single APPEND Operation ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeSMA.init(period)
      NativeSMA.next(state, 100.0, true)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirSMA.init(period)
      ElixirSMA.next(state, 100.0, true)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== SMA State - Single UPDATE Operation ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      NativeSMA.next(small_native_state, 999.0, false)
    end,
    "Elixir" => fn ->
      ElixirSMA.next(small_elixir_state, 999.0, false)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)
