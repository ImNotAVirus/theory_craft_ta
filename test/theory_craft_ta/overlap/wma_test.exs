defmodule TheoryCraftTA.Overlap.WMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{Bar, DataSeries, TimeSeries, MarketEvent}
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

    test "handles NaN at beginning (warmup scenario)" do
      data = [nil, nil, nil, 4.0, 5.0, 6.0, 7.0, 8.0]
      # Python result: [nan nan nan nan nan 5.33333333 6.33333333 7.33333333]
      assert {:ok, result} = WMA.wma(data, 3)
      assert Enum.at(result, 0) == nil
      assert Enum.at(result, 1) == nil
      assert Enum.at(result, 2) == nil
      assert Enum.at(result, 3) == nil
      assert Enum.at(result, 4) == nil
      assert_in_delta Enum.at(result, 5), 5.3333333333, 0.0001
      assert_in_delta Enum.at(result, 6), 6.3333333333, 0.0001
      assert_in_delta Enum.at(result, 7), 7.3333333333, 0.0001
    end

    test "handles NaN in middle (invalid data scenario)" do
      data = [1.0, 2.0, 3.0, nil, 5.0, 6.0, 7.0, 8.0]
      # Python result: [nan nan 2.33333333 nan nan nan nan nan]
      assert {:ok, result} = WMA.wma(data, 3)
      assert Enum.at(result, 0) == nil
      assert Enum.at(result, 1) == nil
      assert_in_delta Enum.at(result, 2), 2.3333333333, 0.0001
      assert Enum.at(result, 3) == nil
      assert Enum.at(result, 4) == nil
      assert Enum.at(result, 5) == nil
      assert Enum.at(result, 6) == nil
      assert Enum.at(result, 7) == nil
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
    test "initializes with valid parameters" do
      assert {:ok, _state} =
               WMA.init(period: 14, data: "eurusd_m1", name: "wma14", source: :close)
    end

    test "returns error for period < 2" do
      assert {:error, msg} =
               WMA.init(period: 1, data: "eurusd_m1", name: "wma1", source: :close)

      assert msg =~ "Invalid period"
    end

    test "accepts optional bar_name parameter" do
      assert {:ok, state} =
               WMA.init(
                 period: 14,
                 data: "rsi",
                 name: "wma_rsi",
                 source: :close,
                 bar_name: "eurusd_m1"
               )

      assert state.bar_name == "eurusd_m1"
    end
  end

  ## Streaming API tests (next/2 with MarketEvent)

  describe "next/2 with Bar input" do
    test "processes bars correctly in APPEND mode" do
      {:ok, state} = WMA.init(period: 2, data: "eurusd_m1", name: "wma2", source: :close)

      # First bar
      event1 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 100.0, new_bar?: true}}
      }

      {:ok, result1, state1} = WMA.next(event1, state)
      assert result1.data["wma2"] == nil

      # Second bar - should calculate
      event2 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 110.0, new_bar?: true}}
      }

      {:ok, result2, state2} = WMA.next(event2, state1)
      # WMA(2) = (100*1 + 110*2) / (1+2) = 320 / 3 ≈ 106.6667
      assert_in_delta result2.data["wma2"], 106.6666667, 0.0001

      # Third bar
      event3 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 120.0, new_bar?: true}}
      }

      {:ok, result3, _state3} = WMA.next(event3, state2)
      # WMA(2) = (110*1 + 120*2) / (1+2) = 350 / 3 ≈ 116.6667
      assert_in_delta result3.data["wma2"], 116.6666667, 0.0001
    end

    test "processes bars correctly in UPDATE mode" do
      {:ok, state} = WMA.init(period: 2, data: "eurusd_m1", name: "wma2", source: :close)

      # First bar (APPEND)
      event1 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 100.0, new_bar?: true}}
      }

      {:ok, _result1, state1} = WMA.next(event1, state)

      # Second bar (APPEND)
      event2 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 110.0, new_bar?: true}}
      }

      {:ok, result2, state2} = WMA.next(event2, state1)
      assert_in_delta result2.data["wma2"], 106.6666667, 0.0001

      # Update second bar (UPDATE mode - new_bar? = false)
      event3 = %MarketEvent{
        data: %{"eurusd_m1" => %Bar{close: 120.0, new_bar?: false}}
      }

      {:ok, result3, _state3} = WMA.next(event3, state2)
      # WMA should be recalculated with [100.0, 120.0] instead of [100.0, 110.0]
      # WMA(2) = (100*1 + 120*2) / (1+2) = 340 / 3 ≈ 113.3333
      assert_in_delta result3.data["wma2"], 113.3333333, 0.0001
    end

    test "uses bar_name parameter to extract new_bar? from different source" do
      # Calculate WMA on RSI indicator, but use eurusd_m1 for new_bar?
      {:ok, state} =
        WMA.init(period: 2, data: "rsi", name: "wma_rsi", source: :close, bar_name: "eurusd_m1")

      # First event: new bar on eurusd_m1, rsi = 50.0
      event1 = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.23, new_bar?: true},
          "rsi" => 50.0
        }
      }

      {:ok, _result1, state1} = WMA.next(event1, state)

      # Second event: still new bar, rsi = 60.0
      event2 = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.24, new_bar?: true},
          "rsi" => 60.0
        }
      }

      {:ok, result2, state2} = WMA.next(event2, state1)
      # WMA(2) = (50*1 + 60*2) / (1+2) = 170 / 3 ≈ 56.6667
      assert_in_delta result2.data["wma_rsi"], 56.6666667, 0.0001

      # Third event: UPDATE on eurusd_m1 (new_bar? = false), rsi = 65.0
      event3 = %MarketEvent{
        data: %{
          "eurusd_m1" => %Bar{close: 1.24, new_bar?: false},
          "rsi" => 65.0
        }
      }

      {:ok, result3, _state3} = WMA.next(event3, state2)
      # WMA should be recalculated with [50.0, 65.0] instead of [50.0, 60.0]
      # WMA(2) = (50*1 + 65*2) / (1+2) = 180 / 3 = 60.0
      assert_in_delta result3.data["wma_rsi"], 60.0, 0.0001
    end

    test "handles nil values from upstream indicators" do
      {:ok, state} =
        WMA.init(
          period: 2,
          data: "indicator",
          name: "wma2",
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

      {:ok, result1, state1} = WMA.next(event1, state)
      assert result1.data["wma2"] == nil

      # Second value is valid
      event2 = %MarketEvent{
        data: %{
          "indicator" => 100.0,
          "eurusd_m1" => %Bar{close: 1.24, new_bar?: true}
        }
      }

      {:ok, result2, state2} = WMA.next(event2, state1)
      assert result2.data["wma2"] == nil

      # Third value is valid - should calculate
      event3 = %MarketEvent{
        data: %{
          "indicator" => 110.0,
          "eurusd_m1" => %Bar{close: 1.25, new_bar?: true}
        }
      }

      {:ok, result3, _state3} = WMA.next(event3, state2)
      # WMA(2) = (100*1 + 110*2) / (1+2) = 320 / 3 ≈ 106.6667
      assert_in_delta result3.data["wma2"], 106.6666667, 0.0001
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
        {:ok, initial_state} =
          WMA.init(period: period, data: "test", name: "wma", source: :close)

        data
        |> Enum.zip(batch_result)
        |> Enum.reduce(initial_state, fn {value, expected_value}, state ->
          event = %MarketEvent{
            data: %{"test" => %Bar{close: value, new_bar?: true}}
          }

          {:ok, result, new_state} = WMA.next(event, state)
          wma_value = result.data["wma"]

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
        {:ok, state} = WMA.init(period: period, data: "test", name: "wma", source: :close)

        {final_state, _} =
          Enum.reduce(data, {state, []}, fn value, {st, results} ->
            event = %MarketEvent{
              data: %{"test" => %Bar{close: value, new_bar?: true}}
            }

            {:ok, result, new_state} = WMA.next(event, st)
            {new_state, [result.data["wma"] | results]}
          end)

        # Apply multiple UPDATE operations - each replaces the last bar
        Enum.reduce(update_values, {final_state, data}, fn update_value, {state, current_data} ->
          event = %MarketEvent{
            data: %{"test" => %Bar{close: update_value, new_bar?: false}}
          }

          {:ok, result, new_state} = WMA.next(event, state)
          state_wma = result.data["wma"]

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
