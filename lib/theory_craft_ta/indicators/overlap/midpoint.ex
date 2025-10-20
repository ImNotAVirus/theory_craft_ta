defmodule TheoryCraftTA.Indicators.Overlap.MIDPOINT do
  @moduledoc """
  Midpoint over period indicator implementing TheoryCraft.Indicator behaviour.

  ## Usage with TheoryCraft

      simulator = %MarketSimulator{}
      |> MarketSimulator.add_data(candle_stream, name: "eurusd_m5")
      |> MarketSimulator.add_indicator(
        TheoryCraftTA.Indicators.Overlap.MIDPOINT,
        period: 20,
        data: "eurusd_m5",
        name: "midpoint20",
        source: :close
      )
      |> MarketSimulator.stream()

  """

  alias __MODULE__
  alias TheoryCraft.MarketEvent
  alias TheoryCraftTA.Overlap.MIDPOINT, as: MIDPOINTCore

  @behaviour TheoryCraft.Indicator

  @typedoc """
  MIDPOINT indicator state.
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

    {:ok, indicator_state} = MIDPOINTCore.init(period)

    state = %MIDPOINT{
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
  def next(%MarketEvent{} = event, %MIDPOINT{} = state) do
    %MIDPOINT{
      source: source,
      data_name: data_name,
      output_name: output_name,
      indicator_state: indicator_state
    } = state

    candle = Map.fetch!(event.data, data_name)
    value = Map.fetch!(candle, source)

    # Hardcoded to true for now, will be calculated later from MarketEvent
    is_new_bar = true

    case MIDPOINTCore.next(value, is_new_bar, indicator_state) do
      {:ok, midpoint_value, new_indicator_state} ->
        new_state = %MIDPOINT{state | indicator_state: new_indicator_state}

        updated_data = Map.put(event.data, output_name, midpoint_value)
        updated_event = %MarketEvent{event | data: updated_data}

        {:ok, updated_event, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
