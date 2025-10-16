defmodule TheoryCraftTA.Helpers do
  @moduledoc false

  # This module provides internal helper functions for TheoryCraftTA.
  # It handles conversions between different input types (list, DataSeries, TimeSeries)
  # and ensures the same type is returned as output.

  alias TheoryCraft.{DataSeries, TimeSeries}

  ## Public API

  @doc """
  Converts input to a list and reverses if it's a DataSeries or TimeSeries.

  DataSeries and TimeSeries store data newest-first, but ta-lib expects oldest-first.
  This function handles the conversion and reversal.

  ## Parameters
    - `data` - Can be a list, DataSeries, or TimeSeries

  ## Returns
    - A list of values in oldest-first order
  """
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
  """
  def rebuild_same_type(%DataSeries{max_size: max_size}, result_list) do
    # result_list is oldest-first, DataSeries.add prepends (newest-first)
    # So we iterate oldest-first, and each add will build newest-first ordering
    Enum.reduce(result_list, DataSeries.new(max_size: max_size), fn val, ds ->
      DataSeries.add(ds, val)
    end)
  end

  def rebuild_same_type(%TimeSeries{} = ts, result_list) do
    # TimeSeries.keys() returns newest-first, but TimeSeries.add requires oldest-first
    # result_list is oldest-first, so we need to reverse both to match and then add in correct order
    keys = ts |> TimeSeries.keys() |> Enum.reverse()

    keys
    |> Enum.zip(result_list)
    |> Enum.reduce(TimeSeries.new(), fn {datetime, value}, acc ->
      TimeSeries.add(acc, datetime, value)
    end)
  end

  def rebuild_same_type(_list, result_list) when is_list(result_list) do
    result_list
  end
end
