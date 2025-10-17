defmodule TheoryCraftTA.Elixir.OverlapState.WMA do
  @moduledoc false

  # Internal state struct for WMA calculation.
  # Used by Elixir backend for streaming/stateful WMA calculation.

  defstruct [:period, :buffer, :lookback_count]

  @type t :: %__MODULE__{
          period: pos_integer(),
          buffer: [float()],
          lookback_count: non_neg_integer()
        }

  @doc """
  Initializes a new WMA state.

  ## Parameters

    - `period` - The WMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> TheoryCraftTA.Elixir.OverlapState.WMA.init(14)
      {:ok, %TheoryCraftTA.Elixir.OverlapState.WMA{period: 14, buffer: [], lookback_count: 0}}

      iex> TheoryCraftTA.Elixir.OverlapState.WMA.init(1)
      {:error, "Invalid period: must be >= 2 for WMA"}

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
    {:error, "Invalid period: must be >= 2 for WMA"}
  end

  @doc """
  Calculates the next WMA value and returns updated state.

  ## Parameters

    - `state` - Current WMA state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, wma_value, new_state}` where wma_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.OverlapState.WMA.init(2)
      iex> {:ok, wma, state2} = TheoryCraftTA.Elixir.OverlapState.WMA.next(state, 100.0, true)
      iex> wma
      nil
      iex> {:ok, wma, _state3} = TheoryCraftTA.Elixir.OverlapState.WMA.next(state2, 110.0, true)
      iex> Float.round(wma, 5)
      106.66667

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
      wma = calculate_weighted_average(new_buffer, state.period)

      new_state = %{state | buffer: new_buffer, lookback_count: new_lookback}
      {:ok, wma, new_state}
    end
  end

  ## Private functions

  defp calculate_weighted_average(buffer, period) do
    # Calculate sum of weights: 1 + 2 + 3 + ... + period = period * (period + 1) / 2
    sum_weights = period * (period + 1) / 2

    # Calculate weighted sum: buffer[0] * 1 + buffer[1] * 2 + ... + buffer[period-1] * period
    weighted_sum =
      buffer
      |> Enum.with_index(1)
      |> Enum.reduce(0.0, fn {value, weight}, acc ->
        acc + value * weight
      end)

    weighted_sum / sum_weights
  end
end
