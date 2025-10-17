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
end
