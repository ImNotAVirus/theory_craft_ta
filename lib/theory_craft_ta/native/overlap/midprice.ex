defmodule TheoryCraftTA.Native.Overlap.MIDPRICE do
  @moduledoc """
  Midpoint Price over period - Native implementation using Rustler NIF.

  Calculates the midpoint between the highest high and lowest low over the specified period.
  This is commonly used to identify price levels in technical analysis.
  """

  alias TheoryCraftTA.{Native, Helpers}

  @doc """
  Midpoint Price over period - Native implementation using Rustler NIF.

  Calculates the midpoint between the highest high and lowest low over the specified period.
  Formula: MIDPRICE = (HIGHEST_HIGH + LOWEST_LOW) / 2

  ## Parameters
    - `high` - High price data (list of floats, DataSeries, or TimeSeries)
    - `low` - Low price data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the midprice calculation (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with MIDPRICE values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Native.Overlap.MIDPRICE.midprice([10.0, 11.0, 12.0, 13.0, 14.0], [8.0, 9.0, 10.0, 11.0, 12.0], 3)
      {:ok, [nil, nil, 10.0, 11.0, 12.0]}

  """
  @spec midprice(TheoryCraftTA.source(), TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def midprice(high, low, period) do
    high_list = Helpers.to_list_and_reverse(high)
    low_list = Helpers.to_list_and_reverse(low)

    with {:ok, result_list} <- Native.overlap_midprice(high_list, low_list, period) do
      {:ok, Helpers.rebuild_same_type(high, result_list)}
    end
  end
end
