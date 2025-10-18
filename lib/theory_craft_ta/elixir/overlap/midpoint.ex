defmodule TheoryCraftTA.Elixir.Overlap.MIDPOINT do
  @moduledoc """
  MidPoint over period - Pure Elixir implementation.

  Calculates the midpoint (average of highest and lowest values) over the specified period.
  """

  alias TheoryCraftTA.Helpers

  @doc """
  MidPoint over period - Pure Elixir implementation.

  Calculates the midpoint (average of highest and lowest values) over the specified period.
  Formula: MIDPOINT = (MAX + MIN) / 2

  ## Parameters
    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the midpoint calculation (must be integer >= 2)

  ## Returns
    - `{:ok, result}` where result is the same type as input with MIDPOINT values
    - `{:error, reason}` if validation fails

  ## Examples
      iex> TheoryCraftTA.Elixir.Overlap.MIDPOINT.midpoint([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec midpoint(TheoryCraftTA.source(), integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def midpoint(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    if length(list_data) == 0 do
      {:ok, Helpers.rebuild_same_type(data, [])}
    else
      if period < 2 do
        {:error, "Invalid period: must be >= 2 for MIDPOINT"}
      else
        result = calculate_midpoint(list_data, period)
        {:ok, Helpers.rebuild_same_type(data, result)}
      end
    end
  end

  ## Private functions

  defp calculate_midpoint(data, period) do
    data_length = length(data)

    midpoint_values =
      data
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(&calculate_midpoint_value/1)

    lookback = period - 1
    num_nils = min(lookback, data_length)

    List.duplicate(nil, num_nils) ++ midpoint_values
  end

  defp calculate_midpoint_value(values) do
    max_val = Enum.max(values)
    min_val = Enum.min(values)

    (max_val + min_val) / 2
  end
end
