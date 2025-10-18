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

  @doc """
  Double Exponential Moving Average.

  Calculates the double exponential moving average of the input data over the specified period.
  DEMA is calculated as: 2 * EMA(period) - EMA(EMA(period)).
  This provides a smoother average with less lag than a simple EMA.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with DEMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.dema([1.0, 2.0, 3.0, 4.0, 5.0], 2)
      {:ok, [nil, nil, 3.0, 4.0, 5.0]}

  """
  @spec dema(source(), pos_integer()) :: {:ok, source()} | {:error, String.t()}
  defdelegate dema(data, period), to: Module.concat([@backend, Overlap, DEMA])

  @doc """
  Double Exponential Moving Average - Bang version.

  Same as `dema/2` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - Result of the same type as input with DEMA values

  ## Raises
    - `RuntimeError` if validation fails or calculation error occurs
    - `FunctionClauseError` if period is not an integer

  ## Examples
      iex> TheoryCraftTA.dema!([1.0, 2.0, 3.0, 4.0, 5.0], 2)
      [nil, nil, 3.0, 4.0, 5.0]

  """
  @spec dema!(source(), pos_integer()) :: source()
  def dema!(data, period) do
    case dema(data, period) do
      {:ok, result} -> result
      {:error, reason} -> raise "DEMA error: #{reason}"
    end
  end

  @doc """
  Triple Exponential Moving Average.

  Calculates the triple exponential moving average of the input data over the specified period.
  TEMA is calculated as: 3 * EMA(period) - 3 * EMA(EMA(period)) + EMA(EMA(EMA(period))).
  This provides a smoother average with even less lag than DEMA.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with TEMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.tema([1.0, 2.0, 3.0, 4.0, 5.0], 2)
      {:ok, [nil, nil, nil, 4.0, 5.0]}

  """
  @spec tema(source(), pos_integer()) :: {:ok, source()} | {:error, String.t()}
  defdelegate tema(data, period), to: Module.concat([@backend, Overlap, TEMA])

  @doc """
  Triple Exponential Moving Average - Bang version.

  Same as `tema/2` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - Result of the same type as input with TEMA values

  ## Raises
    - `RuntimeError` if validation fails or calculation error occurs
    - `FunctionClauseError` if period is not an integer

  ## Examples
      iex> TheoryCraftTA.tema!([1.0, 2.0, 3.0, 4.0, 5.0], 2)
      [nil, nil, nil, 4.0, 5.0]

  """
  @spec tema!(source(), pos_integer()) :: source()
  def tema!(data, period) do
    case tema(data, period) do
      {:ok, result} -> result
      {:error, reason} -> raise "TEMA error: #{reason}"
    end
  end

  @doc """
  Triangular Moving Average.

  Calculates the triangular moving average of the input data over the specified period.
  TRIMA is a double-smoothed moving average (SMA of SMA), which gives more weight to the
  middle portion of the data.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with TRIMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.trima([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec trima(source(), pos_integer()) :: {:ok, source()} | {:error, String.t()}
  defdelegate trima(data, period), to: Module.concat([@backend, Overlap, TRIMA])

  @doc """
  Triangular Moving Average - Bang version.

  Same as `trima/2` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - Result of the same type as input with TRIMA values

  ## Raises
    - `RuntimeError` if validation fails or calculation error occurs
    - `FunctionClauseError` if period is not an integer

  ## Examples
      iex> TheoryCraftTA.trima!([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      [nil, nil, 2.0, 3.0, 4.0]

  """
  @spec trima!(source(), pos_integer()) :: source()
  def trima!(data, period) do
    case trima(data, period) do
      {:ok, result} -> result
      {:error, reason} -> raise "TRIMA error: #{reason}"
    end
  end

  @doc """
  T3 (Tillson T3) Moving Average.

  Calculates the Tillson T3 moving average of the input data over the specified period.
  T3 is a smoothing technique that applies a sequence of generalized DEMA filters
  (GD) to reduce lag and noise. It uses a volume factor to control smoothing.

  The T3 algorithm applies six successive EMA filters with the volume factor.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)
    - `vfactor` - Volume factor (typically 0.0 to 1.0, default is 0.7)

  ## Returns
    - `{:ok, result}` where result is the same type as input with T3 values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.t3([1.0, 2.0, 3.0, 4.0, 5.0], 2, 0.7)
      {:ok, [nil, nil, nil, nil, nil]}

  """
  @spec t3(source(), pos_integer(), float()) :: {:ok, source()} | {:error, String.t()}
  defdelegate t3(data, period, vfactor), to: Module.concat([@backend, Overlap, T3])

  @doc """
  T3 (Tillson T3) Moving Average - Bang version.

  Same as `t3/3` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be an integer >= 2)
    - `vfactor` - Volume factor (typically 0.0 to 1.0, default is 0.7)

  ## Returns
    - Result of the same type as input with T3 values

  ## Raises
    - `RuntimeError` if validation fails or calculation error occurs
    - `FunctionClauseError` if period is not an integer or vfactor is not a float

  ## Examples
      iex> TheoryCraftTA.t3!([1.0, 2.0, 3.0, 4.0, 5.0], 2, 0.7)
      [nil, nil, nil, nil, nil]

  """
  @spec t3!(source(), pos_integer(), float()) :: source()
  def t3!(data, period, vfactor) do
    case t3(data, period, vfactor) do
      {:ok, result} -> result
      {:error, reason} -> raise "T3 error: #{reason}"
    end
  end

  @doc """
  MidPoint over period.

  Calculates the midpoint (average of highest and lowest values) over the specified period.
  Formula: MIDPOINT = (MAX + MIN) / 2

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the midpoint calculation (must be an integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with MIDPOINT values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.midpoint([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec midpoint(source(), pos_integer()) :: {:ok, source()} | {:error, String.t()}
  defdelegate midpoint(data, period), to: Module.concat([@backend, Overlap, MIDPOINT])

  @doc """
  MidPoint over period - Bang version.

  Same as `midpoint/2` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the midpoint calculation (must be an integer >= 2)

  ## Returns
    - Result of the same type as input with MIDPOINT values

  ## Raises
    - `RuntimeError` if validation fails or calculation error occurs
    - `FunctionClauseError` if period is not an integer

  ## Examples
      iex> TheoryCraftTA.midpoint!([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      [nil, nil, 2.0, 3.0, 4.0]

  """
  @spec midpoint!(source(), pos_integer()) :: source()
  def midpoint!(data, period) do
    case midpoint(data, period) do
      {:ok, result} -> result
      {:error, reason} -> raise "MIDPOINT error: #{reason}"
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
  defdelegate sma_state_init(period), to: Module.concat([@backend, Overlap, SMAState]), as: :init

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
    to: Module.concat([@backend, Overlap, SMAState]),
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
  defdelegate ema_state_init(period), to: Module.concat([@backend, Overlap, EMAState]), as: :init

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
    to: Module.concat([@backend, Overlap, EMAState]),
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
  defdelegate wma_state_init(period), to: Module.concat([@backend, Overlap, WMAState]), as: :init

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
    to: Module.concat([@backend, Overlap, WMAState]),
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

  @doc """
  Initialize DEMA state for incremental calculations.

  Creates a new DEMA state that can be updated incrementally with each new value.
  This is useful for streaming data where you want to calculate the DEMA as new
  data arrives without recalculating the entire window.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, state}` - Initial state for DEMA calculations
    - `{:error, reason}` - If validation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.dema_state_init(3)
      iex> is_reference(state) or is_struct(state)
      true

  """
  @spec dema_state_init(pos_integer()) :: {:ok, term()} | {:error, String.t()}
  defdelegate dema_state_init(period),
    to: Module.concat([@backend, Overlap, DEMAState]),
    as: :init

  @doc """
  Initialize DEMA state for incremental calculations - Bang version.

  Same as `dema_state_init/1` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `state` - Initial state for DEMA calculations

  ## Raises
    - `RuntimeError` if validation fails

  ## Examples
      iex> state = TheoryCraftTA.dema_state_init!(3)
      iex> is_reference(state) or is_struct(state)
      true

  """
  @spec dema_state_init!(pos_integer()) :: term()
  def dema_state_init!(period) do
    unwrap_init!(dema_state_init(period), "DEMA")
  end

  @doc """
  Process next value with DEMA state.

  Updates the DEMA state with a new value and returns the current DEMA value.
  Supports two modes:
  - APPEND mode (`is_new_bar = true`): Adds a new value to the window
  - UPDATE mode (`is_new_bar = false`): Recalculates DEMA with updated last value

  The first DEMA value requires enough data to calculate two levels of EMA.

  ## Parameters
    - `state` - Current DEMA state (from `dema_state_init/1` or previous `dema_state_next/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{:ok, dema_value, new_state}` - The DEMA value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.dema_state_init(2)
      iex> {:ok, nil, state2} = TheoryCraftTA.dema_state_next(state, 100.0, true)
      iex> {:ok, nil, state3} = TheoryCraftTA.dema_state_next(state2, 110.0, true)
      iex> {:ok, dema, _state4} = TheoryCraftTA.dema_state_next(state3, 120.0, true)
      iex> dema
      120.0

  """
  @spec dema_state_next(term(), float(), boolean()) ::
          {:ok, float() | nil, term()} | {:error, String.t()}
  defdelegate dema_state_next(state, value, is_new_bar),
    to: Module.concat([@backend, Overlap, DEMAState]),
    as: :next

  @doc """
  Process next value with DEMA state - Bang version.

  Same as `dema_state_next/3` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `state` - Current DEMA state (from `dema_state_init!/1` or previous `dema_state_next!/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{dema_value, new_state}` - The DEMA value (or nil during warmup) and updated state

  ## Raises
    - `RuntimeError` if calculation fails

  ## Examples
      iex> state = TheoryCraftTA.dema_state_init!(2)
      iex> {nil, state2} = TheoryCraftTA.dema_state_next!(state, 100.0, true)
      iex> {nil, state3} = TheoryCraftTA.dema_state_next!(state2, 110.0, true)
      iex> {dema, _state4} = TheoryCraftTA.dema_state_next!(state3, 120.0, true)
      iex> dema
      120.0

  """
  @spec dema_state_next!(term(), float(), boolean()) :: {float() | nil, term()}
  def dema_state_next!(state, value, is_new_bar) do
    unwrap_next!(dema_state_next(state, value, is_new_bar), "DEMA")
  end

  @doc """
  Initialize TEMA state for incremental calculations.

  Creates a new TEMA state that can be updated incrementally with each new value.
  This is useful for streaming data where you want to calculate the TEMA as new
  data arrives without recalculating the entire window.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, state}` - Initial state for TEMA calculations
    - `{:error, reason}` - If validation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.tema_state_init(3)
      iex> is_reference(state) or is_struct(state)
      true

  """
  @spec tema_state_init(pos_integer()) :: {:ok, term()} | {:error, String.t()}
  defdelegate tema_state_init(period),
    to: Module.concat([@backend, Overlap, TEMAState]),
    as: :init

  @doc """
  Initialize TEMA state for incremental calculations - Bang version.

  Same as `tema_state_init/1` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `state` - Initial state for TEMA calculations

  ## Raises
    - `RuntimeError` if validation fails

  ## Examples
      iex> state = TheoryCraftTA.tema_state_init!(3)
      iex> is_reference(state) or is_struct(state)
      true

  """
  @spec tema_state_init!(pos_integer()) :: term()
  def tema_state_init!(period) do
    unwrap_init!(tema_state_init(period), "TEMA")
  end

  @doc """
  Process next value with TEMA state.

  Updates the TEMA state with a new value and returns the current TEMA value.
  Supports two modes:
  - APPEND mode (`is_new_bar = true`): Adds a new value to the window
  - UPDATE mode (`is_new_bar = false`): Recalculates TEMA with updated last value

  The first TEMA value requires enough data to calculate three levels of EMA.

  ## Parameters
    - `state` - Current TEMA state (from `tema_state_init/1` or previous `tema_state_next/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{:ok, tema_value, new_state}` - The TEMA value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.tema_state_init(2)
      iex> {:ok, nil, state2} = TheoryCraftTA.tema_state_next(state, 100.0, true)
      iex> {:ok, nil, state3} = TheoryCraftTA.tema_state_next(state2, 110.0, true)
      iex> {:ok, nil, state4} = TheoryCraftTA.tema_state_next(state3, 120.0, true)
      iex> {:ok, tema, _state5} = TheoryCraftTA.tema_state_next(state4, 130.0, true)
      iex> tema
      130.0

  """
  @spec tema_state_next(term(), float(), boolean()) ::
          {:ok, float() | nil, term()} | {:error, String.t()}
  defdelegate tema_state_next(state, value, is_new_bar),
    to: Module.concat([@backend, Overlap, TEMAState]),
    as: :next

  @doc """
  Process next value with TEMA state - Bang version.

  Same as `tema_state_next/3` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `state` - Current TEMA state (from `tema_state_init!/1` or previous `tema_state_next!/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{tema_value, new_state}` - The TEMA value (or nil during warmup) and updated state

  ## Raises
    - `RuntimeError` if calculation fails

  ## Examples
      iex> state = TheoryCraftTA.tema_state_init!(2)
      iex> {nil, state2} = TheoryCraftTA.tema_state_next!(state, 100.0, true)
      iex> {nil, state3} = TheoryCraftTA.tema_state_next!(state2, 110.0, true)
      iex> {nil, state4} = TheoryCraftTA.tema_state_next!(state3, 120.0, true)
      iex> {tema, _state5} = TheoryCraftTA.tema_state_next!(state4, 130.0, true)
      iex> tema
      130.0

  """
  @spec tema_state_next!(term(), float(), boolean()) :: {float() | nil, term()}
  def tema_state_next!(state, value, is_new_bar) do
    unwrap_next!(tema_state_next(state, value, is_new_bar), "TEMA")
  end

  @doc """
  Initialize TRIMA state for incremental calculations.

  Creates a new TRIMA state that can be updated incrementally with each new value.
  This is useful for streaming data where you want to calculate the TRIMA as new
  data arrives without recalculating the entire window.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `{:ok, state}` - Initial state for TRIMA calculations
    - `{:error, reason}` - If validation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.trima_state_init(3)
      iex> is_reference(state) or is_struct(state)
      true

  """
  @spec trima_state_init(pos_integer()) :: {:ok, term()} | {:error, String.t()}
  defdelegate trima_state_init(period),
    to: Module.concat([@backend, Overlap, TRIMAState]),
    as: :init

  @doc """
  Initialize TRIMA state for incremental calculations - Bang version.

  Same as `trima_state_init/1` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)

  ## Returns
    - `state` - Initial state for TRIMA calculations

  ## Raises
    - `RuntimeError` if validation fails

  ## Examples
      iex> state = TheoryCraftTA.trima_state_init!(3)
      iex> is_reference(state) or is_struct(state)
      true

  """
  @spec trima_state_init!(pos_integer()) :: term()
  def trima_state_init!(period) do
    unwrap_init!(trima_state_init(period), "TRIMA")
  end

  @doc """
  Process next value with TRIMA state.

  Updates the TRIMA state with a new value and returns the current TRIMA value.
  Supports two modes:
  - APPEND mode (`is_new_bar = true`): Adds a new value to the window
  - UPDATE mode (`is_new_bar = false`): Recalculates TRIMA with updated last value

  The first TRIMA value requires enough data to calculate two levels of SMA.

  ## Parameters
    - `state` - Current TRIMA state (from `trima_state_init/1` or previous `trima_state_next/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{:ok, trima_value, new_state}` - The TRIMA value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.trima_state_init(2)
      iex> {:ok, nil, state2} = TheoryCraftTA.trima_state_next(state, 100.0, true)
      iex> {:ok, trima, _state3} = TheoryCraftTA.trima_state_next(state2, 110.0, true)
      iex> trima
      105.0

  """
  @spec trima_state_next(term(), float(), boolean()) ::
          {:ok, float() | nil, term()} | {:error, String.t()}
  defdelegate trima_state_next(state, value, is_new_bar),
    to: Module.concat([@backend, Overlap, TRIMAState]),
    as: :next

  @doc """
  Process next value with TRIMA state - Bang version.

  Same as `trima_state_next/3` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `state` - Current TRIMA state (from `trima_state_init!/1` or previous `trima_state_next!/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{trima_value, new_state}` - The TRIMA value (or nil during warmup) and updated state

  ## Raises
    - `RuntimeError` if calculation fails

  ## Examples
      iex> state = TheoryCraftTA.trima_state_init!(2)
      iex> {nil, state2} = TheoryCraftTA.trima_state_next!(state, 100.0, true)
      iex> {trima, _state3} = TheoryCraftTA.trima_state_next!(state2, 110.0, true)
      iex> trima
      105.0

  """
  @spec trima_state_next!(term(), float(), boolean()) :: {float() | nil, term()}
  def trima_state_next!(state, value, is_new_bar) do
    unwrap_next!(trima_state_next(state, value, is_new_bar), "TRIMA")
  end

  @doc """
  Initialize T3 state for incremental calculations.

  Creates a new T3 state that can be updated incrementally with each new value.
  This is useful for streaming data where you want to calculate the T3 as new
  data arrives without recalculating the entire window.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)
    - `vfactor` - Volume factor (typically 0.0 to 1.0, default is 0.7)

  ## Returns
    - `{:ok, state}` - Initial state for T3 calculations
    - `{:error, reason}` - If validation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.t3_state_init(3, 0.7)
      iex> is_reference(state) or is_struct(state)
      true

  """
  @spec t3_state_init(pos_integer(), float()) :: {:ok, term()} | {:error, String.t()}
  defdelegate t3_state_init(period, vfactor),
    to: Module.concat([@backend, Overlap, T3State]),
    as: :init

  @doc """
  Initialize T3 state for incremental calculations - Bang version.

  Same as `t3_state_init/2` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `period` - Number of periods for the moving average (must be an integer >= 2)
    - `vfactor` - Volume factor (typically 0.0 to 1.0, default is 0.7)

  ## Returns
    - `state` - Initial state for T3 calculations

  ## Raises
    - `RuntimeError` if validation fails

  ## Examples
      iex> state = TheoryCraftTA.t3_state_init!(3, 0.7)
      iex> is_reference(state) or is_struct(state)
      true

  """
  @spec t3_state_init!(pos_integer(), float()) :: term()
  def t3_state_init!(period, vfactor) do
    unwrap_init!(t3_state_init(period, vfactor), "T3")
  end

  @doc """
  Process next value with T3 state.

  Updates the T3 state with a new value and returns the current T3 value.
  Supports two modes:
  - APPEND mode (`is_new_bar = true`): Adds a new value to the window
  - UPDATE mode (`is_new_bar = false`): Recalculates T3 with updated last value

  The first T3 value requires enough data to calculate six levels of EMA.

  ## Parameters
    - `state` - Current T3 state (from `t3_state_init/2` or previous `t3_state_next/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{:ok, t3_value, new_state}` - The T3 value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.t3_state_init(2, 0.7)
      iex> {:ok, nil, state2} = TheoryCraftTA.t3_state_next(state, 100.0, true)
      iex> {:ok, nil, state3} = TheoryCraftTA.t3_state_next(state2, 110.0, true)
      iex> {:ok, t3, _state4} = TheoryCraftTA.t3_state_next(state3, 120.0, true)
      iex> is_nil(t3)
      true

  """
  @spec t3_state_next(term(), float(), boolean()) ::
          {:ok, float() | nil, term()} | {:error, String.t()}
  defdelegate t3_state_next(state, value, is_new_bar),
    to: Module.concat([@backend, Overlap, T3State]),
    as: :next

  @doc """
  Process next value with T3 state - Bang version.

  Same as `t3_state_next/3` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `state` - Current T3 state (from `t3_state_init!/2` or previous `t3_state_next!/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{t3_value, new_state}` - The T3 value (or nil during warmup) and updated state

  ## Raises
    - `RuntimeError` if calculation fails

  ## Examples
      iex> state = TheoryCraftTA.t3_state_init!(2, 0.7)
      iex> {nil, state2} = TheoryCraftTA.t3_state_next!(state, 100.0, true)
      iex> {nil, state3} = TheoryCraftTA.t3_state_next!(state2, 110.0, true)
      iex> {t3, _state4} = TheoryCraftTA.t3_state_next!(state3, 120.0, true)
      iex> is_nil(t3)
      true

  """
  @spec t3_state_next!(term(), float(), boolean()) :: {float() | nil, term()}
  def t3_state_next!(state, value, is_new_bar) do
    unwrap_next!(t3_state_next(state, value, is_new_bar), "T3")
  end

  @doc """
  Initialize MIDPOINT state for incremental calculations.

  Creates a new MIDPOINT state that can be updated incrementally with each new value.

  ## Parameters
    - `period` - Number of periods for the midpoint calculation (must be an integer >= 2)

  ## Returns
    - `{:ok, state}` - Initial state for MIDPOINT calculations
    - `{:error, reason}` - If validation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.midpoint_state_init(3)
      iex> is_reference(state) or is_struct(state)
      true

  """
  @spec midpoint_state_init(pos_integer()) :: {:ok, term()} | {:error, String.t()}
  defdelegate midpoint_state_init(period),
    to: Module.concat([@backend, Overlap, MIDPOINTState]),
    as: :init

  @doc """
  Initialize MIDPOINT state for incremental calculations - Bang version.

  Same as `midpoint_state_init/1` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `period` - Number of periods for the midpoint calculation (must be an integer >= 2)

  ## Returns
    - `state` - Initial state for MIDPOINT calculations

  ## Raises
    - `RuntimeError` if validation fails

  ## Examples
      iex> state = TheoryCraftTA.midpoint_state_init!(3)
      iex> is_reference(state) or is_struct(state)
      true

  """
  @spec midpoint_state_init!(pos_integer()) :: term()
  def midpoint_state_init!(period) do
    unwrap_init!(midpoint_state_init(period), "MIDPOINT")
  end

  @doc """
  Process next value with MIDPOINT state.

  Updates the MIDPOINT state with a new value and returns the current MIDPOINT value.

  ## Parameters
    - `state` - Current MIDPOINT state (from `midpoint_state_init/1` or previous `midpoint_state_next/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{:ok, midpoint_value, new_state}` - The MIDPOINT value (or nil during warmup) and updated state
    - `{:error, reason}` - If calculation fails

  ## Examples
      iex> {:ok, state} = TheoryCraftTA.midpoint_state_init(2)
      iex> {:ok, nil, state2} = TheoryCraftTA.midpoint_state_next(state, 100.0, true)
      iex> {:ok, midpoint, _state3} = TheoryCraftTA.midpoint_state_next(state2, 110.0, true)
      iex> midpoint
      105.0

  """
  @spec midpoint_state_next(term(), float(), boolean()) ::
          {:ok, float() | nil, term()} | {:error, String.t()}
  defdelegate midpoint_state_next(state, value, is_new_bar),
    to: Module.concat([@backend, Overlap, MIDPOINTState]),
    as: :next

  @doc """
  Process next value with MIDPOINT state - Bang version.

  Same as `midpoint_state_next/3` but raises an exception instead of returning an error tuple.

  ## Parameters
    - `state` - Current MIDPOINT state (from `midpoint_state_init!/1` or previous `midpoint_state_next!/3`)
    - `value` - New data point (float)
    - `is_new_bar` - Whether this is a new bar (true) or an update to the last bar (false)

  ## Returns
    - `{midpoint_value, new_state}` - The MIDPOINT value (or nil during warmup) and updated state

  ## Raises
    - `RuntimeError` if calculation fails

  ## Examples
      iex> state = TheoryCraftTA.midpoint_state_init!(2)
      iex> {nil, state2} = TheoryCraftTA.midpoint_state_next!(state, 100.0, true)
      iex> {midpoint, _state3} = TheoryCraftTA.midpoint_state_next!(state2, 110.0, true)
      iex> midpoint
      105.0

  """
  @spec midpoint_state_next!(term(), float(), boolean()) :: {float() | nil, term()}
  def midpoint_state_next!(state, value, is_new_bar) do
    unwrap_next!(midpoint_state_next(state, value, is_new_bar), "MIDPOINT")
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
