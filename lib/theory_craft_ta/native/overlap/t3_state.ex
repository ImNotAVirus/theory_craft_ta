defmodule TheoryCraftTA.Native.Overlap.T3State do
  @moduledoc """
  T3 (Tillson T3) - State-based Native implementation using Rust NIF.

  Provides stateful calculation of T3 for streaming/incremental scenarios where
  data arrives one value at a time. This is more efficient than recalculating
  the entire indicator on each new value.
  """

  alias TheoryCraftTA.Native

  @doc """
  Initializes a new T3 state.

  ## Parameters

    - `period` - The T3 period (must be >= 2)
    - `vfactor` - Volume factor (typically 0.0 to 1.0, default 0.7)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.T3State.init(14, 0.7)
      iex> is_reference(state)
      true

      iex> TheoryCraftTA.Native.Overlap.T3State.init(1, 0.7)
      {:error, "Invalid period: must be >= 2 for T3"}

  """
  @spec init(integer(), float()) :: {:ok, reference()} | {:error, String.t()}
  def init(period, vfactor) when is_integer(period) and is_float(vfactor) do
    Native.overlap_t3_state_init(period, vfactor)
  end

  @doc """
  Calculates the next T3 value and returns updated state.

  ## Parameters

    - `state` - Current T3 state (reference from init/2)
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, t3_value, new_state}` where t3_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.T3State.init(2, 0.7)
      iex> {:ok, t3, state2} = TheoryCraftTA.Native.Overlap.T3State.next(state, 100.0, true)
      iex> t3
      nil
      iex> {:ok, t3, _state3} = TheoryCraftTA.Native.Overlap.T3State.next(state2, 110.0, true)
      iex> t3
      nil

  """
  @spec next(reference(), float(), boolean()) ::
          {:ok, float() | nil, reference()} | {:error, String.t()}
  def next(state, value, is_new_bar)
      when is_reference(state) and is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_t3_state_next(state, value, is_new_bar) do
      {:ok, {t3_value, new_state}} ->
        {:ok, t3_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
