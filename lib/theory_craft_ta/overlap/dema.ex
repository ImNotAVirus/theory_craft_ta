defmodule TheoryCraftTA.Overlap.DEMA do
  @moduledoc """
  Double Exponential Moving Average (DEMA).

  The Double Exponential Moving Average reduces lag by applying EMA twice.
  It responds faster to price changes than a single EMA.

  ## Calculation

  DEMA = 2×EMA - EMA(EMA)

  Where:
  - n = period
  - P₁ = most recent price
  - Pₙ = oldest price in the period

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates Double Exponential Moving Average (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with DEMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.DEMA.dema([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, nil, nil, 5.0]}

  """
  @spec dema(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def dema(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_dema(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new DEMA state for streaming calculation.

  ## Parameters

    - `period` - The DEMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` - Initialized state
    - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.DEMA.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_dema_state_init(period)
  end

  @doc """
  Calculates the next DEMA value in streaming mode.

  ## Parameters

    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)
    - `state` - Current DEMA state (from init or previous next call)

  ## Returns

    - `{:ok, dema_value, new_state}` where dema_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Updates last value in buffer, recalculates DEMA
  - **APPEND mode** (`is_new_bar = true`): Adds new value, removes oldest if buffer full

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.DEMA.init(2)
      iex> {:ok, dema, state2} = TheoryCraftTA.Overlap.DEMA.next(100.0, true, state)
      iex> dema
      nil
      iex> {:ok, dema, state3} = TheoryCraftTA.Overlap.DEMA.next(110.0, true, state2)
      iex> dema
      nil
      iex> {:ok, dema, _state4} = TheoryCraftTA.Overlap.DEMA.next(120.0, true, state3)
      iex> dema
      120.0

  """
  @spec next(float(), boolean(), t()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(value, is_new_bar, state) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_dema_state_next(state, value, is_new_bar) do
      {:ok, {dema_value, new_state}} ->
        {:ok, dema_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
