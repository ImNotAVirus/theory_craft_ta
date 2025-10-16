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

  alias TheoryCraft.{DataSeries, TimeSeries}

  @type source :: [float() | nil] | DataSeries.t(float() | nil) | TimeSeries.t(float() | nil)

  @backend Application.compile_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Native)

  ## Overlap Indicators

  @doc """
  Simple Moving Average.

  Calculates the simple moving average of the input data over the specified period.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with SMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec sma(source(), pos_integer()) :: {:ok, source()} | {:error, String.t()}
  defdelegate sma(data, period), to: Module.concat(@backend, Overlap)

  @doc """
  Simple Moving Average - Bang version.

  Same as `sma/2` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - Result of the same type as input with SMA values

  ## Raises
    - `RuntimeError` if validation fails or calculation error occurs
    - `FunctionClauseError` if period is not an integer

  ## Examples
      iex> TheoryCraftTA.sma!([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      [nil, nil, 2.0, 3.0, 4.0]

  """
  @spec sma!(source(), pos_integer()) :: source()
  def sma!(data, period) do
    case sma(data, period) do
      {:ok, result} -> result
      {:error, reason} -> raise "SMA error: #{reason}"
    end
  end

  @doc """
  Incremental SMA calculation.

  When streaming data, this function efficiently calculates the next SMA value
  without reprocessing the entire dataset.

  ## Behavior
    - If input size == prev size: Updates last value (same bar, multiple ticks)
    - If input size == prev size + 1: Adds new value (new bar)

  ## Parameters
    - `data` - Input data (must have one more element than prev, or same length)
    - `period` - Number of periods for the moving average (must be an integer >= 2)
    - `prev` - Previous SMA result

  ## Returns
    - `{:ok, result}` with updated SMA values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.sma_next([1.0, 2.0, 3.0, 4.0, 5.0], 2, [nil, 1.5, 2.5, 3.5])
      {:ok, [nil, 1.5, 2.5, 3.5, 4.5]}

      iex> TheoryCraftTA.sma_next([1.0, 2.0, 3.0, 4.0, 5.5], 2, [nil, 1.5, 2.5, 3.5, 4.5])
      {:ok, [nil, 1.5, 2.5, 3.5, 4.75]}

  """
  @spec sma_next(source(), pos_integer(), source()) :: {:ok, source()} | {:error, String.t()}
  defdelegate sma_next(data, period, prev), to: Module.concat(@backend, Overlap)

  @doc """
  Incremental SMA calculation - Bang version.

  Same as `sma_next/3` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `data` - Input data (must have one more element than prev, or same length)
    - `period` - Number of periods for the moving average (must be an integer >= 2)
    - `prev` - Previous SMA result

  ## Returns
    - Result with updated SMA values

  ## Raises
    - `RuntimeError` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.sma_next!([1.0, 2.0, 3.0, 4.0, 5.0], 2, [nil, 1.5, 2.5, 3.5])
      [nil, 1.5, 2.5, 3.5, 4.5]

  """
  @spec sma_next!(source(), pos_integer(), source()) :: source()
  def sma_next!(data, period, prev) do
    case sma_next(data, period, prev) do
      {:ok, result} -> result
      {:error, reason} -> raise "SMA_next error: #{reason}"
    end
  end
end
