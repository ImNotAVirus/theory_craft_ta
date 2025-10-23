defmodule TheoryCraftTA do
  @moduledoc """
  TheoryCraftTA - Technical Analysis indicators for TheoryCraft.

  Provides Rust NIF implementations of 200+ technical analysis indicators via TA-Lib.

  ## Input Types

  All indicator functions accept three types of input:
  - `list(float())` - A list of floating point numbers
  - `TheoryCraft.DataSeries.t()` - A DataSeries struct
  - `TheoryCraft.TimeSeries.t()` - A TimeSeries struct

  The output will be of the same type as the input.

  ## Important Note on Data Order

  DataSeries and TimeSeries store data in reverse chronological order (newest first).
  TheoryCraftTA handles this automatically by reversing before calculation and
  reconstructing the result in the correct order.

  ## Examples

      iex> alias TheoryCraft.DataSeries
      iex> TheoryCraftTA.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}
      iex> ds = DataSeries.new() |> DataSeries.add(1.0) |> DataSeries.add(2.0) |> DataSeries.add(3.0)
      iex> {:ok, result} = TheoryCraftTA.sma(ds, 2)
      iex> DataSeries.values(result)
      [2.5, 1.5, nil]
      iex> TheoryCraftTA.sma!([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      [nil, nil, 2.0, 3.0, 4.0]

  """

  alias TheoryCraft.{DataSeries, TimeSeries}

  @type source :: [float() | nil] | DataSeries.t(float() | nil) | TimeSeries.t(float() | nil)

  ## Batch indicators - Delegates

  defdelegate sma(data, period), to: TheoryCraftTA.Overlap.SMA
  defdelegate ema(data, period), to: TheoryCraftTA.Overlap.EMA
  defdelegate wma(data, period), to: TheoryCraftTA.Overlap.WMA
  defdelegate dema(data, period), to: TheoryCraftTA.Overlap.DEMA
  defdelegate tema(data, period), to: TheoryCraftTA.Overlap.TEMA
  defdelegate trima(data, period), to: TheoryCraftTA.Overlap.TRIMA
  defdelegate t3(data, period, vfactor), to: TheoryCraftTA.Overlap.T3
  defdelegate midpoint(data, period), to: TheoryCraftTA.Overlap.MIDPOINT

  ## Batch indicators - Bang functions

  @doc "Simple Moving Average. See `sma/2` for details."
  @spec sma!(source(), pos_integer()) :: source()
  def sma!(data, period), do: unwrap_batch!(sma(data, period), "SMA")

  @doc "Exponential Moving Average. See `ema/2` for details."
  @spec ema!(source(), pos_integer()) :: source()
  def ema!(data, period), do: unwrap_batch!(ema(data, period), "EMA")

  @doc "Weighted Moving Average. See `wma/2` for details."
  @spec wma!(source(), pos_integer()) :: source()
  def wma!(data, period), do: unwrap_batch!(wma(data, period), "WMA")

  @doc "Double Exponential Moving Average. See `dema/2` for details."
  @spec dema!(source(), pos_integer()) :: source()
  def dema!(data, period), do: unwrap_batch!(dema(data, period), "DEMA")

  @doc "Triple Exponential Moving Average. See `tema/2` for details."
  @spec tema!(source(), pos_integer()) :: source()
  def tema!(data, period), do: unwrap_batch!(tema(data, period), "TEMA")

  @doc "Triangular Moving Average. See `trima/2` for details."
  @spec trima!(source(), pos_integer()) :: source()
  def trima!(data, period), do: unwrap_batch!(trima(data, period), "TRIMA")

  @doc "T3 (Tillson T3) Moving Average. See `t3/3` for details."
  @spec t3!(source(), pos_integer(), float()) :: source()
  def t3!(data, period, vfactor), do: unwrap_batch!(t3(data, period, vfactor), "T3")

  @doc "MidPoint over period. See `midpoint/2` for details."
  @spec midpoint!(source(), pos_integer()) :: source()
  def midpoint!(data, period), do: unwrap_batch!(midpoint(data, period), "MIDPOINT")

  ## Private functions

  defp unwrap_batch!(result, indicator_name) do
    case result do
      {:ok, result} -> result
      {:error, reason} -> raise "#{indicator_name} error: #{reason}"
    end
  end
end
