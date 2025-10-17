defmodule TheoryCraftTA.Native.Overlap.EMA do
  @moduledoc """
  Exponential Moving Average - Native implementation using Rust NIF.

  Calculates the exponential moving average of the input data over the specified period.
  EMA applies more weight to recent values using an exponential decay factor.
  """

  alias TheoryCraftTA.{Native, Helpers}

  @doc """
  Exponential Moving Average - Native implementation using Rust NIF.

  Calculates the exponential moving average of the input data over the specified period.
  EMA applies more weight to recent values using an exponential decay factor.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with EMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.Native.Overlap.EMA.ema([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec ema(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def ema(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_ema(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end
end
