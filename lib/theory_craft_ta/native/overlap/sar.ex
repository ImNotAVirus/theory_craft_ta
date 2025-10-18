defmodule TheoryCraftTA.Native.Overlap.SAR do
  @moduledoc """
  Native (Rust NIF) wrapper for SAR indicator.
  """

  alias TheoryCraft.DataSeries
  alias TheoryCraft.TimeSeries
  alias TheoryCraftTA.Helpers
  alias TheoryCraftTA.Native

  @doc """
  Calculates SAR using the native Rust NIF.

  See `TheoryCraftTA.Elixir.Overlap.SAR.sar/4` for documentation.
  """
  @spec sar(
          list(float()) | DataSeries.t() | TimeSeries.t(),
          list(float()) | DataSeries.t() | TimeSeries.t(),
          float(),
          float()
        ) :: {:ok, list(float() | nil) | DataSeries.t() | TimeSeries.t()} | {:error, String.t()}
  def sar(high, low, acceleration \\ 0.02, maximum \\ 0.20)

  def sar(high, low, acceleration, maximum) when is_list(high) and is_list(low) do
    Native.overlap_sar(high, low, acceleration, maximum)
  end

  def sar(%DataSeries{} = high, %DataSeries{} = low, acceleration, maximum) do
    high_list = Helpers.to_list_and_reverse(high)
    low_list = Helpers.to_list_and_reverse(low)

    case sar(high_list, low_list, acceleration, maximum) do
      {:ok, result} -> {:ok, Helpers.rebuild_same_type(high, result)}
      error -> error
    end
  end

  def sar(%TimeSeries{} = high, %TimeSeries{} = low, acceleration, maximum) do
    high_list = Helpers.to_list_and_reverse(high)
    low_list = Helpers.to_list_and_reverse(low)

    case sar(high_list, low_list, acceleration, maximum) do
      {:ok, result} -> {:ok, Helpers.rebuild_same_type(high, result)}
      error -> error
    end
  end
end
