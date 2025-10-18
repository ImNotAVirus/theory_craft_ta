# Benchmark for HT_TRENDLINE state-based (Native-only)
#
# Run with: mix run benchmarks/ht_trendline_state_benchmark.exs

alias TheoryCraftTA.Native.Overlap.HT_TRENDLINEState, as: NativeHT

# Test parameters
num_values = 10_000

# Generate test data
test_data = for _ <- 1..num_values, do: :rand.uniform() * 100.0

IO.puts("\n=== HT_TRENDLINE State-based Benchmark (Native-only) ===\n")
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
    "Native (Rust) - UPDATE" => fn ->
      {:ok, state} = NativeHT.init()

      initial_state =
        Enum.reduce(Enum.take(test_data, 64), state, fn value, st ->
          {:ok, _ht, new_st} = NativeHT.next(st, value, true)
          new_st
        end)

      Enum.reduce(Enum.drop(test_data, 64), initial_state, fn value, st ->
        {:ok, _ht, new_st} = NativeHT.next(st, value, false)
        new_st
      end)
    end
  },
  time: 2,
  memory_time: 1,
  warmup: 1,
  formatters: [
    {Benchee.Formatters.Console,
     comparison: true, extended_statistics: true, unit_scaling: :best}
  ]
)

IO.puts("\n=== Done ===\n")
