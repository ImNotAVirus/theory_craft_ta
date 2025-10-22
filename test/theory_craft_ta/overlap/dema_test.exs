defmodule TheoryCraftTA.DEMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{Bar, DataSeries, TimeSeries, MarketEvent}
  alias TheoryCraftTA.Overlap.DEMA

  doctest TheoryCraftTA.Overlap.DEMA

  ## Batch calculation tests

  describe "dema/2 with list input" do
    test "calculates correctly with period=3" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      # Python result: [nan nan nan nan 5.]
      assert {:ok, result} = DEMA.dema(data, 3)
      assert result == [nil, nil, nil, nil, 5.0]
    end

    test "handles period=2 (minimum valid)" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      # Python result: [nan nan 3. 4. 5.]
      assert {:ok, result} = DEMA.dema(data, 2)
      assert result == [nil, nil, 3.0, 4.0, 5.0]
    end

    test "raises for period=1" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = DEMA.dema(data, 1)
      assert reason =~ "Invalid parameters"
    end

    test "raises for period=0" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = DEMA.dema(data, 0)
      assert reason =~ "Invalid parameters"
    end

    test "returns empty for empty input" do
      assert {:ok, []} = DEMA.dema([], 3)
    end

    test "handles insufficient data" do
      data = [1.0, 2.0]
      assert {:ok, result} = DEMA.dema(data, 3)
      assert result == [nil, nil]
    end

    test "handles NaN at beginning (warmup scenario)" do
      data = [nil, nil, nil, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
      # Python result: [nan nan nan nan nan 6. 7. 8. 9. 10.]
      assert {:ok, result} = DEMA.dema(data, 2)
      assert result == [nil, nil, nil, nil, nil, 6.0, 7.0, 8.0, 9.0, 10.0]
    end

    test "handles NaN in middle (invalid data scenario)" do
      data = [1.0, 2.0, 3.0, nil, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
      # Python result: [nan nan 3. nan nan nan nan nan nan nan]
      assert {:ok, result} = DEMA.dema(data, 2)
      assert result == [nil, nil, 3.0, nil, nil, nil, nil, nil, nil, nil]
    end
  end

  describe "dema/2 with DataSeries input" do
    test "maintains DataSeries type in output" do
      data =
        DataSeries.new()
        |> DataSeries.add(1.0)
        |> DataSeries.add(2.0)
        |> DataSeries.add(3.0)
        |> DataSeries.add(4.0)
        |> DataSeries.add(5.0)

      assert {:ok, result} = DEMA.dema(data, 3)
      assert %DataSeries{} = result
    end
  end

  describe "dema/2 with TimeSeries input" do
    test "maintains TimeSeries type in output" do
      ts =
        TimeSeries.new()
        |> TimeSeries.add(~U[2024-01-01 00:00:00Z], 1.0)
        |> TimeSeries.add(~U[2024-01-01 00:01:00Z], 2.0)
        |> TimeSeries.add(~U[2024-01-01 00:02:00Z], 3.0)
        |> TimeSeries.add(~U[2024-01-01 00:03:00Z], 4.0)
        |> TimeSeries.add(~U[2024-01-01 00:04:00Z], 5.0)

      assert {:ok, result} = DEMA.dema(ts, 3)
      assert %TimeSeries{} = result
    end
  end

  ## State initialization tests

  describe "init/1" do
    test "initializes with valid parameters" do
      assert {:ok, _state} =
               DEMA.init(period: 14, data: "eurusd_m1", name: "dema14", source: :close)
    end

    test "returns error for period < 2" do
      assert {:error, msg} =
               DEMA.init(period: 1, data: "eurusd_m1", name: "dema1", source: :close)

      assert msg =~ "Invalid period"
    end

    test "accepts optional bar_name parameter" do
      assert {:ok, state} =
               DEMA.init(
                 period: 14,
                 data: "rsi",
                 name: "dema_rsi",
                 source: :close,
                 bar_name: "eurusd_m1"
               )

      assert state.bar_name == "eurusd_m1"
    end
  end

  ## Streaming API tests (next/2 with MarketEvent)

  describe "next/2 with Bar input" do
    test "processes bars correctly in APPEND mode" do
      {:ok, state} = DEMA.init(period: 2, data: "eurusd_m1", name: "dema2", source: :close)

      # First bar
      event1 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 100.0, new_bar?: true}}
      }

      {:ok, result1, state1} = DEMA.next(event1, state)
      assert result1.data["dema2"] == nil

      # Second bar
      event2 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 110.0, new_bar?: true}}
      }

      {:ok, result2, state2} = DEMA.next(event2, state1)
      assert result2.data["dema2"] == nil

      # Third bar - should calculate
      event3 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 120.0, new_bar?: true}}
      }

      {:ok, result3, state3} = DEMA.next(event3, state2)
      assert result3.data["dema2"] == 120.0

      # Fourth bar
      event4 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 130.0, new_bar?: true}}
      }

      {:ok, result4, _state4} = DEMA.next(event4, state3)
      assert result4.data["dema2"] == 130.0
    end

    test "processes bars correctly in UPDATE mode" do
      {:ok, state} = DEMA.init(period: 2, data: "eurusd_m1", name: "dema2", source: :close)

      # First bar (APPEND)
      event1 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 100.0, new_bar?: true}}
      }

      {:ok, _result1, state1} = DEMA.next(event1, state)

      # Second bar (APPEND)
      event2 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 110.0, new_bar?: true}}
      }

      {:ok, _result2, state2} = DEMA.next(event2, state1)

      # Third bar (APPEND)
      event3 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 120.0, new_bar?: true}}
      }

      {:ok, result3, state3} = DEMA.next(event3, state2)
      assert result3.data["dema2"] == 120.0

      # Update third bar (UPDATE mode - new_bar? = false)
      event4 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 130.0, new_bar?: false}}
      }

      {:ok, result4, _state4} = DEMA.next(event4, state3)
      # DEMA should be recalculated with [100.0, 110.0, 130.0] instead of [100.0, 110.0, 120.0]
      assert result4.data["dema2"] == 130.0
    end

    test "uses bar_name parameter to extract new_bar? from different source" do
      # Calculate DEMA on RSI indicator, but use eurusd_m1 for new_bar?
      {:ok, state} =
        DEMA.init(
          period: 2,
          data: "rsi",
          name: "dema_rsi",
          source: :close,
          bar_name: "eurusd_m1"
        )

      # First event: new bar on eurusd_m1, rsi = 50.0
      event1 = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.23, new_bar?: true},
          "rsi" => 50.0
        }
      }

      {:ok, _result1, state1} = DEMA.next(event1, state)

      # Second event: still new bar, rsi = 60.0
      event2 = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.24, new_bar?: true},
          "rsi" => 60.0
        }
      }

      {:ok, _result2, state2} = DEMA.next(event2, state1)

      # Third event: still new bar, rsi = 70.0
      event3 = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.25, new_bar?: true},
          "rsi" => 70.0
        }
      }

      {:ok, result3, state3} = DEMA.next(event3, state2)
      assert result3.data["dema_rsi"] == 70.0

      # Fourth event: UPDATE on eurusd_m1 (new_bar? = false), rsi = 75.0
      event4 = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.25, new_bar?: false},
          "rsi" => 75.0
        }
      }

      {:ok, result4, _state4} = DEMA.next(event4, state3)
      # DEMA should be recalculated with [50.0, 60.0, 75.0] instead of [50.0, 60.0, 70.0]
      assert result4.data["dema_rsi"] == 75.0
    end

    test "handles nil values from upstream indicators" do
      {:ok, state} =
        DEMA.init(
          period: 2,
          data: "indicator",
          name: "dema2",
          source: :close,
          bar_name: "eurusd_m1"
        )

      # First value is nil (upstream not ready)
      event1 = %MarketEvent{
        data: %{
          "indicator" => nil,
          "eurusd_m1" => %Bar{close: 1.23, new_bar?: true}
        }
      }

      {:ok, result1, state1} = DEMA.next(event1, state)
      assert result1.data["dema2"] == nil

      # Second value is valid
      event2 = %MarketEvent{
        data: %{
          "indicator" => 100.0,
          "eurusd_m1" => %Bar{close: 1.24, new_bar?: true}
        }
      }

      {:ok, result2, state2} = DEMA.next(event2, state1)
      assert result2.data["dema2"] == nil

      # Third value is valid
      event3 = %MarketEvent{
        data: %{
          "indicator" => 110.0,
          "eurusd_m1" => %Bar{close: 1.25, new_bar?: true}
        }
      }

      {:ok, result3, state3} = DEMA.next(event3, state2)
      # DEMA with period 2 still warming up
      assert result3.data["dema2"] == nil or is_float(result3.data["dema2"])

      # Continue adding values until we get output
      remaining_values = [120.0, 130.0, 140.0, 150.0]

      final_result =
        Enum.reduce(remaining_values, state3, fn val, st ->
          event = %MarketEvent{
            data: %{
              "indicator" => val,
              "eurusd_m1" => %Bar{close: 1.20 + val / 100, new_bar?: true}
            }
          }

          {:ok, _result, new_state} = DEMA.next(event, st)
          new_state
        end)

      # Final value should give us output
      event_final = %MarketEvent{
        data: %{
          "indicator" => 160.0,
          "eurusd_m1" => %Bar{close: 1.26, new_bar?: true}
        }
      }

      {:ok, result_final, _state_final} = DEMA.next(event_final, final_result)
      assert result_final.data["dema2"] != nil
      assert is_float(result_final.data["dema2"])
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    property "APPEND mode matches batch DEMA" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 500),
              period <- integer(2..200)
            ) do
        # Calculate batch DEMA (expected values)
        {:ok, batch_result} = DEMA.dema(data, period)

        # Calculate with state (APPEND only - each value = new bar)
        {:ok, initial_state} =
          DEMA.init(period: period, data: "test", name: "dema", source: :close)

        data
        |> Enum.zip(batch_result)
        |> Enum.reduce(initial_state, fn {value, expected_value}, state ->
          event = %MarketEvent{
            data: %{"test" => %Bar{close: value, new_bar?: true}}
          }

          {:ok, result, new_state} = DEMA.next(event, state)
          dema_value = result.data["dema"]

          case {dema_value, expected_value} do
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
        {:ok, state} = DEMA.init(period: period, data: "test", name: "dema", source: :close)

        {final_state, _} =
          Enum.reduce(data, {state, []}, fn value, {st, results} ->
            event = %MarketEvent{
              data: %{"test" => %Bar{close: value, new_bar?: true}}
            }

            {:ok, result, new_state} = DEMA.next(event, st)
            {new_state, [result.data["dema"] | results]}
          end)

        # Apply multiple UPDATE operations - each replaces the last bar
        Enum.reduce(update_values, {final_state, data}, fn update_value, {state, current_data} ->
          event = %MarketEvent{
            data: %{"test" => %Bar{close: update_value, new_bar?: false}}
          }

          {:ok, result, new_state} = DEMA.next(event, state)
          state_dema = result.data["dema"]

          # Calculate equivalent batch: all previous data + update_value replacing last
          updated_data = List.replace_at(current_data, -1, update_value)
          {:ok, batch_result} = DEMA.dema(updated_data, period)
          batch_dema = List.last(batch_result)

          # State UPDATE should match batch calculation
          case {state_dema, batch_dema} do
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
