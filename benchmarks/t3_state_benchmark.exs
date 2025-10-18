alias TheoryCraftTA.Elixir.Overlap.T3State, as: ElixirT3
alias TheoryCraftTA.Native.Overlap.T3State, as: NativeT3

# Generate test data of various sizes
small_data = Enum.map(1..100, &(&1 * 1.0))
medium_data = Enum.map(1..1_000, &(&1 * 1.0))
large_data = Enum.map(1..10_000, &(&1 * 1.0))

period = 10
vfactor = 0.7

# Helper function to build state through APPEND operations
build_state = fn backend, data, period, vfactor ->
  {:ok, initial_state} = backend.init(period, vfactor)

  {final_state, _results} =
    Enum.reduce(data, {initial_state, []}, fn value, {state, results} ->
      {:ok, t3_value, new_state} = backend.next(state, value, true)
      {new_state, [t3_value | results]}
    end)

  final_state
end

# Prepare states for UPDATE benchmarks
small_native_state = build_state.(NativeT3, small_data, period, vfactor)
small_elixir_state = build_state.(ElixirT3, small_data, period, vfactor)
medium_native_state = build_state.(NativeT3, medium_data, period, vfactor)
medium_elixir_state = build_state.(ElixirT3, medium_data, period, vfactor)
large_native_state = build_state.(NativeT3, large_data, period, vfactor)
large_elixir_state = build_state.(ElixirT3, large_data, period, vfactor)

IO.puts("\n=== T3 State - APPEND Mode - Small Dataset (100 items) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeT3.init(period, vfactor)

      Enum.reduce(small_data, state, fn value, st ->
        {:ok, _t3, new_state} = NativeT3.next(st, value, true)
        new_state
      end)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirT3.init(period, vfactor)

      Enum.reduce(small_data, state, fn value, st ->
        {:ok, _t3, new_state} = ElixirT3.next(st, value, true)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== T3 State - APPEND Mode - Medium Dataset (1K items) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeT3.init(period, vfactor)

      Enum.reduce(medium_data, state, fn value, st ->
        {:ok, _t3, new_state} = NativeT3.next(st, value, true)
        new_state
      end)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirT3.init(period, vfactor)

      Enum.reduce(medium_data, state, fn value, st ->
        {:ok, _t3, new_state} = ElixirT3.next(st, value, true)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== T3 State - APPEND Mode - Large Dataset (10K items) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeT3.init(period, vfactor)

      Enum.reduce(large_data, state, fn value, st ->
        {:ok, _t3, new_state} = NativeT3.next(st, value, true)
        new_state
      end)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirT3.init(period, vfactor)

      Enum.reduce(large_data, state, fn value, st ->
        {:ok, _t3, new_state} = ElixirT3.next(st, value, true)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== T3 State - UPDATE Mode - Small Dataset (100 updates) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      Enum.reduce(small_data, small_native_state, fn value, st ->
        {:ok, _t3, new_state} = NativeT3.next(st, value, false)
        new_state
      end)
    end,
    "Elixir" => fn ->
      Enum.reduce(small_data, small_elixir_state, fn value, st ->
        {:ok, _t3, new_state} = ElixirT3.next(st, value, false)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== T3 State - UPDATE Mode - Medium Dataset (1K updates) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      Enum.reduce(medium_data, medium_native_state, fn value, st ->
        {:ok, _t3, new_state} = NativeT3.next(st, value, false)
        new_state
      end)
    end,
    "Elixir" => fn ->
      Enum.reduce(medium_data, medium_elixir_state, fn value, st ->
        {:ok, _t3, new_state} = ElixirT3.next(st, value, false)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== T3 State - UPDATE Mode - Large Dataset (10K updates) ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      Enum.reduce(large_data, large_native_state, fn value, st ->
        {:ok, _t3, new_state} = NativeT3.next(st, value, false)
        new_state
      end)
    end,
    "Elixir" => fn ->
      Enum.reduce(large_data, large_elixir_state, fn value, st ->
        {:ok, _t3, new_state} = ElixirT3.next(st, value, false)
        new_state
      end)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== T3 State - Single APPEND Operation ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      {:ok, state} = NativeT3.init(period, vfactor)
      NativeT3.next(state, 100.0, true)
    end,
    "Elixir" => fn ->
      {:ok, state} = ElixirT3.init(period, vfactor)
      ElixirT3.next(state, 100.0, true)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

IO.puts("\n=== T3 State - Single UPDATE Operation ===\n")

Benchee.run(
  %{
    "Native" => fn ->
      NativeT3.next(small_native_state, 999.0, false)
    end,
    "Elixir" => fn ->
      ElixirT3.next(small_elixir_state, 999.0, false)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)
