defmodule TheoryCraftTA.Native.Overlap.WMA do
  @moduledoc """
  Weighted Moving Average - Native implementation using Rust NIF.

  Calculates the weighted moving average of the input data over the specified period.
  WMA applies linearly increasing weights to values, with the most recent value having
  the highest weight.
  """

  alias TheoryCraftTA.{Native, Helpers}

  @doc """
  Weighted Moving Average - Native implementation using Rust NIF.

  Calculates the weighted moving average of the input data over the specified period.
  WMA applies linearly increasing weights to values, with the most recent value having
  the highest weight.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with WMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> {:ok, result} = TheoryCraftTA.Native.Overlap.WMA.wma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      iex> Enum.map(result, fn nil -> nil; x -> Float.round(x, 2) end)
      [nil, nil, 2.33, 3.33, 4.33]

  """
  @spec wma(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def wma(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_wma(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end
end
