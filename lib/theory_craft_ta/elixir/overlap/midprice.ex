defmodule TheoryCraftTA.Elixir.Overlap.MIDPRICE do
  @moduledoc """
  Midpoint Price over period - Pure Elixir implementation.

  Calculates the midpoint between the highest high and lowest low over the specified period.
  This is commonly used to identify price levels in technical analysis.
  """

  alias TheoryCraftTA.Helpers

  @doc """
  Midpoint Price over period - Pure Elixir implementation.

  Calculates the midpoint between the highest high and lowest low over the specified period.
  Formula: MIDPRICE = (HIGHEST_HIGH + LOWEST_LOW) / 2

  ## Parameters
    - `high` - High price data (list of floats, DataSeries, or TimeSeries)
    - `low` - Low price data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the midprice calculation (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with MIDPRICE values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Elixir.Overlap.MIDPRICE.midprice([10.0, 11.0, 12.0, 13.0, 14.0], [8.0, 9.0, 10.0, 11.0, 12.0], 3)
      {:ok, [nil, nil, 10.0, 11.0, 12.0]}

  """
  @spec midprice(TheoryCraftTA.source(), TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def midprice(high, low, period) do
    high_list = Helpers.to_list_and_reverse(high)
    low_list = Helpers.to_list_and_reverse(low)

    cond do
      length(high_list) == 0 and length(low_list) == 0 ->
        {:ok, Helpers.rebuild_same_type(high, [])}

      length(high_list) != length(low_list) ->
        {:error, "Invalid input: high and low must have the same length"}

      period < 2 ->
        {:error, "Invalid period: must be >= 2 for MIDPRICE"}

      true ->
        result = calculate_midprice(high_list, low_list, period)
        {:ok, Helpers.rebuild_same_type(high, result)}
    end
  end

  ## Private functions

  defp calculate_midprice(high_data, low_data, period) do
    data_length = length(high_data)

    midprice_values =
      Enum.zip(high_data, low_data)
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(&calculate_midprice_value/1)

    lookback = period - 1
    num_nils = min(lookback, data_length)

    List.duplicate(nil, num_nils) ++ midprice_values
  end

  defp calculate_midprice_value(high_low_pairs) do
    {high_values, low_values} = Enum.unzip(high_low_pairs)

    highest_high = Enum.max(high_values)
    lowest_low = Enum.min(low_values)

    (highest_high + lowest_low) / 2
  end
end
