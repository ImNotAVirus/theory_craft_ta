defmodule TheoryCraftTA.Native.Overlap.HT_TRENDLINE do
  @moduledoc """
  Hilbert Transform - Instantaneous Trendline - Native implementation using Rust NIF.

  The HT_TRENDLINE uses the Hilbert Transform to smooth price data and identify
  the underlying trend by eliminating cyclic components and noise from the price series.
  """

  alias TheoryCraftTA.{Native, Helpers}

  @doc """
  Hilbert Transform - Instantaneous Trendline - Native implementation using Rust NIF.

  Calculates the instantaneous trendline using the Hilbert Transform.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)

  ## Returns
    - `{:ok, result}` where result is the same type as input with HT_TRENDLINE values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> data = Enum.map(1..100, fn i -> 50.0 + :math.sin(i / 10.0) * 10.0 end)
      iex> {:ok, result} = TheoryCraftTA.Native.Overlap.HT_TRENDLINE.ht_trendline(data)
      iex> Enum.take(result, 63) |> Enum.all?(&(&1 == nil))
      true
      iex> is_float(Enum.at(result, 63))
      true

  """
  @spec ht_trendline(TheoryCraftTA.source()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def ht_trendline(data) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_ht_trendline(list_data) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end
end
