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
  defdelegate sma(data, period), to: Module.concat([@backend, Overlap, SMA])

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
  Exponential Moving Average.

  Calculates the exponential moving average of the input data over the specified period.
  EMA applies more weight to recent values using an exponential decay factor.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with EMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.ema([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec ema(source(), pos_integer()) :: {:ok, source()} | {:error, String.t()}
  defdelegate ema(data, period), to: Module.concat([@backend, Overlap, EMA])

  @doc """
  Exponential Moving Average - Bang version.

  Same as `ema/2` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - Result of the same type as input with EMA values

  ## Raises
    - `RuntimeError` if validation fails or calculation error occurs
    - `FunctionClauseError` if period is not an integer

  ## Examples
      iex> TheoryCraftTA.ema!([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      [nil, nil, 2.0, 3.0, 4.0]

  """
  @spec ema!(source(), pos_integer()) :: source()
  def ema!(data, period) do
    case ema(data, period) do
      {:ok, result} -> result
      {:error, reason} -> raise "EMA error: #{reason}"
    end
  end

  @doc """
  Weighted Moving Average.

  Calculates the weighted moving average of the input data over the specified period.
  WMA applies linearly increasing weights to values, with the most recent value having
  the highest weight.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with WMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> {:ok, result} = TheoryCraftTA.wma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      iex> Enum.map(result, fn nil -> nil; x -> Float.round(x, 2) end)
      [nil, nil, 2.33, 3.33, 4.33]

  """
  @spec wma(source(), pos_integer()) :: {:ok, source()} | {:error, String.t()}
  defdelegate wma(data, period), to: Module.concat([@backend, Overlap, WMA])

  @doc """
  Weighted Moving Average - Bang version.

  Same as `wma/2` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - Result of the same type as input with WMA values

  ## Raises
    - `RuntimeError` if validation fails or calculation error occurs
    - `FunctionClauseError` if period is not an integer

  ## Examples
      iex> result = TheoryCraftTA.wma!([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      iex> Enum.map(result, fn nil -> nil; x -> Float.round(x, 2) end)
      [nil, nil, 2.33, 3.33, 4.33]

  """
  @spec wma!(source(), pos_integer()) :: source()
  def wma!(data, period) do
    case wma(data, period) do
      {:ok, result} -> result
      {:error, reason} -> raise "WMA error: #{reason}"
    end
  end

  ## State-based Indicators

  @doc """
  Initialize SMA state for incremental calculations.

  Creates a new SMA state that can be updated incrementally with each new value.
  This is useful for streaming data where you want to calculate the SMA as new
  data arrives without recalculating the entire window.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, state}` - Initial state for SMA calculations
    - `{:error, reason}` - If validation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.sma_state_init(3)
      iex> is_reference(state)
      true

  """
  @spec sma_state_init(pos_integer()) :: {:ok, term()} | {:error, String.t()}
  defdelegate sma_state_init(period), to: Module.concat([@backend, OverlapState, SMA]), as: :init

  @doc """
  Initialize SMA state for incremental calculations - Bang version.

  Same as `sma_state_init/1` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `state` - Initial state for SMA calculations

  ## Raises
    - `RuntimeError` if validation fails

  ## Examples
      iex> state = TheoryCraftTA.sma_state_init!(3)
      iex> is_reference(state)
      true

  """
  @spec sma_state_init!(pos_integer()) :: term()
  def sma_state_init!(period) do
    unwrap_init!(sma_state_init(period), "SMA")
  end

  @doc """
  Process next value with SMA state.

  Updates the SMA state with a new value and returns the current SMA value.
  Supports two modes:
  - APPEND mode (`is_new_bar = true`): Adds a new value to the window
  - UPDATE mode (`is_new_bar = false`): Updates the last value in the window

  ## Parameters
    - `state` - Current SMA state (from `sma_state_init/1` or previous `sma_state_next/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{:ok, sma_value, new_state}` - The SMA value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.sma_state_init(3)
      iex> {:ok, nil, state2} = TheoryCraftTA.sma_state_next(state, 100.0, true)
      iex> {:ok, nil, state3} = TheoryCraftTA.sma_state_next(state2, 110.0, true)
      iex> {:ok, sma, _state4} = TheoryCraftTA.sma_state_next(state3, 120.0, true)
      iex> sma
      110.0

  """
  @spec sma_state_next(term(), float(), boolean()) ::
          {:ok, float() | nil, term()} | {:error, String.t()}
  defdelegate sma_state_next(state, value, is_new_bar),
    to: Module.concat([@backend, OverlapState, SMA]),
    as: :next

  @doc """
  Process next value with SMA state - Bang version.

  Same as `sma_state_next/3` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `state` - Current SMA state (from `sma_state_init!/1` or previous `sma_state_next!/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{sma_value, new_state}` - The SMA value (or nil during warmup) and updated state

  ## Raises
    - `RuntimeError` if calculation fails

  ## Examples
      iex> state = TheoryCraftTA.sma_state_init!(3)
      iex> {nil, state2} = TheoryCraftTA.sma_state_next!(state, 100.0, true)
      iex> {nil, state3} = TheoryCraftTA.sma_state_next!(state2, 110.0, true)
      iex> {sma, _state4} = TheoryCraftTA.sma_state_next!(state3, 120.0, true)
      iex> sma
      110.0

  """
  @spec sma_state_next!(term(), float(), boolean()) :: {float() | nil, term()}
  def sma_state_next!(state, value, is_new_bar) do
    unwrap_next!(sma_state_next(state, value, is_new_bar), "SMA")
  end

  @doc """
  Initialize EMA state for incremental calculations.

  Creates a new EMA state that can be updated incrementally with each new value.
  This is useful for streaming data where you want to calculate the EMA as new
  data arrives without recalculating the entire window.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, state}` - Initial state for EMA calculations
    - `{:error, reason}` - If validation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.ema_state_init(3)
      iex> is_reference(state)
      true

  """
  @spec ema_state_init(pos_integer()) :: {:ok, term()} | {:error, String.t()}
  defdelegate ema_state_init(period), to: Module.concat([@backend, OverlapState, EMA]), as: :init

  @doc """
  Initialize EMA state for incremental calculations - Bang version.

  Same as `ema_state_init/1` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `state` - Initial state for EMA calculations

  ## Raises
    - `RuntimeError` if validation fails

  ## Examples
      iex> state = TheoryCraftTA.ema_state_init!(3)
      iex> is_reference(state)
      true

  """
  @spec ema_state_init!(pos_integer()) :: term()
  def ema_state_init!(period) do
    unwrap_init!(ema_state_init(period), "EMA")
  end

  @doc """
  Process next value with EMA state.

  Updates the EMA state with a new value and returns the current EMA value.
  Supports two modes:
  - APPEND mode (`is_new_bar = true`): Adds a new value to the window
  - UPDATE mode (`is_new_bar = false`): Recalculates EMA with updated last value

  The first EMA value is seeded using the SMA of the accumulated buffer values.

  ## Parameters
    - `state` - Current EMA state (from `ema_state_init/1` or previous `ema_state_next/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{:ok, ema_value, new_state}` - The EMA value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.ema_state_init(2)
      iex> {:ok, nil, state2} = TheoryCraftTA.ema_state_next(state, 100.0, true)
      iex> {:ok, ema, _state3} = TheoryCraftTA.ema_state_next(state2, 110.0, true)
      iex> ema
      105.0

  """
  @spec ema_state_next(term(), float(), boolean()) ::
          {:ok, float() | nil, term()} | {:error, String.t()}
  defdelegate ema_state_next(state, value, is_new_bar),
    to: Module.concat([@backend, OverlapState, EMA]),
    as: :next

  @doc """
  Process next value with EMA state - Bang version.

  Same as `ema_state_next/3` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `state` - Current EMA state (from `ema_state_init!/1` or previous `ema_state_next!/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{ema_value, new_state}` - The EMA value (or nil during warmup) and updated state

  ## Raises
    - `RuntimeError` if calculation fails

  ## Examples
      iex> state = TheoryCraftTA.ema_state_init!(2)
      iex> {nil, state2} = TheoryCraftTA.ema_state_next!(state, 100.0, true)
      iex> {ema, _state3} = TheoryCraftTA.ema_state_next!(state2, 110.0, true)
      iex> ema
      105.0

  """
  @spec ema_state_next!(term(), float(), boolean()) :: {float() | nil, term()}
  def ema_state_next!(state, value, is_new_bar) do
    unwrap_next!(ema_state_next(state, value, is_new_bar), "EMA")
  end

  @doc """
  Initialize WMA state for incremental calculations.

  Creates a new WMA state that can be updated incrementally with each new value.
  This is useful for streaming data where you want to calculate the WMA as new
  data arrives without recalculating the entire window.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, state}` - Initial state for WMA calculations
    - `{:error, reason}` - If validation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.wma_state_init(3)
      iex> is_reference(state)
      true

  """
  @spec wma_state_init(pos_integer()) :: {:ok, term()} | {:error, String.t()}
  defdelegate wma_state_init(period), to: Module.concat([@backend, OverlapState, WMA]), as: :init

  @doc """
  Initialize WMA state for incremental calculations - Bang version.

  Same as `wma_state_init/1` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `state` - Initial state for WMA calculations

  ## Raises
    - `RuntimeError` if validation fails

  ## Examples
      iex> state = TheoryCraftTA.wma_state_init!(3)
      iex> is_reference(state)
      true

  """
  @spec wma_state_init!(pos_integer()) :: term()
  def wma_state_init!(period) do
    unwrap_init!(wma_state_init(period), "WMA")
  end

  @doc """
  Process next value with WMA state.

  Updates the WMA state with a new value and returns the current WMA value.
  Supports two modes:
  - APPEND mode (`is_new_bar = true`): Adds a new value to the window
  - UPDATE mode (`is_new_bar = false`): Updates the last value in the window

  ## Parameters
    - `state` - Current WMA state (from `wma_state_init/1` or previous `wma_state_next/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{:ok, wma_value, new_state}` - The WMA value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.wma_state_init(2)
      iex> {:ok, nil, state2} = TheoryCraftTA.wma_state_next(state, 100.0, true)
      iex> {:ok, wma, _state3} = TheoryCraftTA.wma_state_next(state2, 110.0, true)
      iex> Float.round(wma, 5)
      106.66667

  """
  @spec wma_state_next(term(), float(), boolean()) ::
          {:ok, float() | nil, term()} | {:error, String.t()}
  defdelegate wma_state_next(state, value, is_new_bar),
    to: Module.concat([@backend, OverlapState, WMA]),
    as: :next

  @doc """
  Process next value with WMA state - Bang version.

  Same as `wma_state_next/3` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `state` - Current WMA state (from `wma_state_init!/1` or previous `wma_state_next!/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{wma_value, new_state}` - The WMA value (or nil during warmup) and updated state

  ## Raises
    - `RuntimeError` if calculation fails

  ## Examples
      iex> state = TheoryCraftTA.wma_state_init!(2)
      iex> {nil, state2} = TheoryCraftTA.wma_state_next!(state, 100.0, true)
      iex> {wma, _state3} = TheoryCraftTA.wma_state_next!(state2, 110.0, true)
      iex> Float.round(wma, 5)
      106.66667

  """
  @spec wma_state_next!(term(), float(), boolean()) :: {float() | nil, term()}
  def wma_state_next!(state, value, is_new_bar) do
    unwrap_next!(wma_state_next(state, value, is_new_bar), "WMA")
  end

  ## Private functions

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
