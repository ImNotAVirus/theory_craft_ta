defmodule TheoryCraftTA.Native.Overlap.KAMAState do
  @moduledoc """
  Native (Rust NIF) implementation of stateful KAMA calculation.

  Uses Rustler ResourceArc to maintain internal state for streaming KAMA calculation.
  This is useful for real-time tick processing where you need to maintain a sliding
  window of values.

  The state is an opaque ResourceArc reference to Rust-managed memory.

  ## Usage

      # Initialize state (returns ResourceArc reference)
      {:ok, state} = TheoryCraftTA.Native.Overlap.KAMAState.init(10)

      # Process first bar
      {:ok, kama1, state2} = TheoryCraftTA.Native.Overlap.KAMAState.next(state, 100.0, true)

      # Process second bar
      {:ok, kama2, state3} = TheoryCraftTA.Native.Overlap.KAMAState.next(state2, 110.0, true)

      # Update same bar (multiple ticks)
      {:ok, kama3, state4} = TheoryCraftTA.Native.Overlap.KAMAState.next(state3, 105.0, false)

  """

  alias TheoryCraftTA.Native

  @typedoc """
  Opaque reference to Rust ResourceArc containing KAMA state.
  """
  @type t :: reference()

  @doc """
  Initializes a new KAMA state.

  ## Parameters

    - `period` - The KAMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` with a ResourceArc reference
    - `{:error, message}` if period is invalid or ta-lib is not available

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Native.Overlap.KAMAState.init(10)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_kama_state_init(period)
  end

  @doc """
  Calculates the next KAMA value with stateful update.

  ## Parameters

    - `state` - Current KAMA state (from init or previous next call)
    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)

  ## Returns

    - `{:ok, kama_value, new_state}` where kama_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Multiple ticks on same bar
    - Replaces last value in buffer with new value
    - Recalculates KAMA with updated buffer
    - Does NOT increment lookback_count
  - **APPEND mode** (`is_new_bar = true`): New bar started
    - Adds new value to buffer
    - Removes oldest value if buffer exceeds period + 1
    - Increments lookback_count

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.KAMAState.init(5)
      iex> {:ok, kama, state2} = TheoryCraftTA.Native.Overlap.KAMAState.next(state, 1.0, true)
      iex> kama
      nil
      iex> {:ok, kama, state3} = TheoryCraftTA.Native.Overlap.KAMAState.next(state2, 2.0, true)
      iex> kama
      nil
      iex> {:ok, kama, state4} = TheoryCraftTA.Native.Overlap.KAMAState.next(state3, 3.0, true)
      iex> kama
      nil
      iex> {:ok, kama, state5} = TheoryCraftTA.Native.Overlap.KAMAState.next(state4, 4.0, true)
      iex> kama
      nil
      iex> {:ok, kama, state6} = TheoryCraftTA.Native.Overlap.KAMAState.next(state5, 5.0, true)
      iex> kama
      nil
      iex> {:ok, kama, _state7} = TheoryCraftTA.Native.Overlap.KAMAState.next(state6, 6.0, true)
      iex> Float.round(kama, 5)
      5.44444

  """
  @spec next(t(), float(), boolean()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, value, is_new_bar) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_kama_state_next(state, value, is_new_bar) do
      {:ok, {kama_value, new_state}} ->
        {:ok, kama_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
