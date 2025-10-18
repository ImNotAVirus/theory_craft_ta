defmodule TheoryCraftTA.Native.Overlap.MIDPOINTState do
  @moduledoc """
  MIDPOINT State - Native implementation using Rustler NIF.

  Provides stateful MIDPOINT calculation for streaming data.
  """

  alias TheoryCraftTA.Native

  @doc """
  Initializes a new MIDPOINT state.

  ## Parameters

    - `period` - The MIDPOINT period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.MIDPOINTState.init(14)
      iex> is_reference(state)
      true

      iex> TheoryCraftTA.Native.Overlap.MIDPOINTState.init(1)
      {:error, "Invalid period: must be >= 2 for MIDPOINT"}

  """
  @spec init(integer()) :: {:ok, reference()} | {:error, String.t()}
  defdelegate init(period), to: Native, as: :overlap_midpoint_state_init

  @doc """
  Calculates the next MIDPOINT value and returns updated state.

  ## Parameters

    - `state` - Current MIDPOINT state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, midpoint_value, new_state}` where midpoint_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.MIDPOINTState.init(2)
      iex> {:ok, midpoint, state2} = TheoryCraftTA.Native.Overlap.MIDPOINTState.next(state, 100.0, true)
      iex> midpoint
      nil
      iex> {:ok, midpoint, _state3} = TheoryCraftTA.Native.Overlap.MIDPOINTState.next(state2, 110.0, true)
      iex> midpoint
      105.0

  """
  @spec next(reference(), float(), boolean()) ::
          {:ok, float() | nil, reference()} | {:error, String.t()}
  def next(state, value, is_new_bar) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_midpoint_state_next(state, value, is_new_bar) do
      {:ok, {midpoint_value, new_state}} ->
        {:ok, midpoint_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
