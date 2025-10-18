defmodule TheoryCraftTA.Elixir.Overlap.MIDPRICEState do
  @moduledoc false

  # Internal state struct for MIDPRICE calculation.
  # Used by Elixir backend for streaming/stateful MIDPRICE calculation.

  defstruct [:period, :high_buffer, :low_buffer, :lookback_count]

  @type t :: %__MODULE__{
          period: pos_integer(),
          high_buffer: [float()],
          low_buffer: [float()],
          lookback_count: non_neg_integer()
        }

  @doc """
  Initializes a new MIDPRICE state.

  ## Parameters

    - `period` - The MIDPRICE period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> TheoryCraftTA.Elixir.Overlap.MIDPRICEState.init(14)
      {:ok, %TheoryCraftTA.Elixir.Overlap.MIDPRICEState{period: 14, high_buffer: [], low_buffer: [], lookback_count: 0}}

      iex> TheoryCraftTA.Elixir.Overlap.MIDPRICEState.init(1)
      {:error, "Invalid period: must be >= 2 for MIDPRICE"}

  """
  @spec init(integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) and period >= 2 do
    state = %__MODULE__{
      period: period,
      high_buffer: [],
      low_buffer: [],
      lookback_count: 0
    }

    {:ok, state}
  end

  def init(period) when is_integer(period) do
    {:error, "Invalid period: must be >= 2 for MIDPRICE"}
  end

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

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.MIDPRICEState.init(2)
      iex> {:ok, midprice, state2} = TheoryCraftTA.Elixir.Overlap.MIDPRICEState.next(state, 10.0, 8.0, true)
      iex> midprice
      nil
      iex> {:ok, midprice, _state3} = TheoryCraftTA.Elixir.Overlap.MIDPRICEState.next(state2, 11.0, 9.0, true)
      iex> midprice
      9.5

  """
  @spec next(t(), float(), float(), boolean()) :: {:ok, float() | nil, t()}
  def next(%__MODULE__{} = state, high_value, low_value, is_new_bar)
      when is_float(high_value) and is_float(low_value) and is_boolean(is_new_bar) do
    new_lookback =
      if is_new_bar do
        state.lookback_count + 1
      else
        state.lookback_count
      end

    {new_high_buffer, new_low_buffer} =
      if is_new_bar do
        updated_high = state.high_buffer ++ [high_value]
        updated_low = state.low_buffer ++ [low_value]

        high_buf =
          if length(updated_high) > state.period do
            Enum.drop(updated_high, 1)
          else
            updated_high
          end

        low_buf =
          if length(updated_low) > state.period do
            Enum.drop(updated_low, 1)
          else
            updated_low
          end

        {high_buf, low_buf}
      else
        high_buf =
          if state.high_buffer == [] do
            [high_value]
          else
            List.replace_at(state.high_buffer, -1, high_value)
          end

        low_buf =
          if state.low_buffer == [] do
            [low_value]
          else
            List.replace_at(state.low_buffer, -1, low_value)
          end

        {high_buf, low_buf}
      end

    if new_lookback < state.period do
      new_state = %{
        state
        | high_buffer: new_high_buffer,
          low_buffer: new_low_buffer,
          lookback_count: new_lookback
      }

      {:ok, nil, new_state}
    else
      highest_high = Enum.max(new_high_buffer)
      lowest_low = Enum.min(new_low_buffer)
      midprice = (highest_high + lowest_low) / 2

      new_state = %{
        state
        | high_buffer: new_high_buffer,
          low_buffer: new_low_buffer,
          lookback_count: new_lookback
      }

      {:ok, midprice, new_state}
    end
  end
end
