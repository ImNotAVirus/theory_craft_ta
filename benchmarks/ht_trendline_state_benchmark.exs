# Benchmark comparing Native (Rust NIF) vs Pure Elixir state-based HT_TRENDLINE implementations
#
# Run with: mix run benchmarks/ht_trendline_state_benchmark.exs

alias TheoryCraftTA.Native.Overlap.HT_TRENDLINEState, as: NativeHT
alias TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState, as: ElixirHT

# Test parameters
num_values = 10_000

# Generate test data
test_data = for _ <- 1..num_values, do: :rand.uniform() * 100.0

IO.puts("\n=== HT_TRENDLINE State-based Benchmark ===\n")
IO.puts("Comparing Native (Rust NIF) vs Pure Elixir state implementations")
IO.puts("Values: #{num_values}\n")

Benchee.run(
  %{
    "Native (Rust) - APPEND" => fn ->
      {:ok, state} = NativeHT.init()

      Enum.reduce(test_data, state, fn value, st ->
        {:ok, _ht, new_st} = NativeHT.next(st, value, true)
        new_st
      end)
    end,
    "Elixir - APPEND" => fn ->
      {:ok, state} = ElixirHT.init()

      Enum.reduce(test_data, state, fn value, st ->
        {:ok, _ht, new_st} = ElixirHT.next(st, value, true)
        new_st
      end)
    end,
    "Native (Rust) - UPDATE" => fn ->
      # Build initial state with warmup (64 bars)
      {:ok, state} = NativeHT.init()

      initial_state =
        Enum.reduce(Enum.take(test_data, 64), state, fn value, st ->
          {:ok, _ht, new_st} = NativeHT.next(st, value, true)
          new_st
        end)

      # Now run updates
      Enum.reduce(Enum.drop(test_data, 64), initial_state, fn value, st ->
        {:ok, _ht, new_st} = NativeHT.next(st, value, false)
        new_st
      end)
    end,
    "Elixir - UPDATE" => fn ->
      # Build initial state with warmup (64 bars)
      {:ok, state} = ElixirHT.init()

      initial_state =
        Enum.reduce(Enum.take(test_data, 64), state, fn value, st ->
          {:ok, _ht, new_st} = ElixirHT.next(st, value, true)
          new_st
        end)

      # Now run updates
      Enum.reduce(Enum.drop(test_data, 64), initial_state, fn value, st ->
        {:ok, _ht, new_st} = ElixirHT.next(st, value, false)
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
