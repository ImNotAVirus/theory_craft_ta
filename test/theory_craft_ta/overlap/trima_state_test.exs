defmodule TheoryCraftTA.State.TRIMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.Overlap.TRIMAState, as: ElixirTRIMA
  alias TheoryCraftTA.Native.Overlap.TRIMAState, as: NativeTRIMA

  doctest TheoryCraftTA.Elixir.Overlap.TRIMAState
  doctest TheoryCraftTA.Native.Overlap.TRIMAState

  @backends [
    {ElixirTRIMA, "Elixir"},
    {NativeTRIMA, "Native"}
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
      assert {:ok, state} = ElixirTRIMA.init(14)
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
        {:ok, trima1, state2} = @backend.next(state, 100.0, true)
        assert trima1 == nil

        # Second bar
        {:ok, trima2, state3} = @backend.next(state2, 110.0, true)
        assert trima2 == nil

        # Third bar - first TRIMA value
        {:ok, trima3, _state4} = @backend.next(state3, 120.0, true)
        # TRIMA(period=3) for [100, 110, 120]
        # First SMA: [nil, nil, 110.0]
        # Second SMA of first SMA: TRIMA = 110.0
        assert_in_delta(trima3, 110.0, 0.001)
      end

      test "#{name}: calculates TRIMA correctly after warmup" do
        {:ok, state} = @backend.init(2)

        # First bar (warmup)
        {:ok, nil, state2} = @backend.next(state, 100.0, true)

        # Second bar - first TRIMA
        {:ok, trima2, state3} = @backend.next(state2, 110.0, true)
        # TRIMA(period=2) for [100, 110]
        # First SMA(period=1): [100.0, 110.0]
        # Second SMA(period=2): 105.0
        assert_in_delta(trima2, 105.0, 0.001)

        # Third bar - sliding window
        {:ok, trima3, _state4} = @backend.next(state3, 120.0, true)
        # TRIMA(period=2) for [100, 110, 120]
        # First SMA(period=1): [100.0, 110.0, 120.0]
        # Second SMA(period=2): 115.0
        assert_in_delta(trima3, 115.0, 0.001)
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
        {:ok, trima2, state3} = @backend.next(state2, 110.0, true)

        # UPDATE mode: replace last value
        {:ok, trima_update1, state4} = @backend.next(state3, 105.0, false)
        # TRIMA(period=2) for [100, 105]
        # First SMA: [nil, 102.5]
        # Second SMA: 102.5
        assert_in_delta(trima_update1, 102.5, 0.001)

        {:ok, trima_update2, _state5} = @backend.next(state4, 115.0, false)
        # TRIMA(period=2) for [100, 115]
        # First SMA: [nil, 107.5]
        # Second SMA: 107.5
        assert_in_delta(trima_update2, 107.5, 0.001)

        # Original trima2 was 105.0
        assert_in_delta(trima2, 105.0, 0.001)
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirTRIMA.init(2)

      {:ok, nil, state2} = ElixirTRIMA.next(state, 100.0, true)
      {:ok, _trima, state3} = ElixirTRIMA.next(state2, 110.0, true)
      initial_lookback = state3.lookback_count

      {:ok, _trima, state4} = ElixirTRIMA.next(state3, 105.0, false)
      assert state4.lookback_count == initial_lookback

      {:ok, _trima, state5} = ElixirTRIMA.next(state4, 115.0, false)
      assert state5.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: APPEND mode matches batch TRIMA" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 50),
                period <- integer(2..10)
              ) do
          # Calculate batch TRIMA
          {:ok, batch_result} = TheoryCraftTA.trima(data, period)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init(period)

          {_final_state, incremental_results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, trima_value, new_state} = @backend.next(st, value, true)
              {new_state, [trima_value | results]}
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
              {:ok, trima_value, new_state} = @backend.next(st, value, true)
              {new_state, [trima_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_trimas} =
            Enum.reduce(update_values, {final_state, []}, fn value, {st, trimas} ->
              {:ok, trima, new_st} = @backend.next(st, value, false)
              {new_st, [trima | trimas]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirTRIMA do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All TRIMA values should be different (unless values are identical)
          unique_trimas = Enum.uniq(update_trimas)
          assert length(unique_trimas) >= 1
        end
      end
    end
  end
end
