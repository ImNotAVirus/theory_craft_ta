defmodule TheoryCraftTA.TEMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{Bar, DataSeries, TimeSeries, MarketEvent}
  alias TheoryCraftTA.Overlap.TEMA

  doctest TheoryCraftTA.Overlap.TEMA

  ## Batch calculation tests

  describe "tema/2 with list input" do
    test "calculates correctly with period=2" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      # Python result: [nan nan nan 4. 5.]
      assert {:ok, result} = TEMA.tema(data, 2)
      assert result == [nil, nil, nil, 4.0, 5.0]
    end

    test "raises for period=1" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = TEMA.tema(data, 1)
      assert reason =~ "Invalid parameters"
    end

    test "raises for period=0" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = TEMA.tema(data, 0)
      assert reason =~ "Invalid parameters"
    end

    test "returns empty for empty input" do
      assert {:ok, []} = TEMA.tema([], 3)
    end

    test "handles insufficient data" do
      data = [1.0, 2.0]
      assert {:ok, result} = TEMA.tema(data, 3)
      assert result == [nil, nil]
    end

    test "handles NaN at beginning (warmup scenario)" do
      data = [nil, nil, nil, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
      # Python result: [nan nan nan nan nan nan 7. 8. 9. 10. 11. 12.]
      assert {:ok, result} = TEMA.tema(data, 2)
      assert result == [nil, nil, nil, nil, nil, nil, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
    end

    test "handles NaN in middle (invalid data scenario)" do
      data = [1.0, 2.0, 3.0, nil, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
      # Python result: [nan nan nan nan nan nan nan nan nan nan nan nan]
      assert {:ok, result} = TEMA.tema(data, 2)
      assert result == [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
    end
  end

  describe "tema/2 with DataSeries input" do
    test "maintains DataSeries type in output" do
      data =
        DataSeries.new()
        |> DataSeries.add(1.0)
        |> DataSeries.add(2.0)
        |> DataSeries.add(3.0)
        |> DataSeries.add(4.0)
        |> DataSeries.add(5.0)

      assert {:ok, result} = TEMA.tema(data, 2)
      assert %DataSeries{} = result
    end
  end

  describe "tema/2 with TimeSeries input" do
    test "maintains TimeSeries type in output" do
      ts =
        TimeSeries.new()
        |> TimeSeries.add(~U[2024-01-01 00:00:00Z], 1.0)
        |> TimeSeries.add(~U[2024-01-01 00:01:00Z], 2.0)
        |> TimeSeries.add(~U[2024-01-01 00:02:00Z], 3.0)
        |> TimeSeries.add(~U[2024-01-01 00:03:00Z], 4.0)
        |> TimeSeries.add(~U[2024-01-01 00:04:00Z], 5.0)

      assert {:ok, result} = TEMA.tema(ts, 2)
      assert %TimeSeries{} = result
    end
  end

  ## State initialization tests

  describe "init/1" do
    test "initializes with valid parameters" do
      assert {:ok, _state} =
               TEMA.init(period: 14, data: "eurusd_m1", name: "tema14", source: :close)
    end

    test "returns error for period < 2" do
      assert {:error, msg} =
               TEMA.init(period: 1, data: "eurusd_m1", name: "tema1", source: :close)

      assert msg =~ "Invalid period"
    end

    test "accepts optional bar_name parameter" do
      assert {:ok, state} =
               TEMA.init(
                 period: 14,
                 data: "rsi",
                 name: "tema_rsi",
                 source: :close,
                 bar_name: "eurusd_m1"
               )

      assert state.bar_name == "eurusd_m1"
    end
  end

  ## Streaming API tests (next/2 with MarketEvent)

  describe "next/2 with Bar input" do
    test "processes bars correctly in APPEND mode" do
      {:ok, state} = TEMA.init(period: 2, data: "eurusd_m1", name: "tema2", source: :close)

      # First bar
      event1 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 100.0, new_bar?: true}}
      }

      {:ok, result1, state1} = TEMA.next(event1, state)
      assert result1.data["tema2"] == nil

      # Second bar
      event2 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 110.0, new_bar?: true}}
      }

      {:ok, result2, state2} = TEMA.next(event2, state1)
      assert result2.data["tema2"] == nil

      # Third bar
      event3 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 120.0, new_bar?: true}}
      }

      {:ok, result3, state3} = TEMA.next(event3, state2)
      assert result3.data["tema2"] == nil

      # Fourth bar - should calculate
      event4 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 130.0, new_bar?: true}}
      }

      {:ok, result4, state4} = TEMA.next(event4, state3)
      assert result4.data["tema2"] == 130.0

      # Fifth bar
      event5 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 140.0, new_bar?: true}}
      }

      {:ok, result5, _state5} = TEMA.next(event5, state4)
      assert result5.data["tema2"] == 140.0
    end

    test "processes bars correctly in UPDATE mode" do
      {:ok, state} = TEMA.init(period: 2, data: "eurusd_m1", name: "tema2", source: :close)

      # Build up to the point where we have a valid TEMA value
      events = [
        %MarketEvent{data: %{"eurusd_m1" => %Bar{close: 100.0, new_bar?: true}}},
        %MarketEvent{data: %{"eurusd_m1" => %Bar{close: 110.0, new_bar?: true}}},
        %MarketEvent{data: %{"eurusd_m1" => %Bar{close: 120.0, new_bar?: true}}},
        %MarketEvent{data: %{"eurusd_m1" => %Bar{close: 130.0, new_bar?: true}}}
      ]

      final_state =
        Enum.reduce(events, state, fn event, st ->
          {:ok, _result, new_state} = TEMA.next(event, st)
          new_state
        end)

      # Get current value before update
      {:ok, result_before, state_before} =
        TEMA.next(
          %MarketEvent{data: %{"eurusd_m1" => %Bar{close: 130.0, new_bar?: true}}},
          final_state
        )

      value_before = result_before.data["tema2"]

      # Now update the last bar
      update_event = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 140.0, new_bar?: false}}
      }

      {:ok, result, _state} = TEMA.next(update_event, state_before)
      # TEMA should be recalculated with updated last value
      # Value should be different (unless both nil)
      case {value_before, result.data["tema2"]} do
        {nil, nil} -> :ok
        {v1, v2} when is_float(v1) and is_float(v2) -> assert v1 != v2
        _ -> flunk("Unexpected nil/float combination")
      end
    end

    test "uses bar_name parameter to extract new_bar? from different source" do
      # Calculate TEMA on RSI indicator, but use eurusd_m1 for new_bar?
      {:ok, state} =
        TEMA.init(
          period: 2,
          data: "rsi",
          name: "tema_rsi",
          source: :close,
          bar_name: "eurusd_m1"
        )

      # Build up events
      events = [
        %MarketEvent{
          data: %{"eurusd_m1" => %Bar{close: 1.23, new_bar?: true}, "rsi" => 50.0}
        },
        %MarketEvent{
          data: %{"eurusd_m1" => %Bar{close: 1.24, new_bar?: true}, "rsi" => 60.0}
        },
        %MarketEvent{
          data: %{"eurusd_m1" => %Bar{close: 1.25, new_bar?: true}, "rsi" => 70.0}
        },
        %MarketEvent{
          data: %{"eurusd_m1" => %Bar{close: 1.26, new_bar?: true}, "rsi" => 80.0}
        }
      ]

      final_state =
        Enum.reduce(events, state, fn event, st ->
          {:ok, _result, new_state} = TEMA.next(event, st)
          new_state
        end)

      # UPDATE event
      update_event = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 1.26, new_bar?: false}, "rsi" => 85.0}
      }

      {:ok, result, _state} = TEMA.next(update_event, final_state)
      # TEMA should be recalculated with updated RSI value
      # Just verify we got a value (actual value depends on complex EMA calculations)
      assert result.data["tema_rsi"] != nil
      assert is_float(result.data["tema_rsi"])
    end

    test "handles nil values from upstream indicators" do
      {:ok, state} =
        TEMA.init(
          period: 2,
          data: "indicator",
          name: "tema2",
          source: :close,
          bar_name: "eurusd_m1"
        )

      # First three values with nils
      events_with_nils = [
        %MarketEvent{
          data: %{"indicator" => nil, "eurusd_m1" => %Bar{close: 1.23, new_bar?: true}}
        },
        %MarketEvent{
          data: %{"indicator" => nil, "eurusd_m1" => %Bar{close: 1.24, new_bar?: true}}
        },
        %MarketEvent{
          data: %{"indicator" => 100.0, "eurusd_m1" => %Bar{close: 1.25, new_bar?: true}}
        }
      ]

      state_after_nils =
        Enum.reduce(events_with_nils, state, fn event, st ->
          {:ok, result, new_state} = TEMA.next(event, st)
          assert result.data["tema2"] == nil
          new_state
        end)

      # Continue with valid values
      event4 = %MarketEvent{
        data: %{"indicator" => 110.0, "eurusd_m1" => %Bar{close: 1.26, new_bar?: true}}
      }

      {:ok, result4, state4} = TEMA.next(event4, state_after_nils)
      # TEMA with period 2 needs 4 values total (3*period - 2 = 4)
      # But might still be nil if lookback not satisfied
      assert result4.data["tema2"] == nil or is_float(result4.data["tema2"])

      # Continue adding values until we get output
      remaining_values = [120.0, 130.0, 140.0, 150.0, 160.0]

      final_result =
        Enum.reduce(remaining_values, state4, fn val, st ->
          event = %MarketEvent{
            data: %{
              "indicator" => val,
              "eurusd_m1" => %Bar{close: 1.20 + val / 100, new_bar?: true}
            }
          }

          {:ok, _result, new_state} = TEMA.next(event, st)
          new_state
        end)

      # Final value should give us output
      event_final = %MarketEvent{
        data: %{"indicator" => 170.0, "eurusd_m1" => %Bar{close: 1.27, new_bar?: true}}
      }

      {:ok, result_final, _state_final} = TEMA.next(event_final, final_result)
      assert result_final.data["tema2"] != nil
      assert is_float(result_final.data["tema2"])
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    property "APPEND mode matches batch TEMA" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 500),
              period <- integer(2..200)
            ) do
        # Calculate batch TEMA (expected values)
        {:ok, batch_result} = TEMA.tema(data, period)

        # Calculate with state (APPEND only - each value = new bar)
        {:ok, initial_state} =
          TEMA.init(period: period, data: "test", name: "tema", source: :close)

        data
        |> Enum.zip(batch_result)
        |> Enum.reduce(initial_state, fn {value, expected_value}, state ->
          event = %MarketEvent{
            data: %{"test" => %Bar{close: value, new_bar?: true}}
          }

          {:ok, result, new_state} = TEMA.next(event, state)
          tema_value = result.data["tema"]

          case {tema_value, expected_value} do
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
        {:ok, state} = TEMA.init(period: period, data: "test", name: "tema", source: :close)

        {final_state, _} =
          Enum.reduce(data, {state, []}, fn value, {st, results} ->
            event = %MarketEvent{
              data: %{"test" => %Bar{close: value, new_bar?: true}}
            }

            {:ok, result, new_state} = TEMA.next(event, st)
            {new_state, [result.data["tema"] | results]}
          end)

        # Apply multiple UPDATE operations - each replaces the last bar
        Enum.reduce(update_values, {final_state, data}, fn update_value, {state, current_data} ->
          event = %MarketEvent{
            data: %{"test" => %Bar{close: update_value, new_bar?: false}}
          }

          {:ok, result, new_state} = TEMA.next(event, state)
          state_tema = result.data["tema"]

          # Calculate equivalent batch: all previous data + update_value replacing last
          updated_data = List.replace_at(current_data, -1, update_value)
          {:ok, batch_result} = TEMA.tema(updated_data, period)
          batch_tema = List.last(batch_result)

          # State UPDATE should match batch calculation
          case {state_tema, batch_tema} do
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
