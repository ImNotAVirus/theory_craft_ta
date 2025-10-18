defmodule TheoryCraftTA.Native.Overlap.TEMAState do
  @moduledoc """
  Native (Rust NIF) implementation of stateful TEMA calculation.

  Uses Rustler ResourceArc to maintain internal state for streaming TEMA calculation.
  This is the recommended approach for real-time tick processing where recalculating
  the full TEMA on every tick would be too expensive.

  The state is an opaque ResourceArc reference to Rust-managed memory.

  ## Usage

      # Initialize state (returns ResourceArc reference)
      {:ok, state} = TheoryCraftTA.Native.Overlap.TEMAState.init(14)

      # Process first bar
      {:ok, tema1, state2} = TheoryCraftTA.Native.Overlap.TEMAState.next(state, 100.0, true)

      # Process second bar
      {:ok, tema2, state3} = TheoryCraftTA.Native.Overlap.TEMAState.next(state2, 110.0, true)

      # Update same bar (multiple ticks)
      {:ok, tema3, state4} = TheoryCraftTA.Native.Overlap.TEMAState.next(state3, 105.0, false)

  """

  alias TheoryCraftTA.Native

  @typedoc """
  Opaque reference to Rust ResourceArc containing TEMA state.
  """
  @type t :: reference()

  @doc """
  Initializes a new TEMA state.

  ## Parameters

    - `period` - The TEMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` with a ResourceArc reference
    - `{:error, message}` if period is invalid or ta-lib is not available

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Native.Overlap.TEMAState.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_tema_state_init(period)
  end

  @doc """
  Calculates the next TEMA value with stateful update.

  ## Parameters

    - `state` - Current TEMA state (from init or previous next call)
    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)

  ## Returns

    - `{:ok, tema_value, new_state}` where tema_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Multiple ticks on same bar
    - Calculates new TEMA with current value
    - Updates internal state (current_ema changes)
    - Does NOT increment lookback_count
  - **APPEND mode** (`is_new_bar = true`): New bar started
    - Calculates TEMA with value from new bar
    - Updates internal state
    - Increments lookback_count

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.TEMAState.init(2)
      iex> {:ok, tema, state2} = TheoryCraftTA.Native.Overlap.TEMAState.next(state, 100.0, true)
      iex> tema
      nil
      iex> {:ok, tema, state3} = TheoryCraftTA.Native.Overlap.TEMAState.next(state2, 110.0, true)
      iex> tema
      nil
      iex> {:ok, tema, state4} = TheoryCraftTA.Native.Overlap.TEMAState.next(state3, 120.0, true)
      iex> tema
      nil
      iex> {:ok, tema, _state5} = TheoryCraftTA.Native.Overlap.TEMAState.next(state4, 130.0, true)
      iex> tema
      130.0

  """
  @spec next(t(), float(), boolean()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, value, is_new_bar) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_tema_state_next(state, value, is_new_bar) do
      {:ok, {tema_value, new_state}} ->
        {:ok, tema_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
