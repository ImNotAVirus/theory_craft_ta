defmodule TheoryCraftTA.Native.Overlap.DEMAState do
  @moduledoc """
  Native (Rust NIF) implementation of stateful DEMA calculation.

  Uses Rustler ResourceArc to maintain internal state for streaming DEMA calculation.
  This is the recommended approach for real-time tick processing where recalculating
  the full DEMA on every tick would be too expensive.

  The state is an opaque ResourceArc reference to Rust-managed memory.

  ## Usage

      # Initialize state (returns ResourceArc reference)
      {:ok, state} = TheoryCraftTA.Native.Overlap.DEMAState.init(14)

      # Process first bar
      {:ok, dema1, state2} = TheoryCraftTA.Native.Overlap.DEMAState.next(state, 100.0, true)

      # Process second bar
      {:ok, dema2, state3} = TheoryCraftTA.Native.Overlap.DEMAState.next(state2, 110.0, true)

      # Update same bar (multiple ticks)
      {:ok, dema3, state4} = TheoryCraftTA.Native.Overlap.DEMAState.next(state3, 105.0, false)

  """

  alias TheoryCraftTA.Native

  @typedoc """
  Opaque reference to Rust ResourceArc containing DEMA state.
  """
  @type t :: reference()

  @doc """
  Initializes a new DEMA state.

  ## Parameters

    - `period` - The DEMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` with a ResourceArc reference
    - `{:error, message}` if period is invalid or ta-lib is not available

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Native.Overlap.DEMAState.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_dema_state_init(period)
  end

  @doc """
  Calculates the next DEMA value with stateful update.

  ## Parameters

    - `state` - Current DEMA state (from init or previous next call)
    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)

  ## Returns

    - `{:ok, dema_value, new_state}` where dema_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Multiple ticks on same bar
    - Calculates new DEMA with current value
    - Updates internal state (current_ema changes)
    - Does NOT increment lookback_count
  - **APPEND mode** (`is_new_bar = true`): New bar started
    - Calculates DEMA with value from new bar
    - Updates internal state
    - Increments lookback_count

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.DEMAState.init(2)
      iex> {:ok, dema, state2} = TheoryCraftTA.Native.Overlap.DEMAState.next(state, 100.0, true)
      iex> dema
      nil
      iex> {:ok, dema, state3} = TheoryCraftTA.Native.Overlap.DEMAState.next(state2, 110.0, true)
      iex> dema
      nil
      iex> {:ok, dema, _state4} = TheoryCraftTA.Native.Overlap.DEMAState.next(state3, 120.0, true)
      iex> dema
      120.0

  """
  @spec next(t(), float(), boolean()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, value, is_new_bar) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_dema_state_next(state, value, is_new_bar) do
      {:ok, {dema_value, new_state}} ->
        {:ok, dema_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
