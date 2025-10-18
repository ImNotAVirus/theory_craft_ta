defmodule TheoryCraftTA.Native.Overlap.MIDPOINT do
  @moduledoc """
  MidPoint over period - Native implementation using Rustler NIF.

  Calculates the midpoint (average of highest and lowest values) over the specified period.
  """

  alias TheoryCraftTA.{Native, Helpers}

  @doc """
  MidPoint over period - Native implementation using Rustler NIF.

  Calculates the midpoint (average of highest and lowest values) over the specified period.
  Formula: MIDPOINT = (MAX + MIN) / 2

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the midpoint calculation (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with MIDPOINT values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Native.Overlap.MIDPOINT.midpoint([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec midpoint(TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def midpoint(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    with {:ok, result_list} <- Native.overlap_midpoint(list_data, period) do
      {:ok, Helpers.rebuild_same_type(data, result_list)}
    end
  end
end
