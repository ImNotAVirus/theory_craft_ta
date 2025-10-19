defmodule TheoryCraftTA.Overlap.MIDPOINT do
  @moduledoc """
  MidPoint over period (MIDPOINT).

  The MidPoint calculates the average of the highest and lowest values over the period.
  It represents the middle of the price range.

  ## Calculation

  MIDPOINT = (highest(high) + lowest(low)) / 2

  Where:
  - n = period
  - P₁ = most recent price
  - Pₙ = oldest price in the period

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates MidPoint over period (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with MIDPOINT values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.MIDPOINT.midpoint([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec midpoint(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def midpoint(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_midpoint(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new MIDPOINT state for streaming calculation.

  ## Parameters

    - `period` - The MIDPOINT period (must be >= 2)

  ## Returns

    - `{:ok, state}` - Initialized state
    - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.MIDPOINT.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_midpoint_state_init(period)
  end

  @doc """
  Calculates the next MIDPOINT value in streaming mode.

  ## Parameters

    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)
    - `state` - Current MIDPOINT state (from init or previous next call)

  ## Returns

    - `{:ok, midpoint_value, new_state}` where midpoint_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Updates last value in buffer, recalculates MIDPOINT
  - **APPEND mode** (`is_new_bar = true`): Adds new value, removes oldest if buffer full

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.MIDPOINT.init(2)
      iex> {:ok, midpoint, state2} = TheoryCraftTA.Overlap.MIDPOINT.next(100.0, true, state)
      iex> midpoint
      nil
      iex> {:ok, midpoint, _state3} = TheoryCraftTA.Overlap.MIDPOINT.next(110.0, true, state2)
      iex> midpoint
      105.0

  """
  @spec next(float(), boolean(), t()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(value, is_new_bar, state) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_midpoint_state_next(state, value, is_new_bar) do
      {:ok, {midpoint_value, new_state}} ->
        {:ok, midpoint_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
