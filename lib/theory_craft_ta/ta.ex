defmodule TheoryCraftTA.TA do
  @moduledoc """
  Syntactic sugar for TheoryCraftTA indicators in MarketSimulator.

  Provides macros to simplify indicator spec creation for use with
  `TheoryCraft.MarketSimulator.add_indicator/2`.

  ## Usage

  Instead of writing verbose specs like:

      simulator
      |> MarketSimulator.add_indicator(
        {TheoryCraftTA.Overlap.SMA, [period: 14, data: "eurusd", name: "sma14", source: :close]}
      )

  You can use the compact syntax:

      simulator
      |> MarketSimulator.add_indicator(TA.sma(eurusd[:close], 14, name: "sma14"))
      |> MarketSimulator.add_indicator(TA.ema(eurusd[:close], 20, name: "ema20"))

  ## Syntax

  The first argument can be:
  - An accessor: `eurusd[:close]` - extracts data name and source field
  - A string: `"eurusd"` - uses the string as data name, source defaults to module behavior
  - A variable: `eurusd` - converts to string and uses as data name

  ## Examples

      # With accessor - explicitly specifies source
      TA.sma(eurusd[:close], 14, name: "sma14")
      # => {TheoryCraftTA.Overlap.SMA, [period: 14, data: "eurusd", source: :close, name: "sma14"]}

      # Without accessor - omits source, module will use its default
      TA.sma("eurusd", 14, name: "sma14")
      # => {TheoryCraftTA.Overlap.SMA, [period: 14, data: "eurusd", name: "sma14"]}

      # With additional options
      TA.sma(eurusd[:close], 14, name: "sma14", bar_name: "eurusd_m1")
      # => {TheoryCraftTA.Overlap.SMA, [period: 14, data: "eurusd", source: :close, name: "sma14", bar_name: "eurusd_m1"]}

      # T3 with vfactor parameter
      TA.t3(eurusd[:close], 5, 0.7, name: "t3")
      # => {TheoryCraftTA.Overlap.T3, [period: 5, vfactor: 0.7, data: "eurusd", source: :close, name: "t3"]}

  """

  ## Overlap indicators

  @doc """
  Simple Moving Average (SMA).

  ## Parameters

  - `data_or_accessor` - Data source (e.g., `eurusd[:close]` or `"eurusd"`)
  - `period` - Number of periods for the moving average
  - `opts` - Additional options (e.g., `name: "sma14"`, `bar_name: "eurusd_m1"`)

  """
  defmacro sma(data_or_accessor, period, opts \\ []) do
    {data, source} = parse_data_accessor(data_or_accessor)

    base_opts = [period: period, data: data]
    base_opts = if source, do: base_opts ++ [source: source], else: base_opts
    keyword_list = base_opts ++ opts

    quote do
      {TheoryCraftTA.Overlap.SMA, unquote(keyword_list)}
    end
  end

  @doc """
  Exponential Moving Average (EMA).

  ## Parameters

  - `data_or_accessor` - Data source (e.g., `eurusd[:close]` or `"eurusd"`)
  - `period` - Number of periods for the moving average
  - `opts` - Additional options (e.g., `name: "ema14"`, `bar_name: "eurusd_m1"`)

  """
  defmacro ema(data_or_accessor, period, opts \\ []) do
    {data, source} = parse_data_accessor(data_or_accessor)

    base_opts = [period: period, data: data]
    base_opts = if source, do: base_opts ++ [source: source], else: base_opts
    keyword_list = base_opts ++ opts

    quote do
      {TheoryCraftTA.Overlap.EMA, unquote(keyword_list)}
    end
  end

  @doc """
  Weighted Moving Average (WMA).

  ## Parameters

  - `data_or_accessor` - Data source (e.g., `eurusd[:close]` or `"eurusd"`)
  - `period` - Number of periods for the moving average
  - `opts` - Additional options (e.g., `name: "wma14"`, `bar_name: "eurusd_m1"`)

  """
  defmacro wma(data_or_accessor, period, opts \\ []) do
    {data, source} = parse_data_accessor(data_or_accessor)

    base_opts = [period: period, data: data]
    base_opts = if source, do: base_opts ++ [source: source], else: base_opts
    keyword_list = base_opts ++ opts

    quote do
      {TheoryCraftTA.Overlap.WMA, unquote(keyword_list)}
    end
  end

  @doc """
  Double Exponential Moving Average (DEMA).

  ## Parameters

  - `data_or_accessor` - Data source (e.g., `eurusd[:close]` or `"eurusd"`)
  - `period` - Number of periods for the moving average
  - `opts` - Additional options (e.g., `name: "dema14"`, `bar_name: "eurusd_m1"`)

  """
  defmacro dema(data_or_accessor, period, opts \\ []) do
    {data, source} = parse_data_accessor(data_or_accessor)

    base_opts = [period: period, data: data]
    base_opts = if source, do: base_opts ++ [source: source], else: base_opts
    keyword_list = base_opts ++ opts

    quote do
      {TheoryCraftTA.Overlap.DEMA, unquote(keyword_list)}
    end
  end

  @doc """
  Triple Exponential Moving Average (TEMA).

  ## Parameters

  - `data_or_accessor` - Data source (e.g., `eurusd[:close]` or `"eurusd"`)
  - `period` - Number of periods for the moving average
  - `opts` - Additional options (e.g., `name: "tema14"`, `bar_name: "eurusd_m1"`)

  """
  defmacro tema(data_or_accessor, period, opts \\ []) do
    {data, source} = parse_data_accessor(data_or_accessor)

    base_opts = [period: period, data: data]
    base_opts = if source, do: base_opts ++ [source: source], else: base_opts
    keyword_list = base_opts ++ opts

    quote do
      {TheoryCraftTA.Overlap.TEMA, unquote(keyword_list)}
    end
  end

  @doc """
  Triangular Moving Average (TRIMA).

  ## Parameters

  - `data_or_accessor` - Data source (e.g., `eurusd[:close]` or `"eurusd"`)
  - `period` - Number of periods for the moving average
  - `opts` - Additional options (e.g., `name: "trima14"`, `bar_name: "eurusd_m1"`)

  """
  defmacro trima(data_or_accessor, period, opts \\ []) do
    {data, source} = parse_data_accessor(data_or_accessor)

    base_opts = [period: period, data: data]
    base_opts = if source, do: base_opts ++ [source: source], else: base_opts
    keyword_list = base_opts ++ opts

    quote do
      {TheoryCraftTA.Overlap.TRIMA, unquote(keyword_list)}
    end
  end

  @doc """
  MidPoint over period.

  ## Parameters

  - `data_or_accessor` - Data source (e.g., `eurusd[:close]` or `"eurusd"`)
  - `period` - Number of periods
  - `opts` - Additional options (e.g., `name: "midpoint14"`, `bar_name: "eurusd_m1"`)

  """
  defmacro midpoint(data_or_accessor, period, opts \\ []) do
    {data, source} = parse_data_accessor(data_or_accessor)

    base_opts = [period: period, data: data]
    base_opts = if source, do: base_opts ++ [source: source], else: base_opts
    keyword_list = base_opts ++ opts

    quote do
      {TheoryCraftTA.Overlap.MIDPOINT, unquote(keyword_list)}
    end
  end

  @doc """
  T3 (Tillson T3) Moving Average.

  ## Parameters

  - `data_or_accessor` - Data source (e.g., `eurusd[:close]` or `"eurusd"`)
  - `period` - Number of periods for the moving average
  - `vfactor` - Volume factor (typically between 0 and 1)
  - `opts` - Additional options (e.g., `name: "t3"`, `bar_name: "eurusd_m1"`)

  """
  defmacro t3(data_or_accessor, period, vfactor, opts \\ []) do
    {data, source} = parse_data_accessor(data_or_accessor)

    base_opts = [period: period, vfactor: vfactor, data: data]
    base_opts = if source, do: base_opts ++ [source: source], else: base_opts
    keyword_list = base_opts ++ opts

    quote do
      {TheoryCraftTA.Overlap.T3, unquote(keyword_list)}
    end
  end

  ## Private functions

  defp parse_data_accessor({{:., _, [Access, :get]}, _, [var, source]}) do
    data =
      case var do
        {name, _, _} -> Atom.to_string(name)
        other -> other
      end

    {data, source}
  end

  defp parse_data_accessor(var) do
    data =
      case var do
        {name, _, _} -> Atom.to_string(name)
        other -> other
      end

    {data, nil}
  end
end
