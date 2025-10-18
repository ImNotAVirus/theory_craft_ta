# Benchmark for HT_TRENDLINE (Native-only)
#
# Run with: mix run benchmarks/ht_trendline_benchmark.exs

alias TheoryCraftTA.Native.Overlap.HT_TRENDLINE, as: NativeHT

# Generate test data (HT_TRENDLINE requires at least 64 points)
data_sizes = [100, 1_000, 10_000]

IO.puts("\n=== HT_TRENDLINE Batch Benchmark (Native-only) ===\n")

for data_size <- data_sizes do
  IO.puts("Data size: #{data_size}")

  data = for _ <- 1..data_size, do: :rand.uniform() * 100.0

  Benchee.run(
    %{
      "Native (Rust)" => fn -> NativeHT.ht_trendline(data) end
    },
    time: 2,
    memory_time: 1,
    warmup: 1,
    formatters: [
      {Benchee.Formatters.Console,
       comparison: true, extended_statistics: true, unit_scaling: :best}
    ]
  )

  IO.puts("")
end

IO.puts("\n=== Done ===\n")
