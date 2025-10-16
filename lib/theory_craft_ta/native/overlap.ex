defmodule TheoryCraftTA.Native.Overlap do
  @moduledoc """
  This module provides Native (Rust NIF) implementations of overlap indicators.

  Overlap indicators include: SMA, EMA, BBANDS, etc.
  """

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
  @spec sma(TheoryCraftTA.source(), integer()) ::
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
  @spec sma_next(TheoryCraftTA.source(), integer(), TheoryCraftTA.source()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def sma_next(data, period, prev) do
    list_data = Helpers.to_list_and_reverse(data)
    prev_list = Helpers.to_list_and_reverse(prev)

    case Native.overlap_sma_next(list_data, period, prev_list) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end
end
