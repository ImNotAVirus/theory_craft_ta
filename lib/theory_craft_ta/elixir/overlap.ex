defmodule TheoryCraftTA.Elixir.Overlap do
  @moduledoc """
  This module provides Pure Elixir implementations of overlap indicators.

  Overlap indicators include: SMA, EMA, BBANDS, etc.
  """

  alias TheoryCraft.{DataSeries, TimeSeries}
  alias TheoryCraftTA.Helpers

  ## Public API

  @doc """
  Simple Moving Average - Pure Elixir implementation.

  Calculates the simple moving average of the input data over the specified period.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with SMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Elixir.Overlap.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec sma(TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def sma(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    if length(list_data) == 0 do
      {:ok, Helpers.rebuild_same_type(data, [])}
    else
      if period < 2 do
        {:error, "Invalid period: must be >= 2 for SMA"}
      else
        result = calculate_sma(list_data, period)
        {:ok, Helpers.rebuild_same_type(data, result)}
      end
    end
  end

  @doc """
  Incremental SMA calculation - adds or updates the next value.

  When streaming data, this function efficiently calculates the next SMA value
  without reprocessing the entire dataset.

  ## Behavior
    - If input size == prev size: Updates last value (same bar, multiple ticks)
    - If input size == prev size + 1: Adds new value (new bar)

  ## Parameters
    - `data` - Input data (must have one more element than prev, or same length)
    - `period` - Number of periods for the moving average
    - `prev` - Previous SMA result

  ## Returns
    - `{:ok, result}` with updated SMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Elixir.Overlap.sma_next([1.0, 2.0, 3.0, 4.0, 5.0], 2, [nil, 1.5, 2.5, 3.5])
      {:ok, [nil, 1.5, 2.5, 3.5, 4.5]}

      iex> TheoryCraftTA.Elixir.Overlap.sma_next([1.0, 2.0, 3.0, 4.0, 5.5], 2, [nil, 1.5, 2.5, 3.5, 4.5])
      {:ok, [nil, 1.5, 2.5, 3.5, 4.75]}

  """
  @spec sma_next(TheoryCraftTA.source(), integer(), TheoryCraftTA.source()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def sma_next(data, period, prev) do
    input_size = get_size(data)
    prev_size = get_size(prev)

    cond do
      input_size == prev_size ->
        update_last_sma(data, period, prev)

      input_size == prev_size + 1 ->
        append_new_sma(data, period, prev)

      true ->
        {:error, "Input size must be equal to or one more than prev size"}
    end
  end

  ## Private functions

  defp get_size(data) when is_list(data), do: length(data)
  defp get_size(%DataSeries{} = ds), do: DataSeries.size(ds)
  defp get_size(%TimeSeries{} = ts), do: TimeSeries.size(ts)

  defp update_last_sma(data, period, prev) do
    list_data = Helpers.to_list_and_reverse(data)

    last_values = Enum.take(list_data, -period)

    new_sma =
      if length(last_values) == period do
        calculate_average(last_values)
      else
        nil
      end

    case prev do
      %DataSeries{data: prev_data} = ds ->
        updated_data = [new_sma | tl(prev_data)]
        {:ok, %DataSeries{ds | data: updated_data}}

      %TimeSeries{data: prev_data_series} = ts ->
        updated_data_series = %DataSeries{
          prev_data_series
          | data: [new_sma | tl(prev_data_series.data)]
        }

        {:ok, %TimeSeries{ts | data: updated_data_series}}

      prev_list when is_list(prev_list) ->
        updated = List.replace_at(prev_list, -1, new_sma)
        {:ok, updated}
    end
  end

  defp append_new_sma(data, period, prev) do
    list_data = Helpers.to_list_and_reverse(data)

    last_values = Enum.take(list_data, -period)

    new_sma =
      if length(last_values) == period do
        calculate_average(last_values)
      else
        nil
      end

    case prev do
      %DataSeries{data: prev_data} = ds ->
        updated_data = [new_sma | prev_data]
        {:ok, %DataSeries{ds | data: updated_data}}

      %TimeSeries{data: prev_data_series, dt: prev_dt} = ts ->
        new_dt_key = hd(Helpers.to_list_and_reverse(TimeSeries.keys(data)))

        updated_data_series = %DataSeries{
          prev_data_series
          | data: [new_sma | prev_data_series.data]
        }

        updated_dt = [new_dt_key | prev_dt]
        {:ok, %TimeSeries{ts | data: updated_data_series, dt: updated_dt}}

      prev_list when is_list(prev_list) ->
        {:ok, prev_list ++ [new_sma]}
    end
  end

  defp calculate_sma(data, period) do
    data_length = length(data)

    sma_values =
      data
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(&calculate_average/1)

    lookback = period - 1
    num_nils = min(lookback, data_length)

    List.duplicate(nil, num_nils) ++ sma_values
  end

  defp calculate_average(values) do
    Enum.sum(values) / length(values)
  end
end
