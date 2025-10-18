defmodule TheoryCraftTA.Native.Overlap.TRIMAState do
  @moduledoc """
  Native (Rust NIF) implementation of stateful TRIMA calculation.

  Uses Rustler ResourceArc to maintain internal state for streaming TRIMA calculation.
  This is useful for real-time tick processing where you need to maintain sliding
  windows for the double-smoothing process.

  The state is an opaque ResourceArc reference to Rust-managed memory.

  ## Usage

      # Initialize state (returns ResourceArc reference)
      {:ok, state} = TheoryCraftTA.Native.Overlap.TRIMAState.init(14)

      # Process first bar
      {:ok, trima1, state2} = TheoryCraftTA.Native.Overlap.TRIMAState.next(state, 100.0, true)

      # Process second bar
      {:ok, trima2, state3} = TheoryCraftTA.Native.Overlap.TRIMAState.next(state2, 110.0, true)

      # Update same bar (multiple ticks)
      {:ok, trima3, state4} = TheoryCraftTA.Native.Overlap.TRIMAState.next(state3, 105.0, false)

  """

  alias TheoryCraftTA.Native

  @typedoc """
  Opaque reference to Rust ResourceArc containing TRIMA state.
  """
  @type t :: reference()

  @doc """
  Initializes a new TRIMA state.

  ## Parameters

    - `period` - The TRIMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` with a ResourceArc reference
    - `{:error, message}` if period is invalid or ta-lib is not available

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Native.Overlap.TRIMAState.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_trima_state_init(period)
  end

  @doc """
  Calculates the next TRIMA value with stateful update.

  ## Parameters

    - `state` - Current TRIMA state (from init or previous next call)
    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)

  ## Returns

    - `{:ok, trima_value, new_state}` where trima_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Multiple ticks on same bar
    - Replaces last value in buffers with new value
    - Recalculates TRIMA with updated buffers
    - Does NOT increment lookback_count
  - **APPEND mode** (`is_new_bar = true`): New bar started
    - Adds new value to first SMA buffer
    - Calculates first SMA and adds to second SMA buffer
    - Removes oldest values if buffers exceed period
    - Increments lookback_count

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.TRIMAState.init(2)
      iex> {:ok, trima, state2} = TheoryCraftTA.Native.Overlap.TRIMAState.next(state, 100.0, true)
      iex> trima
      nil
      iex> {:ok, trima, _state3} = TheoryCraftTA.Native.Overlap.TRIMAState.next(state2, 110.0, true)
      iex> trima
      105.0

  """
  @spec next(t(), float(), boolean()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, value, is_new_bar) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_trima_state_next(state, value, is_new_bar) do
      {:ok, {trima_value, new_state}} ->
        {:ok, trima_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
