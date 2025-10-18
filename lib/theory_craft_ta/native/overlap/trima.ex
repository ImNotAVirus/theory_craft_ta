defmodule TheoryCraftTA.Native.Overlap.TRIMA do
  @moduledoc """
  Triangular Moving Average - Native implementation using Rust NIF.

  Calculates the triangular moving average of the input data over the specified period.
  TRIMA is a double-smoothed moving average (SMA of SMA), which gives more weight to the
  middle portion of the data.
  """

  alias TheoryCraftTA.{Native, Helpers}

  @doc """
  Triangular Moving Average - Native implementation using Rust NIF.

  Calculates the triangular moving average of the input data over the specified period.
  TRIMA is a double-smoothed moving average (SMA of SMA).

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with TRIMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.Native.Overlap.TRIMA.trima([1.0, 2.0, 3.0, 4.0, 5.0], 3)
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
end
