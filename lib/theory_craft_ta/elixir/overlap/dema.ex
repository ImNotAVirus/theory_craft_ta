defmodule TheoryCraftTA.Elixir.Overlap.DEMA do
  @moduledoc """
  Double Exponential Moving Average - Pure Elixir implementation.

  Calculates the double exponential moving average of the input data over the specified period.
  DEMA is calculated as: 2 * EMA(period) - EMA(EMA(period)).
  This provides a smoother average with less lag than a simple EMA.
  """

  alias TheoryCraftTA.Helpers

  @doc """
  Double Exponential Moving Average - Pure Elixir implementation.

  Calculates the double exponential moving average of the input data over the specified period.
  DEMA is calculated as: 2 * EMA(period) - EMA(EMA(period)).

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with DEMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Elixir.Overlap.DEMA.dema([1.0, 2.0, 3.0, 4.0, 5.0], 2)
      {:ok, [nil, nil, 3.0, 4.0, 5.0]}

  """
  @spec dema(TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def dema(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    if length(list_data) == 0 do
      {:ok, Helpers.rebuild_same_type(data, [])}
    else
      if period < 2 do
        {:error, "Invalid period: must be >= 2 for DEMA"}
      else
        result = calculate_dema(list_data, period)
        {:ok, Helpers.rebuild_same_type(data, result)}
      end
    end
  end

  ## Private functions

  defp calculate_dema(data, period) do
    data_length = length(data)
    # DEMA lookback = 2 * (period - 1)
    lookback = 2 * (period - 1)

    if data_length <= lookback do
      List.duplicate(nil, data_length)
    else
      # Calculate first EMA
      ema1 = calculate_ema(data, period)

      # Calculate second EMA (EMA of EMA1)
      # Remove nils from ema1 for second EMA calculation
      ema1_without_nils = Enum.drop(ema1, period - 1)
      ema2 = calculate_ema(ema1_without_nils, period)

      # DEMA = 2 * EMA1 - EMA2
      # We need to align the arrays properly
      # ema1 has (period-1) nils at the start
      # ema2 has (period-1) nils at the start (from the second EMA calculation)
      # So DEMA will have 2*(period-1) nils at the start

      num_nils = lookback

      # Drop nils from both EMAs for calculation
      # EMA1 needs to drop 'lookback' values to align with DEMA output
      # EMA2 needs to drop 'period-1' values (its own warmup)
      ema1_values = Enum.drop(ema1, lookback)
      ema2_values = Enum.drop(ema2, period - 1)

      # Calculate DEMA = 2 * EMA1 - EMA2
      dema_values =
        Enum.zip(ema1_values, ema2_values)
        |> Enum.map(fn
          {nil, nil} -> nil
          {e1, nil} when is_float(e1) -> nil
          {nil, e2} when is_float(e2) -> nil
          {e1, e2} when is_float(e1) and is_float(e2) -> 2.0 * e1 - e2
        end)

      List.duplicate(nil, num_nils) ++ dema_values
    end
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

  defp calculate_average(values) do
    Enum.sum(values) / length(values)
  end
end
