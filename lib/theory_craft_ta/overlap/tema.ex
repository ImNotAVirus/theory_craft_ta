defmodule TheoryCraftTA.Overlap.TEMA do
  @moduledoc """
  Triple Exponential Moving Average (TEMA).

  The Triple Exponential Moving Average further reduces lag by applying EMA three times.
  It is highly responsive to recent price movements.

  ## Calculation

  TEMA = 3×EMA - 3×EMA(EMA) + EMA(EMA(EMA))

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
        |> MarketSimulator.add_indicator(TA.tema(eurusd_m5[:close], 20, name: "tema20"))
        |> MarketSimulator.stream()

  """

  alias __MODULE__
  alias TheoryCraft.MarketSource.{IndicatorValue, MarketEvent}
  alias TheoryCraftTA.{Helpers, Native}

  @behaviour TheoryCraft.MarketSource.Indicator

  @type t :: %__MODULE__{
          period: pos_integer(),
          source: atom(),
          data_name: String.t(),
          state: reference()
        }

  defstruct [:period, :source, :data_name, :state]

  ## Public API

  @doc """
  Calculates Triple Exponential Moving Average (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with TEMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.TEMA.tema([1.0, 2.0, 3.0, 4.0, 5.0], 2)
      {:ok, [nil, nil, nil, 4.0, 5.0]}

  """
  @spec tema(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def tema(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_tema(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new TEMA state for streaming calculation.

  ## Parameters

  - `opts` - Keyword list with:
    - `:period` (required) - The TEMA period (must be >= 2)
    - `:data` (required) - The name of the data stream to read from
    - `:name` (required) - The output name for the indicator
    - `:source` (optional) - The field to extract from bar (default: `:close`).
      Only used if the data is a bar/struct. If the data is a float/nil, this is ignored.

  ## Returns

  - `{:ok, state}` - Initialized state
  - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.TEMA.init(period: 14, data: "eurusd", name: "tema14", source: :close)

  """
  @impl true
  @spec init(Keyword.t()) :: {:ok, t()}
  def init(opts) when is_list(opts) do
    period = Keyword.fetch!(opts, :period)
    source = Keyword.get(opts, :source, :close)
    data_name = Keyword.fetch!(opts, :data)

    case Native.overlap_tema_state_init(period) do
      {:ok, native_state} ->
        state = %TEMA{
          period: period,
          source: source,
          data_name: data_name,
          state: native_state
        }

        {:ok, state}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Processes a MarketEvent and calculates the next TEMA value.

  ## Parameters

  - `event` - The `MarketEvent` to process
  - `state` - The indicator state (from `init/1` or previous `next/2`)

  ## Returns

  - `{:ok, indicator_value, new_state}` - IndicatorValue with TEMA calculation
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
  def next(%MarketEvent{} = event, %TEMA{} = state) do
    %TEMA{
      source: source,
      data_name: data_name,
      state: native_state
    } = state

    value = MarketEvent.extract_value(event, data_name, source)
    is_new_bar = MarketEvent.new_bar?(event, data_name)

    {:ok, {tema_value, new_native_state}} =
      Native.overlap_tema_state_next(native_state, value, is_new_bar)

    new_state = %TEMA{state | state: new_native_state}

    indicator_value = %IndicatorValue{
      value: tema_value,
      data_name: data_name
    }

    {:ok, indicator_value, new_state}
  end
end
