# Benchmark different list append patterns
# Testing: prev_list ++ [new] vs reverse patterns

small_list = Enum.to_list(1..100)
medium_list = Enum.to_list(1..1000)
large_list = Enum.to_list(1..10000)

new_value = 9999

IO.puts("\n=== Small List (100 items) ===\n")

Benchee.run(
  %{
    "++ append" => fn -> small_list ++ [new_value] end,
    "reverse + prepend + reverse" => fn ->
      Enum.reverse([new_value | Enum.reverse(small_list)])
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)

IO.puts("\n=== Medium List (1K items) ===\n")

Benchee.run(
  %{
    "++ append" => fn -> medium_list ++ [new_value] end,
    "reverse + prepend + reverse" => fn ->
      Enum.reverse([new_value | Enum.reverse(medium_list)])
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)

IO.puts("\n=== Large List (10K items) ===\n")

Benchee.run(
  %{
    "++ append" => fn -> large_list ++ [new_value] end,
    "reverse + prepend + reverse" => fn ->
      Enum.reverse([new_value | Enum.reverse(large_list)])
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)
