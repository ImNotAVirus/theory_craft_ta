# Benchmark comparing Native (Rust NIF) vs Pure Elixir implementations for MIDPOINT
#
# Run with: mix run benchmarks/midpoint_benchmark.exs

alias TheoryCraftTA.Native.Overlap.MIDPOINT, as: NativeMIDPOINT
alias TheoryCraftTA.Elixir.Overlap.MIDPOINT, as: ElixirMIDPOINT

# Generate test data
data_sizes = [100, 1_000, 10_000]
periods = [14, 50, 200]

IO.puts("\n=== MIDPOINT Batch Benchmark ===\n")
IO.puts("Comparing Native (Rust NIF) vs Pure Elixir implementations\n")

for data_size <- data_sizes do
  IO.puts("Data size: #{data_size}")

  data = for _ <- 1..data_size, do: :rand.uniform() * 100.0

  for period <- periods do
    IO.puts("  Period: #{period}")

    Benchee.run(
      %{
        "Native (Rust)" => fn -> NativeMIDPOINT.midpoint(data, period) end,
        "Elixir" => fn -> ElixirMIDPOINT.midpoint(data, period) end
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
