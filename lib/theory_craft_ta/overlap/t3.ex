defmodule TheoryCraftTA.Overlap.T3 do
  @moduledoc """
  T3 Moving Average (T3).

  The T3 Moving Average uses a generalized DEMA applied six times for extreme smoothness.
  It has minimal lag while providing excellent smoothing.

  ## Calculation

  T3 = GD(GD(GD(GD(GD(GD(price)))))), where GD = generalized DEMA

  Where:
  - n = period
  - P₁ = most recent price
  - Pₙ = oldest price in the period

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates T3 Moving Average (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with T3 values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
      iex> {:ok, result} = TheoryCraftTA.Overlap.T3.t3(data, 2, 0.7)
      iex> Enum.map(result, fn
      ...>   nil -> nil
      ...>   val -> Float.round(val, 2)
      ...> end)
      [nil, nil, nil, nil, nil, nil, 6.55, 7.55, 8.55, 9.55]

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

  @doc """
  Initializes a new T3 state for streaming calculation.

  ## Parameters

    - `period` - The T3 period (must be >= 2)
    - `vfactor` - Volume factor (typically 0.0 to 1.0)

  ## Returns

    - `{:ok, state}` - Initialized state
    - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.T3.init(14, 0.7)

  """
  @spec init(pos_integer(), float()) :: {:ok, t()} | {:error, String.t()}
  def init(period, vfactor) when is_integer(period) and is_float(vfactor) do
    Native.overlap_t3_state_init(period, vfactor)
  end

  @doc """
  Calculates the next T3 value in streaming mode.

  ## Parameters

    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)
    - `state` - Current T3 state (from init or previous next call)

  ## Returns

    - `{:ok, t3_value, new_state}` where t3_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Updates last value in buffer, recalculates T3
  - **APPEND mode** (`is_new_bar = true`): Adds new value, removes oldest if buffer full

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.T3.init(2, 0.7)
      iex> {:ok, t3, state2} = TheoryCraftTA.Overlap.T3.next(100.0, true, state)
      iex> t3
      nil
      iex> {:ok, t3, _state3} = TheoryCraftTA.Overlap.T3.next(110.0, true, state2)
      iex> t3
      nil

  """
  @spec next(float(), boolean(), t()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(value, is_new_bar, state) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_t3_state_next(state, value, is_new_bar) do
      {:ok, {t3_value, new_state}} ->
        {:ok, t3_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
