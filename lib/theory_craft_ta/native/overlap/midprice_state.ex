defmodule TheoryCraftTA.Native.Overlap.MIDPRICEState do
  @moduledoc """
  MIDPRICE State - Native implementation using Rustler NIF.

  Provides stateful MIDPRICE calculation for streaming data.
  """

  alias TheoryCraftTA.Native

  @doc """
  Initializes a new MIDPRICE state.

  ## Parameters

    - `period` - The MIDPRICE period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.MIDPRICEState.init(14)
      iex> is_reference(state)
      true

      iex> TheoryCraftTA.Native.Overlap.MIDPRICEState.init(1)
      {:error, "Invalid period: must be >= 2 for MIDPRICE"}

  """
  @spec init(integer()) :: {:ok, reference()} | {:error, String.t()}
  defdelegate init(period), to: Native, as: :overlap_midprice_state_init

  @doc """
  Calculates the next MIDPRICE value and returns updated state.

  ## Parameters

    - `state` - Current MIDPRICE state
    - `high_value` - New high price value
    - `low_value` - New low price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, midprice_value, new_state}` where midprice_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Native.Overlap.MIDPRICEState.init(2)
      iex> {:ok, midprice, state2} = TheoryCraftTA.Native.Overlap.MIDPRICEState.next(state, 10.0, 8.0, true)
      iex> midprice
      nil
      iex> {:ok, midprice, _state3} = TheoryCraftTA.Native.Overlap.MIDPRICEState.next(state2, 11.0, 9.0, true)
      iex> midprice
      9.5

  """
  @spec next(reference(), float(), float(), boolean()) ::
          {:ok, float() | nil, reference()} | {:error, String.t()}
  def next(state, high_value, low_value, is_new_bar)
      when is_float(high_value) and is_float(low_value) and is_boolean(is_new_bar) do
    case Native.overlap_midprice_state_next(state, high_value, low_value, is_new_bar) do
      {:ok, {midprice_value, new_state}} ->
        {:ok, midprice_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
