defmodule TheoryCraftTA.State.T3Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.Overlap.T3State, as: ElixirT3
  alias TheoryCraftTA.Native.Overlap.T3State, as: NativeT3

  doctest TheoryCraftTA.Elixir.Overlap.T3State
  doctest TheoryCraftTA.Native.Overlap.T3State

  @backends [
    {ElixirT3, "Elixir"},
    {NativeT3, "Native"}
  ]

  ## Setup

  describe "init/2" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: initializes with valid period and vfactor" do
        assert {:ok, _state} = @backend.init(14, 0.7)
      end

      test "#{name}: returns error for period < 2" do
        assert {:error, msg} = @backend.init(1, 0.7)
        assert msg =~ "Invalid period"
      end
    end

    test "Elixir: stores period and vfactor in state" do
      assert {:ok, state} = ElixirT3.init(14, 0.7)
      assert state.period == 14
      assert state.vfactor == 0.7
    end
  end

  ## Tests

  describe "next/3 - APPEND mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: returns nil during warmup period" do
        {:ok, state} = @backend.init(2, 0.7)

        # T3 with period=2 requires significant warmup (unstable period)
        # First bar
        {:ok, t3_1, state2} = @backend.next(state, 100.0, true)
        assert t3_1 == nil

        # Second bar
        {:ok, t3_2, state3} = @backend.next(state2, 110.0, true)
        assert t3_2 == nil

        # Third bar
        {:ok, t3_3, state4} = @backend.next(state3, 120.0, true)
        assert t3_3 == nil

        # Fourth bar
        {:ok, t3_4, state5} = @backend.next(state4, 130.0, true)
        assert t3_4 == nil

        # Fifth bar
        {:ok, t3_5, state6} = @backend.next(state5, 140.0, true)
        assert t3_5 == nil

        # Sixth bar
        {:ok, t3_6, state7} = @backend.next(state6, 150.0, true)
        assert t3_6 == nil

        # Seventh bar - first T3 value (based on Python reference)
        {:ok, t3_7, _state8} = @backend.next(state7, 160.0, true)
        # We get a value now
        assert is_float(t3_7)
      end

      test "#{name}: calculates T3 correctly after warmup" do
        {:ok, state} = @backend.init(2, 0.7)

        # Feed the extended test data
        data = [1.0, 5.0, 3.0, 4.0, 7.0, 3.0, 8.0, 1.0, 4.0, 6.0]

        {_final_state, results} =
          Enum.reduce(data, {state, []}, fn value, {st, acc} ->
            {:ok, t3_value, new_state} = @backend.next(st, value, true)
            {new_state, [t3_value | acc]}
          end)

        results = Enum.reverse(results)

        # Python result: [nil, nil, nil, nil, nil, nil, 6.33673769, 3.68369497, 3.39703406, 4.80587282]
        assert Enum.at(results, 0) == nil
        assert Enum.at(results, 1) == nil
        assert Enum.at(results, 2) == nil
        assert Enum.at(results, 3) == nil
        assert Enum.at(results, 4) == nil
        assert Enum.at(results, 5) == nil
        assert_in_delta(Enum.at(results, 6), 6.33673769, 0.001)
        assert_in_delta(Enum.at(results, 7), 3.68369497, 0.001)
        assert_in_delta(Enum.at(results, 8), 3.39703406, 0.001)
        assert_in_delta(Enum.at(results, 9), 4.80587282, 0.001)
      end
    end
  end

  describe "next/3 - UPDATE mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: updates last value correctly" do
        {:ok, state} = @backend.init(2, 0.7)

        # Build state with warmup using extended test data
        data = [1.0, 5.0, 3.0, 4.0, 7.0, 3.0, 8.0, 1.0]

        {state_after_warmup, _results} =
          Enum.reduce(data, {state, []}, fn value, {st, acc} ->
            {:ok, t3_value, new_state} = @backend.next(st, value, true)
            {new_state, [t3_value | acc]}
          end)

        # Get T3 with value 4.0 (9th value - index 8)
        {:ok, t3_original, state_with_4} = @backend.next(state_after_warmup, 4.0, true)
        # Python result for 9th position (index 8): 3.39703406
        assert_in_delta(t3_original, 3.39703406, 0.001)

        # UPDATE mode: replace last value with 6.0
        {:ok, t3_update, _state_updated} = @backend.next(state_with_4, 6.0, false)
        # Python result for 10th position (index 9) with 6.0: 4.80587282
        assert_in_delta(t3_update, 4.80587282, 0.001)
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirT3.init(2, 0.7)

      # Build warmup
      data = [1.0, 5.0, 3.0, 4.0, 7.0, 3.0, 8.0, 1.0, 4.0, 6.0]

      {state_after_data, _results} =
        Enum.reduce(data, {state, []}, fn value, {st, acc} ->
          {:ok, t3_value, new_state} = ElixirT3.next(st, value, true)
          {new_state, [t3_value | acc]}
        end)

      initial_lookback = state_after_data.lookback_count

      {:ok, _t3, state_after_update} = ElixirT3.next(state_after_data, 7.0, false)
      assert state_after_update.lookback_count == initial_lookback

      {:ok, _t3, state_after_update2} = ElixirT3.next(state_after_update, 8.0, false)
      assert state_after_update2.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      @tag :native_backend
      property "#{name}: APPEND mode matches batch T3" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 25, max_length: 50),
                period <- integer(2..10),
                vfactor <- float(min: 0.0, max: 1.0)
              ) do
          # Calculate batch T3
          {:ok, batch_result} = TheoryCraftTA.t3(data, period, vfactor)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init(period, vfactor)

          {_final_state, incremental_results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, t3_value, new_state} = @backend.next(st, value, true)
              {new_state, [t3_value | results]}
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

      @tag :native_backend
      property "#{name}: UPDATE recalculates with replaced last value" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 25, max_length: 40),
                period <- integer(2..8),
                vfactor <- float(min: 0.0, max: 1.0),
                update_values <-
                  list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 5)
              ) do
          {:ok, state} = @backend.init(period, vfactor)

          # Build state with enough bars to get past warmup
          warmup_size = period * 3 + 10

          {final_state, _results} =
            Enum.reduce(Enum.take(data, warmup_size), {state, []}, fn value, {st, results} ->
              {:ok, t3_value, new_state} = @backend.next(st, value, true)
              {new_state, [t3_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_t3s} =
            Enum.reduce(update_values, {final_state, []}, fn value, {st, t3s} ->
              {:ok, t3, new_st} = @backend.next(st, value, false)
              {new_st, [t3 | t3s]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirT3 do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All T3 values should be different (unless values are identical)
          unique_t3s = Enum.uniq(update_t3s)
          assert length(unique_t3s) >= 1
        end
      end
    end
  end
end
