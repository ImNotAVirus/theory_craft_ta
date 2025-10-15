defmodule TheoryCraftTA.Native.Overlap do
  @moduledoc false

  # This module provides Native (Rust NIF) implementations of overlap indicators.
  # Overlap indicators include: SMA, EMA, BBANDS, etc.

  alias TheoryCraftTA.{Native, Helpers}
  alias TheoryCraft.{DataSeries, TimeSeries}

  @doc """
  Simple Moving Average - Native implementation using Rust NIF.

  Calculates the simple moving average of the input data over the specified period.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with SMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.Native.Overlap.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec sma(list(float()) | DataSeries.t() | TimeSeries.t(), pos_integer()) ::
          {:ok, list(float() | nil) | DataSeries.t() | TimeSeries.t()} | {:error, String.t()}
  def sma(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_sma(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end
end
