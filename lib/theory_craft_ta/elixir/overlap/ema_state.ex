defmodule TheoryCraftTA.Elixir.Overlap.EMAState do
  @moduledoc false

  # Internal state struct for EMA calculation.
  # Used by Elixir backend for streaming/stateful EMA calculation.

  defstruct [:period, :k, :current_ema, :lookback_count, :buffer]

  @type t :: %__MODULE__{
          period: pos_integer(),
          k: float(),
          current_ema: float() | nil,
          lookback_count: non_neg_integer(),
          buffer: [float()]
        }

  @doc """
  Initializes a new EMA state.

  ## Parameters

    - `period` - The EMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> TheoryCraftTA.Elixir.Overlap.EMAState.init(14)
      {:ok, %TheoryCraftTA.Elixir.Overlap.EMAState{period: 14, k: 0.13333333333333333, current_ema: nil, lookback_count: 0, buffer: []}}

      iex> TheoryCraftTA.Elixir.Overlap.EMAState.init(1)
      {:error, "Invalid period: must be >= 2 for EMA"}

  """
  @spec init(integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) and period >= 2 do
    state = %__MODULE__{
      period: period,
      k: 2.0 / (period + 1.0),
      current_ema: nil,
      lookback_count: 0,
      buffer: []
    }

    {:ok, state}
  end

  def init(period) when is_integer(period) do
    {:error, "Invalid period: must be >= 2 for EMA"}
  end

  @doc """
  Calculates the next EMA value and returns updated state.

  ## Parameters

    - `state` - Current EMA state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, ema_value, new_state}` where ema_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.EMAState.init(2)
      iex> {:ok, ema, state2} = TheoryCraftTA.Elixir.Overlap.EMAState.next(state, 100.0, true)
      iex> ema
      nil
      iex> {:ok, ema, _state3} = TheoryCraftTA.Elixir.Overlap.EMAState.next(state2, 110.0, true)
      iex> ema
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

    # Update buffer
    new_buffer =
      if is_new_bar do
        state.buffer ++ [value]
      else
        if state.buffer == [] do
          [value]
        else
          List.replace_at(state.buffer, -1, value)
        end
      end

    # During warmup, accumulate values in buffer
    if new_lookback < state.period do
      new_state = %{state | lookback_count: new_lookback, buffer: new_buffer}
      {:ok, nil, new_state}
    else
      # Calculate EMA
      new_ema =
        if state.current_ema == nil do
          # First EMA: use SMA as seed (average of all values in buffer)
          sum = Enum.sum(new_buffer)
          sum / state.period
        else
          # Subsequent EMAs: use EMA formula
          (value - state.current_ema) * state.k + state.current_ema
        end

      new_state = %{
        state
        | current_ema: new_ema,
          lookback_count: new_lookback,
          buffer: new_buffer
      }

      {:ok, new_ema, new_state}
    end
  end
end
