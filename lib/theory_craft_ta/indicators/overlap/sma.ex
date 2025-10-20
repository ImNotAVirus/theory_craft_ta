defmodule TheoryCraftTA.Indicators.Overlap.SMA do
  @moduledoc """
  Simple Moving Average (SMA) indicator implementing TheoryCraft.Indicator behaviour.

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

      simulator = %MarketSimulator{}
      |> MarketSimulator.add_data(candle_stream, name: "eurusd_m5")
      |> MarketSimulator.add_indicator(
        TheoryCraftTA.Indicators.Overlap.SMA,
        period: 20,
        data: "eurusd_m5",
        name: "sma20",
        source: :close
      )
      |> MarketSimulator.stream()

  """

  alias __MODULE__
  alias TheoryCraft.MarketEvent
  alias TheoryCraftTA.Overlap.SMA, as: SMACore

  @behaviour TheoryCraft.Indicator

  @typedoc """
  SMA indicator state.
  """
  @type t :: %__MODULE__{
          period: pos_integer(),
          source: atom(),
          data_name: String.t(),
          output_name: String.t(),
          indicator_state: reference()
        }

  defstruct [:period, :source, :data_name, :output_name, :indicator_state]

  ## Indicator callbacks

  @impl true
  @spec init(Keyword.t()) :: {:ok, t()}
  def init(opts) do
    period = Keyword.fetch!(opts, :period)
    source = Keyword.get(opts, :source, :close)
    data_name = Keyword.fetch!(opts, :data)
    output_name = Keyword.fetch!(opts, :name)

    {:ok, indicator_state} = SMACore.init(period)

    state = %SMA{
      period: period,
      source: source,
      data_name: data_name,
      output_name: output_name,
      indicator_state: indicator_state
    }

    {:ok, state}
  end

  @impl true
  @spec next(MarketEvent.t(), t()) :: {:ok, MarketEvent.t(), t()}
  def next(%MarketEvent{} = event, %SMA{} = state) do
    %SMA{
      source: source,
      data_name: data_name,
      output_name: output_name,
      indicator_state: indicator_state
    } = state

    # Extract the candle from the event
    candle = Map.fetch!(event.data, data_name)

    # Get the value from the candle based on source
    value = Map.fetch!(candle, source)

    # Hardcoded to true for now, will be calculated later from MarketEvent
    is_new_bar = true

    case SMACore.next(value, is_new_bar, indicator_state) do
      {:ok, sma_value, new_indicator_state} ->
        new_state = %SMA{state | indicator_state: new_indicator_state}

        # Add the SMA value to the event data
        updated_data = Map.put(event.data, output_name, sma_value)
        updated_event = %MarketEvent{event | data: updated_data}

        {:ok, updated_event, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
