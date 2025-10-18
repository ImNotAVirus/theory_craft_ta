# Benchmark comparing Native (Rust NIF) vs Pure Elixir state-based MIDPRICE implementations
#
# Run with: mix run benchmarks/midprice_state_benchmark.exs

alias TheoryCraftTA.Native.Overlap.MIDPRICEState, as: NativeMIDPRICE
alias TheoryCraftTA.Elixir.Overlap.MIDPRICEState, as: ElixirMIDPRICE

# Test parameters
num_values = 10_000
period = 14

# Generate test data - high and low pairs
test_high = for _ <- 1..num_values, do: 90.0 + :rand.uniform() * 20.0
test_low = Enum.map(test_high, fn h -> h - :rand.uniform() * 10.0 end)
test_data = Enum.zip(test_high, test_low)

IO.puts("\n=== MIDPRICE State-based Benchmark ===\n")
IO.puts("Comparing Native (Rust NIF) vs Pure Elixir state implementations")
IO.puts("Period: #{period}, Values: #{num_values}\n")

Benchee.run(
  %{
    "Native (Rust) - APPEND" => fn ->
      {:ok, state} = NativeMIDPRICE.init(period)

      Enum.reduce(test_data, state, fn {high, low}, st ->
        {:ok, _midprice, new_st} = NativeMIDPRICE.next(st, high, low, true)
        new_st
      end)
    end,
    "Elixir - APPEND" => fn ->
      {:ok, state} = ElixirMIDPRICE.init(period)

      Enum.reduce(test_data, state, fn {high, low}, st ->
        {:ok, _midprice, new_st} = ElixirMIDPRICE.next(st, high, low, true)
        new_st
      end)
    end,
    "Native (Rust) - UPDATE" => fn ->
      # Build initial state with warmup
      {:ok, state} = NativeMIDPRICE.init(period)

      initial_state =
        Enum.reduce(Enum.take(test_data, period), state, fn {high, low}, st ->
          {:ok, _midprice, new_st} = NativeMIDPRICE.next(st, high, low, true)
          new_st
        end)

      # Now run updates
      Enum.reduce(Enum.drop(test_data, period), initial_state, fn {high, low}, st ->
        {:ok, _midprice, new_st} = NativeMIDPRICE.next(st, high, low, false)
        new_st
      end)
    end,
    "Elixir - UPDATE" => fn ->
      # Build initial state with warmup
      {:ok, state} = ElixirMIDPRICE.init(period)

      initial_state =
        Enum.reduce(Enum.take(test_data, period), state, fn {high, low}, st ->
          {:ok, _midprice, new_st} = ElixirMIDPRICE.next(st, high, low, true)
          new_st
        end)

      # Now run updates
      Enum.reduce(Enum.drop(test_data, period), initial_state, fn {high, low}, st ->
        {:ok, _midprice, new_st} = ElixirMIDPRICE.next(st, high, low, false)
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
