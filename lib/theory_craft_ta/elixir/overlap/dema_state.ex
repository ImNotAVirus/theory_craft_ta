defmodule TheoryCraftTA.Elixir.Overlap.DEMAState do
  @moduledoc false

  # Internal state struct for DEMA calculation.
  # Used by Elixir backend for streaming/stateful DEMA calculation.
  #
  # DEMA requires maintaining two EMA states internally:
  # - ema1_state: First EMA calculation
  # - ema2_state: Second EMA calculation (EMA of EMA1)

  alias TheoryCraftTA.Elixir.Overlap.EMAState

  defstruct [:period, :lookback_count, :ema1_state, :ema2_state]

  @type t :: %__MODULE__{
          period: pos_integer(),
          lookback_count: non_neg_integer(),
          ema1_state: EMAState.t(),
          ema2_state: EMAState.t()
        }

  @doc """
  Initializes a new DEMA state.

  ## Parameters

    - `period` - The DEMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.DEMAState.init(14)
      iex> state.period
      14

      iex> TheoryCraftTA.Elixir.Overlap.DEMAState.init(1)
      {:error, "Invalid period: must be >= 2 for DEMA"}

  """
  @spec init(integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) and period >= 2 do
    {:ok, ema1_state} = EMAState.init(period)
    {:ok, ema2_state} = EMAState.init(period)

    state = %__MODULE__{
      period: period,
      lookback_count: 0,
      ema1_state: ema1_state,
      ema2_state: ema2_state
    }

    {:ok, state}
  end

  def init(period) when is_integer(period) do
    {:error, "Invalid period: must be >= 2 for DEMA"}
  end

  @doc """
  Calculates the next DEMA value and returns updated state.

  ## Parameters

    - `state` - Current DEMA state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, dema_value, new_state}` where dema_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.DEMAState.init(2)
      iex> {:ok, dema, state2} = TheoryCraftTA.Elixir.Overlap.DEMAState.next(state, 100.0, true)
      iex> dema
      nil
      iex> {:ok, dema, state3} = TheoryCraftTA.Elixir.Overlap.DEMAState.next(state2, 110.0, true)
      iex> dema
      nil
      iex> {:ok, dema, _state4} = TheoryCraftTA.Elixir.Overlap.DEMAState.next(state3, 120.0, true)
      iex> dema
      120.0

  """
  @spec next(t(), float(), boolean()) :: {:ok, float() | nil, t()}
  def next(%__MODULE__{} = state, value, is_new_bar)
      when is_float(value) and is_boolean(is_new_bar) do
    # Update lookback count
    new_lookback =
      if is_new_bar do
        state.lookback_count + 1
      else
        state.lookback_count
      end

    # Calculate first EMA
    {:ok, ema1_value, new_ema1_state} = EMAState.next(state.ema1_state, value, is_new_bar)

    # Calculate second EMA (EMA of EMA1)
    # Only feed ema1_value to ema2 if ema1_value is not nil
    {ema2_value, new_ema2_state} =
      if ema1_value != nil do
        {:ok, ema2_val, new_ema2_st} = EMAState.next(state.ema2_state, ema1_value, is_new_bar)
        {ema2_val, new_ema2_st}
      else
        # During warmup of first EMA, don't update second EMA
        {nil, state.ema2_state}
      end

    # Calculate DEMA = 2 * EMA1 - EMA2
    dema_value =
      if ema1_value != nil and ema2_value != nil do
        2.0 * ema1_value - ema2_value
      else
        nil
      end

    new_state = %{
      state
      | lookback_count: new_lookback,
        ema1_state: new_ema1_state,
        ema2_state: new_ema2_state
    }

    {:ok, dema_value, new_state}
  end
end
