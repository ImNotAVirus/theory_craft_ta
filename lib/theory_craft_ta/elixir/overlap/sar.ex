defmodule TheoryCraftTA.Elixir.Overlap.SAR do
  @moduledoc """
  Parabolic SAR (Stop and Reverse) indicator implementation in pure Elixir.

  The Parabolic SAR is a trend-following indicator that provides entry and exit points.
  It appears as dots above or below the price bars, indicating the direction of the trend.
  """

  alias TheoryCraft.DataSeries
  alias TheoryCraft.TimeSeries
  alias TheoryCraftTA.Helpers

  @doc """
  Calculates the Parabolic SAR (Stop and Reverse) indicator.

  ## Parameters
    - `high` - High prices (list, DataSeries, or TimeSeries)
    - `low` - Low prices (list, DataSeries, or TimeSeries)
    - `acceleration` - Acceleration Factor (default: 0.02)
    - `maximum` - Maximum Acceleration Factor (default: 0.20)

  ## Returns
    - `{:ok, result}` - SAR values in the same type as input
    - `{:error, reason}` - Error message

  ## Examples

      iex> high = [10.0, 11.0, 12.0, 13.0, 14.0]
      iex> low = [8.0, 9.0, 10.0, 11.0, 12.0]
      iex> {:ok, result} = TheoryCraftTA.Elixir.Overlap.SAR.sar(high, low)
      iex> length(result)
      5

  """
  @spec sar(
          list(float()) | DataSeries.t() | TimeSeries.t(),
          list(float()) | DataSeries.t() | TimeSeries.t(),
          float(),
          float()
        ) :: {:ok, list(float() | nil) | DataSeries.t() | TimeSeries.t()} | {:error, String.t()}
  def sar(high, low, acceleration \\ 0.02, maximum \\ 0.20)

  def sar(high, low, acceleration, maximum) when is_list(high) and is_list(low) do
    with :ok <- validate_inputs(high, low, acceleration, maximum) do
      result = calculate_sar(high, low, acceleration, maximum)
      {:ok, result}
    end
  end

  def sar(%DataSeries{} = high, %DataSeries{} = low, acceleration, maximum) do
    high_list = Helpers.to_list_and_reverse(high)
    low_list = Helpers.to_list_and_reverse(low)

    case sar(high_list, low_list, acceleration, maximum) do
      {:ok, result} -> {:ok, Helpers.rebuild_same_type(high, result)}
      error -> error
    end
  end

  def sar(%TimeSeries{} = high, %TimeSeries{} = low, acceleration, maximum) do
    high_list = Helpers.to_list_and_reverse(high)
    low_list = Helpers.to_list_and_reverse(low)

    case sar(high_list, low_list, acceleration, maximum) do
      {:ok, result} -> {:ok, Helpers.rebuild_same_type(high, result)}
      error -> error
    end
  end

  ## Private functions

  defp validate_inputs(high, low, acceleration, maximum) do
    cond do
      length(high) != length(low) ->
        {:error, "high and low must have the same length"}

      acceleration <= 0.0 ->
        {:error, "acceleration must be positive"}

      maximum <= 0.0 ->
        {:error, "maximum must be positive"}

      acceleration > maximum ->
        {:error, "acceleration must be less than or equal to maximum"}

      true ->
        :ok
    end
  end

  defp calculate_sar([], [], _acceleration, _maximum), do: []
  defp calculate_sar([_h], [_l], _acceleration, _maximum), do: [nil]

  defp calculate_sar(high, low, acceleration, maximum) do
    # SAR algorithm based on ta-lib implementation
    # Start with initial position detection
    [h0, h1 | _] = high
    [l0, l1 | _] = low

    # Determine initial trend direction
    {is_long, initial_sar, initial_ep} =
      if h1 - h0 > l0 - l1 do
        # Uptrend
        {true, l0, h1}
      else
        # Downtrend
        {false, h0, l1}
      end

    # Initialize state
    initial_state = %{
      is_long: is_long,
      sar: initial_sar,
      ep: initial_ep,
      af: acceleration,
      acceleration: acceleration,
      maximum: maximum
    }

    # Process remaining bars
    {results, _final_state} =
      high
      |> Enum.zip(low)
      |> Enum.with_index()
      |> Enum.map_reduce(initial_state, fn {{h, l}, idx}, state ->
        if idx == 0 do
          {nil, state}
        else
          calculate_sar_for_bar(h, l, state)
        end
      end)

    results
  end

  defp calculate_sar_for_bar(high, low, state) do
    %{is_long: is_long, sar: sar, ep: ep, af: af, acceleration: accel, maximum: max_af} = state

    # Calculate new SAR
    new_sar = sar + af * (ep - sar)

    # Check for reversal
    {final_sar, new_ep, new_af, new_is_long} =
      if is_long do
        # Long position
        if low <= new_sar do
          # Reversal to short
          {ep, low, accel, false}
        else
          # Continue long
          adjusted_sar = new_sar

          # Update EP and AF if new high
          {updated_ep, updated_af} =
            if high > ep do
              {high, min(af + accel, max_af)}
            else
              {ep, af}
            end

          {adjusted_sar, updated_ep, updated_af, true}
        end
      else
        # Short position
        if high >= new_sar do
          # Reversal to long
          {ep, high, accel, true}
        else
          # Continue short
          adjusted_sar = new_sar

          # Update EP and AF if new low
          {updated_ep, updated_af} =
            if low < ep do
              {low, min(af + accel, max_af)}
            else
              {ep, af}
            end

          {adjusted_sar, updated_ep, updated_af, false}
        end
      end

    # Build new state
    new_state = %{
      is_long: new_is_long,
      sar: final_sar,
      ep: new_ep,
      af: new_af,
      acceleration: accel,
      maximum: max_af
    }

    {final_sar, new_state}
  end
end
