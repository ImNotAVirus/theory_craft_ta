alias TheoryCraftTA.Elixir.Overlap.DEMAState, as: ElixirDEMA
alias TheoryCraftTA.Native.Overlap.DEMAState, as: NativeDEMA

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
      {:ok, dema_value, new_state} = backend.next(state, value, true)
      {new_state, [dema_value | results]}
    end)

  final_state
end

# Prepare states for UPDATE benchmarks
small_native_state = build_state.(NativeDEMA, small_data, period)
small_elixir_state = build_state.(ElixirDEMA, small_data, period)
medium_native_state = build_state.(NativeDEMA, medium_data, period)
medium_elixir_state = build_state.(ElixirDEMA, medium_data, period)
large_native_state = build_state.(NativeDEMA, large_data, period)
large_elixir_state = build_state.(ElixirDEMA, large_data, period)

IO.puts("\n=== DEMA State - APPEND Mode - Small Dataset (100 items) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeDEMA.init(period)

      Enum.reduce(small_data, state, fn value, st ->
        {:ok, _dema, new_state} = NativeDEMA.next(st, value, true)
        new_state
      end)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirDEMA.init(period)

      Enum.reduce(small_data, state, fn value, st ->
        {:ok, _dema, new_state} = ElixirDEMA.next(st, value, true)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== DEMA State - APPEND Mode - Medium Dataset (1K items) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeDEMA.init(period)

      Enum.reduce(medium_data, state, fn value, st ->
        {:ok, _dema, new_state} = NativeDEMA.next(st, value, true)
        new_state
      end)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirDEMA.init(period)

      Enum.reduce(medium_data, state, fn value, st ->
        {:ok, _dema, new_state} = ElixirDEMA.next(st, value, true)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== DEMA State - APPEND Mode - Large Dataset (10K items) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeDEMA.init(period)

      Enum.reduce(large_data, state, fn value, st ->
        {:ok, _dema, new_state} = NativeDEMA.next(st, value, true)
        new_state
      end)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirDEMA.init(period)

      Enum.reduce(large_data, state, fn value, st ->
        {:ok, _dema, new_state} = ElixirDEMA.next(st, value, true)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== DEMA State - UPDATE Mode - Small Dataset (100 updates) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      Enum.reduce(small_data, small_native_state, fn value, st ->
        {:ok, _dema, new_state} = NativeDEMA.next(st, value, false)
        new_state
      end)
    end,
    "Elixir" => fn ->
      Enum.reduce(small_data, small_elixir_state, fn value, st ->
        {:ok, _dema, new_state} = ElixirDEMA.next(st, value, false)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== DEMA State - UPDATE Mode - Medium Dataset (1K updates) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      Enum.reduce(medium_data, medium_native_state, fn value, st ->
        {:ok, _dema, new_state} = NativeDEMA.next(st, value, false)
        new_state
      end)
    end,
    "Elixir" => fn ->
      Enum.reduce(medium_data, medium_elixir_state, fn value, st ->
        {:ok, _dema, new_state} = ElixirDEMA.next(st, value, false)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== DEMA State - UPDATE Mode - Large Dataset (10K updates) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      Enum.reduce(large_data, large_native_state, fn value, st ->
        {:ok, _dema, new_state} = NativeDEMA.next(st, value, false)
        new_state
      end)
    end,
    "Elixir" => fn ->
      Enum.reduce(large_data, large_elixir_state, fn value, st ->
        {:ok, _dema, new_state} = ElixirDEMA.next(st, value, false)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== DEMA State - Single APPEND Operation ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeDEMA.init(period)
      NativeDEMA.next(state, 100.0, true)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirDEMA.init(period)
      ElixirDEMA.next(state, 100.0, true)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== DEMA State - Single UPDATE Operation ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      NativeDEMA.next(small_native_state, 999.0, false)
    end,
    "Elixir" => fn ->
      ElixirDEMA.next(small_elixir_state, 999.0, false)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)
