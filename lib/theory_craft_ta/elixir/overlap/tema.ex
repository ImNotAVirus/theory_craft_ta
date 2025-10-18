defmodule TheoryCraftTA.Elixir.Overlap.TEMA do
  @moduledoc """
  Triple Exponential Moving Average - Pure Elixir implementation.

  Calculates the triple exponential moving average of the input data over the specified period.
  TEMA is calculated as: 3 * EMA(period) - 3 * EMA(EMA(period)) + EMA(EMA(EMA(period))).
  This provides a smoother average with even less lag than DEMA.
  """

  alias TheoryCraftTA.Helpers

  @doc """
  Triple Exponential Moving Average - Pure Elixir implementation.

  Calculates the triple exponential moving average of the input data over the specified period.
  TEMA is calculated as: 3 * EMA(period) - 3 * EMA(EMA(period)) + EMA(EMA(EMA(period))).

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with TEMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Elixir.Overlap.TEMA.tema([1.0, 2.0, 3.0, 4.0, 5.0], 2)
      {:ok, [nil, nil, nil, 4.0, 5.0]}

  """
  @spec tema(TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def tema(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    if length(list_data) == 0 do
      {:ok, Helpers.rebuild_same_type(data, [])}
    else
      if period < 2 do
        {:error, "Invalid period: must be >= 2 for TEMA"}
      else
        result = calculate_tema(list_data, period)
        {:ok, Helpers.rebuild_same_type(data, result)}
      end
    end
  end

  ## Private functions

  defp calculate_tema(data, period) do
    data_length = length(data)
    # TEMA lookback = 3 * (period - 1)
    lookback = 3 * (period - 1)

    if data_length <= lookback do
      List.duplicate(nil, data_length)
    else
      # Calculate first EMA
      ema1 = calculate_ema(data, period)

      # Calculate second EMA (EMA of EMA1)
      # Remove nils from ema1 for second EMA calculation
      ema1_without_nils = Enum.drop(ema1, period - 1)
      ema2 = calculate_ema(ema1_without_nils, period)

      # Calculate third EMA (EMA of EMA2)
      # Remove nils from ema2 for third EMA calculation
      ema2_without_nils = Enum.drop(ema2, period - 1)
      ema3 = calculate_ema(ema2_without_nils, period)

      # TEMA = 3 * EMA1 - 3 * EMA2 + EMA3
      # We need to align the arrays properly
      # ema1 has (period-1) nils at the start
      # ema2 has (period-1) nils at the start (from the second EMA calculation)
      # ema3 has (period-1) nils at the start (from the third EMA calculation)
      # So TEMA will have 3*(period-1) nils at the start

      num_nils = lookback

      # Drop nils from all EMAs for calculation
      # EMA1 needs to drop 'lookback' values to align with TEMA output
      # EMA2 needs to drop '2*(period-1)' values (from first and second EMA warmup)
      # EMA3 needs to drop 'period-1' values (its own warmup)
      ema1_values = Enum.drop(ema1, lookback)
      ema2_values = Enum.drop(ema2, 2 * (period - 1))
      ema3_values = Enum.drop(ema3, period - 1)

      # Calculate TEMA = 3 * EMA1 - 3 * EMA2 + EMA3
      tema_values =
        Enum.zip([ema1_values, ema2_values, ema3_values])
        |> Enum.map(fn
          {e1, e2, e3} when is_float(e1) and is_float(e2) and is_float(e3) ->
            3.0 * e1 - 3.0 * e2 + e3

          _ ->
            nil
        end)

      List.duplicate(nil, num_nils) ++ tema_values
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
