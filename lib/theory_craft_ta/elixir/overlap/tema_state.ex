defmodule TheoryCraftTA.Elixir.Overlap.TEMAState do
  @moduledoc false

  # Internal state struct for TEMA calculation.
  # Used by Elixir backend for streaming/stateful TEMA calculation.
  #
  # TEMA requires maintaining three EMA states internally:
  # - ema1_state: First EMA calculation
  # - ema2_state: Second EMA calculation (EMA of EMA1)
  # - ema3_state: Third EMA calculation (EMA of EMA2)

  alias TheoryCraftTA.Elixir.Overlap.EMAState

  defstruct [:period, :lookback_count, :ema1_state, :ema2_state, :ema3_state]

  @type t :: %__MODULE__{
          period: pos_integer(),
          lookback_count: non_neg_integer(),
          ema1_state: EMAState.t(),
          ema2_state: EMAState.t(),
          ema3_state: EMAState.t()
        }

  @doc """
  Initializes a new TEMA state.

  ## Parameters

    - `period` - The TEMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.TEMAState.init(14)
      iex> state.period
      14

      iex> TheoryCraftTA.Elixir.Overlap.TEMAState.init(1)
      {:error, "Invalid period: must be >= 2 for TEMA"}

  """
  @spec init(integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) and period >= 2 do
    {:ok, ema1_state} = EMAState.init(period)
    {:ok, ema2_state} = EMAState.init(period)
    {:ok, ema3_state} = EMAState.init(period)

    state = %__MODULE__{
      period: period,
      lookback_count: 0,
      ema1_state: ema1_state,
      ema2_state: ema2_state,
      ema3_state: ema3_state
    }

    {:ok, state}
  end

  def init(period) when is_integer(period) do
    {:error, "Invalid period: must be >= 2 for TEMA"}
  end

  @doc """
  Calculates the next TEMA value and returns updated state.

  ## Parameters

    - `state` - Current TEMA state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, tema_value, new_state}` where tema_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.TEMAState.init(2)
      iex> {:ok, tema, state2} = TheoryCraftTA.Elixir.Overlap.TEMAState.next(state, 100.0, true)
      iex> tema
      nil
      iex> {:ok, tema, state3} = TheoryCraftTA.Elixir.Overlap.TEMAState.next(state2, 110.0, true)
      iex> tema
      nil
      iex> {:ok, tema, state4} = TheoryCraftTA.Elixir.Overlap.TEMAState.next(state3, 120.0, true)
      iex> tema
      nil
      iex> {:ok, tema, _state5} = TheoryCraftTA.Elixir.Overlap.TEMAState.next(state4, 130.0, true)
      iex> tema
      130.0

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

    # Calculate third EMA (EMA of EMA2)
    # Only feed ema2_value to ema3 if ema2_value is not nil
    {ema3_value, new_ema3_state} =
      if ema2_value != nil do
        {:ok, ema3_val, new_ema3_st} = EMAState.next(state.ema3_state, ema2_value, is_new_bar)
        {ema3_val, new_ema3_st}
      else
        # During warmup of second EMA, don't update third EMA
        {nil, state.ema3_state}
      end

    # Calculate TEMA = 3 * EMA1 - 3 * EMA2 + EMA3
    tema_value =
      if ema1_value != nil and ema2_value != nil and ema3_value != nil do
        3.0 * ema1_value - 3.0 * ema2_value + ema3_value
      else
        nil
      end

    new_state = %{
      state
      | lookback_count: new_lookback,
        ema1_state: new_ema1_state,
        ema2_state: new_ema2_state,
        ema3_state: new_ema3_state
    }

    {:ok, tema_value, new_state}
  end
end
