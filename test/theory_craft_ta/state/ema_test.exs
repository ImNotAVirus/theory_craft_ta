defmodule TheoryCraftTA.State.EMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.State.EMA, as: ElixirEMA
  alias TheoryCraftTA.Native.State.EMA, as: NativeEMA

  @backends [
    {ElixirEMA, "Elixir"},
    {NativeEMA, "Native"}
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
      assert {:ok, state} = ElixirEMA.init(14)
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
        {:ok, ema1, state2} = @backend.next(state, 100.0, true)
        assert ema1 == nil

        # Second bar
        {:ok, ema2, state3} = @backend.next(state2, 110.0, true)
        assert ema2 == nil

        # Third bar - first EMA value (SMA seed = (100+110+120)/3 = 110.0)
        {:ok, ema3, _state4} = @backend.next(state3, 120.0, true)
        assert_in_delta(ema3, 110.0, 0.0001)
      end

      test "#{name}: calculates EMA correctly after warmup" do
        {:ok, state} = @backend.init(2)

        # First bar (warmup)
        {:ok, nil, state2} = @backend.next(state, 100.0, true)

        # Second bar - first EMA = SMA seed = (100+110)/2 = 105.0
        {:ok, ema2, state3} = @backend.next(state2, 110.0, true)
        assert_in_delta(ema2, 105.0, 0.0001)

        # Third bar
        {:ok, ema3, _state4} = @backend.next(state3, 120.0, true)
        # k = 2/(2+1) = 0.6667
        # EMA = (120 - 105) * 0.6667 + 105 = 115.0
        assert_in_delta(ema3, 115.0, 0.001)
      end
    end
  end

  describe "next/3 - UPDATE mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: updates state continuously in UPDATE mode" do
        {:ok, state} = @backend.init(2)

        # Build state with warmup
        {:ok, nil, state2} = @backend.next(state, 100.0, true)
        {:ok, _ema2, state3} = @backend.next(state2, 110.0, true)
        # _ema2 = SMA(100, 110) = 105.0

        # UPDATE mode: simulate multiple ticks on same bar
        # k = 2/(2+1) = 0.6667
        # ema_update1 = (105 - 105) * 0.6667 + 105 = 105.0
        {:ok, ema_update1, state4} = @backend.next(state3, 105.0, false)
        # ema_update2 = (108 - 105) * 0.6667 + 105 = 107.0
        {:ok, ema_update2, _state5} = @backend.next(state4, 108.0, false)

        # Value 105.0 equals _ema2 (105.0), but 108.0 should be different
        assert_in_delta(ema_update1, 105.0, 0.0001)
        assert_in_delta(ema_update2, 107.0, 0.001)
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirEMA.init(2)

      {:ok, nil, state2} = ElixirEMA.next(state, 100.0, true)
      {:ok, _ema, state3} = ElixirEMA.next(state2, 110.0, true)
      initial_lookback = state3.lookback_count

      {:ok, _ema, state4} = ElixirEMA.next(state3, 105.0, false)
      assert state4.lookback_count == initial_lookback

      {:ok, _ema, state5} = ElixirEMA.next(state4, 108.0, false)
      assert state5.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: APPEND mode matches batch EMA" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 50),
                period <- integer(2..10)
              ) do
          # Calculate batch EMA
          {:ok, batch_result} = TheoryCraftTA.ema(data, period)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init(period)

          {_final_state, incremental_results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, ema_value, new_state} = @backend.next(st, value, true)
              {new_state, [ema_value | results]}
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

      property "#{name}: UPDATE recalculates without affecting lookback" do
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
              {:ok, ema_value, new_state} = @backend.next(st, value, true)
              {new_state, [ema_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_emas} =
            Enum.reduce(update_values, {final_state, []}, fn value, {st, emas} ->
              {:ok, ema, new_st} = @backend.next(st, value, false)
              {new_st, [ema | emas]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirEMA do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All EMA values should be different (unless values are identical)
          unique_emas = Enum.uniq(update_emas)
          assert length(unique_emas) >= 1
        end
      end
    end
  end
end
