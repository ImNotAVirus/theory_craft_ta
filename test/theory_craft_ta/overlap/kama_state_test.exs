defmodule TheoryCraftTA.State.KAMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.Overlap.KAMAState, as: ElixirKAMA
  alias TheoryCraftTA.Native.Overlap.KAMAState, as: NativeKAMA

  doctest TheoryCraftTA.Elixir.Overlap.KAMAState
  doctest TheoryCraftTA.Native.Overlap.KAMAState

  @backends [
    {ElixirKAMA, "Elixir"},
    {NativeKAMA, "Native"}
  ]

  ## Setup

  describe "init/1" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: initializes with valid period" do
        assert {:ok, _state} = @backend.init(10)
      end

      test "#{name}: returns error for period < 2" do
        assert {:error, msg} = @backend.init(1)
        assert msg =~ "Invalid period"
      end
    end

    test "Elixir: stores period in state" do
      assert {:ok, state} = ElixirKAMA.init(10)
      assert state.period == 10
    end
  end

  ## Tests

  describe "next/3 - APPEND mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: returns nil during warmup period" do
        {:ok, state} = @backend.init(5)

        # First 5 bars should return nil
        {:ok, kama1, state2} = @backend.next(state, 1.0, true)
        assert kama1 == nil

        {:ok, kama2, state3} = @backend.next(state2, 2.0, true)
        assert kama2 == nil

        {:ok, kama3, state4} = @backend.next(state3, 3.0, true)
        assert kama3 == nil

        {:ok, kama4, state5} = @backend.next(state4, 4.0, true)
        assert kama4 == nil

        {:ok, kama5, state6} = @backend.next(state5, 5.0, true)
        assert kama5 == nil

        # Sixth bar - first KAMA value
        {:ok, kama6, _state7} = @backend.next(state6, 6.0, true)
        # Should match Python: 5.44444444
        assert_in_delta(kama6, 5.44444444, 0.001)
      end

      test "#{name}: calculates KAMA correctly after warmup" do
        {:ok, state} = @backend.init(5)

        # Build up state with ascending values [1.0, 2.0, ..., 10.0]
        data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]

        {_final_state, results} =
          Enum.reduce(data, {state, []}, fn value, {st, acc} ->
            {:ok, kama, new_st} = @backend.next(st, value, true)
            {new_st, [kama | acc]}
          end)

        results = Enum.reverse(results)

        # Python result: [nan nan nan nan nan 5.44444444 6.13580247 6.96433471 7.86907484 8.81615269]
        assert Enum.at(results, 0) == nil
        assert Enum.at(results, 1) == nil
        assert Enum.at(results, 2) == nil
        assert Enum.at(results, 3) == nil
        assert Enum.at(results, 4) == nil
        assert_in_delta Enum.at(results, 5), 5.44444444, 0.001
        assert_in_delta Enum.at(results, 6), 6.13580247, 0.001
        assert_in_delta Enum.at(results, 7), 6.96433471, 0.001
        assert_in_delta Enum.at(results, 8), 7.86907484, 0.001
        assert_in_delta Enum.at(results, 9), 8.81615269, 0.001
      end
    end
  end

  describe "next/3 - UPDATE mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: updates last value correctly" do
        {:ok, state} = @backend.init(5)

        # Build state with values [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]

        {state_after_append, _results} =
          Enum.reduce(data, {state, []}, fn value, {st, acc} ->
            {:ok, kama, new_st} = @backend.next(st, value, true)
            {new_st, [kama | acc]}
          end)

        # Last KAMA value was 5.44444444 (from value 6.0)
        # UPDATE mode: replace last value with 7.0
        {:ok, kama_update1, state_updated} = @backend.next(state_after_append, 7.0, false)

        # Recalculated with [1.0, 2.0, 3.0, 4.0, 5.0, 7.0]
        # Should be different from original
        assert is_float(kama_update1)

        # Another UPDATE with 5.0 (going back)
        {:ok, kama_update2, _state_updated2} = @backend.next(state_updated, 5.0, false)

        # Should be different from first update
        assert is_float(kama_update2)
        assert abs(kama_update1 - kama_update2) > 0.001
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirKAMA.init(5)

      # Build state
      data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]

      {state_after, _} =
        Enum.reduce(data, {state, []}, fn value, {st, acc} ->
          {:ok, kama, new_st} = ElixirKAMA.next(st, value, true)
          {new_st, [kama | acc]}
        end)

      initial_lookback = state_after.lookback_count

      {:ok, _kama, state_updated1} = ElixirKAMA.next(state_after, 7.0, false)
      assert state_updated1.lookback_count == initial_lookback

      {:ok, _kama, state_updated2} = ElixirKAMA.next(state_updated1, 8.0, false)
      assert state_updated2.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      @tag :native_backend
      property "#{name}: APPEND mode matches batch KAMA" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 50),
                period <- integer(2..10)
              ) do
          # Calculate batch KAMA
          {:ok, batch_result} = TheoryCraftTA.kama(data, period)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init(period)

          {_final_state, incremental_results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, kama_value, new_state} = @backend.next(st, value, true)
              {new_state, [kama_value | results]}
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
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 15, max_length: 30),
                period <- integer(2..8),
                update_values <-
                  list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 5)
              ) do
          {:ok, state} = @backend.init(period)

          # Build state with N bars
          {final_state, _results} =
            Enum.reduce(Enum.take(data, period + 3), {state, []}, fn value, {st, results} ->
              {:ok, kama_value, new_state} = @backend.next(st, value, true)
              {new_state, [kama_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_kamas} =
            Enum.reduce(update_values, {final_state, []}, fn value, {st, kamas} ->
              {:ok, kama, new_st} = @backend.next(st, value, false)
              {new_st, [kama | kamas]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirKAMA do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All KAMA values should be calculated (not nil)
          assert Enum.all?(update_kamas, &is_float/1)
        end
      end
    end
  end
end
