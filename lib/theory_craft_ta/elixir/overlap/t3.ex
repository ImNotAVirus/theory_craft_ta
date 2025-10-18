defmodule TheoryCraftTA.Elixir.Overlap.T3 do
  @moduledoc """
  T3 (Tillson T3) - Pure Elixir implementation.

  Calculates the Tillson T3 moving average of the input data over the specified period.
  T3 is a smoothing technique that applies a sequence of generalized DEMA filters
  (GD) to reduce lag and noise. It uses a volume factor to control smoothing.

  The T3 algorithm applies six successive EMA filters with the volume factor.
  """

  alias TheoryCraftTA.Helpers

  @doc """
  T3 (Tillson T3) - Pure Elixir implementation.

  Calculates the Tillson T3 moving average of the input data over the specified period.
  T3 is a smoothing technique that applies a sequence of generalized DEMA filters
  to reduce lag and noise.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)
    - `vfactor` - Volume factor (typically 0.0 to 1.0, default is 0.7)

  ## Returns
    - `{:ok, result}` where result is the same type as input with T3 values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Elixir.Overlap.T3.t3([1.0, 2.0, 3.0, 4.0, 5.0], 2, 0.7)
      {:ok, [nil, nil, nil, nil, nil]}

  """
  @spec t3(TheoryCraftTA.source(), integer(), float()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def t3(data, period, vfactor) do
    list_data = Helpers.to_list_and_reverse(data)

    if length(list_data) == 0 do
      {:ok, Helpers.rebuild_same_type(data, [])}
    else
      if period < 2 do
        {:error, "Invalid period: must be >= 2 for T3"}
      else
        result = calculate_t3(list_data, period, vfactor)
        {:ok, Helpers.rebuild_same_type(data, result)}
      end
    end
  end

  ## Private functions

  defp calculate_t3(data, period, vfactor) do
    # T3 applies six successive EMAs with volume factor adjustments
    # Each EMA is calculated on the output of the previous EMA
    # Nils propagate through the chain until all 6 EMAs have warmed up

    # Calculate the 6 successive EMAs, propagating nils
    ema1 = calculate_ema(data, period)
    ema2 = calculate_ema_on_values(ema1, period)
    ema3 = calculate_ema_on_values(ema2, period)
    ema4 = calculate_ema_on_values(ema3, period)
    ema5 = calculate_ema_on_values(ema4, period)
    ema6 = calculate_ema_on_values(ema5, period)

    # Calculate coefficients based on vfactor
    c1 = -vfactor * vfactor * vfactor
    c2 = 3.0 * vfactor * vfactor + 3.0 * vfactor * vfactor * vfactor
    c3 = -6.0 * vfactor * vfactor - 3.0 * vfactor - 3.0 * vfactor * vfactor * vfactor
    c4 = 1.0 + 3.0 * vfactor + vfactor * vfactor * vfactor + 3.0 * vfactor * vfactor

    # Calculate T3 = c1*e6 + c2*e5 + c3*e4 + c4*e3
    # Only calculate when all 4 required EMAs have values
    [ema3, ema4, ema5, ema6]
    |> Enum.zip()
    |> Enum.map(fn
      {e3, e4, e5, e6}
      when is_float(e3) and is_float(e4) and is_float(e5) and is_float(e6) ->
        c1 * e6 + c2 * e5 + c3 * e4 + c4 * e3

      _ ->
        nil
    end)
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

  defp calculate_ema_on_values(values, period) do
    k = 2.0 / (period + 1)

    {result, _state} =
      Enum.reduce(values, {[], :init}, fn
        nil, {acc, state} ->
          {[nil | acc], state}

        value, {acc, :init} ->
          {[nil | acc], {:collecting, [value], 1}}

        value, {acc, {:collecting, buffer, count}} when count < period - 1 ->
          {[nil | acc], {:collecting, [value | buffer], count + 1}}

        value, {acc, {:collecting, buffer, _count}} ->
          all_values = [value | buffer]
          seed = Enum.sum(all_values) / length(all_values)
          {[seed | acc], {:calculating, seed}}

        value, {acc, {:calculating, prev_ema}} ->
          new_ema = (value - prev_ema) * k + prev_ema
          {[new_ema | acc], {:calculating, new_ema}}
      end)

    Enum.reverse(result)
  end

  defp calculate_average(values) do
    Enum.sum(values) / length(values)
  end
end
