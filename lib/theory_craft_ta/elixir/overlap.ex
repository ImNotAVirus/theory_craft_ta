defmodule TheoryCraftTA.Elixir.Overlap do
  @moduledoc """
  This module provides Pure Elixir implementations of overlap indicators.

  Overlap indicators include: SMA, EMA, BBANDS, etc.
  """

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
  Exponential Moving Average - Pure Elixir implementation.

  Calculates the exponential moving average of the input data over the specified period.
  EMA applies more weight to recent values using an exponential decay factor.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with EMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Elixir.Overlap.ema([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec ema(TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def ema(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    if length(list_data) == 0 do
      {:ok, Helpers.rebuild_same_type(data, [])}
    else
      if period < 2 do
        {:error, "Invalid period: must be >= 2 for EMA"}
      else
        result = calculate_ema(list_data, period)
        {:ok, Helpers.rebuild_same_type(data, result)}
      end
    end
  end

  ## Private functions

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

  defp calculate_ema(data, period) do
    data_length = length(data)
    lookback = period - 1

    if data_length < period do
      List.duplicate(nil, data_length)
    else
      k = 2.0 / (period + 1)
      num_nils = min(lookback, data_length)
      first_values = Enum.take(data, period)
      seed_ema = calculate_average(first_values)

      {ema_values, _} =
        data
        |> Enum.drop(period)
        |> Enum.reduce({[seed_ema], seed_ema}, fn value, {acc, prev_ema} ->
          new_ema = (value - prev_ema) * k + prev_ema
          {[new_ema | acc], new_ema}
        end)

      List.duplicate(nil, num_nils) ++ Enum.reverse(ema_values)
    end
  end
end
