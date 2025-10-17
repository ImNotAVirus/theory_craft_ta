# Benchmark comparing Native (Rust NIF) vs Pure Elixir state-based WMA implementations
#
# Run with: mix run benchmarks/wma_state_benchmark.exs

alias TheoryCraftTA.Native.OverlapState.WMA, as: NativeWMA
alias TheoryCraftTA.Elixir.OverlapState.WMA, as: ElixirWMA

# Test parameters
num_values = 10_000
period = 14

# Generate test data
test_data = for _ <- 1..num_values, do: :rand.uniform() * 100.0

IO.puts("\n=== WMA State-based Benchmark ===\n")
IO.puts("Comparing Native (Rust NIF) vs Pure Elixir state implementations")
IO.puts("Period: #{period}, Values: #{num_values}\n")

Benchee.run(
  %{
    "Native (Rust) - APPEND" => fn ->
      {:ok, state} = NativeWMA.init(period)

      Enum.reduce(test_data, state, fn value, st ->
        {:ok, _wma, new_st} = NativeWMA.next(st, value, true)
        new_st
      end)
    end,
    "Elixir - APPEND" => fn ->
      {:ok, state} = ElixirWMA.init(period)

      Enum.reduce(test_data, state, fn value, st ->
        {:ok, _wma, new_st} = ElixirWMA.next(st, value, true)
        new_st
      end)
    end,
    "Native (Rust) - UPDATE" => fn ->
      # Build initial state with warmup
      {:ok, state} = NativeWMA.init(period)

      initial_state =
        Enum.reduce(Enum.take(test_data, period), state, fn value, st ->
          {:ok, _wma, new_st} = NativeWMA.next(st, value, true)
          new_st
        end)

      # Now run updates
      Enum.reduce(Enum.drop(test_data, period), initial_state, fn value, st ->
        {:ok, _wma, new_st} = NativeWMA.next(st, value, false)
        new_st
      end)
    end,
    "Elixir - UPDATE" => fn ->
      # Build initial state with warmup
      {:ok, state} = ElixirWMA.init(period)

      initial_state =
        Enum.reduce(Enum.take(test_data, period), state, fn value, st ->
          {:ok, _wma, new_st} = ElixirWMA.next(st, value, true)
          new_st
        end)

      # Now run updates
      Enum.reduce(Enum.drop(test_data, period), initial_state, fn value, st ->
        {:ok, _wma, new_st} = ElixirWMA.next(st, value, false)
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
