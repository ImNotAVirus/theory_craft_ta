defmodule TheoryCraftTA.Elixir.Overlap.SMAState do
  @moduledoc false

  # Internal state struct for SMA calculation.
  # Used by Elixir backend for streaming/stateful SMA calculation.

  defstruct [:period, :buffer, :lookback_count]

  @type t :: %__MODULE__{
          period: pos_integer(),
          buffer: [float()],
          lookback_count: non_neg_integer()
        }

  @doc """
  Initializes a new SMA state.

  ## Parameters

    - `period` - The SMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> TheoryCraftTA.Elixir.Overlap.SMAState.init(14)
      {:ok, %TheoryCraftTA.Elixir.Overlap.SMAState{period: 14, buffer: [], lookback_count: 0}}

      iex> TheoryCraftTA.Elixir.Overlap.SMAState.init(1)
      {:error, "Invalid period: must be >= 2 for SMA"}

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
    {:error, "Invalid period: must be >= 2 for SMA"}
  end

  @doc """
  Calculates the next SMA value and returns updated state.

  ## Parameters

    - `state` - Current SMA state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, sma_value, new_state}` where sma_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.SMAState.init(2)
      iex> {:ok, sma, state2} = TheoryCraftTA.Elixir.Overlap.SMAState.next(state, 100.0, true)
      iex> sma
      nil
      iex> {:ok, sma, _state3} = TheoryCraftTA.Elixir.Overlap.SMAState.next(state2, 110.0, true)
      iex> sma
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
      sum = Enum.sum(new_buffer)
      sma = sum / state.period

      new_state = %{state | buffer: new_buffer, lookback_count: new_lookback}
      {:ok, sma, new_state}
    end
  end
end
