defmodule TheoryCraftTA.Overlap.KAMA do
  @moduledoc """
  KAMA - Kaufman Adaptive Moving Average.

  KAMA is a moving average designed to account for market noise and volatility.
  It adapts its smoothing constant based on the Efficiency Ratio (ER), which measures
  the strength of the trend relative to the noise in the price data.

  ## Calculation

  1. Calculate Efficiency Ratio (ER):
     - Direction = |Price[t] - Price[t-period]|
     - Volatility = Sum of |Price[i] - Price[i-1]| over period
     - ER = Direction / Volatility

  2. Calculate Smoothing Constant (SC):
     - Fastest SC = 2/(2+1) = 0.6667
     - Slowest SC = 2/(30+1) = 0.0645
     - SC = [ER × (Fastest SC - Slowest SC) + Slowest SC]²

  3. Calculate KAMA:
     - KAMA[0] = SMA of first period values
     - KAMA[t] = KAMA[t-1] + SC × (Price[t] - KAMA[t-1])

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the efficiency ratio calculation (must be >= 2)

  ## Returns

    - `{:ok, result}` - Result of the same type as input with KAMA values
    - `{:error, reason}` - If validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.KAMA.kama([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0], 5)
      {:ok, [nil, nil, nil, nil, nil, 5.44444444, 6.13580247, 6.96433471, 7.86907484, 8.81615269]}

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates KAMA (Kaufman Adaptive Moving Average) for the given data.

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for efficiency ratio (must be >= 2)

  ## Returns

    - `{:ok, result}` - Result of the same type as input
    - `{:error, reason}` - If validation or calculation fails

  ## Examples

      iex> TheoryCraftTA.Overlap.KAMA.kama([1.0, 2.0, 3.0, 4.0, 5.0], 2)
      {:ok, [nil, nil, 2.888888888888889, 3.7901234567901234, 4.783950617283951]}

  """
  @spec kama(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def kama(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_kama(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new KAMA state for streaming calculation.

  ## Parameters

    - `period` - Number of periods for efficiency ratio (must be >= 2)

  ## Returns

    - `{:ok, state}` - Opaque state reference
    - `{:error, reason}` - If validation fails

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.KAMA.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) do
    Native.overlap_kama_state_init(period)
  end

  @doc """
  Calculates the next KAMA value in streaming mode.

  ## Parameters

    - `value` - New price value
    - `is_new_bar` - true for APPEND (new bar), false for UPDATE (modify last bar)
    - `state` - Current state reference

  ## Returns

    - `{:ok, kama_value, new_state}` - KAMA value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.KAMA.init(5)
      iex> {:ok, nil, state} = TheoryCraftTA.Overlap.KAMA.next(1.0, true, state)
      iex> {:ok, nil, state} = TheoryCraftTA.Overlap.KAMA.next(2.0, true, state)
      iex> {:ok, nil, state} = TheoryCraftTA.Overlap.KAMA.next(3.0, true, state)
      iex> {:ok, nil, state} = TheoryCraftTA.Overlap.KAMA.next(4.0, true, state)
      iex> {:ok, nil, state} = TheoryCraftTA.Overlap.KAMA.next(5.0, true, state)
      iex> {:ok, kama, _state} = TheoryCraftTA.Overlap.KAMA.next(6.0, true, state)
      iex> is_float(kama)
      true

  """
  @spec next(float(), boolean(), t()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(value, is_new_bar, state) do
    Native.overlap_kama_state_next(value, is_new_bar, state)
  end
end
