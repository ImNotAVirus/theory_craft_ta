defmodule TheoryCraftTA.Helpers do
  @moduledoc false

  # This module provides internal helper functions for TheoryCraftTA.
  # It handles conversions between different input types (list, DataSeries, TimeSeries)
  # and ensures the same type is returned as output.

  alias TheoryCraft.{DataSeries, TimeSeries}
  alias TheoryCraft.MarketSource.Bar

  ## Public API

  @doc """
  Converts input to a list and reverses if it's a DataSeries or TimeSeries.

  DataSeries and TimeSeries store data newest-first, but ta-lib expects oldest-first.
  This function handles the conversion and reversal.

  ## Parameters
    - `data` - Can be a list, DataSeries, or TimeSeries

  ## Returns
    - A list of values in oldest-first order

  ## Examples

      iex> TheoryCraftTA.Helpers.to_list_and_reverse([1.0, 2.0, 3.0])
      [1.0, 2.0, 3.0]

      iex> ds = TheoryCraft.DataSeries.new() |> TheoryCraft.DataSeries.add(1.0) |> TheoryCraft.DataSeries.add(2.0)
      iex> TheoryCraftTA.Helpers.to_list_and_reverse(ds)
      [1.0, 2.0]

  """
  @spec to_list_and_reverse(TheoryCraftTA.source()) :: list(float() | nil)
  def to_list_and_reverse(%DataSeries{} = ds) do
    ds |> DataSeries.values() |> Enum.reverse()
  end

  def to_list_and_reverse(%TimeSeries{} = ts) do
    ts |> TimeSeries.values() |> Enum.reverse()
  end

  def to_list_and_reverse(list) when is_list(list), do: list

  @doc """
  Rebuilds the same type of data structure with new values.

  Takes the original input and a list of calculated values, and reconstructs
  the same type (list, DataSeries, or TimeSeries) with the new values.

  ## Parameters
    - `original` - The original input (list, DataSeries, or TimeSeries)
    - `result_list` - The calculated values (oldest-first)

  ## Returns
    - The same type as `original` with the new values

  ## Examples

      iex> TheoryCraftTA.Helpers.rebuild_same_type([1.0, 2.0], [10.0, 20.0])
      [10.0, 20.0]

      iex> ds = TheoryCraft.DataSeries.new() |> TheoryCraft.DataSeries.add(1.0) |> TheoryCraft.DataSeries.add(2.0)
      iex> result = TheoryCraftTA.Helpers.rebuild_same_type(ds, [10.0, 20.0])
      iex> TheoryCraft.DataSeries.values(result)
      [20.0, 10.0]

  """
  @spec rebuild_same_type(TheoryCraftTA.source(), list(float() | nil)) ::
          TheoryCraftTA.source()
  def rebuild_same_type(%DataSeries{} = original, result_list) do
    # result_list is oldest-first, DataSeries stores newest-first
    %DataSeries{original | data: Enum.reverse(result_list)}
  end

  def rebuild_same_type(%TimeSeries{data: data_series} = original, result_list) do
    # result_list is oldest-first, TimeSeries stores newest-first
    updated_data_series = %DataSeries{data_series | data: Enum.reverse(result_list)}

    %TimeSeries{original | data: updated_data_series}
  end

  def rebuild_same_type(_list, result_list) when is_list(result_list) do
    result_list
  end

  @doc """
  Extracts a value from event data.

  Handles two cases:
  - If the data is a bar/struct, extracts the field specified by `source`
  - If the data is a float/nil (e.g., from another indicator), returns it directly

  ## Parameters

  - `event_data` - The event.data map
  - `data_name` - The key to extract from event.data
  - `source` - The field to extract from the bar/struct (ignored if data is float/nil)

  ## Returns

  - The extracted value (float or nil)

  ## Raises

  - If `data_name` is not found in `event_data`
  - If `source` is not found in the bar/struct

  ## Examples

      iex> event_data = %{"eurusd" => %{close: 1.23}}
      iex> TheoryCraftTA.Helpers.extract_value(event_data, "eurusd", :close)
      1.23

      iex> event_data = %{"sma20" => 1.25}
      iex> TheoryCraftTA.Helpers.extract_value(event_data, "sma20", :close)
      1.25

  """
  @spec extract_value(map(), String.t(), atom() | String.t() | nil) :: float() | nil
  def extract_value(event_data, data_name, source) do
    case {event_data, source} do
      {%{^data_name => %{^source => val}}, _source} ->
        val

      {%{^data_name => %{}}, source} when not is_nil(source) ->
        raise "source #{inspect(source)} not found in data"

      {%{^data_name => data}, _source} ->
        data

      {%{}, _source} ->
        raise "data_name #{inspect(data_name)} not found in event"
    end
  end

  @doc """
  Extracts `new_bar?` field from event data.

  ## Parameters

  - `event_data` - The event.data map
  - `data_name` - The key to extract from event.data (used if `bar_name` is nil)
  - `bar_name` - Optional key to extract `new_bar?` from (defaults to nil)

  ## Returns

  - `true` or `false`

  ## Behavior

  - If `bar_name` is provided: extracts `new_bar?` from `event_data[bar_name]`, raises if not found
  - If `bar_name` is nil: extracts `new_bar?` from `event_data[data_name]`, raises if data is not a map/bar

  ## Raises

  - If `bar_name` is provided but not found in event data
  - If `bar_name` is provided but doesn't contain `new_bar?`
  - If `bar_name` is nil and data is not a map (must use `bar_name` parameter)

  ## Examples

      iex> alias TheoryCraft.MarketSource.Bar
      iex> event_data = %{"eurusd_m1" => %Bar{close: 1.23, new_bar?: false}}
      iex> TheoryCraftTA.Helpers.extract_is_new_bar(event_data, "eurusd_m1", nil)
      false

      iex> alias TheoryCraft.MarketSource.Bar
      iex> event_data = %{"rsi" => 45.0, "eurusd_m1" => %Bar{close: 1.23, new_bar?: true}}
      iex> TheoryCraftTA.Helpers.extract_is_new_bar(event_data, "rsi", "eurusd_m1")
      true

  """
  @spec extract_is_new_bar(map(), String.t(), String.t() | nil) :: boolean()
  def extract_is_new_bar(event_data, data_name, bar_name \\ nil) do
    source_name = bar_name || data_name

    case event_data do
      %{^source_name => %Bar{new_bar?: new_bar?}} when is_boolean(new_bar?) ->
        new_bar?

      %{^source_name => _value} when is_nil(bar_name) ->
        raise "data #{inspect(source_name)} is not a bar (no new_bar? field). " <>
                "When calculating an indicator on another indicator's output, " <>
                "you must specify the `bar_name` parameter to indicate which bar stream to use for new_bar?. " <>
                "Example: SMA.init(period: 14, data: \"rsi\", name: \"sma_rsi\", bar_name: \"eurusd_m1\")"

      %{} when not is_nil(bar_name) ->
        raise "bar_name #{inspect(bar_name)} not found in event"

      %{} ->
        raise "data_name #{inspect(data_name)} not found in event"
    end
  end
end
