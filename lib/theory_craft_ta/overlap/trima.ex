defmodule TheoryCraftTA.Overlap.TRIMA do
  @moduledoc """
  Triangular Moving Average (TRIMA).

  The Triangular Moving Average applies double smoothing by calculating the SMA of an SMA.
  This produces a smoother average with less sensitivity to price spikes.

  ## Calculation

  TRIMA = SMA(SMA(price))

  Where:
  - n = period
  - P₁ = most recent price
  - Pₙ = oldest price in the period

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates Triangular Moving Average (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with TRIMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.TRIMA.trima([1.0, 2.0, 3.0, 4.0, 5.0], 3)
      {:ok, [nil, nil, 2.0, 3.0, 4.0]}

  """
  @spec trima(TheoryCraftTA.source(), pos_integer()) ::
          {:ok, TheoryCraftTA.source()} | {:error, String.t()}
  def trima(data, period) do
    list_data = Helpers.to_list_and_reverse(data)

    case Native.overlap_trima(list_data, period) do
      {:ok, result_list} ->
        {:ok, Helpers.rebuild_same_type(data, result_list)}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Initializes a new TRIMA state for streaming calculation.

  ## Parameters

    - `period` - The TRIMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` - Initialized state
    - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.TRIMA.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_trima_state_init(period)
  end

  @doc """
  Calculates the next TRIMA value in streaming mode.

  ## Parameters

    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)
    - `state` - Current TRIMA state (from init or previous next call)

  ## Returns

    - `{:ok, trima_value, new_state}` where trima_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Updates last value in buffer, recalculates TRIMA
  - **APPEND mode** (`is_new_bar = true`): Adds new value, removes oldest if buffer full

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.TRIMA.init(2)
      iex> {:ok, trima, state2} = TheoryCraftTA.Overlap.TRIMA.next(100.0, true, state)
      iex> trima
      nil
      iex> {:ok, trima, _state3} = TheoryCraftTA.Overlap.TRIMA.next(110.0, true, state2)
      iex> trima
      105.0

  """
  @spec next(float(), boolean(), t()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(value, is_new_bar, state) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_trima_state_next(state, value, is_new_bar) do
      {:ok, {trima_value, new_state}} ->
        {:ok, trima_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
