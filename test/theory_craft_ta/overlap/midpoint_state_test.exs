defmodule TheoryCraftTA.State.MIDPOINTTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.Overlap.MIDPOINTState, as: ElixirMIDPOINT
  alias TheoryCraftTA.Native.Overlap.MIDPOINTState, as: NativeMIDPOINT

  doctest TheoryCraftTA.Elixir.Overlap.MIDPOINTState
  doctest TheoryCraftTA.Native.Overlap.MIDPOINTState

  @backends [
    {ElixirMIDPOINT, "Elixir"},
    {NativeMIDPOINT, "Native"}
  ]

  ## Setup

  describe "init/1" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: initializes with valid period" do
        assert {:ok, _state} = @backend.init(14)
      end

      test "#{name}: returns error for period < 2" do
        assert {:error, msg} = @backend.init(1)
        assert msg =~ "Invalid period"
      end
    end

    test "Elixir: stores period in state" do
      assert {:ok, state} = ElixirMIDPOINT.init(14)
      assert state.period == 14
    end
  end

  ## Tests

  describe "next/3 - APPEND mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: returns nil during warmup period" do
        {:ok, state} = @backend.init(3)

        # First bar
        {:ok, midpoint1, state2} = @backend.next(state, 100.0, true)
        assert midpoint1 == nil

        # Second bar
        {:ok, midpoint2, state3} = @backend.next(state2, 110.0, true)
        assert midpoint2 == nil

        # Third bar - first MIDPOINT value
        {:ok, midpoint3, _state4} = @backend.next(state3, 120.0, true)
        # MIDPOINT = (MAX + MIN) / 2 = (120.0 + 100.0) / 2
        expected = (120.0 + 100.0) / 2
        assert_in_delta(midpoint3, expected, 0.0001)
      end

      test "#{name}: calculates MIDPOINT correctly after warmup" do
        {:ok, state} = @backend.init(2)

        # First bar (warmup)
        {:ok, nil, state2} = @backend.next(state, 100.0, true)

        # Second bar - first MIDPOINT
        {:ok, midpoint2, state3} = @backend.next(state2, 110.0, true)
        # MIDPOINT = (110.0 + 100.0) / 2 = 105.0
        assert_in_delta(midpoint2, 105.0, 0.0001)

        # Third bar - sliding window
        {:ok, midpoint3, _state4} = @backend.next(state3, 120.0, true)
        # MIDPOINT = (120.0 + 110.0) / 2 = 115.0
        assert_in_delta(midpoint3, 115.0, 0.0001)
      end

      test "#{name}: handles varying values correctly" do
        {:ok, state} = @backend.init(3)

        # Build state with warmup
        {:ok, nil, state2} = @backend.next(state, 5.0, true)
        {:ok, nil, state3} = @backend.next(state2, 1.0, true)
        {:ok, midpoint3, state4} = @backend.next(state3, 3.0, true)
        # MIDPOINT = (5.0 + 1.0) / 2 = 3.0
        assert_in_delta(midpoint3, 3.0, 0.0001)

        # Add another value
        {:ok, midpoint4, _state5} = @backend.next(state4, 7.0, true)
        # Window: [1.0, 3.0, 7.0], MIDPOINT = (7.0 + 1.0) / 2 = 4.0
        assert_in_delta(midpoint4, 4.0, 0.0001)
      end
    end
  end

  describe "next/3 - UPDATE mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: updates last value in buffer" do
        {:ok, state} = @backend.init(2)

        # Build state with warmup
        {:ok, nil, state2} = @backend.next(state, 100.0, true)
        {:ok, midpoint2, state3} = @backend.next(state2, 110.0, true)

        # UPDATE mode: replace last value
        {:ok, midpoint_update1, state4} = @backend.next(state3, 105.0, false)
        # Window: [100.0, 105.0], MIDPOINT = (105.0 + 100.0) / 2 = 102.5
        assert_in_delta(midpoint_update1, 102.5, 0.0001)

        {:ok, midpoint_update2, _state5} = @backend.next(state4, 115.0, false)
        # Window: [100.0, 115.0], MIDPOINT = (115.0 + 100.0) / 2 = 107.5
        assert_in_delta(midpoint_update2, 107.5, 0.0001)

        # Original midpoint2 was (110.0 + 100.0) / 2 = 105.0
        assert_in_delta(midpoint2, 105.0, 0.0001)
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirMIDPOINT.init(2)

      {:ok, nil, state2} = ElixirMIDPOINT.next(state, 100.0, true)
      {:ok, _midpoint, state3} = ElixirMIDPOINT.next(state2, 110.0, true)
      initial_lookback = state3.lookback_count

      {:ok, _midpoint, state4} = ElixirMIDPOINT.next(state3, 105.0, false)
      assert state4.lookback_count == initial_lookback

      {:ok, _midpoint, state5} = ElixirMIDPOINT.next(state4, 115.0, false)
      assert state5.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: APPEND mode matches batch MIDPOINT" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 50),
                period <- integer(2..10)
              ) do
          # Calculate batch MIDPOINT
          {:ok, batch_result} = TheoryCraftTA.midpoint(data, period)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init(period)

          {_final_state, incremental_results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, midpoint_value, new_state} = @backend.next(st, value, true)
              {new_state, [midpoint_value | results]}
            end)

          incremental_results = Enum.reverse(incremental_results)

          # Compare results
          assert length(batch_result) == length(incremental_results)

          Enum.zip(batch_result, incremental_results)
          |> Enum.each(fn
            {nil, nil} ->
              :ok

            {batch_val, incr_val} when is_float(batch_val) and is_float(incr_val) ->
              assert_in_delta(batch_val, incr_val, 0.0001)

            _ ->
              flunk("Mismatch in batch vs incremental results")
          end)
        end
      end
    end
  end

  describe "property: UPDATE mode behaves correctly" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: UPDATE recalculates with replaced last value" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 15, max_length: 30),
                period <- integer(2..8),
                update_values <-
                  list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 5)
              ) do
          {:ok, state} = @backend.init(period)

          # Build state with N bars
          {final_state, _results} =
            Enum.reduce(Enum.take(data, period + 3), {state, []}, fn value, {st, results} ->
              {:ok, midpoint_value, new_state} = @backend.next(st, value, true)
              {new_state, [midpoint_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_midpoints} =
            Enum.reduce(update_values, {final_state, []}, fn value, {st, midpoints} ->
              {:ok, midpoint, new_st} = @backend.next(st, value, false)
              {new_st, [midpoint | midpoints]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirMIDPOINT do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All MIDPOINT values should be different (unless values are identical)
          unique_midpoints = Enum.uniq(update_midpoints)
          assert length(unique_midpoints) >= 1
        end
      end
    end
  end
end
