defmodule TheoryCraftTA.Elixir.Overlap.TRIMA do
  @moduledoc """
  Triangular Moving Average - Pure Elixir implementation.

  Calculates the triangular moving average of the input data over the specified period.
  TRIMA is a double-smoothed moving average (SMA of SMA), which gives more weight to the
  middle portion of the data.
  """

  alias TheoryCraftTA.Helpers

  @doc """
  Triangular Moving Average - Pure Elixir implementation.

  Calculates the triangular moving average of the input data over the specified period.
  TRIMA is a double-smoothed moving average (SMA of SMA).

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with TRIMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Elixir.Overlap.TRIMA.trima([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec trima(TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def trima(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    if length(list_data) == 0 do
      {:ok, Helpers.rebuild_same_type(data, [])}
    else
      if period < 2 do
        {:error, "Invalid period: must be >= 2 for TRIMA"}
      else
        result = calculate_trima(list_data, period)
        {:ok, Helpers.rebuild_same_type(data, result)}
      end
    end
  end

  ## Private functions

  defp calculate_trima(data, period) do
    # TRIMA uses different period calculations based on odd/even
    # For period < 3, TRIMA = SMA
    if period < 3 do
      calculate_sma(data, period)
    else
      # Calculate periods for double smoothing
      {first_period, second_period} =
        if rem(period, 2) == 1 do
          # Odd period
          half = div(period + 1, 2)
          {half, half}
        else
          # Even period
          half = div(period, 2)
          {half, half + 1}
        end

      # Step 1: Calculate first SMA
      first_sma = calculate_sma(data, first_period)

      # Step 2: Calculate second SMA on non-nil values of first SMA
      calculate_sma_with_nils(first_sma, second_period)
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

  defp calculate_sma_with_nils(data, period) do
    data_length = length(data)

    # Find first non-nil index
    first_non_nil_index =
      Enum.find_index(data, fn val -> val != nil end)

    if first_non_nil_index == nil do
      # All nils
      data
    else
      # Extract non-nil data
      non_nil_data = Enum.drop(data, first_non_nil_index)

      # Calculate SMA on non-nil data
      sma_values =
        non_nil_data
        |> Enum.chunk_every(period, 1, :discard)
        |> Enum.map(&calculate_average/1)

      # Calculate total lookback
      lookback = first_non_nil_index + (period - 1)
      num_nils = min(lookback, data_length)

      List.duplicate(nil, num_nils) ++ sma_values
    end
  end

  defp calculate_average(values) do
    Enum.sum(values) / length(values)
  end
end
