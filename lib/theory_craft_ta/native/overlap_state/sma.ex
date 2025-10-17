defmodule TheoryCraftTA.Native.OverlapState.SMA do
  @moduledoc """
  Native (Rust NIF) implementation of stateful SMA calculation.

  Uses Rustler ResourceArc to maintain internal state for streaming SMA calculation.
  This is useful for real-time tick processing where you need to maintain a sliding
  window of values.

  The state is an opaque ResourceArc reference to Rust-managed memory.

  ## Usage

      # Initialize state (returns ResourceArc reference)
      {:ok, state} = TheoryCraftTA.Native.OverlapState.SMA.init(14)

      # Process first bar
      {:ok, sma1, state2} = TheoryCraftTA.Native.OverlapState.SMA.next(state, 100.0, true)

      # Process second bar
      {:ok, sma2, state3} = TheoryCraftTA.Native.OverlapState.SMA.next(state2, 110.0, true)

      # Update same bar (multiple ticks)
      {:ok, sma3, state4} = TheoryCraftTA.Native.OverlapState.SMA.next(state3, 105.0, false)

  """

  alias TheoryCraftTA.Native

  @typedoc """
  Opaque reference to Rust ResourceArc containing SMA state.
  """
  @type t :: reference()

  @doc """
  Initializes a new SMA state.

  ## Parameters

    - `period` - The SMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` with a ResourceArc reference
    - `{:error, message}` if period is invalid or ta-lib is not available

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Native.OverlapState.SMA.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_sma_state_init(period)
  end

  @doc """
  Calculates the next SMA value with stateful update.

  ## Parameters

    - `state` - Current SMA state (from init or previous next call)
    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)

  ## Returns

    - `{:ok, sma_value, new_state}` where sma_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Multiple ticks on same bar
    - Replaces last value in buffer with new value
    - Recalculates SMA with updated buffer
    - Does NOT increment lookback_count
  - **APPEND mode** (`is_new_bar = true`): New bar started
    - Adds new value to buffer
    - Removes oldest value if buffer exceeds period
    - Increments lookback_count

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.OverlapState.SMA.init(2)
      iex> {:ok, sma, state2} = TheoryCraftTA.Native.OverlapState.SMA.next(state, 100.0, true)
      iex> sma
      nil
      iex> {:ok, sma, _state3} = TheoryCraftTA.Native.OverlapState.SMA.next(state2, 110.0, true)
      iex> sma
      105.0

  """
  @spec next(t(), float(), boolean()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, value, is_new_bar) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_sma_state_next(state, value, is_new_bar) do
      {:ok, {sma_value, new_state}} ->
        {:ok, sma_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
