defmodule TheoryCraftTA.Elixir.Overlap.WMA do
  @moduledoc """
  Weighted Moving Average - Pure Elixir implementation.

  Calculates the weighted moving average of the input data over the specified period.
  WMA applies linearly increasing weights to values, with the most recent value having
  the highest weight.
  """

  alias TheoryCraftTA.Helpers

  @doc """
  Weighted Moving Average - Pure Elixir implementation.

  Calculates the weighted moving average of the input data over the specified period.
  WMA applies linearly increasing weights to values, with the most recent value having
  the highest weight.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with WMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> {:ok, result} = TheoryCraftTA.Elixir.Overlap.WMA.wma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      iex> Enum.map(result, fn nil -> nil; x -> Float.round(x, 2) end)
      [nil, nil, 2.33, 3.33, 4.33]

  """
  @spec wma(TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def wma(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    if length(list_data) == 0 do
      {:ok, Helpers.rebuild_same_type(data, [])}
    else
      if period < 2 do
        {:error, "Invalid period: must be >= 2 for WMA"}
      else
        result = calculate_wma(list_data, period)
        {:ok, Helpers.rebuild_same_type(data, result)}
      end
    end
  end

  ## Private functions

  defp calculate_wma(data, period) do
    data_length = length(data)

    wma_values =
      data
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(fn window -> calculate_weighted_average(window, period) end)

    lookback = period - 1
    num_nils = min(lookback, data_length)

    List.duplicate(nil, num_nils) ++ wma_values
  end

  defp calculate_weighted_average(values, period) do
    # Calculate sum of weights: 1 + 2 + 3 + ... + period = period * (period + 1) / 2
    sum_weights = period * (period + 1) / 2

    # Calculate weighted sum: value[0] * 1 + value[1] * 2 + ... + value[period-1] * period
    weighted_sum =
      values
      |> Enum.with_index(1)
      |> Enum.reduce(0.0, fn {value, weight}, acc ->
        acc + value * weight
      end)

    weighted_sum / sum_weights
  end
end
