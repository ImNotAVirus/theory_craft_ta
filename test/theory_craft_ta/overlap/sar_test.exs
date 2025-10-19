defmodule TheoryCraftTA.SARTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.DataSeries
  alias TheoryCraft.TimeSeries
  alias TheoryCraftTA.Overlap.SAR

  ## Setup

  @moduletag :sar
  @moduletag timeout: 120_000

  ## Tests

  describe "sar/4 with list input" do
    test "returns list with SAR values (default parameters)" do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      assert {:ok, result} = SAR.sar(high, low)

      expected = [
        nil,
        8.0,
        8.06,
        8.217600000000001,
        8.504544000000001,
        8.944180480000002,
        9.549762432000001,
        10.323790940160002,
        11.258460208537603,
        12.337106575171585
      ]

      assert length(result) == length(expected)

      result
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "with custom acceleration and maximum" do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      assert {:ok, result} = SAR.sar(high, low, 0.03, 0.25)

      expected = [
        nil,
        8.0,
        8.09,
        8.3246,
        8.745386,
        9.37593968,
        10.219548728,
        11.26002995696,
        12.4654236659984,
        13.793721986158785
      ]

      assert length(result) == length(expected)

      result
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "handles downtrend" do
      high = [19.0, 18.0, 17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0]
      low = [17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0]

      assert {:ok, result} = SAR.sar(high, low)

      expected = [
        nil,
        19.0,
        18.94,
        18.782400000000003,
        18.495456,
        18.05581952,
        17.450237568,
        16.676209059839998,
        15.741539791462397,
        14.662893424828415
      ]

      assert length(result) == length(expected)

      result
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "handles trend reversal" do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 13.5, 12.5, 11.5, 10.5, 9.5]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 11.5, 10.5, 9.5, 8.5, 7.5]

      assert {:ok, result} = SAR.sar(high, low)

      expected = [
        nil,
        8.0,
        8.06,
        8.217600000000001,
        8.504544000000001,
        8.944180480000002,
        9.348646041600002,
        14.0,
        13.91,
        13.6936
      ]

      assert length(result) == length(expected)

      result
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "with minimum data (2 bars)" do
      high = [10.0, 11.0]
      low = [8.0, 9.0]

      assert {:ok, result} = SAR.sar(high, low)
      assert result == [nil, 8.0]
    end

    test "with single bar returns list with nil" do
      high = [10.0]
      low = [8.0]

      assert {:ok, result} = SAR.sar(high, low)
      assert result == [nil]
    end

    test "with empty list returns empty list" do
      assert {:ok, result} = SAR.sar([], [])
      assert result == []
    end

    test "raises for mismatched high/low lengths" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0]

      assert {:error, reason} = SAR.sar(high, low)
      assert reason =~ "high and low must have the same length"
    end

    test "raises for invalid acceleration (negative)" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = SAR.sar(high, low, -0.01, 0.2)
      assert reason =~ "acceleration must be positive"
    end

    test "raises for invalid acceleration (zero)" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = SAR.sar(high, low, 0.0, 0.2)
      assert reason =~ "acceleration must be positive"
    end

    test "raises for invalid maximum (negative)" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = SAR.sar(high, low, 0.02, -0.2)
      assert reason =~ "maximum must be positive"
    end

    test "raises for invalid maximum (zero)" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = SAR.sar(high, low, 0.02, 0.0)
      assert reason =~ "maximum must be positive"
    end

    test "raises for acceleration > maximum" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = SAR.sar(high, low, 0.25, 0.2)
      assert reason =~ "acceleration must be less than or equal to maximum"
    end
  end

  describe "sar/4 with DataSeries input" do
    test "returns DataSeries with SAR values in newest-first order" do
      high_values = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low_values = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      high =
        high_values
        |> Enum.reduce(DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

      low =
        low_values
        |> Enum.reduce(DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

      assert {:ok, %DataSeries{} = result} = SAR.sar(high, low)

      values = DataSeries.values(result)

      expected = [
        12.337106575171585,
        11.258460208537603,
        10.323790940160002,
        9.549762432000001,
        8.944180480000002,
        8.504544000000001,
        8.217600000000001,
        8.06,
        8.0,
        nil
      ]

      assert length(values) == length(expected)

      values
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end
  end

  describe "sar/4 with TimeSeries input" do
    test "returns TimeSeries with SAR values in newest-first order" do
      high_values = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low_values = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      timestamps =
        0..9
        |> Enum.map(fn i ->
          DateTime.add(~U[2024-01-01 00:00:00Z], i * 60, :second)
        end)

      high =
        Enum.zip(timestamps, high_values)
        |> Enum.reduce(TimeSeries.new(), fn {ts, val}, acc ->
          TimeSeries.add(acc, ts, val)
        end)

      low =
        Enum.zip(timestamps, low_values)
        |> Enum.reduce(TimeSeries.new(), fn {ts, val}, acc ->
          TimeSeries.add(acc, ts, val)
        end)

      assert {:ok, %TimeSeries{} = result} = SAR.sar(high, low)

      values = TimeSeries.values(result)

      expected = [
        12.337106575171585,
        11.258460208537603,
        10.323790940160002,
        9.549762432000001,
        8.944180480000002,
        8.504544000000001,
        8.217600000000001,
        8.06,
        8.0,
        nil
      ]

      assert length(values) == length(expected)

      values
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end
  end

  describe "property: state-based APPEND matches batch calculation" do
    property "APPEND mode matches batch SAR" do
      check all(
              high <- list_of(float(min: 100.0, max: 200.0), min_length: 10, max_length: 100),
              low <- list_of(float(min: 50.0, max: 99.0), min_length: 10, max_length: 100),
              acceleration <- float(min: 0.01, max: 0.1),
              maximum <- float(min: 0.1, max: 0.3),
              length(high) == length(low),
              acceleration <= maximum
            ) do
        {:ok, batch_result} = SAR.sar(high, low, acceleration, maximum)

        {:ok, initial_state} = SAR.init(acceleration, maximum)

        Enum.zip([high, low, batch_result])
        |> Enum.reduce(initial_state, fn {h, l, expected_value}, state ->
          {:ok, sar_value, new_state} = SAR.next(state, h, l, true)

          case {sar_value, expected_value} do
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
    property "UPDATE recalculates with replaced last values" do
      check all(
              high <- list_of(float(min: 100.0, max: 200.0), min_length: 10, max_length: 50),
              low <- list_of(float(min: 50.0, max: 99.0), min_length: 10, max_length: 50),
              update_highs <-
                list_of(float(min: 100.0, max: 200.0), min_length: 2, max_length: 5),
              update_lows <- list_of(float(min: 50.0, max: 99.0), min_length: 2, max_length: 5),
              acceleration <- float(min: 0.01, max: 0.1),
              maximum <- float(min: 0.1, max: 0.3),
              length(high) == length(low),
              length(update_highs) == length(update_lows),
              acceleration <= maximum
            ) do
        {:ok, state} = SAR.init(acceleration, maximum)

        {final_state, _} =
          Enum.zip(high, low)
          |> Enum.reduce({state, []}, fn {h, l}, {st, results} ->
            {:ok, sar_value, new_state} = SAR.next(st, h, l, true)
            {new_state, [sar_value | results]}
          end)

        Enum.zip(update_highs, update_lows)
        |> Enum.reduce({final_state, high, low}, fn {upd_h, upd_l}, {state, curr_h, curr_l} ->
          {:ok, state_sar, new_state} = SAR.next(state, upd_h, upd_l, false)

          updated_high = List.replace_at(curr_h, -1, upd_h)
          updated_low = List.replace_at(curr_l, -1, upd_l)
          {:ok, batch_result} = SAR.sar(updated_high, updated_low, acceleration, maximum)
          batch_sar = List.last(batch_result)

          case {state_sar, batch_sar} do
            {nil, nil} ->
              :ok

            {s_val, b_val} when is_float(s_val) and is_float(b_val) ->
              assert_in_delta(s_val, b_val, 0.0001)

            _ ->
              flunk("Mismatch between state UPDATE and batch")
          end

          {new_state, updated_high, updated_low}
        end)
      end
    end
  end
end
