defmodule TheoryCraftTA.Overlap.SMA do
  @moduledoc """
  Simple Moving Average (SMA).

  The Simple Moving Average calculates the arithmetic mean of prices over a specified
  period. It gives equal weight to all values in the period, making it useful for
  identifying trends and smoothing out price data.

  ## Calculation

  SMA = (P₁ + P₂ + ... + Pₙ) / n

  Where:
  - n = period
  - P₁ = most recent price
  - Pₙ = oldest price in the period

  ## Usage with TheoryCraft

  This module implements the `TheoryCraft.Indicator` behaviour and can be used
  with `TheoryCraft.Processors.IndicatorProcessor`:

      simulator = %MarketSimulator{}
      |> MarketSimulator.add_data(bar_stream, name: "eurusd_m5")
      |> MarketSimulator.add_indicator(
        TheoryCraftTA.Overlap.SMA,
        period: 20,
        data: "eurusd_m5",
        name: "sma20",
        source: :close
      )
      |> MarketSimulator.stream()

  """

  alias __MODULE__
  alias TheoryCraft.MarketEvent
  alias TheoryCraftTA.{Native, Helpers}

  @behaviour TheoryCraft.Indicator

  @type t :: %__MODULE__{
          period: pos_integer(),
          source: atom(),
          data_name: String.t(),
          output_name: String.t(),
          bar_name: String.t() | nil,
          state: reference()
        }

  defstruct [:period, :source, :data_name, :output_name, :bar_name, :state]

  ## Public API

  @doc """
  Calculates Simple Moving Average (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with SMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.SMA.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec sma(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def sma(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_sma(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new SMA state for streaming calculation.

  ## Parameters

  - `opts` - Keyword list with:
    - `:period` (required) - The SMA period (must be >= 2)
    - `:data` (required) - The name of the data stream to read from
    - `:name` (required) - The output name for the indicator
    - `:source` (optional) - The field to extract from bar (default: `:close`).
      Only used if the data is a bar/struct. If the data is a float/nil, this is ignored.
    - `:bar_name` (optional) - The name of the bar stream to extract `new_bar?` from (default: nil).
      If nil, uses `:data` name. If specified, will raise if bar not found.

  ## Returns

  - `{:ok, state}` - Initialized state
  - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.SMA.init(period: 14, data: "eurusd", name: "sma14", source: :close)

      iex> {:ok, _state} = TheoryCraftTA.Overlap.SMA.init(period: 14, data: "rsi", name: "sma_rsi", bar_name: "eurusd_m1")

  """
  @impl true
  @spec init(Keyword.t()) :: {:ok, t()}
  def init(opts) when is_list(opts) do
    period = Keyword.fetch!(opts, :period)
    source = Keyword.get(opts, :source, :close)
    data_name = Keyword.fetch!(opts, :data)
    output_name = Keyword.fetch!(opts, :name)
    bar_name = Keyword.get(opts, :bar_name, nil)

    case Native.overlap_sma_state_init(period) do
      {:ok, native_state} ->
        state = %SMA{
          period: period,
          source: source,
          data_name: data_name,
          output_name: output_name,
          bar_name: bar_name,
          state: native_state
        }

        {:ok, state}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Processes a MarketEvent and calculates the next SMA value.

  ## Parameters

  - `event` - The `MarketEvent` to process
  - `state` - The indicator state (from `init/1` or previous `next/2`)

  ## Returns

  - `{:ok, updated_event, new_state}` - Event with SMA value added
  - `{:error, message}` on error

  ## Nil Handling

  If the input value is `nil` (e.g., upstream indicator not yet ready), this function
  returns `nil` without modifying the state. This matches ta-lib behavior for chained
  indicators during warmup.

  ## Data Types

  The data extracted from `event.data[data_name]` can be:
  - A bar/struct with fields like `:close`, `:high`, etc. - uses the `:source` field
  - A float/nil value directly (e.g., from another indicator) - uses the value as-is

  """
  @impl true
  @spec next(MarketEvent.t(), t()) :: {:ok, MarketEvent.t(), t()}
  def next(%MarketEvent{data: event_data} = event, %SMA{} = state) do
    %SMA{
      source: source,
      data_name: data_name,
      output_name: output_name,
      bar_name: bar_name,
      state: native_state
    } = state

    value = Helpers.extract_value(event_data, data_name, source)
    is_new_bar = Helpers.extract_is_new_bar(event_data, data_name, bar_name)

    {:ok, {sma_value, new_native_state}} =
      Native.overlap_sma_state_next(native_state, value, is_new_bar)

    new_state = %SMA{state | state: new_native_state}
    updated_data = Map.put(event.data, output_name, sma_value)
    updated_event = %MarketEvent{event | data: updated_data}

    {:ok, updated_event, new_state}
  end
end
