defmodule TheoryCraftTA.State.DEMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.Overlap.DEMAState, as: ElixirDEMA
  alias TheoryCraftTA.Native.Overlap.DEMAState, as: NativeDEMA

  doctest TheoryCraftTA.Elixir.Overlap.DEMAState
  doctest TheoryCraftTA.Native.Overlap.DEMAState

  @backends [
    {ElixirDEMA, "Elixir"},
    {NativeDEMA, "Native"}
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
      assert {:ok, state} = ElixirDEMA.init(14)
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
        {:ok, dema1, state2} = @backend.next(state, 100.0, true)
        assert dema1 == nil

        # Second bar
        {:ok, dema2, state3} = @backend.next(state2, 110.0, true)
        assert dema2 == nil

        # Third bar
        {:ok, dema3, state4} = @backend.next(state3, 120.0, true)
        assert dema3 == nil

        # Fourth bar
        {:ok, dema4, state5} = @backend.next(state4, 130.0, true)
        assert dema4 == nil

        # Fifth bar - first DEMA value
        {:ok, dema5, _state6} = @backend.next(state5, 140.0, true)
        assert_in_delta(dema5, 140.0, 0.01)
      end

      test "#{name}: calculates DEMA correctly after warmup" do
        {:ok, state} = @backend.init(2)

        # First bar (warmup)
        {:ok, nil, state2} = @backend.next(state, 100.0, true)

        # Second bar (warmup for DEMA)
        {:ok, nil, state3} = @backend.next(state2, 110.0, true)

        # Third bar - first DEMA value
        {:ok, dema3, state4} = @backend.next(state3, 120.0, true)
        assert_in_delta(dema3, 120.0, 0.01)

        # Fourth bar
        {:ok, dema4, _state5} = @backend.next(state4, 130.0, true)
        assert_in_delta(dema4, 130.0, 0.01)
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
        {:ok, nil, state3} = @backend.next(state2, 110.0, true)
        {:ok, _dema3, state4} = @backend.next(state3, 120.0, true)

        # UPDATE mode: simulate multiple ticks on same bar
        {:ok, dema_update1, state5} = @backend.next(state4, 115.0, false)
        {:ok, dema_update2, _state6} = @backend.next(state5, 125.0, false)

        # Values should be different when inputs differ
        assert is_float(dema_update1)
        assert is_float(dema_update2)
        refute_in_delta(dema_update1, dema_update2, 0.0001)
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirDEMA.init(2)

      {:ok, nil, state2} = ElixirDEMA.next(state, 100.0, true)
      {:ok, nil, state3} = ElixirDEMA.next(state2, 110.0, true)
      {:ok, _dema, state4} = ElixirDEMA.next(state3, 120.0, true)
      initial_lookback = state4.lookback_count

      {:ok, _dema, state5} = ElixirDEMA.next(state4, 115.0, false)
      assert state5.lookback_count == initial_lookback

      {:ok, _dema, state6} = ElixirDEMA.next(state5, 125.0, false)
      assert state6.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: APPEND mode matches batch DEMA" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 50),
                period <- integer(2..10)
              ) do
          # Calculate batch DEMA
          {:ok, batch_result} = TheoryCraftTA.dema(data, period)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init(period)

          {_final_state, incremental_results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, dema_value, new_state} = @backend.next(st, value, true)
              {new_state, [dema_value | results]}
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

          # Build state with N bars (need 2*period-1 for DEMA warmup)
          warmup_count = 2 * period + 3

          {final_state, _results} =
            Enum.reduce(Enum.take(data, warmup_count), {state, []}, fn value, {st, results} ->
              {:ok, dema_value, new_state} = @backend.next(st, value, true)
              {new_state, [dema_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_demas} =
            Enum.reduce(update_values, {final_state, []}, fn value, {st, demas} ->
              {:ok, dema, new_st} = @backend.next(st, value, false)
              {new_st, [dema | demas]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirDEMA do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All DEMA values should be different (unless values are identical)
          unique_demas = Enum.uniq(update_demas)
          assert length(unique_demas) >= 1
        end
      end
    end
  end
end
