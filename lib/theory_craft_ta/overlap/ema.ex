defmodule TheoryCraftTA.Overlap.EMA do
  @moduledoc """
  Exponential Moving Average (EMA).

  The Exponential Moving Average applies more weight to recent prices using an exponential
  decay factor. This makes it more responsive to recent price changes compared to SMA.

  ## Calculation

  EMA = α × P + (1 - α) × EMA_prev, where α = 2/(period+1)

  Where:
  - n = period
  - P₁ = most recent price
  - Pₙ = oldest price in the period

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates Exponential Moving Average (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with EMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.EMA.ema([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec ema(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def ema(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_ema(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new EMA state for streaming calculation.

  ## Parameters

    - `period` - The EMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` - Initialized state
    - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.EMA.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_ema_state_init(period)
  end

  @doc """
  Calculates the next EMA value in streaming mode.

  ## Parameters

    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)
    - `state` - Current EMA state (from init or previous next call)

  ## Returns

    - `{:ok, ema_value, new_state}` where ema_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Updates last value in buffer, recalculates EMA
  - **APPEND mode** (`is_new_bar = true`): Adds new value, removes oldest if buffer full

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.EMA.init(2)
      iex> {:ok, ema, state2} = TheoryCraftTA.Overlap.EMA.next(100.0, true, state)
      iex> ema
      nil
      iex> {:ok, ema, _state3} = TheoryCraftTA.Overlap.EMA.next(110.0, true, state2)
      iex> ema
      105.0

  """
  @spec next(float(), boolean(), t()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(value, is_new_bar, state) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_ema_state_next(state, value, is_new_bar) do
      {:ok, {ema_value, new_state}} ->
        {:ok, ema_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
