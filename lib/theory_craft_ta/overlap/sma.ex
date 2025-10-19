defmodule TheoryCraftTA.Overlap.SMA do
  @moduledoc """
  Simple Moving Average (SMA).

  The Simple Moving Average calculates the arithmetic mean of prices over a specified
  period. It gives equal weight to all values in the period, making it useful for
  identifying trends and smoothing out price data.

  ## Calculation

  SMA = (P₁ + P₂ + ... + Pₙ) / n

  Where:
  - n = period
  - P₁ = most recent price
  - Pₙ = oldest price in the period

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates Simple Moving Average (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with SMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.SMA.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec sma(TheoryCraftTA.source(), pos_integer()) ::
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
  Initializes a new SMA state for streaming calculation.

  ## Parameters

    - `period` - The SMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` - Initialized state
    - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.SMA.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_sma_state_init(period)
  end

  @doc """
  Calculates the next SMA value in streaming mode.

  ## Parameters

    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)
    - `state` - Current SMA state (from init or previous next call)

  ## Returns

    - `{:ok, sma_value, new_state}` where sma_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Updates last value in buffer, recalculates SMA
  - **APPEND mode** (`is_new_bar = true`): Adds new value, removes oldest if buffer full

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.SMA.init(2)
      iex> {:ok, sma, state2} = TheoryCraftTA.Overlap.SMA.next(100.0, true, state)
      iex> sma
      nil
      iex> {:ok, sma, _state3} = TheoryCraftTA.Overlap.SMA.next(110.0, true, state2)
      iex> sma
      105.0

  """
  @spec next(float(), boolean(), t()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(value, is_new_bar, state) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_sma_state_next(state, value, is_new_bar) do
      {:ok, {sma_value, new_state}} ->
        {:ok, sma_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
