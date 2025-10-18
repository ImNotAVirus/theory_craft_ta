defmodule TheoryCraftTA.Native.Overlap.HT_TRENDLINEState do
  @moduledoc """
  Native (Rust NIF) implementation of stateful HT_TRENDLINE calculation.

  Uses Rustler ResourceArc to maintain internal state for streaming HT_TRENDLINE calculation.
  This is useful for real-time tick processing where you need to maintain the Hilbert Transform
  state across multiple price updates.

  The state is an opaque ResourceArc reference to Rust-managed memory.

  ## Usage

      # Initialize state (returns ResourceArc reference)
      {:ok, state} = TheoryCraftTA.Native.Overlap.HT_TRENDLINEState.init()

      # Process first 64 bars (63 warmup + 1 valid)
      {:ok, nil, state2} = TheoryCraftTA.Native.Overlap.HT_TRENDLINEState.next(state, 100.0, true)

      # After 63 bars, values start appearing
      {:ok, ht_value, state65} = TheoryCraftTA.Native.Overlap.HT_TRENDLINEState.next(state64, 110.0, true)

      # Update same bar (multiple ticks)
      {:ok, ht_updated, state66} = TheoryCraftTA.Native.Overlap.HT_TRENDLINEState.next(state65, 105.0, false)

  """

  alias TheoryCraftTA.Native

  @typedoc """
  Opaque reference to Rust ResourceArc containing HT_TRENDLINE state.
  """
  @type t :: reference()

  @doc """
  Initializes a new HT_TRENDLINE state.

  ## Returns

    - `{:ok, state}` with a ResourceArc reference
    - `{:error, message}` if ta-lib is not available

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Native.Overlap.HT_TRENDLINEState.init()

  """
  @spec init() :: {:ok, t()} | {:error, String.t()}
  def init do
    Native.overlap_ht_trendline_state_init()
  end

  @doc """
  Calculates the next HT_TRENDLINE value with stateful update.

  ## Parameters

    - `state` - Current HT_TRENDLINE state (from init or previous next call)
    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)

  ## Returns

    - `{:ok, ht_value, new_state}` where ht_value is nil during warmup (first 63 bars)
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Multiple ticks on same bar
    - Replaces last value in buffer with new value
    - Recalculates HT_TRENDLINE with updated buffer
    - Does NOT increment lookback_count
  - **APPEND mode** (`is_new_bar = true`): New bar started
    - Adds new value to buffer
    - Increments lookback_count

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.HT_TRENDLINEState.init()
      iex> {:ok, ht, state2} = TheoryCraftTA.Native.Overlap.HT_TRENDLINEState.next(state, 100.0, true)
      iex> ht
      nil
      iex> # After 63 bars, we get values
      iex> {:ok, state63} = Enum.reduce(1..62, {:ok, state2}, fn _, {:ok, s} ->
      ...>   {:ok, _ht, new_s} = TheoryCraftTA.Native.Overlap.HT_TRENDLINEState.next(s, 100.0, true)
      ...>   {:ok, new_s}
      ...> end)
      iex> {:ok, ht64, _state64} = TheoryCraftTA.Native.Overlap.HT_TRENDLINEState.next(state63, 100.0, true)
      iex> is_float(ht64)
      true

  """
  @spec next(t(), float(), boolean()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, value, is_new_bar) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_ht_trendline_state_next(state, value, is_new_bar) do
      {:ok, {ht_value, new_state}} ->
        {:ok, ht_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
