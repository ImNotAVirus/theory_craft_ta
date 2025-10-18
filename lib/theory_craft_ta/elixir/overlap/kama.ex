defmodule TheoryCraftTA.Elixir.Overlap.KAMA do
  @moduledoc """
  Kaufman Adaptive Moving Average - Pure Elixir implementation.

  KAMA is an adaptive moving average that adjusts its sensitivity based on market volatility.
  It uses the Efficiency Ratio (ER) to determine how directional the price movement is.
  """

  alias TheoryCraftTA.Helpers

  @doc """
  Kaufman Adaptive Moving Average - Pure Elixir implementation.

  KAMA adapts its smoothing based on price movement efficiency. In trending markets,
  it becomes more responsive; in choppy markets, it smooths more.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the efficiency ratio (must be integer >= 2, default 30)

  ## Returns
    - `{:ok, result}` where result is the same type as input with KAMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> {:ok, result} = TheoryCraftTA.Elixir.Overlap.KAMA.kama([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0], 5)
      iex> Enum.map(result, fn nil -> nil; x -> Float.round(x, 2) end)
      [nil, nil, nil, nil, nil, 5.44, 6.14, 6.96, 7.87, 8.82]

  """
  @spec kama(TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def kama(data, period) when is_integer(period) do
    list_data = Helpers.to_list_and_reverse(data)

    if length(list_data) == 0 do
      {:ok, Helpers.rebuild_same_type(data, [])}
    else
      if period < 2 do
        {:error, "Invalid period: must be >= 2 for KAMA"}
      else
        result = calculate_kama(list_data, period)
        {:ok, Helpers.rebuild_same_type(data, result)}
      end
    end
  end

  ## Private functions

  defp calculate_kama(data, period) do
    data_length = length(data)
    lookback = period

    if data_length < lookback + 1 do
      # Not enough data
      List.duplicate(nil, data_length)
    else
      # Calculate KAMA values
      # Fastest SC = 2/(2+1) = 2/3
      # Slowest SC = 2/(30+1) = 2/31
      fastest_sc = 2.0 / 3.0
      slowest_sc = 2.0 / 31.0

      # Calculate first KAMA using value at lookback-1 as previous
      prev_kama_init = Enum.at(data, lookback - 1)
      first_price = Enum.at(data, lookback)

      # Calculate first KAMA value
      window = Enum.slice(data, 0, period + 1)
      change = abs(Enum.at(window, period) - Enum.at(window, 0))

      volatility =
        window
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [a, b] -> abs(b - a) end)
        |> Enum.sum()

      er = if volatility == 0.0, do: 0.0, else: change / volatility
      sc = :math.pow(er * (fastest_sc - slowest_sc) + slowest_sc, 2)
      first_kama = prev_kama_init + sc * (first_price - prev_kama_init)

      {_final_kama, kama_values} =
        data
        |> Enum.drop(lookback + 1)
        |> Enum.with_index(lookback + 1)
        |> Enum.reduce({first_kama, [first_kama]}, fn {price, idx}, {prev_kama, acc} ->
          # Calculate Efficiency Ratio (ER)
          window = Enum.slice(data, idx - period, period + 1)
          change = abs(Enum.at(window, period) - Enum.at(window, 0))

          volatility =
            window
            |> Enum.chunk_every(2, 1, :discard)
            |> Enum.map(fn [a, b] -> abs(b - a) end)
            |> Enum.sum()

          er = if volatility == 0.0, do: 0.0, else: change / volatility

          # Smoothing Constant (SC)
          sc = :math.pow(er * (fastest_sc - slowest_sc) + slowest_sc, 2)

          # KAMA calculation
          new_kama = prev_kama + sc * (price - prev_kama)

          {new_kama, [new_kama | acc]}
        end)

      kama_values = Enum.reverse(kama_values)
      List.duplicate(nil, lookback) ++ kama_values
    end
  end
end
