defmodule TheoryCraftTA.SARTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.DataSeries
  alias TheoryCraft.TimeSeries

  ## Setup

  @moduletag :sar
  @moduletag timeout: 120_000

  describe "setup" do
    @describetag backend: :elixir

    setup do
      Application.put_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Elixir)
      :ok
    end

    test "elixir - sar/2 with list input returns list with SAR values (defaults)", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)

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

    test "elixir - sar/4 with custom acceleration and maximum", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      assert {:ok, result} = TheoryCraftTA.sar(high, low, 0.03, 0.25)

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

    test "elixir - sar/2 handles downtrend", %{} do
      high = [19.0, 18.0, 17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0]
      low = [17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)

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

    test "elixir - sar/2 handles trend reversal", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 13.5, 12.5, 11.5, 10.5, 9.5]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 11.5, 10.5, 9.5, 8.5, 7.5]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)

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

    test "elixir - sar/2 with extended data (20 bars)", %{} do
      high = [
        10.0,
        11.0,
        12.0,
        13.0,
        14.0,
        15.0,
        16.0,
        17.0,
        18.0,
        19.0,
        18.5,
        17.5,
        16.5,
        15.5,
        14.5,
        13.5,
        12.5,
        11.5,
        10.5,
        9.5
      ]

      low = [
        8.0,
        9.0,
        10.0,
        11.0,
        12.0,
        13.0,
        14.0,
        15.0,
        16.0,
        17.0,
        16.5,
        15.5,
        14.5,
        13.5,
        12.5,
        11.5,
        10.5,
        9.5,
        8.5,
        7.5
      ]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)

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
        12.337106575171585,
        13.5364273916407,
        14.519870461145373,
        19.0,
        18.91,
        18.6936,
        18.321984,
        17.776225280000002,
        17.048602752,
        16.14277042176,
        15.072782562713602
      ]

      assert length(result) == length(expected)

      result
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "elixir - sar/2 with minimum data (2 bars)", %{} do
      high = [10.0, 11.0]
      low = [8.0, 9.0]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)

      expected = [nil, 8.0]

      assert result == expected
    end

    test "elixir - sar/2 with single bar returns list with nil", %{} do
      high = [10.0]
      low = [8.0]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)
      assert result == [nil]
    end

    test "elixir - sar/2 with empty list returns empty list", %{} do
      assert {:ok, result} = TheoryCraftTA.sar([], [])
      assert result == []
    end

    test "elixir - sar/2 raises for mismatched high/low lengths", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low)
      assert reason =~ "high and low must have the same length"
    end

    test "elixir - sar/4 raises for invalid acceleration (negative)", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low, -0.01, 0.2)
      assert reason =~ "acceleration must be positive"
    end

    test "elixir - sar/4 raises for invalid acceleration (zero)", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low, 0.0, 0.2)
      assert reason =~ "acceleration must be positive"
    end

    test "elixir - sar/4 raises for invalid maximum (negative)", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low, 0.02, -0.2)
      assert reason =~ "maximum must be positive"
    end

    test "elixir - sar/4 raises for invalid maximum (zero)", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low, 0.02, 0.0)
      assert reason =~ "maximum must be positive"
    end

    test "elixir - sar/4 raises for acceleration > maximum", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low, 0.25, 0.2)
      assert reason =~ "acceleration must be less than or equal to maximum"
    end

    test "elixir - sar/2 with DataSeries input returns DataSeries with SAR values in newest-first order",
         %{} do
      high_values = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low_values = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      # Build DataSeries by adding values (oldest to newest, so they end up newest-first)
      high =
        high_values
        |> Enum.reduce(DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

      low =
        low_values
        |> Enum.reduce(DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

      assert {:ok, %DataSeries{} = result} = TheoryCraftTA.sar(high, low)

      # Extract values (should be in newest-first order)
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

    test "elixir - sar/2 with TimeSeries input returns TimeSeries with SAR values in newest-first order",
         %{} do
      high_values = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low_values = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      # Create timestamps (oldest to newest)
      timestamps =
        0..9
        |> Enum.map(fn i ->
          DateTime.add(~U[2024-01-01 00:00:00Z], i * 60, :second)
        end)

      # Build TimeSeries by adding values with timestamps (oldest to newest)
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

      assert {:ok, %TimeSeries{} = result} = TheoryCraftTA.sar(high, low)

      # Extract values (should be in newest-first order, matching timestamps)
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

  describe "native backend" do
    @describetag backend: :native
    @describetag :native_backend

    setup do
      Application.put_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Native)
      :ok
    end

    test "native - sar/2 with list input returns list with SAR values (defaults)", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)

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

    test "native - sar/4 with custom acceleration and maximum", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      assert {:ok, result} = TheoryCraftTA.sar(high, low, 0.03, 0.25)

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

    test "native - sar/2 handles downtrend", %{} do
      high = [19.0, 18.0, 17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0]
      low = [17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)

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

    test "native - sar/2 handles trend reversal", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 13.5, 12.5, 11.5, 10.5, 9.5]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 11.5, 10.5, 9.5, 8.5, 7.5]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)

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

    test "native - sar/2 with extended data (20 bars)", %{} do
      high = [
        10.0,
        11.0,
        12.0,
        13.0,
        14.0,
        15.0,
        16.0,
        17.0,
        18.0,
        19.0,
        18.5,
        17.5,
        16.5,
        15.5,
        14.5,
        13.5,
        12.5,
        11.5,
        10.5,
        9.5
      ]

      low = [
        8.0,
        9.0,
        10.0,
        11.0,
        12.0,
        13.0,
        14.0,
        15.0,
        16.0,
        17.0,
        16.5,
        15.5,
        14.5,
        13.5,
        12.5,
        11.5,
        10.5,
        9.5,
        8.5,
        7.5
      ]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)

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
        12.337106575171585,
        13.5364273916407,
        14.519870461145373,
        19.0,
        18.91,
        18.6936,
        18.321984,
        17.776225280000002,
        17.048602752,
        16.14277042176,
        15.072782562713602
      ]

      assert length(result) == length(expected)

      result
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "native - sar/2 with minimum data (2 bars)", %{} do
      high = [10.0, 11.0]
      low = [8.0, 9.0]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)

      expected = [nil, 8.0]

      assert result == expected
    end

    test "native - sar/2 with single bar returns list with nil", %{} do
      high = [10.0]
      low = [8.0]

      assert {:ok, result} = TheoryCraftTA.sar(high, low)
      assert result == [nil]
    end

    test "native - sar/2 with empty list returns empty list", %{} do
      assert {:ok, result} = TheoryCraftTA.sar([], [])
      assert result == []
    end

    test "native - sar/2 raises for mismatched high/low lengths", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low)
      assert reason =~ "high and low must have the same length"
    end

    test "native - sar/4 raises for invalid acceleration (negative)", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low, -0.01, 0.2)
      assert reason =~ "acceleration must be positive"
    end

    test "native - sar/4 raises for invalid acceleration (zero)", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low, 0.0, 0.2)
      assert reason =~ "acceleration must be positive"
    end

    test "native - sar/4 raises for invalid maximum (negative)", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low, 0.02, -0.2)
      assert reason =~ "maximum must be positive"
    end

    test "native - sar/4 raises for invalid maximum (zero)", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low, 0.02, 0.0)
      assert reason =~ "maximum must be positive"
    end

    test "native - sar/4 raises for acceleration > maximum", %{} do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0, 10.0]

      assert {:error, reason} = TheoryCraftTA.sar(high, low, 0.25, 0.2)
      assert reason =~ "acceleration must be less than or equal to maximum"
    end

    test "native - sar/2 with DataSeries input returns DataSeries with SAR values in newest-first order",
         %{} do
      high_values = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low_values = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      # Build DataSeries by adding values (oldest to newest, so they end up newest-first)
      high =
        high_values
        |> Enum.reduce(DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

      low =
        low_values
        |> Enum.reduce(DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

      assert {:ok, %DataSeries{} = result} = TheoryCraftTA.sar(high, low)

      # Extract values (should be in newest-first order)
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

    test "native - sar/2 with TimeSeries input returns TimeSeries with SAR values in newest-first order",
         %{} do
      high_values = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low_values = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      # Create timestamps (oldest to newest)
      timestamps =
        0..9
        |> Enum.map(fn i ->
          DateTime.add(~U[2024-01-01 00:00:00Z], i * 60, :second)
        end)

      # Build TimeSeries by adding values with timestamps (oldest to newest)
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

      assert {:ok, %TimeSeries{} = result} = TheoryCraftTA.sar(high, low)

      # Extract values (should be in newest-first order, matching timestamps)
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

  describe "TheoryCraftTA.sar!/4 - bang version" do
    @describetag backend: :elixir

    setup do
      Application.put_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Elixir)
      :ok
    end

    test "returns result directly on success with defaults" do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      result = TheoryCraftTA.sar!(high, low)

      assert length(result) == 10
      assert Enum.at(result, 0) == nil
      assert_in_delta Enum.at(result, 1), 8.0, 0.0001
      assert_in_delta Enum.at(result, 2), 8.06, 0.0001
    end

    test "returns result directly on success with custom params" do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

      result = TheoryCraftTA.sar!(high, low, 0.03, 0.25)

      assert length(result) == 10
      assert Enum.at(result, 0) == nil
      assert_in_delta Enum.at(result, 1), 8.0, 0.0001
      assert_in_delta Enum.at(result, 2), 8.09, 0.0001
    end

    test "raises on error" do
      high = [10.0, 11.0, 12.0]
      low = [8.0, 9.0]

      assert_raise RuntimeError, fn ->
        TheoryCraftTA.sar!(high, low)
      end
    end
  end

  describe "property-based testing: Native vs Elixir backends for sar" do
    @describetag :native_backend

    property "Native and Elixir backends produce identical results for lists" do
      check all(
              high <- list_of(float(min: 100.0, max: 200.0), min_length: 5, max_length: 50),
              low <- list_of(float(min: 50.0, max: 99.0), min_length: 5, max_length: 50),
              acceleration <- float(min: 0.01, max: 0.1),
              maximum <- float(min: 0.1, max: 0.3),
              length(high) == length(low),
              acceleration <= maximum
            ) do
        native_module = TheoryCraftTA.Native.Overlap.SAR
        elixir_module = TheoryCraftTA.Elixir.Overlap.SAR

        {:ok, native_result} = native_module.sar(high, low, acceleration, maximum)
        {:ok, elixir_result} = elixir_module.sar(high, low, acceleration, maximum)

        assert length(native_result) == length(elixir_result)

        Enum.zip(native_result, elixir_result)
        |> Enum.each(fn
          {nil, nil} ->
            :ok

          {native_val, elixir_val} ->
            assert_in_delta native_val, elixir_val, 0.0001
        end)
      end
    end

    property "Native and Elixir backends produce identical results for DataSeries" do
      check all(
              high_values <-
                list_of(float(min: 100.0, max: 200.0), min_length: 5, max_length: 20),
              low_values <- list_of(float(min: 50.0, max: 99.0), min_length: 5, max_length: 20),
              acceleration <- float(min: 0.01, max: 0.1),
              maximum <- float(min: 0.1, max: 0.3),
              length(high_values) == length(low_values),
              acceleration <= maximum
            ) do
        native_module = TheoryCraftTA.Native.Overlap.SAR
        elixir_module = TheoryCraftTA.Elixir.Overlap.SAR

        high = DataSeries.new(high_values)
        low = DataSeries.new(low_values)

        {:ok, native_result} = native_module.sar(high, low, acceleration, maximum)
        {:ok, elixir_result} = elixir_module.sar(high, low, acceleration, maximum)

        native_values = DataSeries.values(native_result)
        elixir_values = DataSeries.values(elixir_result)

        assert length(native_values) == length(elixir_values)

        Enum.zip(native_values, elixir_values)
        |> Enum.each(fn
          {nil, nil} ->
            :ok

          {native_val, elixir_val} ->
            assert_in_delta native_val, elixir_val, 0.0001
        end)
      end
    end
  end
end
