defmodule TheoryCraftTA.Overlap.TRIMA do
  @moduledoc """
  Triangular Moving Average (TRIMA).

  The Triangular Moving Average applies double smoothing by calculating the SMA of an SMA.
  This produces a smoother average with less sensitivity to price spikes.

  ## Calculation

  TRIMA = SMA(SMA(price))

  Where:
  - n = period
  - P₁ = most recent price
  - Pₙ = oldest price in the period

  ## Usage with TheoryCraft

  This module implements the `TheoryCraft.Indicator` behaviour and can be used
  with `TheoryCraft.MarketSimulator`:

      require TheoryCraftTA.TA, as: TA

      simulator =
        %MarketSimulator{}
        |> MarketSimulator.add_data(bar_stream, name: "eurusd_m5")
        |> MarketSimulator.add_indicator(TA.trima(eurusd_m5[:close], 20, name: "trima20"))
        |> MarketSimulator.stream()

  """

  alias __MODULE__
  alias TheoryCraft.{IndicatorValue, MarketEvent}
  alias TheoryCraftTA.{Native, Helpers}

  @behaviour TheoryCraft.Indicator

  @type t :: %__MODULE__{
          period: pos_integer(),
          source: atom(),
          data_name: String.t(),
          output_name: String.t(),
          state: reference()
        }

  defstruct [:period, :source, :data_name, :output_name, :state]

  ## Public API

  @doc """
  Calculates Triangular Moving Average (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with TRIMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.TRIMA.trima([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec trima(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def trima(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_trima(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new TRIMA state for streaming calculation.

  ## Parameters

  - `opts` - Keyword list with:
    - `:period` (required) - The TRIMA period (must be >= 2)
    - `:data` (required) - The name of the data stream to read from
    - `:name` (required) - The output name for the indicator
    - `:source` (optional) - The field to extract from bar (default: `:close`).
      Only used if the data is a bar/struct. If the data is a float/nil, this is ignored.

  ## Returns

  - `{:ok, state}` - Initialized state
  - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.TRIMA.init(period: 14, data: "eurusd", name: "trima14", source: :close)

  """
  @impl true
  @spec init(Keyword.t()) :: {:ok, t()}
  def init(opts) when is_list(opts) do
    period = Keyword.fetch!(opts, :period)
    source = Keyword.get(opts, :source, :close)
    data_name = Keyword.fetch!(opts, :data)
    output_name = Keyword.fetch!(opts, :name)

    case Native.overlap_trima_state_init(period) do
      {:ok, native_state} ->
        state = %TRIMA{
          period: period,
          source: source,
          data_name: data_name,
          output_name: output_name,
          state: native_state
        }

        {:ok, state}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Processes a MarketEvent and calculates the next TRIMA value.

  ## Parameters

  - `event` - The `MarketEvent` to process
  - `state` - The indicator state (from `init/1` or previous `next/2`)

  ## Returns

  - `{:ok, indicator_value, new_state}` - IndicatorValue with TRIMA calculation
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
  @spec next(MarketEvent.t(), t()) :: {:ok, IndicatorValue.t(), t()}
  def next(%MarketEvent{} = event, %TRIMA{} = state) do
    %TRIMA{
      source: source,
      data_name: data_name,
      output_name: output_name,
      state: native_state
    } = state

    value = MarketEvent.extract_value(event, data_name, source)
    is_new_bar = MarketEvent.new_bar?(event, data_name)

    {:ok, {trima_value, new_native_state}} =
      Native.overlap_trima_state_next(native_state, value, is_new_bar)

    new_state = %TRIMA{state | state: new_native_state}

    indicator_value = %IndicatorValue{
      value: trima_value,
      data_name: output_name
    }

    {:ok, indicator_value, new_state}
  end
end
