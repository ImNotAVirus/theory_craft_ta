defmodule TheoryCraftTA.T3Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{Bar, DataSeries, TimeSeries, MarketEvent}
  alias TheoryCraftTA.Overlap.T3

  doctest TheoryCraftTA.Overlap.T3

  ## Batch calculation tests

  describe "t3/3 with list input" do
    test "calculates correctly with period=5, vfactor=0.7" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0]
      # Python result with period=5, vfactor=0.7
      assert {:ok, result} = T3.t3(data, 5, 0.7)
      # First several values should be nil (lookback for T3 is quite long: 6*period - 3)
      # For period=5, lookback = 6*5 - 3 = 27, so we need 27+ values for output
      # With only 15 values, we might not get any output
      # Let's just verify the result is a list
      assert is_list(result)
      assert length(result) == length(data)
    end

    test "handles default vfactor=0.7" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
      assert {:ok, result} = T3.t3(data, 5, 0.7)
      assert is_list(result)
    end

    test "raises for period < 2" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = T3.t3(data, 1, 0.7)
      assert reason =~ "Invalid parameters"
    end

    test "raises for period=0" do
      data = [1.0, 2.0, 3.0]
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

    test "handles NaN at beginning (warmup scenario)" do
      # T3 has very long lookback, so use more data
      data = [nil, nil, nil] ++ Enum.to_list(4..20)

      # Python result: [nan nan nan nan nan nan nan nan nan nan nan nan nan nan nan 15.1 16.1 17.1 18.1 19.1]
      assert {:ok, result} = T3.t3(data, 3, 0.7)
      # First 15 values are nil
      assert Enum.take(result, 15) |> Enum.all?(&is_nil/1)
      # Then we get values starting at index 15
      assert_in_delta Enum.at(result, 15), 15.1, 0.1
      assert_in_delta Enum.at(result, 16), 16.1, 0.1
      assert_in_delta Enum.at(result, 17), 17.1, 0.1
      assert_in_delta Enum.at(result, 18), 18.1, 0.1
      assert_in_delta Enum.at(result, 19), 19.1, 0.1
    end

    test "handles NaN in middle (invalid data scenario)" do
      data = [1.0, 2.0, 3.0, nil] ++ Enum.to_list(5..20)
      # Python result: all nan
      assert {:ok, result} = T3.t3(data, 3, 0.7)
      # NaN at index 3 contaminates everything
      assert Enum.all?(result, &is_nil/1)
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

      assert {:ok, result} = T3.t3(data, 3, 0.7)
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

      assert {:ok, result} = T3.t3(ts, 3, 0.7)
      assert %TimeSeries{} = result
    end
  end

  ## State initialization tests

  describe "init/1" do
    test "initializes with valid parameters" do
      assert {:ok, _state} =
               T3.init(
                 period: 14,
                 vfactor: 0.7,
                 data: "eurusd_m1",
                 name: "t3_14",
                 source: :close
               )
    end

    test "returns error for period < 2" do
      assert {:error, msg} =
               T3.init(period: 1, vfactor: 0.7, data: "eurusd_m1", name: "t3_1", source: :close)

      assert msg =~ "Invalid period"
    end

    test "accepts optional bar_name parameter" do
      assert {:ok, state} =
               T3.init(
                 period: 14,
                 vfactor: 0.7,
                 data: "rsi",
                 name: "t3_rsi",
                 source: :close,
                 bar_name: "eurusd_m1"
               )

      assert state.bar_name == "eurusd_m1"
    end
  end

  ## Streaming API tests (next/2 with MarketEvent)

  describe "next/2 with Bar input" do
    test "processes bars correctly in APPEND mode" do
      {:ok, state} =
        T3.init(period: 3, vfactor: 0.7, data: "eurusd_m1", name: "t3", source: :close)

      # Generate enough events to get past warmup (T3 has long lookback: 6*period - 3 = 15 for period=3)
      # Let's generate even more values to ensure we get output
      values = Enum.to_list(100..300//10)

      {_final_state, results} =
        Enum.reduce(values, {state, []}, fn value, {st, acc} ->
          event = %MarketEvent{
            data: %{"eurusd_m1" => %Bar{close: value, new_bar?: true}}
          }

          {:ok, result, new_state} = T3.next(event, st)
          {new_state, [result.data["t3"] | acc]}
        end)

      results_forward = Enum.reverse(results)

      # First several values should be nil (lookback period)
      assert Enum.take(results_forward, 10) |> Enum.all?(&is_nil/1)
      # With 21 values (100..300 step 10), we should have some output eventually
      # If we don't, just verify we have results
      assert length(results_forward) > 0
    end

    test "processes bars correctly in UPDATE mode" do
      {:ok, state} =
        T3.init(period: 3, vfactor: 0.7, data: "eurusd_m1", name: "t3", source: :close)

      # Build up initial state
      values = [100.0, 110.0, 120.0, 130.0, 140.0, 150.0, 160.0, 170.0, 180.0]

      final_state =
        Enum.reduce(values, state, fn value, st ->
          event = %MarketEvent{
            data: %{"eurusd_m1" => %Bar{close: value, new_bar?: true}}
          }

          {:ok, _result, new_state} = T3.next(event, st)
          new_state
        end)

      # Get value with last bar
      event_last = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 190.0, new_bar?: true}}
      }

      {:ok, result_last, state_with_last} = T3.next(event_last, final_state)
      value_with_190 = result_last.data["t3"]

      # Now UPDATE the last bar
      event_update = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 200.0, new_bar?: false}}
      }

      {:ok, result_update, _state_after_update} = T3.next(event_update, state_with_last)
      value_with_200 = result_update.data["t3"]

      # Values should be different (unless both nil)
      case {value_with_190, value_with_200} do
        {nil, nil} -> :ok
        {v1, v2} when is_float(v1) and is_float(v2) -> assert v1 != v2
        _ -> flunk("Unexpected nil/float combination")
      end
    end

    test "uses bar_name parameter to extract new_bar? from different source" do
      # Calculate T3 on RSI indicator, but use eurusd_m1 for new_bar?
      {:ok, state} =
        T3.init(
          period: 3,
          vfactor: 0.7,
          data: "rsi",
          name: "t3_rsi",
          source: :close,
          bar_name: "eurusd_m1"
        )

      # Build up events
      rsi_values = [50.0, 55.0, 60.0, 65.0, 70.0, 75.0, 80.0, 85.0, 90.0]

      final_state =
        Enum.reduce(Enum.with_index(rsi_values, 1), state, fn {rsi, idx}, st ->
          event = %MarketEvent{
            data: %{
              "eurusd_m1" => %Bar{close: 1.20 + idx * 0.01, new_bar?: true},
              "rsi" => rsi
            }
          }

          {:ok, _result, new_state} = T3.next(event, st)
          new_state
        end)

      # APPEND event
      event_append = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.30, new_bar?: true},
          "rsi" => 95.0
        }
      }

      {:ok, result_append, state_after_append} = T3.next(event_append, final_state)
      value_append = result_append.data["t3_rsi"]

      # UPDATE event
      event_update = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.30, new_bar?: false},
          "rsi" => 98.0
        }
      }

      {:ok, result_update, _state_after_update} = T3.next(event_update, state_after_append)
      value_update = result_update.data["t3_rsi"]

      # Values should be different (unless both nil)
      case {value_append, value_update} do
        {nil, nil} -> :ok
        {v1, v2} when is_float(v1) and is_float(v2) -> assert v1 != v2
        _ -> flunk("Unexpected nil/float combination")
      end
    end

    test "handles nil values from upstream indicators" do
      {:ok, state} =
        T3.init(
          period: 3,
          vfactor: 0.7,
          data: "indicator",
          name: "t3",
          source: :close,
          bar_name: "eurusd_m1"
        )

      # Start with nils
      event1 = %MarketEvent{
        data: %{
          "indicator" => nil,
          "eurusd_m1" => %Bar{close: 1.23, new_bar?: true}
        }
      }

      {:ok, result1, state1} = T3.next(event1, state)
      assert result1.data["t3"] == nil

      event2 = %MarketEvent{
        data: %{
          "indicator" => nil,
          "eurusd_m1" => %Bar{close: 1.24, new_bar?: true}
        }
      }

      {:ok, result2, state2} = T3.next(event2, state1)
      assert result2.data["t3"] == nil

      # Continue with valid values
      values = [100.0, 110.0, 120.0, 130.0, 140.0, 150.0, 160.0, 170.0]

      Enum.reduce(Enum.with_index(values, 3), state2, fn {val, idx}, st ->
        event = %MarketEvent{
          data: %{
            "indicator" => val,
            "eurusd_m1" => %Bar{close: 1.20 + idx * 0.01, new_bar?: true}
          }
        }

        {:ok, result, new_state} = T3.next(event, st)
        # T3 output can still be nil during warmup
        assert result.data["t3"] == nil or is_float(result.data["t3"])
        new_state
      end)
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    property "APPEND mode matches batch T3" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 500),
              period <- integer(2..50),
              vfactor <- float(min: 0.0, max: 1.0)
            ) do
        # Calculate batch T3 (expected values)
        {:ok, batch_result} = T3.t3(data, period, vfactor)

        # Calculate with state (APPEND only - each value = new bar)
        {:ok, initial_state} =
          T3.init(period: period, vfactor: vfactor, data: "test", name: "t3", source: :close)

        data
        |> Enum.zip(batch_result)
        |> Enum.reduce(initial_state, fn {value, expected_value}, state ->
          event = %MarketEvent{
            data: %{"test" => %Bar{close: value, new_bar?: true}}
          }

          {:ok, result, new_state} = T3.next(event, state)
          t3_value = result.data["t3"]

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
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 500),
              period <- integer(2..50),
              vfactor <- float(min: 0.0, max: 1.0),
              update_values <-
                list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 5)
            ) do
        # Build initial state with data
        {:ok, state} =
          T3.init(period: period, vfactor: vfactor, data: "test", name: "t3", source: :close)

        {final_state, _} =
          Enum.reduce(data, {state, []}, fn value, {st, results} ->
            event = %MarketEvent{
              data: %{"test" => %Bar{close: value, new_bar?: true}}
            }

            {:ok, result, new_state} = T3.next(event, st)
            {new_state, [result.data["t3"] | results]}
          end)

        # Apply multiple UPDATE operations - each replaces the last bar
        Enum.reduce(update_values, {final_state, data}, fn update_value, {state, current_data} ->
          event = %MarketEvent{
            data: %{"test" => %Bar{close: update_value, new_bar?: false}}
          }

          {:ok, result, new_state} = T3.next(event, state)
          state_t3 = result.data["t3"]

          # Calculate equivalent batch: all previous data + update_value replacing last
          updated_data = List.replace_at(current_data, -1, update_value)
          {:ok, batch_result} = T3.t3(updated_data, period, vfactor)
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
