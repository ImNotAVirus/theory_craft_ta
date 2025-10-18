defmodule TheoryCraftTA.Elixir.Overlap.SARState do
  @moduledoc """
  State-based implementation of Parabolic SAR for streaming data.

  This module provides a stateful implementation that can process high/low prices
  one bar at a time, maintaining internal state for incremental SAR calculations.
  """

  @type t :: %__MODULE__{
          acceleration: float(),
          maximum: float(),
          is_long: boolean() | nil,
          sar: float() | nil,
          ep: float() | nil,
          af: float(),
          prev_high: float() | nil,
          prev_low: float() | nil,
          prev_prev_high: float() | nil,
          prev_prev_low: float() | nil,
          prev_sar: float() | nil,
          prev_ep: float() | nil,
          prev_af: float() | nil,
          prev_is_long: boolean() | nil,
          bar_count: non_neg_integer()
        }

  defstruct acceleration: 0.02,
            maximum: 0.20,
            is_long: nil,
            sar: nil,
            ep: nil,
            af: 0.02,
            prev_high: nil,
            prev_low: nil,
            prev_prev_high: nil,
            prev_prev_low: nil,
            prev_sar: nil,
            prev_ep: nil,
            prev_af: nil,
            prev_is_long: nil,
            bar_count: 0

  @doc """
  Initializes a new SAR state.

  ## Parameters
    - `acceleration` - Acceleration Factor (default: 0.02)
    - `maximum` - Maximum Acceleration Factor (default: 0.20)

  ## Returns
    - `{:ok, state}` - Initial state
    - `{:error, reason}` - Error message

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.SARState.init()
      iex> state.acceleration
      0.02

  """
  @spec init(float(), float()) :: {:ok, t()} | {:error, String.t()}
  def init(acceleration \\ 0.02, maximum \\ 0.20) do
    cond do
      acceleration <= 0.0 ->
        {:error, "acceleration must be positive"}

      maximum <= 0.0 ->
        {:error, "maximum must be positive"}

      acceleration > maximum ->
        {:error, "acceleration must be less than or equal to maximum"}

      true ->
        {:ok,
         %__MODULE__{
           acceleration: acceleration,
           maximum: maximum,
           af: acceleration
         }}
    end
  end

  @doc """
  Processes the next high/low bar.

  ## Parameters
    - `state` - Current SAR state
    - `high` - High price
    - `low` - Low price
    - `is_new_bar` - true for APPEND mode, false for UPDATE mode

  ## Returns
    - `{sar_value, new_state}` - SAR value (or nil during warmup) and updated state

  ## Examples

      iex> {:ok, state} = TheoryCraftTA.Elixir.Overlap.SARState.init()
      iex> {result, _state} = TheoryCraftTA.Elixir.Overlap.SARState.next(state, 10.0, 8.0, true)
      iex> result
      nil

  """
  @spec next(t(), float(), float(), boolean()) :: {:ok, float() | nil, t()} | {:error, String.t()}
  def next(state, high, low, is_new_bar)

  # First bar - just store values
  def next(%__MODULE__{bar_count: 0} = state, high, low, true) do
    new_state = %{state | prev_high: high, prev_low: low, bar_count: 1}
    {:ok, nil, new_state}
  end

  # Second bar - initialize position
  def next(%__MODULE__{bar_count: 1} = state, high, low, true) do
    %{prev_high: prev_high, prev_low: prev_low, acceleration: accel} = state

    # Determine initial trend direction
    {is_long, initial_sar, initial_ep} =
      if high - prev_high > prev_low - low do
        # Uptrend
        {true, prev_low, high}
      else
        # Downtrend
        {false, prev_high, low}
      end

    new_state = %{
      state
      | is_long: is_long,
        sar: initial_sar,
        ep: initial_ep,
        af: accel,
        prev_high: high,
        prev_low: low,
        bar_count: 2
    }

    {:ok, initial_sar, new_state}
  end

  # Subsequent bars - normal SAR calculation
  def next(%__MODULE__{bar_count: count} = state, high, low, true) when count >= 2 do
    %{is_long: is_long, sar: sar, ep: ep, af: af, acceleration: accel, maximum: max_af} = state
    %{prev_high: prev_high, prev_low: prev_low} = state

    # Calculate new SAR
    new_sar = sar + af * (ep - sar)

    # Check for reversal
    {final_sar, new_ep, new_af, new_is_long} =
      if is_long do
        # Long position
        if low <= new_sar do
          # Reversal to short
          {ep, low, accel, false}
        else
          # Continue long
          adjusted_sar = new_sar

          # Update EP and AF if new high
          {updated_ep, updated_af} =
            if high > ep do
              {high, min(af + accel, max_af)}
            else
              {ep, af}
            end

          {adjusted_sar, updated_ep, updated_af, true}
        end
      else
        # Short position
        if high >= new_sar do
          # Reversal to long
          {ep, high, accel, true}
        else
          # Continue short
          adjusted_sar = new_sar

          # Update EP and AF if new low
          {updated_ep, updated_af} =
            if low < ep do
              {low, min(af + accel, max_af)}
            else
              {ep, af}
            end

          {adjusted_sar, updated_ep, updated_af, false}
        end
      end

    new_state = %{
      state
      | is_long: new_is_long,
        sar: final_sar,
        ep: new_ep,
        af: new_af,
        prev_high: high,
        prev_low: low,
        prev_prev_high: prev_high,
        prev_prev_low: prev_low,
        prev_sar: sar,
        prev_ep: ep,
        prev_af: af,
        prev_is_long: is_long,
        bar_count: count + 1
    }

    {:ok, final_sar, new_state}
  end

  # UPDATE mode - recalculate with new high/low for current bar
  def next(%__MODULE__{bar_count: count} = state, high, low, false) when count >= 2 do
    # For UPDATE mode, restore the state from before the last bar was added
    # Then recalculate with the new values
    # NOTE: There's a known issue where UPDATE may not return the exact same value
    # as APPEND did for the same bar due to how SAR state is maintained.
    # This is a complex stateful indicator and UPDATE mode needs more investigation.
    %{
      prev_sar: prev_sar,
      prev_ep: prev_ep,
      prev_af: prev_af,
      prev_is_long: prev_is_long,
      prev_prev_high: prev_prev_high,
      prev_prev_low: prev_prev_low
    } = state

    temp_state = %{
      state
      | bar_count: count - 1,
        sar: prev_sar,
        ep: prev_ep,
        af: prev_af,
        is_long: prev_is_long,
        prev_high: prev_prev_high,
        prev_low: prev_prev_low
    }

    {:ok, result, updated_state} = next(temp_state, high, low, true)

    # Restore bar count (it was incremented in APPEND mode)
    final_state = %{updated_state | bar_count: count}

    {:ok, result, final_state}
  end

  # UPDATE mode during warmup - just update stored values
  def next(%__MODULE__{bar_count: count} = state, high, low, false) when count < 2 do
    if count == 0 do
      {:ok, nil, %{state | prev_high: high, prev_low: low}}
    else
      # UPDATE second bar
      {:ok, nil, %{state | prev_high: high, prev_low: low}}
    end
  end
end
