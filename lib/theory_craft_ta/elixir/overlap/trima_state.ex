defmodule TheoryCraftTA.Elixir.Overlap.TRIMAState do
  @moduledoc false

  # Internal state struct for TRIMA calculation.
  # Used by Elixir backend for streaming/stateful TRIMA calculation.
  #
  # TRIMA is SMA of SMA, so we need two buffers:
  # - first_sma_buffer: for calculating the first SMA
  # - second_sma_buffer: for calculating the second SMA (TRIMA)

  defstruct [
    :period,
    :first_period,
    :second_period,
    :first_sma_buffer,
    :second_sma_buffer,
    :lookback_count
  ]

  @type t :: %__MODULE__{
          period: pos_integer(),
          first_period: pos_integer(),
          second_period: pos_integer(),
          first_sma_buffer: [float()],
          second_sma_buffer: [float()],
          lookback_count: non_neg_integer()
        }

  @doc """
  Initializes a new TRIMA state.

  ## Parameters

    - `period` - The TRIMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` on success
    - `{:error, message}` if period is invalid

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.TRIMAState.init(14)
      iex> state.period
      14

      iex> TheoryCraftTA.Elixir.Overlap.TRIMAState.init(1)
      {:error, "Invalid period: must be >= 2 for TRIMA"}

  """
  @spec init(integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) and period >= 2 do
    # Calculate periods for double smoothing
    {first_period, second_period} =
      if period < 3 do
        # For period < 3, TRIMA = SMA
        {period, period}
      else
        if rem(period, 2) == 1 do
          # Odd period
          half = div(period + 1, 2)
          {half, half}
        else
          # Even period
          half = div(period, 2)
          {half, half + 1}
        end
      end

    state = %__MODULE__{
      period: period,
      first_period: first_period,
      second_period: second_period,
      first_sma_buffer: [],
      second_sma_buffer: [],
      lookback_count: 0
    }

    {:ok, state}
  end

  def init(period) when is_integer(period) do
    {:error, "Invalid period: must be >= 2 for TRIMA"}
  end

  @doc """
  Calculates the next TRIMA value and returns updated state.

  ## Parameters

    - `state` - Current TRIMA state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, trima_value, new_state}` where trima_value is nil during warmup period

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.TRIMAState.init(2)
      iex> {:ok, trima, state2} = TheoryCraftTA.Elixir.Overlap.TRIMAState.next(state, 100.0, true)
      iex> trima
      nil
      iex> {:ok, trima, _state3} = TheoryCraftTA.Elixir.Overlap.TRIMAState.next(state2, 110.0, true)
      iex> trima
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

    # Update first SMA buffer
    new_first_buffer =
      if is_new_bar do
        updated = state.first_sma_buffer ++ [value]

        if length(updated) > state.first_period do
          Enum.drop(updated, 1)
        else
          updated
        end
      else
        if state.first_sma_buffer == [] do
          [value]
        else
          List.replace_at(state.first_sma_buffer, -1, value)
        end
      end

    # Calculate first SMA if we have enough data
    first_sma =
      if length(new_first_buffer) >= state.first_period do
        Enum.sum(new_first_buffer) / state.first_period
      else
        nil
      end

    # Update second SMA buffer with first SMA value
    new_second_buffer =
      if first_sma == nil do
        state.second_sma_buffer
      else
        if is_new_bar do
          updated = state.second_sma_buffer ++ [first_sma]

          if length(updated) > state.second_period do
            Enum.drop(updated, 1)
          else
            updated
          end
        else
          if state.second_sma_buffer == [] do
            [first_sma]
          else
            List.replace_at(state.second_sma_buffer, -1, first_sma)
          end
        end
      end

    # Calculate TRIMA (second SMA)
    trima =
      if state.period < 3 do
        # For period < 3, TRIMA = first SMA
        first_sma
      else
        if length(new_second_buffer) >= state.second_period do
          Enum.sum(new_second_buffer) / state.second_period
        else
          nil
        end
      end

    new_state = %{
      state
      | first_sma_buffer: new_first_buffer,
        second_sma_buffer: new_second_buffer,
        lookback_count: new_lookback
    }

    {:ok, trima, new_state}
  end
end
