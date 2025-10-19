defmodule TheoryCraftTA.Overlap.HT_TRENDLINE do
  @moduledoc """
  HT_TRENDLINE - Hilbert Transform - Instantaneous Trendline.

  The HT_TRENDLINE uses the Hilbert Transform to smooth price data and identify
  the underlying trend by eliminating cyclic components and noise from the price series.

  This indicator requires a minimum of 63 data points for warmup before producing values.

  ## Calculation

  The Hilbert Transform applies a digital signal processing technique to decompose
  the price series into its trend and cyclic components. The instantaneous trendline
  represents the smoothed trend component after removing the dominant cycle.

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)

  ## Returns

    - `{:ok, result}` - Result of the same type as input with HT_TRENDLINE values
    - `{:error, reason}` - If validation fails or calculation error occurs

  ## Examples

      iex> data = Enum.map(1..100, fn i -> 50.0 + :math.sin(i / 10.0) * 10.0 end)
      iex> {:ok, result} = TheoryCraftTA.Overlap.HT_TRENDLINE.ht_trendline(data)
      iex> Enum.take(result, 63) |> Enum.all?(&(&1 == nil))
      true
      iex> is_float(Enum.at(result, 63))
      true

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates HT_TRENDLINE (Hilbert Transform - Instantaneous Trendline) for the given data.

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)

  ## Returns

    - `{:ok, result}` - Result of the same type as input
    - `{:error, reason}` - If validation or calculation fails

  ## Examples

      iex> data = Enum.map(1..100, fn i -> 50.0 + :math.sin(i / 10.0) * 10.0 end)
      iex> {:ok, result} = TheoryCraftTA.Overlap.HT_TRENDLINE.ht_trendline(data)
      iex> length(result)
      100

  """
  @spec ht_trendline(TheoryCraftTA.source()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def ht_trendline(data) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_ht_trendline(list_data) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new HT_TRENDLINE state for streaming calculation.

  ## Returns

    - `{:ok, state}` - Opaque state reference
    - `{:error, reason}` - If initialization fails

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.HT_TRENDLINE.init()

  """
  @spec init() :: {:ok, t()} | {:error, String.t()}
  def init do
    Native.overlap_ht_trendline_state_init()
  end

  @doc """
  Calculates the next HT_TRENDLINE value in streaming mode.

  ## Parameters

    - `state` - Current state reference
    - `value` - New price value
    - `is_new_bar` - true for APPEND (new bar), false for UPDATE (modify last bar)

  ## Returns

    - `{:ok, ht_value, new_state}` - HT_TRENDLINE value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.HT_TRENDLINE.init()
      iex> {:ok, nil, state2} = TheoryCraftTA.Overlap.HT_TRENDLINE.next(state, 100.0, true)
      iex> # After 63 bars, values start appearing
      iex> {:ok, state63} = Enum.reduce(1..62, {:ok, state2}, fn _, {:ok, s} ->
      ...>   {:ok, _ht, new_s} = TheoryCraftTA.Overlap.HT_TRENDLINE.next(s, 100.0, true)
      ...>   {:ok, new_s}
      ...> end)
      iex> {:ok, ht64, _state64} = TheoryCraftTA.Overlap.HT_TRENDLINE.next(state63, 100.0, true)
      iex> is_float(ht64)
      true

  """
  @spec next(t(), float(), boolean()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, value, is_new_bar) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_ht_trendline_state_next(state, value, is_new_bar) do
      {:ok, {ht_value, new_state}} ->
        {:ok, ht_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
