defmodule TheoryCraftTA.MIDPRICETest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{DataSeries, TimeSeries}
  alias TheoryCraftTA.Overlap.MIDPRICE

  doctest TheoryCraftTA.Overlap.MIDPRICE

  ## Batch calculation tests

  describe "midprice/3 with list input" do
    test "calculates correctly with period=3" do
      high = [10.0, 11.0, 12.0, 13.0, 14.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0]
      # Python result: [nan nan 10. 11. 12.]
      assert {:ok, result} = MIDPRICE.midprice(high, low, 3)

      assert Enum.at(result, 0) == nil
      assert Enum.at(result, 1) == nil
      assert_in_delta Enum.at(result, 2), 10.0, 0.001
      assert_in_delta Enum.at(result, 3), 11.0, 0.001
      assert_in_delta Enum.at(result, 4), 12.0, 0.001
    end

    test "handles period=2 (minimum valid)" do
      high = [100.0, 101.0, 102.0, 103.0, 104.0]
      low = [98.0, 99.0, 100.0, 101.0, 102.0]
      # Python result: [  nan  99.5 100.5 101.5 102.5]
      assert {:ok, result} = MIDPRICE.midprice(high, low, 2)

      assert Enum.at(result, 0) == nil
      assert_in_delta Enum.at(result, 1), 99.5, 0.001
      assert_in_delta Enum.at(result, 2), 100.5, 0.001
      assert_in_delta Enum.at(result, 3), 101.5, 0.001
      assert_in_delta Enum.at(result, 4), 102.5, 0.001
    end

    test "calculates correctly for varying data" do
      high = [10.0, 11.0, 12.0, 11.0, 10.0, 9.0, 10.0, 11.0]
      low = [8.0, 9.0, 10.0, 9.0, 8.0, 7.0, 8.0, 9.0]
      # Python result: [ nan  nan 10.  10.5 10.   9.   8.5  9. ]
      assert {:ok, result} = MIDPRICE.midprice(high, low, 3)

      assert Enum.at(result, 0) == nil
      assert Enum.at(result, 1) == nil
      assert_in_delta Enum.at(result, 2), 10.0, 0.001
      assert_in_delta Enum.at(result, 3), 10.5, 0.001
      assert_in_delta Enum.at(result, 4), 10.0, 0.001
      assert_in_delta Enum.at(result, 5), 9.0, 0.001
      assert_in_delta Enum.at(result, 6), 8.5, 0.001
      assert_in_delta Enum.at(result, 7), 9.0, 0.001
    end

    test "raises for period=1" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]
      assert {:error, reason} = MIDPRICE.midprice(high, low, 1)
      assert reason =~ "Invalid parameters"
    end

    test "raises for period=0" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]
      assert {:error, reason} = MIDPRICE.midprice(high, low, 0)
      assert reason =~ "Invalid parameters"
    end

    test "raises for negative period" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]
      assert {:error, reason} = MIDPRICE.midprice(high, low, -1)
      assert reason =~ "Invalid parameters"
    end

    test "raises for mismatched high/low lengths" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0]

      assert {:error, reason} = MIDPRICE.midprice(high, low, 2)
      assert reason =~ "Input arrays must have the same length"
    end

    test "returns empty for empty input" do
      assert {:ok, []} = MIDPRICE.midprice([], [], 3)
    end

    test "handles insufficient data (period > data length)" do
      high = [10.0, 11.0]
      low = [8.0, 9.0]
      assert {:ok, result} = MIDPRICE.midprice(high, low, 5)
      assert result == [nil, nil]
    end

    test "handles period equal to data length" do
      high = [10.0, 11.0, 12.0, 13.0, 14.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0]
      assert {:ok, result} = MIDPRICE.midprice(high, low, 5)

      assert Enum.at(result, 0) == nil
      assert Enum.at(result, 1) == nil
      assert Enum.at(result, 2) == nil
      assert Enum.at(result, 3) == nil
      assert_in_delta Enum.at(result, 4), 11.0, 0.001
    end
  end

  describe "midprice/3 with DataSeries input" do
    test "maintains DataSeries type in output" do
      high_ds =
        DataSeries.new()
        |> DataSeries.add(10.0)
        |> DataSeries.add(11.0)
        |> DataSeries.add(12.0)
        |> DataSeries.add(13.0)
        |> DataSeries.add(14.0)

      low_ds =
        DataSeries.new()
        |> DataSeries.add(8.0)
        |> DataSeries.add(9.0)
        |> DataSeries.add(10.0)
        |> DataSeries.add(11.0)
        |> DataSeries.add(12.0)

      assert {:ok, result_ds} = MIDPRICE.midprice(high_ds, low_ds, 3)
      assert %DataSeries{} = result_ds
    end
  end

  describe "midprice/3 with TimeSeries input" do
    test "maintains TimeSeries type in output" do
      base_time = ~U[2024-01-01 00:00:00.000000Z]

      high_ts =
        TimeSeries.new()
        |> TimeSeries.add(DateTime.add(base_time, 0, :second), 10.0)
        |> TimeSeries.add(DateTime.add(base_time, 60, :second), 11.0)
        |> TimeSeries.add(DateTime.add(base_time, 120, :second), 12.0)
        |> TimeSeries.add(DateTime.add(base_time, 180, :second), 13.0)
        |> TimeSeries.add(DateTime.add(base_time, 240, :second), 14.0)

      low_ts =
        TimeSeries.new()
        |> TimeSeries.add(DateTime.add(base_time, 0, :second), 8.0)
        |> TimeSeries.add(DateTime.add(base_time, 60, :second), 9.0)
        |> TimeSeries.add(DateTime.add(base_time, 120, :second), 10.0)
        |> TimeSeries.add(DateTime.add(base_time, 180, :second), 11.0)
        |> TimeSeries.add(DateTime.add(base_time, 240, :second), 12.0)

      assert {:ok, result_ts} = MIDPRICE.midprice(high_ts, low_ts, 3)
      assert %TimeSeries{} = result_ts
    end
  end

  ## State initialization tests

  describe "init/1" do
    test "initializes with valid period" do
      assert {:ok, _state} = MIDPRICE.init(14)
    end

    test "returns error for period < 2" do
      assert {:error, msg} = MIDPRICE.init(1)
      assert msg =~ "Invalid period"
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    property "APPEND mode matches batch MIDPRICE" do
      check all(
              high_data <- list_of(float(min: 50.0, max: 150.0), min_length: 21, max_length: 500),
              period <- integer(2..200)
            ) do
        # Generate low prices that are always less than high
        low_data = Enum.map(high_data, fn h -> h - :rand.uniform() * 10.0 end)

        # Calculate batch MIDPRICE (expected values)
        {:ok, batch_result} = MIDPRICE.midprice(high_data, low_data, period)

        # Calculate with state (APPEND only - each value = new bar)
        {:ok, initial_state} = MIDPRICE.init(period)

        high_data
        |> Enum.zip(low_data)
        |> Enum.zip(batch_result)
        |> Enum.reduce(initial_state, fn {{high_val, low_val}, expected_value}, state ->
          {:ok, midprice_value, new_state} = MIDPRICE.next(high_val, low_val, true, state)

          case {midprice_value, expected_value} do
            {nil, nil} -> :ok
            {val, exp} when is_float(val) and is_float(exp) -> assert_in_delta(val, exp, 0.0001)
            _ -> flunk("Mismatch in batch vs incremental results")
          end

          new_state
        end)
      end
    end
  end

  describe "property: UPDATE mode behaves correctly" do
    property "UPDATE recalculates with replaced last value" do
      check all(
              high_data <- list_of(float(min: 50.0, max: 150.0), min_length: 15, max_length: 500),
              period <- integer(2..200),
              update_values <-
                list_of(float(min: 50.0, max: 150.0), min_length: 2, max_length: 5)
            ) do
        # Generate low prices that are always less than high
        low_data = Enum.map(high_data, fn h -> h - :rand.uniform() * 10.0 end)

        # Build initial state with data
        {:ok, state} = MIDPRICE.init(period)

        {final_state, _} =
          Enum.zip(high_data, low_data)
          |> Enum.reduce({state, []}, fn {high_val, low_val}, {st, results} ->
            {:ok, midprice_value, new_state} = MIDPRICE.next(high_val, low_val, true, st)
            {new_state, [midprice_value | results]}
          end)

        # Apply multiple UPDATE operations - each replaces the last bar
        Enum.reduce(update_values, {final_state, {high_data, low_data}}, fn update_high,
                                                                            {state,
                                                                             {current_high,
                                                                              current_low}} ->
          # Generate corresponding low value
          update_low = update_high - :rand.uniform() * 10.0

          {:ok, state_midprice, new_state} =
            MIDPRICE.next(update_high, update_low, false, state)

          # Calculate equivalent batch: all previous data + update_value replacing last
          updated_high = List.replace_at(current_high, -1, update_high)
          updated_low = List.replace_at(current_low, -1, update_low)

          {:ok, batch_result} = MIDPRICE.midprice(updated_high, updated_low, period)
          batch_midprice = List.last(batch_result)

          # State UPDATE should match batch calculation
          case {state_midprice, batch_midprice} do
            {nil, nil} ->
              :ok

            {s_val, b_val} when is_float(s_val) and is_float(b_val) ->
              assert_in_delta(s_val, b_val, 0.0001)

            _ ->
              flunk("Mismatch between state UPDATE and batch")
          end

          {new_state, {updated_high, updated_low}}
        end)
      end
    end
  end
end
