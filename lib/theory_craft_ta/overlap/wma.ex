defmodule TheoryCraftTA.Overlap.WMA do
  @moduledoc """
  Weighted Moving Average (WMA).

  The Weighted Moving Average applies linearly decreasing weights to older prices.
  Recent prices have more influence on the average than older prices.

  ## Calculation

  WMA = (n×P₁ + (n-1)×P₂ + ... + 1×Pₙ) / (n + (n-1) + ... + 1)

  Where:
  - n = period
  - P₁ = most recent price
  - Pₙ = oldest price in the period

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates Weighted Moving Average (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with WMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> {:ok, result} = TheoryCraftTA.Overlap.WMA.wma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      iex> [Enum.at(result, 0), Enum.at(result, 1)] == [nil, nil]
      true
      iex> abs(Enum.at(result, 2) - 2.3333) < 0.01
      true

  """
  @spec wma(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def wma(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_wma(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new WMA state for streaming calculation.

  ## Parameters

    - `period` - The WMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` - Initialized state
    - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.WMA.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_wma_state_init(period)
  end

  @doc """
  Calculates the next WMA value in streaming mode.

  ## Parameters

    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)
    - `state` - Current WMA state (from init or previous next call)

  ## Returns

    - `{:ok, wma_value, new_state}` where wma_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Updates last value in buffer, recalculates WMA
  - **APPEND mode** (`is_new_bar = true`): Adds new value, removes oldest if buffer full

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.WMA.init(2)
      iex> {:ok, wma, state2} = TheoryCraftTA.Overlap.WMA.next(100.0, true, state)
      iex> wma
      nil
      iex> {:ok, wma, _state3} = TheoryCraftTA.Overlap.WMA.next(110.0, true, state2)
      iex> abs(wma - 106.67) < 0.01
      true

  """
  @spec next(float(), boolean(), t()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(value, is_new_bar, state) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_wma_state_next(state, value, is_new_bar) do
      {:ok, {wma_value, new_state}} ->
        {:ok, wma_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
