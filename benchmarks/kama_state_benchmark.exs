# Benchmark comparing Native (Rust NIF) vs Pure Elixir state-based KAMA implementations
#
# Run with: mix run benchmarks/kama_state_benchmark.exs

alias TheoryCraftTA.Native.Overlap.KAMAState, as: NativeKAMA
alias TheoryCraftTA.Elixir.Overlap.KAMAState, as: ElixirKAMA

# Test parameters
num_values = 10_000
period = 30

# Generate test data
test_data = for _ <- 1..num_values, do: :rand.uniform() * 100.0

IO.puts("\n=== KAMA State-based Benchmark ===\n")
IO.puts("Comparing Native (Rust NIF) vs Pure Elixir state implementations")
IO.puts("Period: #{period}, Values: #{num_values}\n")

Benchee.run(
  %{
    "Native (Rust) - APPEND" => fn ->
      {:ok, state} = NativeKAMA.init(period)

      Enum.reduce(test_data, state, fn value, st ->
        {:ok, _kama, new_st} = NativeKAMA.next(st, value, true)
        new_st
      end)
    end,
    "Elixir - APPEND" => fn ->
      {:ok, state} = ElixirKAMA.init(period)

      Enum.reduce(test_data, state, fn value, st ->
        {:ok, _kama, new_st} = ElixirKAMA.next(st, value, true)
        new_st
      end)
    end,
    "Native (Rust) - UPDATE" => fn ->
      # Build initial state with warmup
      {:ok, state} = NativeKAMA.init(period)

      initial_state =
        Enum.reduce(Enum.take(test_data, period), state, fn value, st ->
          {:ok, _kama, new_st} = NativeKAMA.next(st, value, true)
          new_st
        end)

      # Now run updates
      Enum.reduce(Enum.drop(test_data, period), initial_state, fn value, st ->
        {:ok, _kama, new_st} = NativeKAMA.next(st, value, false)
        new_st
      end)
    end,
    "Elixir - UPDATE" => fn ->
      # Build initial state with warmup
      {:ok, state} = ElixirKAMA.init(period)

      initial_state =
        Enum.reduce(Enum.take(test_data, period), state, fn value, st ->
          {:ok, _kama, new_st} = ElixirKAMA.next(st, value, true)
          new_st
        end)

      # Now run updates
      Enum.reduce(Enum.drop(test_data, period), initial_state, fn value, st ->
        {:ok, _kama, new_st} = ElixirKAMA.next(st, value, false)
        new_st
      end)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    {Benchee.Formatters.Console, comparison: true, extended_statistics: true, unit_scaling: :best}
  ]
)

IO.puts("\n=== Done ===\n")
