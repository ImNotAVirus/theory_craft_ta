defmodule TheoryCraftTA.TRIMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{Bar, DataSeries, TimeSeries, MarketEvent}
  alias TheoryCraftTA.Overlap.TRIMA

  doctest TheoryCraftTA.Overlap.TRIMA

  ## Batch calculation tests

  describe "trima/2 with list input" do
    test "calculates correctly with period=3" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      # Python result: [nan nan 2. 3. 4.]
      assert {:ok, result} = TRIMA.trima(data, 3)
      assert result == [nil, nil, 2.0, 3.0, 4.0]
    end

    test "handles period=2 (minimum valid)" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      # Python result: [nan 1.5 2.5 3.5 4.5]
      assert {:ok, result} = TRIMA.trima(data, 2)
      assert result == [nil, 1.5, 2.5, 3.5, 4.5]
    end

    test "raises for period=1" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = TRIMA.trima(data, 1)
      assert reason =~ "Invalid parameters"
    end

    test "raises for period=0" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = TRIMA.trima(data, 0)
      assert reason =~ "Invalid parameters"
    end

    test "returns empty for empty input" do
      assert {:ok, []} = TRIMA.trima([], 3)
    end

    test "handles insufficient data" do
      data = [1.0, 2.0]
      assert {:ok, result} = TRIMA.trima(data, 3)
      assert result == [nil, nil]
    end

    test "handles NaN at beginning (warmup scenario)" do
      data = [nil, nil, nil, 4.0, 5.0, 6.0, 7.0, 8.0]
      # Python result: [nan nan nan nan nan 5. 6. 7.]
      assert {:ok, result} = TRIMA.trima(data, 3)
      assert result == [nil, nil, nil, nil, nil, 5.0, 6.0, 7.0]
    end

    test "handles NaN in middle (invalid data scenario)" do
      data = [1.0, 2.0, 3.0, nil, 5.0, 6.0, 7.0, 8.0]
      # Python result: [nan nan 2. nan nan nan nan nan]
      assert {:ok, result} = TRIMA.trima(data, 3)
      assert result == [nil, nil, 2.0, nil, nil, nil, nil, nil]
    end
  end

  describe "trima/2 with DataSeries input" do
    test "maintains DataSeries type in output" do
      data =
        DataSeries.new()
        |> DataSeries.add(1.0)
        |> DataSeries.add(2.0)
        |> DataSeries.add(3.0)
        |> DataSeries.add(4.0)
        |> DataSeries.add(5.0)

      assert {:ok, result} = TRIMA.trima(data, 3)
      assert %DataSeries{} = result
    end
  end

  describe "trima/2 with TimeSeries input" do
    test "maintains TimeSeries type in output" do
      ts =
        TimeSeries.new()
        |> TimeSeries.add(~U[2024-01-01 00:00:00Z], 1.0)
        |> TimeSeries.add(~U[2024-01-01 00:01:00Z], 2.0)
        |> TimeSeries.add(~U[2024-01-01 00:02:00Z], 3.0)
        |> TimeSeries.add(~U[2024-01-01 00:03:00Z], 4.0)
        |> TimeSeries.add(~U[2024-01-01 00:04:00Z], 5.0)

      assert {:ok, result} = TRIMA.trima(ts, 3)
      assert %TimeSeries{} = result
    end
  end

  ## State initialization tests

  describe "init/1" do
    test "initializes with valid parameters" do
      assert {:ok, _state} =
               TRIMA.init(period: 14, data: "eurusd_m1", name: "trima14", source: :close)
    end

    test "returns error for period < 2" do
      assert {:error, msg} =
               TRIMA.init(period: 1, data: "eurusd_m1", name: "trima1", source: :close)

      assert msg =~ "Invalid period"
    end

    test "accepts optional bar_name parameter" do
      assert {:ok, state} =
               TRIMA.init(
                 period: 14,
                 data: "rsi",
                 name: "trima_rsi",
                 source: :close,
                 bar_name: "eurusd_m1"
               )

      assert state.bar_name == "eurusd_m1"
    end
  end

  ## Streaming API tests (next/2 with MarketEvent)

  describe "next/2 with Bar input" do
    test "processes bars correctly in APPEND mode" do
      {:ok, state} = TRIMA.init(period: 2, data: "eurusd_m1", name: "trima2", source: :close)

      # First bar
      event1 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 100.0, new_bar?: true}}
      }

      {:ok, result1, state1} = TRIMA.next(event1, state)
      assert result1.data["trima2"] == nil

      # Second bar - should calculate
      event2 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 110.0, new_bar?: true}}
      }

      {:ok, result2, state2} = TRIMA.next(event2, state1)
      assert result2.data["trima2"] == 105.0

      # Third bar
      event3 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 120.0, new_bar?: true}}
      }

      {:ok, result3, _state3} = TRIMA.next(event3, state2)
      assert result3.data["trima2"] == 115.0
    end

    test "processes bars correctly in UPDATE mode" do
      {:ok, state} = TRIMA.init(period: 2, data: "eurusd_m1", name: "trima2", source: :close)

      # First bar (APPEND)
      event1 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 100.0, new_bar?: true}}
      }

      {:ok, _result1, state1} = TRIMA.next(event1, state)

      # Second bar (APPEND)
      event2 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 110.0, new_bar?: true}}
      }

      {:ok, result2, state2} = TRIMA.next(event2, state1)
      assert result2.data["trima2"] == 105.0

      # Update second bar (UPDATE mode - new_bar? = false)
      event3 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 120.0, new_bar?: false}}
      }

      {:ok, result3, _state3} = TRIMA.next(event3, state2)
      # TRIMA should be recalculated with [100.0, 120.0] instead of [100.0, 110.0]
      assert result3.data["trima2"] == 110.0
    end

    test "uses bar_name parameter to extract new_bar? from different source" do
      # Calculate TRIMA on RSI indicator, but use eurusd_m1 for new_bar?
      {:ok, state} =
        TRIMA.init(
          period: 2,
          data: "rsi",
          name: "trima_rsi",
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

      {:ok, _result1, state1} = TRIMA.next(event1, state)

      # Second event: still new bar, rsi = 60.0
      event2 = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.24, new_bar?: true},
          "rsi" => 60.0
        }
      }

      {:ok, result2, state2} = TRIMA.next(event2, state1)
      assert result2.data["trima_rsi"] == 55.0

      # Third event: UPDATE on eurusd_m1 (new_bar? = false), rsi = 65.0
      event3 = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.24, new_bar?: false},
          "rsi" => 65.0
        }
      }

      {:ok, result3, _state3} = TRIMA.next(event3, state2)
      # TRIMA should be recalculated with [50.0, 65.0] instead of [50.0, 60.0]
      assert_in_delta result3.data["trima_rsi"], 57.5, 0.0001
    end

    test "handles nil values from upstream indicators" do
      {:ok, state} =
        TRIMA.init(
          period: 2,
          data: "indicator",
          name: "trima2",
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

      {:ok, result1, state1} = TRIMA.next(event1, state)
      assert result1.data["trima2"] == nil

      # Second value is valid
      event2 = %MarketEvent{
        data: %{
          "indicator" => 100.0,
          "eurusd_m1" => %Bar{close: 1.24, new_bar?: true}
        }
      }

      {:ok, result2, state2} = TRIMA.next(event2, state1)
      assert result2.data["trima2"] == nil

      # Third value is valid - should calculate
      event3 = %MarketEvent{
        data: %{
          "indicator" => 110.0,
          "eurusd_m1" => %Bar{close: 1.25, new_bar?: true}
        }
      }

      {:ok, result3, _state3} = TRIMA.next(event3, state2)
      assert result3.data["trima2"] == 105.0
    end
  end

  ## Property-based tests

  describe "property: state-based APPEND matches batch calculation" do
    property "APPEND mode matches batch TRIMA" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 500),
              period <- integer(2..200)
            ) do
        # Calculate batch TRIMA (expected values)
        {:ok, batch_result} = TRIMA.trima(data, period)

        # Calculate with state (APPEND only - each value = new bar)
        {:ok, initial_state} =
          TRIMA.init(period: period, data: "test", name: "trima", source: :close)

        data
        |> Enum.zip(batch_result)
        |> Enum.reduce(initial_state, fn {value, expected_value}, state ->
          event = %MarketEvent{
            data: %{"test" => %Bar{close: value, new_bar?: true}}
          }

          {:ok, result, new_state} = TRIMA.next(event, state)
          trima_value = result.data["trima"]

          case {trima_value, expected_value} do
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
        {:ok, state} = TRIMA.init(period: period, data: "test", name: "trima", source: :close)

        {final_state, _} =
          Enum.reduce(data, {state, []}, fn value, {st, results} ->
            event = %MarketEvent{
              data: %{"test" => %Bar{close: value, new_bar?: true}}
            }

            {:ok, result, new_state} = TRIMA.next(event, st)
            {new_state, [result.data["trima"] | results]}
          end)

        # Apply multiple UPDATE operations - each replaces the last bar
        Enum.reduce(update_values, {final_state, data}, fn update_value, {state, current_data} ->
          event = %MarketEvent{
            data: %{"test" => %Bar{close: update_value, new_bar?: false}}
          }

          {:ok, result, new_state} = TRIMA.next(event, state)
          state_trima = result.data["trima"]

          # Calculate equivalent batch: all previous data + update_value replacing last
          updated_data = List.replace_at(current_data, -1, update_value)
          {:ok, batch_result} = TRIMA.trima(updated_data, period)
          batch_trima = List.last(batch_result)

          # State UPDATE should match batch calculation
          case {state_trima, batch_trima} do
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
