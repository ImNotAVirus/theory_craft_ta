# Benchmark comparing Native (Rust NIF) vs Pure Elixir implementations for MIDPRICE
#
# Run with: mix run benchmarks/midprice_benchmark.exs

alias TheoryCraftTA.Native.Overlap.MIDPRICE, as: NativeMIDPRICE
alias TheoryCraftTA.Elixir.Overlap.MIDPRICE, as: ElixirMIDPRICE

# Generate test data
data_sizes = [100, 1_000, 10_000]
periods = [14, 50, 200]

IO.puts("\n=== MIDPRICE Batch Benchmark ===\n")
IO.puts("Comparing Native (Rust NIF) vs Pure Elixir implementations\n")

for data_size <- data_sizes do
  IO.puts("Data size: #{data_size}")

  # Generate high and low price data
  high = for _ <- 1..data_size, do: 90.0 + :rand.uniform() * 20.0
  low = Enum.map(high, fn h -> h - :rand.uniform() * 10.0 end)

  for period <- periods do
    IO.puts("  Period: #{period}")

    Benchee.run(
      %{
        "Native (Rust)" => fn -> NativeMIDPRICE.midprice(high, low, period) end,
        "Elixir" => fn -> ElixirMIDPRICE.midprice(high, low, period) end
      },
      time: 2,
      memory_time: 1,
      warmup: 1,
      formatters: [
        {Benchee.Formatters.Console,
         comparison: true, extended_statistics: true, unit_scaling: :best}
      ]
    )
  end

  IO.puts("")
end

IO.puts("\n=== Done ===\n")
