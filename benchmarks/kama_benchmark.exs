# Benchmark comparing Native (Rust NIF) vs Pure Elixir implementations for KAMA
#
# Run with: mix run benchmarks/kama_benchmark.exs

alias TheoryCraftTA.Native.Overlap.KAMA, as: NativeKAMA
alias TheoryCraftTA.Elixir.Overlap.KAMA, as: ElixirKAMA

# Generate test data
data_sizes = [100, 1_000, 10_000]
periods = [10, 30, 50]

IO.puts("\n=== KAMA Batch Benchmark ===\n")
IO.puts("Comparing Native (Rust NIF) vs Pure Elixir implementations\n")

for data_size <- data_sizes do
  IO.puts("Data size: #{data_size}")

  data = for _ <- 1..data_size, do: :rand.uniform() * 100.0

  for period <- periods do
    IO.puts("  Period: #{period}")

    Benchee.run(
      %{
        "Native (Rust)" => fn -> NativeKAMA.kama(data, period) end,
        "Elixir" => fn -> ElixirKAMA.kama(data, period) end
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
