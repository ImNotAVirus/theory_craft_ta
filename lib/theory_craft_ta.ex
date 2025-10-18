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

  ## State indicators - Delegates

  defdelegate sma_state_init(period), to: TheoryCraftTA.Overlap.SMA, as: :init
  defdelegate sma_state_next(value, is_new_bar, state), to: TheoryCraftTA.Overlap.SMA, as: :next

  defdelegate ema_state_init(period), to: TheoryCraftTA.Overlap.EMA, as: :init
  defdelegate ema_state_next(value, is_new_bar, state), to: TheoryCraftTA.Overlap.EMA, as: :next

  defdelegate wma_state_init(period), to: TheoryCraftTA.Overlap.WMA, as: :init
  defdelegate wma_state_next(value, is_new_bar, state), to: TheoryCraftTA.Overlap.WMA, as: :next

  defdelegate dema_state_init(period), to: TheoryCraftTA.Overlap.DEMA, as: :init
  defdelegate dema_state_next(value, is_new_bar, state), to: TheoryCraftTA.Overlap.DEMA, as: :next

  defdelegate tema_state_init(period), to: TheoryCraftTA.Overlap.TEMA, as: :init
  defdelegate tema_state_next(value, is_new_bar, state), to: TheoryCraftTA.Overlap.TEMA, as: :next

  defdelegate trima_state_init(period), to: TheoryCraftTA.Overlap.TRIMA, as: :init

  defdelegate trima_state_next(value, is_new_bar, state),
    to: TheoryCraftTA.Overlap.TRIMA,
    as: :next

  defdelegate t3_state_init(period, vfactor), to: TheoryCraftTA.Overlap.T3, as: :init
  defdelegate t3_state_next(value, is_new_bar, state), to: TheoryCraftTA.Overlap.T3, as: :next

  defdelegate midpoint_state_init(period), to: TheoryCraftTA.Overlap.MIDPOINT, as: :init

  defdelegate midpoint_state_next(value, is_new_bar, state),
    to: TheoryCraftTA.Overlap.MIDPOINT,
    as: :next

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

  ## State indicators - Bang functions

  @doc "Initialize SMA state. See `sma_state_init/1` for details."
  @spec sma_state_init!(pos_integer()) :: term()
  def sma_state_init!(period), do: unwrap_init!(sma_state_init(period), "SMA")

  @doc "Process next value with SMA state. See `sma_state_next/3` for details."
  @spec sma_state_next!(float(), boolean(), term()) :: {float() | nil, term()}
  def sma_state_next!(value, is_new_bar, state),
    do: unwrap_next!(sma_state_next(value, is_new_bar, state), "SMA")

  @doc "Initialize EMA state. See `ema_state_init/1` for details."
  @spec ema_state_init!(pos_integer()) :: term()
  def ema_state_init!(period), do: unwrap_init!(ema_state_init(period), "EMA")

  @doc "Process next value with EMA state. See `ema_state_next/3` for details."
  @spec ema_state_next!(float(), boolean(), term()) :: {float() | nil, term()}
  def ema_state_next!(value, is_new_bar, state),
    do: unwrap_next!(ema_state_next(value, is_new_bar, state), "EMA")

  @doc "Initialize WMA state. See `wma_state_init/1` for details."
  @spec wma_state_init!(pos_integer()) :: term()
  def wma_state_init!(period), do: unwrap_init!(wma_state_init(period), "WMA")

  @doc "Process next value with WMA state. See `wma_state_next/3` for details."
  @spec wma_state_next!(float(), boolean(), term()) :: {float() | nil, term()}
  def wma_state_next!(value, is_new_bar, state),
    do: unwrap_next!(wma_state_next(value, is_new_bar, state), "WMA")

  @doc "Initialize DEMA state. See `dema_state_init/1` for details."
  @spec dema_state_init!(pos_integer()) :: term()
  def dema_state_init!(period), do: unwrap_init!(dema_state_init(period), "DEMA")

  @doc "Process next value with DEMA state. See `dema_state_next/3` for details."
  @spec dema_state_next!(float(), boolean(), term()) :: {float() | nil, term()}
  def dema_state_next!(value, is_new_bar, state),
    do: unwrap_next!(dema_state_next(value, is_new_bar, state), "DEMA")

  @doc "Initialize TEMA state. See `tema_state_init/1` for details."
  @spec tema_state_init!(pos_integer()) :: term()
  def tema_state_init!(period), do: unwrap_init!(tema_state_init(period), "TEMA")

  @doc "Process next value with TEMA state. See `tema_state_next/3` for details."
  @spec tema_state_next!(float(), boolean(), term()) :: {float() | nil, term()}
  def tema_state_next!(value, is_new_bar, state),
    do: unwrap_next!(tema_state_next(value, is_new_bar, state), "TEMA")

  @doc "Initialize TRIMA state. See `trima_state_init/1` for details."
  @spec trima_state_init!(pos_integer()) :: term()
  def trima_state_init!(period), do: unwrap_init!(trima_state_init(period), "TRIMA")

  @doc "Process next value with TRIMA state. See `trima_state_next/3` for details."
  @spec trima_state_next!(float(), boolean(), term()) :: {float() | nil, term()}
  def trima_state_next!(value, is_new_bar, state),
    do: unwrap_next!(trima_state_next(value, is_new_bar, state), "TRIMA")

  @doc "Initialize T3 state. See `t3_state_init/2` for details."
  @spec t3_state_init!(pos_integer(), float()) :: term()
  def t3_state_init!(period, vfactor), do: unwrap_init!(t3_state_init(period, vfactor), "T3")

  @doc "Process next value with T3 state. See `t3_state_next/3` for details."
  @spec t3_state_next!(float(), boolean(), term()) :: {float() | nil, term()}
  def t3_state_next!(value, is_new_bar, state),
    do: unwrap_next!(t3_state_next(value, is_new_bar, state), "T3")

  @doc "Initialize MIDPOINT state. See `midpoint_state_init/1` for details."
  @spec midpoint_state_init!(pos_integer()) :: term()
  def midpoint_state_init!(period), do: unwrap_init!(midpoint_state_init(period), "MIDPOINT")

  @doc "Process next value with MIDPOINT state. See `midpoint_state_next/3` for details."
  @spec midpoint_state_next!(float(), boolean(), term()) :: {float() | nil, term()}
  def midpoint_state_next!(value, is_new_bar, state),
    do: unwrap_next!(midpoint_state_next(value, is_new_bar, state), "MIDPOINT")

  @doc """
  Initialize SAR state for incremental calculations.

  Creates a new SAR state that can be updated incrementally with each new high/low bar.

  ## Parameters
    - `acceleration` - Acceleration Factor (default: 0.02)
    - `maximum` - Maximum Acceleration Factor (default: 0.20)

  ## Returns
    - `{:ok, state}` - Initial SAR state
    - `{:error, reason}` if parameters are invalid

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.sar_state_init()
      iex> is_reference(state)
      true

  """
  @spec sar_state_init(float(), float()) :: {:ok, term()} | {:error, String.t()}
  defdelegate sar_state_init(acceleration \\ 0.02, maximum \\ 0.20),
    to: Module.concat([@backend, Overlap, SARState]),
    as: :init

  @doc """
  Initialize SAR state - Bang version.

  Same as `sar_state_init/2` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `acceleration` - Acceleration Factor (default: 0.02)
    - `maximum` - Maximum Acceleration Factor (default: 0.20)

  ## Returns
    - `state` - Initial SAR state

  ## Raises
    - `RuntimeError` if parameters are invalid

  ## Examples
      iex> state = TheoryCraftTA.sar_state_init!()
      iex> is_reference(state)
      true

  """
  @spec sar_state_init!(float(), float()) :: term()
  def sar_state_init!(acceleration \\ 0.02, maximum \\ 0.20) do
    unwrap_init!(sar_state_init(acceleration, maximum), "SAR")
  end

  @doc """
  Process next high/low bar with SAR state.

  ## Parameters
    - `state` - Current SAR state (from `sar_state_init/2` or previous `sar_state_next/4`)
    - `high` - High price for this bar
    - `low` - Low price for this bar
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{:ok, sar_value, new_state}` - The SAR value (or nil during warmup) and updated state
    - `{:error, reason}` if calculation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.sar_state_init()
      iex> {:ok, nil, state2} = TheoryCraftTA.sar_state_next(state, 10.0, 8.0, true)
      iex> {:ok, sar, _state3} = TheoryCraftTA.sar_state_next(state2, 11.0, 9.0, true)
      iex> is_float(sar)
      true

  """
  @spec sar_state_next(term(), float(), float(), boolean()) ::
          {:ok, float() | nil, term()} | {:error, String.t()}
  defdelegate sar_state_next(state, high, low, is_new_bar),
    to: Module.concat([@backend, Overlap, SARState]),
    as: :next

  @doc """
  Process next high/low bar with SAR state - Bang version.

  Same as `sar_state_next/4` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `state` - Current SAR state (from `sar_state_init!/2` or previous `sar_state_next!/4`)
    - `high` - High price for this bar
    - `low` - Low price for this bar
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{sar_value, new_state}` - The SAR value (or nil during warmup) and updated state

  ## Raises
    - `RuntimeError` if calculation fails

  ## Examples
      iex> state = TheoryCraftTA.sar_state_init!()
      iex> {nil, state2} = TheoryCraftTA.sar_state_next!(state, 10.0, 8.0, true)
      iex> {sar, _state3} = TheoryCraftTA.sar_state_next!(state2, 11.0, 9.0, true)
      iex> is_float(sar)
      true

  """
  @spec sar_state_next!(term(), float(), float(), boolean()) :: {float() | nil, term()}
  def sar_state_next!(state, high, low, is_new_bar) do
    unwrap_next!(sar_state_next(state, high, low, is_new_bar), "SAR")
  end

  ## Private functions

  defp unwrap_batch!(result, indicator_name) do
    case result do
      {:ok, result} -> result
      {:error, reason} -> raise "#{indicator_name} error: #{reason}"
    end
  end

  defp unwrap_init!(result, indicator_name) do
    case result do
      {:ok, state} -> state
      {:error, reason} -> raise "#{indicator_name} state init error: #{reason}"
    end
  end

  defp unwrap_next!(result, indicator_name) do
    case result do
      {:ok, value, new_state} -> {value, new_state}
      {:error, reason} -> raise "#{indicator_name} state next error: #{reason}"
    end
  end
end
