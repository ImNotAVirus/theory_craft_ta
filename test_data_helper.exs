# Helper script to generate test data from Python reference file

File.read!("ht_trendline_reference.txt")
|> String.split("\n")
|> Enum.reduce({:input, []}, fn line, {section, acc} ->
  cond do
    String.contains?(line, "Input:") -> {:input, acc}
    String.contains?(line, "Output:") -> {:output, acc}
    String.match?(line, ~r/^\d+: /) ->
      [_, value] = String.split(line, ": ", parts: 2)
      {section, [{section, value} | acc]}
    true -> {section, acc}
  end
end)
|> elem(1)
|> Enum.reverse()
|> Enum.each(fn {section, value} ->
  if section == :input do
    IO.puts("#{value},")
  else
    if value == "NaN" do
      IO.puts("nil,")
    else
      IO.puts("#{value},")
    end
  end
end)
