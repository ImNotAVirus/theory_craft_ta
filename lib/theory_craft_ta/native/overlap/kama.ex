defmodule TheoryCraftTA.Native.Overlap.KAMA do
  @moduledoc """
  Kaufman Adaptive Moving Average - Native implementation using Rust NIF.

  KAMA is an adaptive moving average that adjusts its sensitivity based on market volatility.
  It uses the Efficiency Ratio (ER) to determine how directional the price movement is.
  """

  alias TheoryCraftTA.{Native, Helpers}

  @doc """
  Kaufman Adaptive Moving Average - Native implementation using Rust NIF.

  KAMA adapts its smoothing based on price movement efficiency. In trending markets,
  it becomes more responsive; in choppy markets, it smooths more.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the efficiency ratio (must be integer >= 2, default 30)

  ## Returns
    - `{:ok, result}` where result is the same type as input with KAMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> {:ok, result} = TheoryCraftTA.Native.Overlap.KAMA.kama([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0], 5)
      iex> Enum.map(result, fn nil -> nil; x -> Float.round(x, 2) end)
      [nil, nil, nil, nil, nil, 5.44, 6.14, 6.96, 7.87, 8.82]

  """
  @spec kama(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def kama(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_kama(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end
end
