defmodule TheoryCraftTA.Elixir.Overlap.MIDPOINTState do
  @moduledoc false

  # Internal state struct for MIDPOINT calculation.
  # Used by Elixir backend for streaming/stateful MIDPOINT calculation.

  defstruct [:period, :buffer, :lookback_count]

  @type t :: %__MODULE__{
          period: pos_integer(),
          buffer: [float()],
          lookback_count: non_neg_integer()
        }

  @doc """
  Initializes a new MIDPOINT state.

  ## Parameters

    - `period` - The MIDPOINT period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> TheoryCraftTA.Elixir.Overlap.MIDPOINTState.init(14)
      {:ok, %TheoryCraftTA.Elixir.Overlap.MIDPOINTState{period: 14, buffer: [], lookback_count: 0}}

      iex> TheoryCraftTA.Elixir.Overlap.MIDPOINTState.init(1)
      {:error, "Invalid period: must be >= 2 for MIDPOINT"}

  """
  @spec init(integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) and period >= 2 do
    state = %__MODULE__{
      period: period,
      buffer: [],
      lookback_count: 0
    }

    {:ok, state}
  end

  def init(period) when is_integer(period) do
    {:error, "Invalid period: must be >= 2 for MIDPOINT"}
  end

  @doc """
  Calculates the next MIDPOINT value and returns updated state.

  ## Parameters

    - `state` - Current MIDPOINT state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, midpoint_value, new_state}` where midpoint_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.MIDPOINTState.init(2)
      iex> {:ok, midpoint, state2} = TheoryCraftTA.Elixir.Overlap.MIDPOINTState.next(state, 100.0, true)
      iex> midpoint
      nil
      iex> {:ok, midpoint, _state3} = TheoryCraftTA.Elixir.Overlap.MIDPOINTState.next(state2, 110.0, true)
      iex> midpoint
      105.0

  """
  @spec next(t(), float(), boolean()) :: {:ok, float() | nil, t()}
  def next(%__MODULE__{} = state, value, is_new_bar)
      when is_float(value) and is_boolean(is_new_bar) do
    new_lookback =
      if is_new_bar do
        state.lookback_count + 1
      else
        state.lookback_count
      end

    new_buffer =
      if is_new_bar do
        updated = state.buffer ++ [value]

        if length(updated) > state.period do
          Enum.drop(updated, 1)
        else
          updated
        end
      else
        if state.buffer == [] do
          [value]
        else
          List.replace_at(state.buffer, -1, value)
        end
      end

    if new_lookback < state.period do
      new_state = %{state | buffer: new_buffer, lookback_count: new_lookback}
      {:ok, nil, new_state}
    else
      max_val = Enum.max(new_buffer)
      min_val = Enum.min(new_buffer)
      midpoint = (max_val + min_val) / 2

      new_state = %{state | buffer: new_buffer, lookback_count: new_lookback}
      {:ok, midpoint, new_state}
    end
  end
end
