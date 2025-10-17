defmodule TheoryCraftTA.Native.OverlapState.WMA do
  @moduledoc """
  Native (Rust NIF) implementation of stateful WMA calculation.

  Uses Rustler ResourceArc to maintain internal state for streaming WMA calculation.
  This is useful for real-time tick processing where you need to maintain a sliding
  window of values.

  The state is an opaque ResourceArc reference to Rust-managed memory.

  ## Usage

      # Initialize state (returns ResourceArc reference)
      {:ok, state} = TheoryCraftTA.Native.OverlapState.WMA.init(14)

      # Process first bar
      {:ok, wma1, state2} = TheoryCraftTA.Native.OverlapState.WMA.next(state, 100.0, true)

      # Process second bar
      {:ok, wma2, state3} = TheoryCraftTA.Native.OverlapState.WMA.next(state2, 110.0, true)

      # Update same bar (multiple ticks)
      {:ok, wma3, state4} = TheoryCraftTA.Native.OverlapState.WMA.next(state3, 105.0, false)

  """

  alias TheoryCraftTA.Native

  @typedoc """
  Opaque reference to Rust ResourceArc containing WMA state.
  """
  @type t :: reference()

  @doc """
  Initializes a new WMA state.

  ## Parameters

    - `period` - The WMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` with a ResourceArc reference
    - `{:error, message}` if period is invalid or ta-lib is not available

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Native.OverlapState.WMA.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_wma_state_init(period)
  end

  @doc """
  Calculates the next WMA value with stateful update.

  ## Parameters

    - `state` - Current WMA state (from init or previous next call)
    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)

  ## Returns

    - `{:ok, wma_value, new_state}` where wma_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Multiple ticks on same bar
    - Replaces last value in buffer with new value
    - Recalculates WMA with updated buffer
    - Does NOT increment lookback_count
  - **APPEND mode** (`is_new_bar = true`): New bar started
    - Adds new value to buffer
    - Removes oldest value if buffer exceeds period
    - Increments lookback_count

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.OverlapState.WMA.init(2)
      iex> {:ok, wma, state2} = TheoryCraftTA.Native.OverlapState.WMA.next(state, 100.0, true)
      iex> wma
      nil
      iex> {:ok, wma, _state3} = TheoryCraftTA.Native.OverlapState.WMA.next(state2, 110.0, true)
      iex> Float.round(wma, 5)
      106.66667

  """
  @spec next(t(), float(), boolean()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, value, is_new_bar) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_wma_state_next(state, value, is_new_bar) do
      {:ok, {wma_value, new_state}} ->
        {:ok, wma_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
