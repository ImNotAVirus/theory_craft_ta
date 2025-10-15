defmodule TheoryCraftTA do
  @moduledoc """
  TheoryCraftTA - Technical Analysis indicators for TheoryCraft.

  A wrapper library around TA-Lib providing both Native (Rust NIF) and Pure Elixir
  implementations of 200+ technical analysis indicators.

  ## Backend Configuration

  TheoryCraftTA supports two backends:
  - `TheoryCraftTA.Native` - Fast Rust NIF implementation (default)
  - `TheoryCraftTA.Elixir` - Pure Elixir implementation

  The backend is configured at compile time via application config:

      config :theory_craft_ta,
        default_backend: TheoryCraftTA.Native

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

  @backend Application.compile_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Native)

  alias TheoryCraft.{DataSeries, TimeSeries}

  ## Overlap Indicators

  @doc """
  Simple Moving Average.

  Calculates the simple moving average of the input data over the specified period.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with SMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec sma(list(float()) | DataSeries.t() | TimeSeries.t(), pos_integer()) ::
          {:ok, list(float() | nil) | DataSeries.t() | TimeSeries.t()} | {:error, String.t()}
  defdelegate sma(data, period), to: Module.concat(@backend, Overlap)

  @doc """
  Simple Moving Average - Bang version.

  Same as `sma/2` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns
    - Result of the same type as input with SMA values

  ## Raises
    - `RuntimeError` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.sma!([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      [nil, nil, 2.0, 3.0, 4.0]

  """
  @spec sma!(list(float()) | DataSeries.t() | TimeSeries.t(), pos_integer()) ::
          list(float() | nil) | DataSeries.t() | TimeSeries.t()
  def sma!(data, period) do
    case sma(data, period) do
      {:ok, result} -> result
      {:error, reason} -> raise "SMA error: #{reason}"
    end
  end
end
