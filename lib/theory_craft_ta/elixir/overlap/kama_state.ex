defmodule TheoryCraftTA.Elixir.Overlap.KAMAState do
  @moduledoc false

  # Internal state struct for KAMA calculation.
  # Used by Elixir backend for streaming/stateful KAMA calculation.

  defstruct [:period, :buffer, :lookback_count, :prev_kama, :fastest_sc, :slowest_sc]

  @type t :: %__MODULE__{
          period: pos_integer(),
          buffer: [float()],
          lookback_count: non_neg_integer(),
          prev_kama: float() | nil,
          fastest_sc: float(),
          slowest_sc: float()
        }

  @doc """
  Initializes a new KAMA state.

  ## Parameters

    - `period` - The KAMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> TheoryCraftTA.Elixir.Overlap.KAMAState.init(10)
      {:ok, %TheoryCraftTA.Elixir.Overlap.KAMAState{period: 10, buffer: [], lookback_count: 0, prev_kama: nil, fastest_sc: 0.6666666666666666, slowest_sc: 0.06451612903225806}}

      iex> TheoryCraftTA.Elixir.Overlap.KAMAState.init(1)
      {:error, "Invalid period: must be >= 2 for KAMA"}

  """
  @spec init(integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) and period >= 2 do
    # Fastest SC = 2/(2+1) = 2/3
    # Slowest SC = 2/(30+1) = 2/31
    fastest_sc = 2.0 / 3.0
    slowest_sc = 2.0 / 31.0

    state = %__MODULE__{
      period: period,
      buffer: [],
      lookback_count: 0,
      prev_kama: nil,
      fastest_sc: fastest_sc,
      slowest_sc: slowest_sc
    }

    {:ok, state}
  end

  def init(period) when is_integer(period) do
    {:error, "Invalid period: must be >= 2 for KAMA"}
  end

  @doc """
  Calculates the next KAMA value and returns updated state.

  ## Parameters

    - `state` - Current KAMA state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, kama_value, new_state}` where kama_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.KAMAState.init(5)
      iex> {:ok, kama, state2} = TheoryCraftTA.Elixir.Overlap.KAMAState.next(state, 1.0, true)
      iex> kama
      nil
      iex> {:ok, kama, state3} = TheoryCraftTA.Elixir.Overlap.KAMAState.next(state2, 2.0, true)
      iex> kama
      nil
      iex> {:ok, kama, state4} = TheoryCraftTA.Elixir.Overlap.KAMAState.next(state3, 3.0, true)
      iex> kama
      nil
      iex> {:ok, kama, state5} = TheoryCraftTA.Elixir.Overlap.KAMAState.next(state4, 4.0, true)
      iex> kama
      nil
      iex> {:ok, kama, state6} = TheoryCraftTA.Elixir.Overlap.KAMAState.next(state5, 5.0, true)
      iex> kama
      nil
      iex> {:ok, kama, _state7} = TheoryCraftTA.Elixir.Overlap.KAMAState.next(state6, 6.0, true)
      iex> Float.round(kama, 5)
      5.44444

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

        if length(updated) > state.period + 1 do
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

    if new_lookback <= state.period do
      new_state = %{state | buffer: new_buffer, lookback_count: new_lookback}
      {:ok, nil, new_state}
    else
      # Calculate KAMA
      kama =
        if state.prev_kama == nil do
          # First KAMA value - use value at lookback position
          Enum.at(new_buffer, state.period)
        else
          calculate_kama(new_buffer, value, state)
        end

      new_state = %{state | buffer: new_buffer, lookback_count: new_lookback, prev_kama: kama}
      {:ok, kama, new_state}
    end
  end

  ## Private functions

  defp calculate_kama(buffer, price, state) do
    # Calculate Efficiency Ratio (ER)
    change = abs(Enum.at(buffer, -1) - Enum.at(buffer, 0))

    volatility =
      buffer
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> abs(b - a) end)
      |> Enum.sum()

    er = if volatility == 0.0, do: 0.0, else: change / volatility

    # Smoothing Constant (SC)
    sc = :math.pow(er * (state.fastest_sc - state.slowest_sc) + state.slowest_sc, 2)

    # KAMA calculation
    state.prev_kama + sc * (price - state.prev_kama)
  end
end
