defmodule TheoryCraftTA.T3Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{DataSeries, TimeSeries}
  alias TheoryCraftTA.Overlap.T3

  doctest TheoryCraftTA.Overlap.T3

  ## Batch calculation tests

  describe "t3/3 with list input" do
    test "calculates correctly with period=2 and long data" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
      # Python result: [nan nan nan nan nan nan 6.55 7.55 8.55 9.55]
      assert {:ok, result} = T3.t3(data, 2, 0.7)
      # T3 has a long lookback period
      assert Enum.take(result, 6) == [nil, nil, nil, nil, nil, nil]
      assert_in_delta Enum.at(result, 6), 6.55, 0.01
      assert_in_delta Enum.at(result, 7), 7.55, 0.01
    end

    test "raises for period=1" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      assert {:error, reason} = T3.t3(data, 1, 0.7)
      assert reason =~ "Invalid parameters"
    end

    test "raises for period=0" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      assert {:error, reason} = T3.t3(data, 0, 0.7)
      assert reason =~ "Invalid parameters"
    end

    test "returns empty for empty input" do
      assert {:ok, []} = T3.t3([], 3, 0.7)
    end

    test "handles insufficient data" do
      data = [1.0, 2.0]
      assert {:ok, result} = T3.t3(data, 3, 0.7)
      assert result == [nil, nil]
    end
  end

  describe "t3/3 with DataSeries input" do
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

      assert {:ok, result} = T3.t3(data, 2, 0.7)
      assert %DataSeries{} = result
    end
  end

  describe "t3/3 with TimeSeries input" do
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

      assert {:ok, result} = T3.t3(ts, 2, 0.7)
      assert %TimeSeries{} = result
    end
  end

  ## State initialization tests

  describe "init/2" do
    test "initializes with valid period and vfactor" do
      assert {:ok, _state} = T3.init(14, 0.7)
    end

    test "returns error for period < 2" do
      assert {:error, msg} = T3.init(1, 0.7)
      assert msg =~ "Invalid period"
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    property "APPEND mode matches batch T3" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 500),
              period <- integer(2..200)
            ) do
        # Calculate batch T3 (expected values)
        {:ok, batch_result} = T3.t3(data, period, 0.7)

        # Calculate with state (APPEND only - each value = new bar)
        {:ok, initial_state} = T3.init(period, 0.7)

        data
        |> Enum.zip(batch_result)
        |> Enum.reduce(initial_state, fn {value, expected_value}, state ->
          {:ok, t3_value, new_state} = T3.next(value, true, state)

          case {t3_value, expected_value} do
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
        {:ok, state} = T3.init(period, 0.7)

        {final_state, _} =
          Enum.reduce(data, {state, []}, fn value, {st, results} ->
            {:ok, t3_value, new_state} = T3.next(value, true, st)
            {new_state, [t3_value | results]}
          end)

        # Apply multiple UPDATE operations - each replaces the last bar
        Enum.reduce(update_values, {final_state, data}, fn update_value, {state, current_data} ->
          {:ok, state_t3, new_state} = T3.next(update_value, false, state)

          # Calculate equivalent batch: all previous data + update_value replacing last
          updated_data = List.replace_at(current_data, -1, update_value)
          {:ok, batch_result} = T3.t3(updated_data, period, 0.7)
          batch_t3 = List.last(batch_result)

          # State UPDATE should match batch calculation
          case {state_t3, batch_t3} do
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
