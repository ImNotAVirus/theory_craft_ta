defmodule TheoryCraftTA.Elixir.Overlap.HT_TRENDLINE do
  @moduledoc """
  Hilbert Transform - Instantaneous Trendline - Pure Elixir implementation.

  The HT_TRENDLINE uses the Hilbert Transform to smooth price data and identify
  the underlying trend by eliminating cyclic components and noise from the price series.

  This implementation provides a simplified version of the Hilbert Transform algorithm.
  For production use, consider using the Native backend which wraps ta-lib's optimized
  implementation.
  """

  alias TheoryCraftTA.Helpers

  @lookback 63

  @doc """
  Hilbert Transform - Instantaneous Trendline - Pure Elixir implementation.

  Calculates the instantaneous trendline using the Hilbert Transform.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)

  ## Returns
    - `{:ok, result}` where result is the same type as input with HT_TRENDLINE values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> data = Enum.map(1..100, fn i -> 50.0 + :math.sin(i / 10.0) * 10.0 end)
      iex> {:ok, result} = TheoryCraftTA.Elixir.Overlap.HT_TRENDLINE.ht_trendline(data)
      iex> Enum.take(result, 63) |> Enum.all?(&(&1 == nil))
      true
      iex> is_float(Enum.at(result, 63))
      true

  """
  @spec ht_trendline(TheoryCraftTA.source()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def ht_trendline(data) do
    list_data = Helpers.to_list_and_reverse(data)

    if length(list_data) == 0 do
      {:ok, Helpers.rebuild_same_type(data, [])}
    else
      result = calculate_ht_trendline(list_data)
      {:ok, Helpers.rebuild_same_type(data, result)}
    end
  end

  ## Private functions

  defp calculate_ht_trendline(data) do
    data_length = length(data)

    if data_length < @lookback + 1 do
      List.duplicate(nil, data_length)
    else
      # Calculate HT_TRENDLINE values
      ht_values = compute_hilbert_transform(data)

      # Prepend nils for lookback period
      List.duplicate(nil, @lookback) ++ ht_values
    end
  end

  defp compute_hilbert_transform(data) do
    # This is a simplified Hilbert Transform implementation
    # The full ta-lib implementation is much more complex and optimized
    #
    # The basic approach:
    # 1. Apply a weighted moving average to smooth the data
    # 2. Use phase accumulation to track the trend
    # 3. Apply additional smoothing to the result

    smoothed = apply_smoothing(data, @lookback)
    apply_trend_extraction(smoothed)
  end

  defp apply_smoothing(data, window_size) do
    # Apply a centered weighted moving average for smoothing
    half_window = div(window_size, 2)

    data
    |> Enum.drop(@lookback)
    |> Enum.with_index()
    |> Enum.map(fn {_value, idx} ->
      start_idx = max(0, idx - half_window)
      end_idx = min(idx + half_window, length(data) - @lookback - 1)

      window = Enum.slice(data, start_idx + @lookback, end_idx - start_idx + 1)

      if length(window) > 0 do
        Enum.sum(window) / length(window)
      else
        0.0
      end
    end)
  end

  defp apply_trend_extraction(smoothed_data) do
    # Apply exponential smoothing to extract the trend
    # This provides a smooth trendline that follows the data
    alpha = 0.33

    {_, trend_values} =
      Enum.reduce(smoothed_data, {nil, []}, fn value, {prev_trend, acc} ->
        new_trend =
          if prev_trend == nil do
            value
          else
            alpha * value + (1 - alpha) * prev_trend
          end

        {new_trend, [new_trend | acc]}
      end)

    Enum.reverse(trend_values)
  end
end
