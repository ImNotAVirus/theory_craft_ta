defmodule TheoryCraftTA.KAMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{DataSeries, TimeSeries}
  alias TheoryCraftTA.Overlap.KAMA

  doctest TheoryCraftTA.Overlap.KAMA

  ## Batch calculation tests

  describe "kama/2 with list input" do
    test "calculates correctly with period=5, ascending data" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]

      # Python result: [nan nan nan nan nan 5.44444444 6.13580247 6.96433471 7.86907484 8.81615269]
      assert {:ok, result} = KAMA.kama(data, 5)

      assert Enum.take(result, 5) == [nil, nil, nil, nil, nil]
      assert_in_delta Enum.at(result, 5), 5.44444444, 0.01
      assert_in_delta Enum.at(result, 6), 6.13580247, 0.01
      assert_in_delta Enum.at(result, 7), 6.96433471, 0.01
      assert_in_delta Enum.at(result, 8), 7.86907484, 0.01
      assert_in_delta Enum.at(result, 9), 8.81615269, 0.01
    end

    test "calculates correctly with period=5, descending data" do
      data = [10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0]

      # Python result: [nan nan nan nan nan 5.55555556 4.86419753 4.03566529 3.13092516 2.18384731]
      assert {:ok, result} = KAMA.kama(data, 5)

      assert Enum.take(result, 5) == [nil, nil, nil, nil, nil]
      assert_in_delta Enum.at(result, 5), 5.55555556, 0.01
      assert_in_delta Enum.at(result, 6), 4.86419753, 0.01
      assert_in_delta Enum.at(result, 7), 4.03566529, 0.01
      assert_in_delta Enum.at(result, 8), 3.13092516, 0.01
      assert_in_delta Enum.at(result, 9), 2.18384731, 0.01
    end

    test "handles flat data (no volatility)" do
      data = List.duplicate(100.0, 20)
      assert {:ok, result} = KAMA.kama(data, 10)

      # First 10 values are nil (lookback period)
      assert Enum.take(result, 10) |> Enum.all?(&(&1 == nil))

      # After warmup, all values should be 100.0
      for i <- 10..19 do
        assert_in_delta Enum.at(result, i), 100.0, 0.01
      end
    end

    test "handles period=2 (minimum valid)" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      assert {:ok, result} = KAMA.kama(data, 2)
      assert Enum.take(result, 2) == [nil, nil]
      assert is_float(Enum.at(result, 2))
    end

    test "raises for period=1" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = KAMA.kama(data, 1)
      assert reason =~ "Invalid parameters"
    end

    test "raises for period=0" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = KAMA.kama(data, 0)
      assert reason =~ "Invalid parameters"
    end

    test "returns empty for empty input" do
      assert {:ok, []} = KAMA.kama([], 5)
    end

    test "handles insufficient data" do
      data = [1.0, 2.0, 3.0]
      assert {:ok, result} = KAMA.kama(data, 5)
      assert result == [nil, nil, nil]
    end
  end

  describe "kama/2 with DataSeries input" do
    test "maintains DataSeries type in output" do
      data =
        DataSeries.new()
        |> DataSeries.add(1.0)
        |> DataSeries.add(2.0)
        |> DataSeries.add(3.0)
        |> DataSeries.add(4.0)
        |> DataSeries.add(5.0)
        |> DataSeries.add(6.0)
        |> DataSeries.add(7.0)
        |> DataSeries.add(8.0)
        |> DataSeries.add(9.0)
        |> DataSeries.add(10.0)

      assert {:ok, result} = KAMA.kama(data, 5)
      assert %DataSeries{} = result
    end
  end

  describe "kama/2 with TimeSeries input" do
    test "maintains TimeSeries type in output" do
      ts =
        TimeSeries.new()
        |> TimeSeries.add(~U[2024-01-01 00:00:00Z], 1.0)
        |> TimeSeries.add(~U[2024-01-01 00:01:00Z], 2.0)
        |> TimeSeries.add(~U[2024-01-01 00:02:00Z], 3.0)
        |> TimeSeries.add(~U[2024-01-01 00:03:00Z], 4.0)
        |> TimeSeries.add(~U[2024-01-01 00:04:00Z], 5.0)
        |> TimeSeries.add(~U[2024-01-01 00:05:00Z], 6.0)
        |> TimeSeries.add(~U[2024-01-01 00:06:00Z], 7.0)
        |> TimeSeries.add(~U[2024-01-01 00:07:00Z], 8.0)
        |> TimeSeries.add(~U[2024-01-01 00:08:00Z], 9.0)
        |> TimeSeries.add(~U[2024-01-01 00:09:00Z], 10.0)

      assert {:ok, result} = KAMA.kama(ts, 5)
      assert %TimeSeries{} = result
    end
  end

  ## State initialization tests

  describe "init/1" do
    test "initializes with valid period" do
      assert {:ok, _state} = KAMA.init(14)
    end

    test "returns error for period < 2" do
      assert {:error, msg} = KAMA.init(1)
      assert msg =~ "Invalid period"
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    property "APPEND mode matches batch KAMA" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 500),
              period <- integer(2..200)
            ) do
        # Calculate batch KAMA (expected values)
        {:ok, batch_result} = KAMA.kama(data, period)

        # Calculate with state (APPEND only - each value = new bar)
        {:ok, initial_state} = KAMA.init(period)

        data
        |> Enum.zip(batch_result)
        |> Enum.reduce(initial_state, fn {value, expected_value}, state ->
          {:ok, kama_value, new_state} = KAMA.next(value, true, state)

          case {kama_value, expected_value} do
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
        {:ok, state} = KAMA.init(period)

        {final_state, _} =
          Enum.reduce(data, {state, []}, fn value, {st, results} ->
            {:ok, kama_value, new_state} = KAMA.next(value, true, st)
            {new_state, [kama_value | results]}
          end)

        # Apply multiple UPDATE operations - each replaces the last bar
        Enum.reduce(update_values, {final_state, data}, fn update_value, {state, current_data} ->
          {:ok, state_kama, new_state} = KAMA.next(update_value, false, state)

          # Calculate equivalent batch: all previous data + update_value replacing last
          updated_data = List.replace_at(current_data, -1, update_value)
          {:ok, batch_result} = KAMA.kama(updated_data, period)
          batch_kama = List.last(batch_result)

          # State UPDATE should match batch calculation
          case {state_kama, batch_kama} do
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
