defmodule TheoryCraftTA.Elixir.Overlap do
  @moduledoc false

  # This module provides Pure Elixir implementations of overlap indicators.
  # Overlap indicators include: SMA, EMA, BBANDS, etc.

  alias TheoryCraftTA.Helpers
  alias TheoryCraft.{DataSeries, TimeSeries}

  @doc """
  Simple Moving Average - Pure Elixir implementation.

  Calculates the simple moving average of the input data over the specified period.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with SMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Elixir.Overlap.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec sma(list(float()) | DataSeries.t() | TimeSeries.t(), pos_integer()) ::
          {:ok, list(float() | nil) | DataSeries.t() | TimeSeries.t()} | {:error, String.t()}
  def sma(data, period) when is_integer(period) and period >= 2 do
    list_data = Helpers.to_list_and_reverse(data)

    result = calculate_sma(list_data, period)

    {:ok, Helpers.rebuild_same_type(data, result)}
  end

  def sma(_data, period) when is_integer(period) and period < 2 do
    {:error, "Period must be >= 2"}
  end

  def sma(_data, _period) do
    {:error, "Period must be an integer"}
  end

  # Private functions

  defp calculate_sma(data, period) do
    data_length = length(data)

    # Handle empty data
    if data_length == 0 do
      []
    else
      sma_values =
        data
        |> Enum.chunk_every(period, 1, :discard)
        |> Enum.map(&calculate_average/1)

      # If insufficient data for even one SMA value, return all nils
      if Enum.empty?(sma_values) do
        List.duplicate(nil, data_length)
      else
        lookback = period - 1
        List.duplicate(nil, lookback) ++ sma_values
      end
    end
  end

  defp calculate_average(values) do
    Enum.sum(values) / length(values)
  end
end
