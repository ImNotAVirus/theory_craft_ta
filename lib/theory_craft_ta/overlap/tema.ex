defmodule TheoryCraftTA.Overlap.TEMA do
  @moduledoc """
  Triple Exponential Moving Average (TEMA).

  The Triple Exponential Moving Average further reduces lag by applying EMA three times.
  It is highly responsive to recent price movements.

  ## Calculation

  TEMA = 3×EMA - 3×EMA(EMA) + EMA(EMA(EMA))

  Where:
  - n = period
  - P₁ = most recent price
  - Pₙ = oldest price in the period

  """

  alias TheoryCraftTA.{Native, Helpers}

  @type t :: reference()

  ## Public API

  @doc """
  Calculates Triple Exponential Moving Average (batch calculation).

  ## Parameters

    - `data` - Input data (list of floats, DataSeries, or TimeSeries)
    - `period` - Number of periods for the moving average (must be >= 2)

  ## Returns

    - `{:ok, result}` where result is the same type as input with TEMA values
    - `{:error, reason}` if validation fails or calculation error occurs

  ## Examples

      iex> TheoryCraftTA.Overlap.TEMA.tema([1.0, 2.0, 3.0, 4.0, 5.0], 2)
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

  @doc """
  Initializes a new TEMA state for streaming calculation.

  ## Parameters

    - `period` - The TEMA period (must be >= 2)

  ## Returns

    - `{:ok, state}` - Initialized state
    - `{:error, message}` - If period is invalid

  ## Examples

      iex> {:ok, _state} = TheoryCraftTA.Overlap.TEMA.init(14)

  """
  @spec init(pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(period) when is_integer(period) do
    Native.overlap_tema_state_init(period)
  end

  @doc """
  Calculates the next TEMA value in streaming mode.

  ## Parameters

    - `value` - New price value
    - `is_new_bar` - true for new bar (APPEND), false for same bar update (UPDATE)
    - `state` - Current TEMA state (from init or previous next call)

  ## Returns

    - `{:ok, tema_value, new_state}` where tema_value is nil during warmup
    - `{:error, message}` on error

  ## Behavior

  - **UPDATE mode** (`is_new_bar = false`): Updates last value in buffer, recalculates TEMA
  - **APPEND mode** (`is_new_bar = true`): Adds new value, removes oldest if buffer full

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Overlap.TEMA.init(2)
      iex> {:ok, tema, state2} = TheoryCraftTA.Overlap.TEMA.next(100.0, true, state)
      iex> tema
      nil
      iex> {:ok, tema, state3} = TheoryCraftTA.Overlap.TEMA.next(110.0, true, state2)
      iex> tema
      nil
      iex> {:ok, tema, state4} = TheoryCraftTA.Overlap.TEMA.next(120.0, true, state3)
      iex> tema
      nil
      iex> {:ok, tema, _state5} = TheoryCraftTA.Overlap.TEMA.next(130.0, true, state4)
      iex> tema
      130.0

  """
  @spec next(float(), boolean(), t()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(value, is_new_bar, state) when is_float(value) and is_boolean(is_new_bar) do
    case Native.overlap_tema_state_next(state, value, is_new_bar) do
      {:ok, {tema_value, new_state}} ->
        {:ok, tema_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
