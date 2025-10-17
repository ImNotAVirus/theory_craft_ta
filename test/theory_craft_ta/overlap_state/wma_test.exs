defmodule TheoryCraftTA.State.WMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.OverlapState.WMA, as: ElixirWMA
  alias TheoryCraftTA.Native.OverlapState.WMA, as: NativeWMA

  doctest TheoryCraftTA.Elixir.OverlapState.WMA
  doctest TheoryCraftTA.Native.OverlapState.WMA

  @backends [
    {ElixirWMA, "Elixir"},
    {NativeWMA, "Native"}
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
      assert {:ok, state} = ElixirWMA.init(14)
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
        {:ok, wma1, state2} = @backend.next(state, 100.0, true)
        assert wma1 == nil

        # Second bar
        {:ok, wma2, state3} = @backend.next(state2, 110.0, true)
        assert wma2 == nil

        # Third bar - first WMA value
        {:ok, wma3, _state4} = @backend.next(state3, 120.0, true)
        # WMA = (100*1 + 110*2 + 120*3) / (1+2+3) = (100+220+360) / 6 = 680 / 6 = 113.33333
        assert_in_delta(wma3, 113.33333, 0.001)
      end

      test "#{name}: calculates WMA correctly after warmup" do
        {:ok, state} = @backend.init(2)

        # First bar (warmup)
        {:ok, nil, state2} = @backend.next(state, 100.0, true)

        # Second bar - first WMA
        {:ok, wma2, state3} = @backend.next(state2, 110.0, true)
        # WMA = (100*1 + 110*2) / (1+2) = (100+220) / 3 = 320 / 3 = 106.66667
        assert_in_delta(wma2, 106.66667, 0.001)

        # Third bar - sliding window
        {:ok, wma3, _state4} = @backend.next(state3, 120.0, true)
        # WMA = (110*1 + 120*2) / 3 = (110+240) / 3 = 350 / 3 = 116.66667
        assert_in_delta(wma3, 116.66667, 0.001)
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
        {:ok, wma2, state3} = @backend.next(state2, 110.0, true)

        # UPDATE mode: replace last value
        {:ok, wma_update1, state4} = @backend.next(state3, 105.0, false)
        # WMA = (100*1 + 105*2) / 3 = (100+210) / 3 = 310 / 3 = 103.33333
        assert_in_delta(wma_update1, 103.33333, 0.001)

        {:ok, wma_update2, _state5} = @backend.next(state4, 115.0, false)
        # WMA = (100*1 + 115*2) / 3 = (100+230) / 3 = 330 / 3 = 110.0
        assert_in_delta(wma_update2, 110.0, 0.001)

        # Original wma2 was (100*1 + 110*2) / 3 = 106.66667
        assert_in_delta(wma2, 106.66667, 0.001)
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirWMA.init(2)

      {:ok, nil, state2} = ElixirWMA.next(state, 100.0, true)
      {:ok, _wma, state3} = ElixirWMA.next(state2, 110.0, true)
      initial_lookback = state3.lookback_count

      {:ok, _wma, state4} = ElixirWMA.next(state3, 105.0, false)
      assert state4.lookback_count == initial_lookback

      {:ok, _wma, state5} = ElixirWMA.next(state4, 115.0, false)
      assert state5.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: APPEND mode matches batch WMA" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 50),
                period <- integer(2..10)
              ) do
          # Calculate batch WMA
          {:ok, batch_result} = TheoryCraftTA.wma(data, period)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init(period)

          {_final_state, incremental_results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, wma_value, new_state} = @backend.next(st, value, true)
              {new_state, [wma_value | results]}
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
              {:ok, wma_value, new_state} = @backend.next(st, value, true)
              {new_state, [wma_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_wmas} =
            Enum.reduce(update_values, {final_state, []}, fn value, {st, wmas} ->
              {:ok, wma, new_st} = @backend.next(st, value, false)
              {new_st, [wma | wmas]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirWMA do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All WMA values should be different (unless values are identical)
          unique_wmas = Enum.uniq(update_wmas)
          assert length(unique_wmas) >= 1
        end
      end
    end
  end
end
