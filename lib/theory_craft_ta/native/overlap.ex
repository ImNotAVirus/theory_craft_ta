defmodule TheoryCraftTA.Native.Overlap do
  @moduledoc """
  This module provides Native (Rust NIF) implementations of overlap indicators.

  Overlap indicators include: SMA, EMA, BBANDS, etc.
  """

  alias TheoryCraft.{DataSeries, TimeSeries}
  alias TheoryCraftTA.{Native, Helpers}

  ## Public API

  @doc """
  Simple Moving Average - Native implementation using Rust NIF.

  Calculates the simple moving average of the input data over the specified period.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with SMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.Native.Overlap.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec sma(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def sma(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_sma(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Incremental SMA calculation - adds or updates the next value.

  Optimized Native implementation using Rust NIF that calculates only the
  necessary value using TA-Lib's range feature.

  ## Parameters
    - `data` - Input data (must have one more element than prev, or same length)
    - `period` - Number of periods for the moving average
    - `prev` - Previous SMA result

  ## Returns
    - `{:ok, result}` with updated SMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Native.Overlap.sma_next([1.0, 2.0, 3.0, 4.0, 5.0], 2, [nil, 1.5, 2.5, 3.5])
      {:ok, [nil, 1.5, 2.5, 3.5, 4.5]}

  """
  @spec sma_next(TheoryCraftTA.source(), pos_integer(), TheoryCraftTA.source()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def sma_next(data, period, prev) do
    list_data = Helpers.to_list_and_reverse(data)
    prev_list = Helpers.to_list_and_reverse(prev)

    case Native.overlap_sma_next(list_data, period, prev_list) do
      {:ok, {:create, new_value}} ->
        {:ok, apply_create(data, prev, new_value)}

      {:ok, {:update, new_value}} ->
        {:ok, apply_update(prev, new_value)}

      {:error, _reason} = error ->
        error
    end
  end

  ## Private functions

  # DataSeries stores data newest-first, so prepend for create
  defp apply_create(%DataSeries{}, %DataSeries{data: prev_data} = prev, new_value) do
    %DataSeries{prev | data: [new_value | prev_data]}
  end

  # TimeSeries: extract datetime from data and prepend to both data and dt
  defp apply_create(
         %TimeSeries{} = data_ts,
         %TimeSeries{data: prev_data_series, dt: prev_dt} = prev,
         new_value
       ) do
    [new_datetime | _] = TimeSeries.keys(data_ts)

    updated_data_series =
      %DataSeries{
        prev_data_series
        | data: [new_value | prev_data_series.data]
      }

    %TimeSeries{prev | data: updated_data_series, dt: [new_datetime | prev_dt]}
  end

  defp apply_create(_data, prev_list, new_value) when is_list(prev_list) do
    prev_list ++ [new_value]
  end

  # DataSeries: replace first element (newest) with new value
  defp apply_update(%DataSeries{data: [_old | rest]} = prev, new_value) do
    %DataSeries{prev | data: [new_value | rest]}
  end

  # TimeSeries: only update the data, dt remains the same
  defp apply_update(%TimeSeries{data: prev_data_series} = prev, new_value) do
    %DataSeries{data: [_old | rest]} = prev_data_series
    updated_data_series = %DataSeries{prev_data_series | data: [new_value | rest]}

    %TimeSeries{prev | data: updated_data_series}
  end

  # List: replace last element
  defp apply_update(prev_list, new_value) when is_list(prev_list) do
    List.replace_at(prev_list, -1, new_value)
  end
end
