defmodule TheoryCraftTA.WMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{DataSeries, TimeSeries}
  alias TheoryCraftTA.Overlap.WMA

  doctest TheoryCraftTA.Overlap.WMA

  ## Batch calculation tests

  describe "wma/2 with list input" do
    test "calculates correctly with period=3" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      # Python result: [nan nan 2.33333333 3.33333333 4.33333333]
      assert {:ok, result} = WMA.wma(data, 3)
      assert Enum.at(result, 0) == nil
      assert Enum.at(result, 1) == nil
      assert_in_delta Enum.at(result, 2), 2.3333333333, 0.0001
      assert_in_delta Enum.at(result, 3), 3.3333333333, 0.0001
      assert_in_delta Enum.at(result, 4), 4.3333333333, 0.0001
    end

    test "handles period=2 (minimum valid)" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      # Python result: [nan 1.66666667 2.66666667 3.66666667 4.66666667]
      assert {:ok, result} = WMA.wma(data, 2)
      assert Enum.at(result, 0) == nil
      assert_in_delta Enum.at(result, 1), 1.6666666667, 0.0001
      assert_in_delta Enum.at(result, 2), 2.6666666667, 0.0001
      assert_in_delta Enum.at(result, 3), 3.6666666667, 0.0001
      assert_in_delta Enum.at(result, 4), 4.6666666667, 0.0001
    end

    test "raises for period=1" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = WMA.wma(data, 1)
      assert reason =~ "Invalid parameters"
    end

    test "raises for period=0" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = WMA.wma(data, 0)
      assert reason =~ "Invalid parameters"
    end

    test "raises for negative period" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = WMA.wma(data, -1)
      assert reason =~ "Invalid parameters"
    end

    test "returns empty for empty input" do
      assert {:ok, []} = WMA.wma([], 3)
    end

    test "handles insufficient data (period > data length)" do
      data = [1.0, 2.0]
      assert {:ok, result} = WMA.wma(data, 3)
      assert result == [nil, nil]
    end

    test "handles exactly period length" do
      data = [1.0, 2.0, 3.0]
      # Python result: [nan nan 2.33333333]
      assert {:ok, result} = WMA.wma(data, 3)
      assert Enum.at(result, 0) == nil
      assert Enum.at(result, 1) == nil
      assert_in_delta Enum.at(result, 2), 2.3333333333, 0.0001
    end
  end

  describe "wma/2 with DataSeries input" do
    test "maintains DataSeries type in output" do
      data =
        DataSeries.new()
        |> DataSeries.add(1.0)
        |> DataSeries.add(2.0)
        |> DataSeries.add(3.0)
        |> DataSeries.add(4.0)
        |> DataSeries.add(5.0)

      assert {:ok, result} = WMA.wma(data, 3)
      assert %DataSeries{} = result

      # DataSeries stores newest-first
      values = DataSeries.values(result)
      assert Enum.at(values, 0) != nil
      assert Enum.at(values, 1) != nil
      assert Enum.at(values, 2) != nil
      assert Enum.at(values, 3) == nil
      assert Enum.at(values, 4) == nil
    end
  end

  describe "wma/2 with TimeSeries input" do
    test "maintains TimeSeries type in output" do
      ts =
        TimeSeries.new()
        |> TimeSeries.add(~U[2024-01-01 00:00:00Z], 1.0)
        |> TimeSeries.add(~U[2024-01-01 00:01:00Z], 2.0)
        |> TimeSeries.add(~U[2024-01-01 00:02:00Z], 3.0)
        |> TimeSeries.add(~U[2024-01-01 00:03:00Z], 4.0)
        |> TimeSeries.add(~U[2024-01-01 00:04:00Z], 5.0)

      assert {:ok, result} = WMA.wma(ts, 3)
      assert %TimeSeries{} = result

      values = TimeSeries.values(result)
      assert Enum.at(values, 0) != nil
      assert Enum.at(values, 1) != nil
      assert Enum.at(values, 2) != nil
      assert Enum.at(values, 3) == nil
      assert Enum.at(values, 4) == nil
    end
  end

  ## State initialization tests

  describe "init/1" do
    test "initializes with valid period" do
      assert {:ok, _state} = WMA.init(14)
    end

    test "returns error for period < 2" do
      assert {:error, msg} = WMA.init(1)
      assert msg =~ "Invalid period"
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    property "APPEND mode matches batch WMA" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 500),
              period <- integer(2..200)
            ) do
        # Calculate batch WMA (expected values)
        {:ok, batch_result} = WMA.wma(data, period)

        # Calculate with state (APPEND only - each value = new bar)
        {:ok, initial_state} = WMA.init(period)

        data
        |> Enum.zip(batch_result)
        |> Enum.reduce(initial_state, fn {value, expected_value}, state ->
          {:ok, wma_value, new_state} = WMA.next(value, true, state)

          case {wma_value, expected_value} do
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
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 15, max_length: 500),
              period <- integer(2..200),
              update_values <-
                list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 5)
            ) do
        # Build initial state with data
        {:ok, state} = WMA.init(period)

        {final_state, _} =
          Enum.reduce(data, {state, []}, fn value, {st, results} ->
            {:ok, wma_value, new_state} = WMA.next(value, true, st)
            {new_state, [wma_value | results]}
          end)

        # Apply multiple UPDATE operations - each replaces the last bar
        Enum.reduce(update_values, {final_state, data}, fn update_value, {state, current_data} ->
          {:ok, state_wma, new_state} = WMA.next(update_value, false, state)

          # Calculate equivalent batch: all previous data + update_value replacing last
          updated_data = List.replace_at(current_data, -1, update_value)
          {:ok, batch_result} = WMA.wma(updated_data, period)
          batch_wma = List.last(batch_result)

          # State UPDATE should match batch calculation
          case {state_wma, batch_wma} do
            {nil, nil} ->
              :ok

            {s_val, b_val} when is_float(s_val) and is_float(b_val) ->
              assert_in_delta(s_val, b_val, 0.0001)

            _ ->
              flunk("Mismatch between state UPDATE and batch")
          end

          {new_state, updated_data}
        end)
      end
    end
  end
end
