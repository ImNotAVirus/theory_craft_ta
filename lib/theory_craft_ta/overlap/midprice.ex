defmodule TheoryCraftTA.Overlap.MIDPRICE do
  @moduledoc """
  MIDPRICE - Midpoint Price over period.

  Calculates the midpoint between the highest high and lowest low over the specified period.
  This provides a simple measure of the average price level.

  ## Calculation

  For each period:
  1. Find the highest high value over the period
  2. Find the lowest low value over the period
  3. MIDPRICE = (HIGHEST_HIGH + LOWEST_LOW) / 2

  ## Parameters

    - `high` - High price data (list of floats, DataSeries, or TimeSeries)
    - `low` - Low price data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the calculation (must be >= 2)

  ## Returns

    - `{:ok, result}` - Result of the same type as input with MIDPRICE values
    - `{:error, reason}` - If validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.MIDPRICE.midprice([10.0, 11.0, 12.0, 13.0, 14.0], [8.0, 9.0, 10.0, 11.0, 12.0], 3)
      {:ok, [nil, nil, 10.0, 11.0, 12.0]}

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates MIDPRICE (Midpoint Price over period) for the given data.

  ## Parameters

    - `high` - High price data (list of floats, DataSeries, or TimeSeries)
    - `low` - Low price data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods (must be >= 2)

  ## Returns

    - `{:ok, result}` - Result of the same type as input
    - `{:error, reason}` - If validation or calculation fails

  ## Examples

      iex> TheoryCraftTA.Overlap.MIDPRICE.midprice([10.0, 11.0, 12.0], [8.0, 9.0, 10.0], 2)
      {:ok, [nil, 9.5, 10.5]}

  """
  @spec midprice(TheoryCraftTA.source(), TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def midprice(high, low, period) do
    list_high = Helpers.to_list_and_reverse(high)
    list_low = Helpers.to_list_and_reverse(low)

    case Native.overlap_midprice(list_high, list_low, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(high, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new MIDPRICE state for streaming calculation.

  ## Parameters

    - `period` - Number of periods (must be >= 2)

  ## Returns

    - `{:ok, state}` - Opaque state reference
    - `{:error, reason}` - If validation fails

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.MIDPRICE.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) do
    Native.overlap_midprice_state_init(period)
  end

  @doc """
  Calculates the next MIDPRICE value in streaming mode.

  ## Parameters

    - `state` - Current state reference
    - `high_value` - New high price value
    - `low_value` - New low price value
    - `is_new_bar` - true for APPEND (new bar), false for UPDATE (modify last bar)

  ## Returns

    - `{:ok, midprice_value, new_state}` - MIDPRICE value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.MIDPRICE.init(2)
      iex> {:ok, nil, state} = TheoryCraftTA.Overlap.MIDPRICE.next(state, 10.0, 8.0, true)
      iex> {:ok, midprice, _state} = TheoryCraftTA.Overlap.MIDPRICE.next(state, 11.0, 9.0, true)
      iex> midprice
      9.5

  """
  @spec next(t(), float(), float(), boolean()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, high_value, low_value, is_new_bar) do
    case Native.overlap_midprice_state_next(state, high_value, low_value, is_new_bar) do
      {:ok, {midprice_value, new_state}} ->
        {:ok, midprice_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
