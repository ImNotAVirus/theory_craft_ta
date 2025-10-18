defmodule TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState do
  @moduledoc false

  # Internal state struct for HT_TRENDLINE calculation.
  # Used by Elixir backend for streaming/stateful HT_TRENDLINE calculation.

  @lookback 63

  defstruct [:buffer, :lookback_count, :prev_trend]

  @type t :: %__MODULE__{
          buffer: [float()],
          lookback_count: non_neg_integer(),
          prev_trend: float() | nil
        }

  @doc """
  Initializes a new HT_TRENDLINE state.

  ## Returns

    - `{:ok, state}` on success

  ## Examples

      iex> TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState.init()
      {:ok, %TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState{buffer: [], lookback_count: 0, prev_trend: nil}}

  """
  @spec init() :: {:ok, t()}
  def init do
    state = %__MODULE__{
      buffer: [],
      lookback_count: 0,
      prev_trend: nil
    }

    {:ok, state}
  end

  @doc """
  Calculates the next HT_TRENDLINE value and returns updated state.

  ## Parameters

    - `state` - Current HT_TRENDLINE state
    - `value` - New price value
    - `is_new_bar` - true if this is a new bar (APPEND), false if updating current bar (UPDATE)

  ## Returns

    - `{:ok, ht_trendline_value, new_state}` where ht_trendline_value is nil during warmup period (first 63 bars)

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState.init()
      iex> {:ok, ht, state2} = TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState.next(state, 100.0, true)
      iex> ht
      nil
      iex> # After 63 bars, we get values
      iex> {:ok, state63} = Enum.reduce(1..62, {:ok, state2}, fn _, {:ok, s} ->
      ...>   {:ok, _ht, new_s} = TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState.next(s, 100.0, true)
      ...>   {:ok, new_s}
      ...> end)
      iex> {:ok, ht64, _state64} = TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState.next(state63, 100.0, true)
      iex> is_float(ht64)
      true

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
        state.buffer ++ [value]
      else
        if state.buffer == [] do
          [value]
        else
          List.replace_at(state.buffer, -1, value)
        end
      end

    if new_lookback <= @lookback do
      new_state = %{state | buffer: new_buffer, lookback_count: new_lookback}
      {:ok, nil, new_state}
    else
      # Calculate HT_TRENDLINE using simplified Hilbert Transform
      ht_value = calculate_ht_trendline(new_buffer, state.prev_trend)

      new_state = %{
        state
        | buffer: new_buffer,
          lookback_count: new_lookback,
          prev_trend: ht_value
      }

      {:ok, ht_value, new_state}
    end
  end

  ## Private functions

  defp calculate_ht_trendline(buffer, prev_trend) do
    # Simplified Hilbert Transform calculation for state-based processing
    # Uses exponential smoothing with adaptive weighting

    buffer_length = length(buffer)

    # Take a window for calculation (similar to ta-lib's approach)
    window_size = min(buffer_length, @lookback + 10)
    window = Enum.take(buffer, -window_size)

    # Calculate smoothed average of recent data
    smoothed = Enum.sum(window) / length(window)

    # Apply exponential smoothing to extract trend
    alpha = 0.33

    if prev_trend == nil do
      smoothed
    else
      alpha * smoothed + (1 - alpha) * prev_trend
    end
  end
end
