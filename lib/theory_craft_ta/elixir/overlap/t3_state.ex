defmodule TheoryCraftTA.Elixir.Overlap.T3State do
  @moduledoc false

  # Internal state struct for T3 calculation.
  # Used by Elixir backend for streaming/stateful T3 calculation.
  #
  # T3 requires maintaining six EMA states internally:
  # - ema1_state through ema6_state: Six successive EMA calculations
  # - vfactor: Volume factor for smoothing

  alias TheoryCraftTA.Elixir.Overlap.EMAState

  defstruct [
    :period,
    :vfactor,
    :lookback_count,
    :ema1_state,
    :ema2_state,
    :ema3_state,
    :ema4_state,
    :ema5_state,
    :ema6_state
  ]

  @type t :: %__MODULE__{
          period: pos_integer(),
          vfactor: float(),
          lookback_count: non_neg_integer(),
          ema1_state: EMAState.t(),
          ema2_state: EMAState.t(),
          ema3_state: EMAState.t(),
          ema4_state: EMAState.t(),
          ema5_state: EMAState.t(),
          ema6_state: EMAState.t()
        }

  @doc """
  Initializes a new T3 state.

  ## Parameters

    - `period` - The T3 period (must be >= 2)
    - `vfactor` - Volume factor (typically 0.0 to 1.0, default 0.7)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.T3State.init(14, 0.7)
      iex> state.period
      14

      iex> TheoryCraftTA.Elixir.Overlap.T3State.init(1, 0.7)
      {:error, "Invalid period: must be >= 2 for T3"}

  """
  @spec init(integer(), float()) :: {:ok, t()} | {:error, String.t()}
  def init(period, vfactor) when is_integer(period) and period >= 2 do
    {:ok, ema1_state} = EMAState.init(period)
    {:ok, ema2_state} = EMAState.init(period)
    {:ok, ema3_state} = EMAState.init(period)
    {:ok, ema4_state} = EMAState.init(period)
    {:ok, ema5_state} = EMAState.init(period)
    {:ok, ema6_state} = EMAState.init(period)

    state = %__MODULE__{
      period: period,
      vfactor: vfactor,
      lookback_count: 0,
      ema1_state: ema1_state,
      ema2_state: ema2_state,
      ema3_state: ema3_state,
      ema4_state: ema4_state,
      ema5_state: ema5_state,
      ema6_state: ema6_state
    }

    {:ok, state}
  end

  def init(period, _vfactor) when is_integer(period) do
    {:error, "Invalid period: must be >= 2 for T3"}
  end

  @doc """
  Calculates the next T3 value and returns updated state.

  ## Parameters

    - `state` - Current T3 state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, t3_value, new_state}` where t3_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.T3State.init(2, 0.7)
      iex> {:ok, t3, state2} = TheoryCraftTA.Elixir.Overlap.T3State.next(state, 100.0, true)
      iex> t3
      nil
      iex> {:ok, t3, _state3} = TheoryCraftTA.Elixir.Overlap.T3State.next(state2, 110.0, true)
      iex> t3
      nil

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
    {ema2_value, new_ema2_state} =
      if ema1_value != nil do
        {:ok, ema2_val, new_ema2_st} = EMAState.next(state.ema2_state, ema1_value, is_new_bar)
        {ema2_val, new_ema2_st}
      else
        {nil, state.ema2_state}
      end

    # Calculate third EMA (EMA of EMA2)
    {ema3_value, new_ema3_state} =
      if ema2_value != nil do
        {:ok, ema3_val, new_ema3_st} = EMAState.next(state.ema3_state, ema2_value, is_new_bar)
        {ema3_val, new_ema3_st}
      else
        {nil, state.ema3_state}
      end

    # Calculate fourth EMA (EMA of EMA3)
    {ema4_value, new_ema4_state} =
      if ema3_value != nil do
        {:ok, ema4_val, new_ema4_st} = EMAState.next(state.ema4_state, ema3_value, is_new_bar)
        {ema4_val, new_ema4_st}
      else
        {nil, state.ema4_state}
      end

    # Calculate fifth EMA (EMA of EMA4)
    {ema5_value, new_ema5_state} =
      if ema4_value != nil do
        {:ok, ema5_val, new_ema5_st} = EMAState.next(state.ema5_state, ema4_value, is_new_bar)
        {ema5_val, new_ema5_st}
      else
        {nil, state.ema5_state}
      end

    # Calculate sixth EMA (EMA of EMA5)
    {ema6_value, new_ema6_state} =
      if ema5_value != nil do
        {:ok, ema6_val, new_ema6_st} = EMAState.next(state.ema6_state, ema5_value, is_new_bar)
        {ema6_val, new_ema6_st}
      else
        {nil, state.ema6_state}
      end

    # Calculate coefficients based on vfactor
    c1 = -state.vfactor * state.vfactor * state.vfactor
    c2 = 3.0 * state.vfactor * state.vfactor + 3.0 * state.vfactor * state.vfactor * state.vfactor

    c3 =
      -6.0 * state.vfactor * state.vfactor - 3.0 * state.vfactor -
        3.0 * state.vfactor * state.vfactor * state.vfactor

    c4 =
      1.0 + 3.0 * state.vfactor + state.vfactor * state.vfactor * state.vfactor +
        3.0 * state.vfactor * state.vfactor

    # Calculate T3 = c1*e6 + c2*e5 + c3*e4 + c4*e3
    t3_value =
      if ema3_value != nil and ema4_value != nil and ema5_value != nil and ema6_value != nil do
        c1 * ema6_value + c2 * ema5_value + c3 * ema4_value + c4 * ema3_value
      else
        nil
      end

    new_state = %{
      state
      | lookback_count: new_lookback,
        ema1_state: new_ema1_state,
        ema2_state: new_ema2_state,
        ema3_state: new_ema3_state,
        ema4_state: new_ema4_state,
        ema5_state: new_ema5_state,
        ema6_state: new_ema6_state
    }

    {:ok, t3_value, new_state}
  end
end
