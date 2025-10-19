defmodule TheoryCraftTA.Overlap.SAR do
  @moduledoc """
  SAR - Parabolic SAR (Stop and Reverse).

  The Parabolic SAR is a trend-following indicator that provides entry and exit points.
  It appears as dots placed above or below the price bars. When the dots flip from below
  to above (or vice versa), it signals a potential trend reversal.

  ## Calculation

  The SAR is calculated using an acceleration factor that increases each period when
  a new extreme point (EP) is recorded:

  1. Initial SAR = First low (for uptrend) or first high (for downtrend)
  2. SAR[t] = SAR[t-1] + AF × (EP - SAR[t-1])
     where:
     - AF = Acceleration Factor (starts at `acceleration`, increases by `acceleration`
       each time a new EP is recorded, capped at `maximum`)
     - EP = Extreme Point (highest high for uptrend, lowest low for downtrend)

  3. When SAR crosses price, the trend reverses and SAR flips to the other side

  ## Parameters

    - `high` - High prices (list of floats, DataSeries, or TimeSeries)
    - `low` - Low prices (list of floats, DataSeries, or TimeSeries)
    - `acceleration` - Acceleration Factor (default: 0.02, must be positive and <= maximum)
    - `maximum` - Maximum Acceleration Factor (default: 0.20, must be positive)

  ## Returns

    - `{:ok, result}` - Result of the same type as input with SAR values
    - `{:error, reason}` - If validation fails or calculation error occurs

  ## Examples

      iex> high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      iex> low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]
      iex> TheoryCraftTA.Overlap.SAR.sar(high, low)
      {:ok, [nil, 8.0, 8.06, 8.217600000000001, 8.504544000000001, 8.944180480000002,
             9.549762432000001, 10.323790940160002, 11.258460208537603, 12.337106575171585]}

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates Parabolic SAR for the given high and low prices.

  ## Parameters

    - `high` - High prices (list of floats, DataSeries, or TimeSeries)
    - `low` - Low prices (list of floats, DataSeries, or TimeSeries)
    - `acceleration` - Acceleration Factor (default: 0.02)
    - `maximum` - Maximum Acceleration Factor (default: 0.20)

  ## Returns

    - `{:ok, result}` - Result of the same type as input
    - `{:error, reason}` - If validation or calculation fails

  ## Examples

      iex> high = [10.0, 11.0, 12.0, 13.0, 14.0]
      iex> low = [8.0, 9.0, 10.0, 11.0, 12.0]
      iex> TheoryCraftTA.Overlap.SAR.sar(high, low)
      {:ok, [nil, 8.0, 8.06, 8.217600000000001, 8.504544000000001]}

  """
  @spec sar(
          TheoryCraftTA.source(),
          TheoryCraftTA.source(),
          float(),
          float()
        ) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def sar(high, low, acceleration \\ 0.02, maximum \\ 0.20) do
    list_high = Helpers.to_list_and_reverse(high)
    list_low = Helpers.to_list_and_reverse(low)

    case Native.overlap_sar(list_high, list_low, acceleration, maximum) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(high, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new SAR state for streaming calculation.

  ## Parameters

    - `acceleration` - Acceleration Factor (default: 0.02)
    - `maximum` - Maximum Acceleration Factor (default: 0.20)

  ## Returns

    - `{:ok, state}` - Opaque state reference
    - `{:error, reason}` - If validation fails

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.SAR.init()
      iex> {:ok, _state} = TheoryCraftTA.Overlap.SAR.init(0.03, 0.25)

  """
  @spec init(float(), float()) :: {:ok, t()} | {:error, String.t()}
  def init(acceleration \\ 0.02, maximum \\ 0.20) do
    Native.overlap_sar_state_init(acceleration, maximum)
  end

  @doc """
  Calculates the next SAR value in streaming mode.

  ## Parameters

    - `state` - Current state reference
    - `high` - High price for this bar
    - `low` - Low price for this bar
    - `is_new_bar` - true for APPEND (new bar), false for UPDATE (modify last bar)

  ## Returns

    - `{:ok, sar_value, new_state}` - SAR value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.SAR.init()
      iex> {:ok, nil, state} = TheoryCraftTA.Overlap.SAR.next(state, 10.0, 8.0, true)
      iex> {:ok, sar, _state} = TheoryCraftTA.Overlap.SAR.next(state, 11.0, 9.0, true)
      iex> is_float(sar)
      true

  """
  @spec next(t(), float(), float(), boolean()) ::
          {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, high, low, is_new_bar) do
    case Native.overlap_sar_state_next(state, high, low, is_new_bar) do
      {:ok, {sar_value, new_state}} ->
        {:ok, sar_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
