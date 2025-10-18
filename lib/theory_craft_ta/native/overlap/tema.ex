defmodule TheoryCraftTA.Native.Overlap.TEMA do
  @moduledoc """
  Triple Exponential Moving Average - Native implementation using Rust NIF.

  Calculates the triple exponential moving average of the input data over the specified period.
  TEMA is calculated as: 3 * EMA(period) - 3 * EMA(EMA(period)) + EMA(EMA(EMA(period))).
  This provides a smoother average with even less lag than DEMA.
  """

  alias TheoryCraftTA.{Native, Helpers}

  @doc """
  Triple Exponential Moving Average - Native implementation using Rust NIF.

  Calculates the triple exponential moving average of the input data over the specified period.
  TEMA is calculated as: 3 * EMA(period) - 3 * EMA(EMA(period)) + EMA(EMA(EMA(period))).

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with TEMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.Native.Overlap.TEMA.tema([1.0, 2.0, 3.0, 4.0, 5.0], 2)
      {:ok, [nil, nil, nil, 4.0, 5.0]}

  """
  @spec tema(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def tema(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_tema(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end
end
