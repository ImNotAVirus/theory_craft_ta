defmodule TheoryCraftTA.Native.Overlap.DEMA do
  @moduledoc """
  Double Exponential Moving Average - Native implementation using Rust NIF.

  Calculates the double exponential moving average of the input data over the specified period.
  DEMA is calculated as: 2 * EMA(period) - EMA(EMA(period)).
  This provides a smoother average with less lag than a simple EMA.
  """

  alias TheoryCraftTA.{Native, Helpers}

  @doc """
  Double Exponential Moving Average - Native implementation using Rust NIF.

  Calculates the double exponential moving average of the input data over the specified period.
  DEMA is calculated as: 2 * EMA(period) - EMA(EMA(period)).

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with DEMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.Native.Overlap.DEMA.dema([1.0, 2.0, 3.0, 4.0, 5.0], 2)
      {:ok, [nil, nil, 3.0, 4.0, 5.0]}

  """
  @spec dema(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def dema(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_dema(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end
end
