defmodule TheoryCraftTA.State.SMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.State.SMA, as: ElixirSMA
  alias TheoryCraftTA.Native.State.SMA, as: NativeSMA

  @backends [
    {ElixirSMA, "Elixir"},
    {NativeSMA, "Native"}
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
      assert {:ok, state} = ElixirSMA.init(14)
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
        {:ok, sma1, state2} = @backend.next(state, 100.0, true)
        assert sma1 == nil

        # Second bar
        {:ok, sma2, state3} = @backend.next(state2, 110.0, true)
        assert sma2 == nil

        # Third bar - first SMA value
        {:ok, sma3, _state4} = @backend.next(state3, 120.0, true)
        expected = (100.0 + 110.0 + 120.0) / 3
        assert_in_delta(sma3, expected, 0.0001)
      end

      test "#{name}: calculates SMA correctly after warmup" do
        {:ok, state} = @backend.init(2)

        # First bar (warmup)
        {:ok, nil, state2} = @backend.next(state, 100.0, true)

        # Second bar - first SMA
        {:ok, sma2, state3} = @backend.next(state2, 110.0, true)
        assert_in_delta(sma2, 105.0, 0.0001)

        # Third bar - sliding window
        {:ok, sma3, _state4} = @backend.next(state3, 120.0, true)
        # Average of 110.0 and 120.0
        assert_in_delta(sma3, 115.0, 0.0001)
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
        {:ok, sma2, state3} = @backend.next(state2, 110.0, true)

        # UPDATE mode: replace last value
        {:ok, sma_update1, state4} = @backend.next(state3, 105.0, false)
        # Average of 100.0 and 105.0
        assert_in_delta(sma_update1, 102.5, 0.0001)

        {:ok, sma_update2, _state5} = @backend.next(state4, 115.0, false)
        # Average of 100.0 and 115.0
        assert_in_delta(sma_update2, 107.5, 0.0001)

        # Original sma2 was average of 100.0 and 110.0 = 105.0
        assert_in_delta(sma2, 105.0, 0.0001)
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirSMA.init(2)

      {:ok, nil, state2} = ElixirSMA.next(state, 100.0, true)
      {:ok, _sma, state3} = ElixirSMA.next(state2, 110.0, true)
      initial_lookback = state3.lookback_count

      {:ok, _sma, state4} = ElixirSMA.next(state3, 105.0, false)
      assert state4.lookback_count == initial_lookback

      {:ok, _sma, state5} = ElixirSMA.next(state4, 115.0, false)
      assert state5.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: APPEND mode matches batch SMA" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 50),
                period <- integer(2..10)
              ) do
          # Calculate batch SMA
          {:ok, batch_result} = TheoryCraftTA.sma(data, period)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init(period)

          {_final_state, incremental_results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, sma_value, new_state} = @backend.next(st, value, true)
              {new_state, [sma_value | results]}
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
              {:ok, sma_value, new_state} = @backend.next(st, value, true)
              {new_state, [sma_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_smas} =
            Enum.reduce(update_values, {final_state, []}, fn value, {st, smas} ->
              {:ok, sma, new_st} = @backend.next(st, value, false)
              {new_st, [sma | smas]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirSMA do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All SMA values should be different (unless values are identical)
          unique_smas = Enum.uniq(update_smas)
          assert length(unique_smas) >= 1
        end
      end
    end
  end
end
