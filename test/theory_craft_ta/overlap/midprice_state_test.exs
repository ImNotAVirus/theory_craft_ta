defmodule TheoryCraftTA.State.MIDPRICETest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.Overlap.MIDPRICEState, as: ElixirMIDPRICE
  alias TheoryCraftTA.Native.Overlap.MIDPRICEState, as: NativeMIDPRICE

  doctest TheoryCraftTA.Elixir.Overlap.MIDPRICEState
  doctest TheoryCraftTA.Native.Overlap.MIDPRICEState

  @backends [
    {ElixirMIDPRICE, "Elixir"},
    {NativeMIDPRICE, "Native"}
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
      assert {:ok, state} = ElixirMIDPRICE.init(14)
      assert state.period == 14
    end
  end

  ## Tests

  describe "next/4 - APPEND mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: returns nil during warmup period" do
        {:ok, state} = @backend.init(3)

        # First bar
        {:ok, midprice1, state2} = @backend.next(state, 10.0, 8.0, true)
        assert midprice1 == nil

        # Second bar
        {:ok, midprice2, state3} = @backend.next(state2, 11.0, 9.0, true)
        assert midprice2 == nil

        # Third bar - first MIDPRICE value
        {:ok, midprice3, _state4} = @backend.next(state3, 12.0, 10.0, true)
        # MIDPRICE = (max(10, 11, 12) + min(8, 9, 10)) / 2 = (12 + 8) / 2 = 10.0
        assert_in_delta(midprice3, 10.0, 0.001)
      end

      test "#{name}: calculates MIDPRICE correctly after warmup" do
        {:ok, state} = @backend.init(2)

        # First bar (warmup)
        {:ok, nil, state2} = @backend.next(state, 10.0, 8.0, true)

        # Second bar - first MIDPRICE
        {:ok, midprice2, state3} = @backend.next(state2, 11.0, 9.0, true)
        # MIDPRICE = (max(10, 11) + min(8, 9)) / 2 = (11 + 8) / 2 = 9.5
        assert_in_delta(midprice2, 9.5, 0.001)

        # Third bar - sliding window
        {:ok, midprice3, _state4} = @backend.next(state3, 12.0, 10.0, true)
        # MIDPRICE = (max(11, 12) + min(9, 10)) / 2 = (12 + 9) / 2 = 10.5
        assert_in_delta(midprice3, 10.5, 0.001)
      end

      test "#{name}: handles varying data correctly" do
        {:ok, state} = @backend.init(3)

        # Build up state
        {:ok, nil, state2} = @backend.next(state, 10.0, 8.0, true)
        {:ok, nil, state3} = @backend.next(state2, 11.0, 9.0, true)
        {:ok, midprice3, state4} = @backend.next(state3, 12.0, 10.0, true)
        assert_in_delta(midprice3, 10.0, 0.001)

        # Next bars
        {:ok, midprice4, state5} = @backend.next(state4, 11.0, 9.0, true)
        # MIDPRICE = (max(11, 12, 11) + min(9, 10, 9)) / 2 = (12 + 9) / 2 = 10.5
        assert_in_delta(midprice4, 10.5, 0.001)

        {:ok, midprice5, _state6} = @backend.next(state5, 10.0, 8.0, true)
        # MIDPRICE = (max(12, 11, 10) + min(10, 9, 8)) / 2 = (12 + 8) / 2 = 10.0
        assert_in_delta(midprice5, 10.0, 0.001)
      end
    end
  end

  describe "next/4 - UPDATE mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: updates last high/low values in buffers" do
        {:ok, state} = @backend.init(2)

        # Build state with warmup
        {:ok, nil, state2} = @backend.next(state, 10.0, 8.0, true)
        {:ok, midprice2, state3} = @backend.next(state2, 11.0, 9.0, true)
        # Original: (max(10, 11) + min(8, 9)) / 2 = (11 + 8) / 2 = 9.5
        assert_in_delta(midprice2, 9.5, 0.001)

        # UPDATE mode: replace last values
        {:ok, midprice_update1, state4} = @backend.next(state3, 10.5, 8.5, false)
        # MIDPRICE = (max(10, 10.5) + min(8, 8.5)) / 2 = (10.5 + 8) / 2 = 9.25
        assert_in_delta(midprice_update1, 9.25, 0.001)

        {:ok, midprice_update2, _state5} = @backend.next(state4, 12.0, 10.0, false)
        # MIDPRICE = (max(10, 12) + min(8, 10)) / 2 = (12 + 8) / 2 = 10.0
        assert_in_delta(midprice_update2, 10.0, 0.001)
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirMIDPRICE.init(2)

      {:ok, nil, state2} = ElixirMIDPRICE.next(state, 10.0, 8.0, true)
      {:ok, _midprice, state3} = ElixirMIDPRICE.next(state2, 11.0, 9.0, true)
      initial_lookback = state3.lookback_count

      {:ok, _midprice, state4} = ElixirMIDPRICE.next(state3, 10.5, 8.5, false)
      assert state4.lookback_count == initial_lookback

      {:ok, _midprice, state5} = ElixirMIDPRICE.next(state4, 12.0, 10.0, false)
      assert state5.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: APPEND mode matches batch MIDPRICE" do
        check all(
                high <- list_of(float(min: 50.0, max: 150.0), min_length: 21, max_length: 50),
                period <- integer(2..10)
              ) do
          # Generate low prices that are always less than high
          low = Enum.map(high, fn h -> h - :rand.uniform() * 10.0 end)

          # Calculate batch MIDPRICE
          {:ok, batch_result} = TheoryCraftTA.midprice(high, low, period)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init(period)

          {_final_state, incremental_results} =
            Enum.zip(high, low)
            |> Enum.reduce({state, []}, fn {h, l}, {st, results} ->
              {:ok, midprice_value, new_state} = @backend.next(st, h, l, true)
              {new_state, [midprice_value | results]}
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

      property "#{name}: UPDATE recalculates with replaced last high/low values" do
        check all(
                high <- list_of(float(min: 50.0, max: 150.0), min_length: 15, max_length: 30),
                period <- integer(2..8),
                update_values <-
                  list_of(
                    {float(min: 50.0, max: 150.0), float(min: 40.0, max: 140.0)},
                    min_length: 2,
                    max_length: 5
                  )
              ) do
          # Generate low prices that are always less than high
          low = Enum.map(high, fn h -> h - :rand.uniform() * 10.0 end)

          {:ok, state} = @backend.init(period)

          # Build state with N bars
          {final_state, _results} =
            Enum.zip(Enum.take(high, period + 3), Enum.take(low, period + 3))
            |> Enum.reduce({state, []}, fn {h, l}, {st, results} ->
              {:ok, midprice_value, new_state} = @backend.next(st, h, l, true)
              {new_state, [midprice_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_midprices} =
            Enum.reduce(update_values, {final_state, []}, fn {h, l}, {st, midprices} ->
              {:ok, midprice, new_st} = @backend.next(st, h, l, false)
              {new_st, [midprice | midprices]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirMIDPRICE do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All MIDPRICE values should be valid floats
          assert Enum.all?(update_midprices, &is_float/1)
        end
      end
    end
  end
end
