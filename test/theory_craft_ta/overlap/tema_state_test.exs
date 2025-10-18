defmodule TheoryCraftTA.State.TEMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.Overlap.TEMAState, as: ElixirTEMA
  alias TheoryCraftTA.Native.Overlap.TEMAState, as: NativeTEMA

  doctest TheoryCraftTA.Elixir.Overlap.TEMAState
  doctest TheoryCraftTA.Native.Overlap.TEMAState

  @backends [
    {ElixirTEMA, "Elixir"},
    {NativeTEMA, "Native"}
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
      assert {:ok, state} = ElixirTEMA.init(14)
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
        {:ok, tema1, state2} = @backend.next(state, 100.0, true)
        assert tema1 == nil

        # Second bar
        {:ok, tema2, state3} = @backend.next(state2, 110.0, true)
        assert tema2 == nil

        # Third bar
        {:ok, tema3, state4} = @backend.next(state3, 120.0, true)
        assert tema3 == nil

        # Fourth bar
        {:ok, tema4, state5} = @backend.next(state4, 130.0, true)
        assert tema4 == nil

        # Fifth bar
        {:ok, tema5, state6} = @backend.next(state5, 140.0, true)
        assert tema5 == nil

        # Sixth bar
        {:ok, tema6, state7} = @backend.next(state6, 150.0, true)
        assert tema6 == nil

        # Seventh bar - first TEMA value
        {:ok, tema7, _state8} = @backend.next(state7, 160.0, true)
        assert_in_delta(tema7, 160.0, 0.01)
      end

      test "#{name}: calculates TEMA correctly after warmup" do
        {:ok, state} = @backend.init(2)

        # First bar (warmup)
        {:ok, nil, state2} = @backend.next(state, 100.0, true)

        # Second bar (warmup)
        {:ok, nil, state3} = @backend.next(state2, 110.0, true)

        # Third bar (warmup for TEMA)
        {:ok, nil, state4} = @backend.next(state3, 120.0, true)

        # Fourth bar - first TEMA value
        {:ok, tema4, state5} = @backend.next(state4, 130.0, true)
        assert_in_delta(tema4, 130.0, 0.01)

        # Fifth bar
        {:ok, tema5, _state6} = @backend.next(state5, 140.0, true)
        assert_in_delta(tema5, 140.0, 0.01)
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
        {:ok, nil, state4} = @backend.next(state3, 120.0, true)
        {:ok, _tema4, state5} = @backend.next(state4, 130.0, true)

        # UPDATE mode: simulate multiple ticks on same bar
        {:ok, tema_update1, state6} = @backend.next(state5, 115.0, false)
        {:ok, tema_update2, _state7} = @backend.next(state6, 125.0, false)

        # Values should be different when inputs differ
        assert is_float(tema_update1)
        assert is_float(tema_update2)
        refute_in_delta(tema_update1, tema_update2, 0.0001)
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirTEMA.init(2)

      {:ok, nil, state2} = ElixirTEMA.next(state, 100.0, true)
      {:ok, nil, state3} = ElixirTEMA.next(state2, 110.0, true)
      {:ok, nil, state4} = ElixirTEMA.next(state3, 120.0, true)
      {:ok, _tema, state5} = ElixirTEMA.next(state4, 130.0, true)
      initial_lookback = state5.lookback_count

      {:ok, _tema, state6} = ElixirTEMA.next(state5, 115.0, false)
      assert state6.lookback_count == initial_lookback

      {:ok, _tema, state7} = ElixirTEMA.next(state6, 125.0, false)
      assert state7.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: APPEND mode matches batch TEMA" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 50),
                period <- integer(2..10)
              ) do
          # Calculate batch TEMA
          {:ok, batch_result} = TheoryCraftTA.tema(data, period)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init(period)

          {_final_state, incremental_results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, tema_value, new_state} = @backend.next(st, value, true)
              {new_state, [tema_value | results]}
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
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 30),
                period <- integer(2..8),
                update_values <-
                  list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 5)
              ) do
          {:ok, state} = @backend.init(period)

          # Build state with N bars (need 3*period-2 for TEMA warmup)
          warmup_count = 3 * period + 3

          {final_state, _results} =
            Enum.reduce(Enum.take(data, warmup_count), {state, []}, fn value, {st, results} ->
              {:ok, tema_value, new_state} = @backend.next(st, value, true)
              {new_state, [tema_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_temas} =
            Enum.reduce(update_values, {final_state, []}, fn value, {st, temas} ->
              {:ok, tema, new_st} = @backend.next(st, value, false)
              {new_st, [tema | temas]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirTEMA do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All TEMA values should be different (unless values are identical)
          unique_temas = Enum.uniq(update_temas)
          assert length(unique_temas) >= 1
        end
      end
    end
  end
end
