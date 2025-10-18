defmodule TheoryCraftTA.Native.Overlap.T3 do
  @moduledoc """
  T3 (Tillson T3) - Native implementation using Rust NIF.

  Calculates the Tillson T3 moving average of the input data over the specified period.
  T3 is a smoothing technique that applies a sequence of generalized DEMA filters
  (GD) to reduce lag and noise. It uses a volume factor to control smoothing.

  The T3 algorithm applies six successive EMA filters with the volume factor.
  """

  alias TheoryCraftTA.{Native, Helpers}

  @doc """
  T3 (Tillson T3) - Native implementation using Rust NIF.

  Calculates the Tillson T3 moving average of the input data over the specified period.
  T3 is a smoothing technique that applies a sequence of generalized DEMA filters
  to reduce lag and noise.

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be integer >= 2)
    - `vfactor` - Volume factor (typically 0.0 to 1.0, default is 0.7)

  ## Returns
    - `{:ok, result}` where result is the same type as input with T3 values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples
      iex> TheoryCraftTA.Native.Overlap.T3.t3([1.0, 2.0, 3.0, 4.0, 5.0], 2, 0.7)
      {:ok, [nil, nil, nil, nil, nil]}

  """
  @spec t3(TheoryCraftTA.source(), pos_integer(), float()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def t3(data, period, vfactor) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_t3(list_data, period, vfactor) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end
end
