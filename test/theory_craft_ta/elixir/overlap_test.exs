defmodule TheoryCraftTA.Elixir.OverlapTest do
  use ExUnit.Case, async: true

  alias TheoryCraftTA.Elixir.Overlap
  alias TheoryCraft.{DataSeries, TimeSeries}

  ## Tests

  describe "sma/2 with list input" do
    test "calculates SMA correctly with valid period" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      assert {:ok, result} = Overlap.sma(data, 3)

      # First two values should be nil (lookback = period - 1)
      assert Enum.at(result, 0) == nil
      assert Enum.at(result, 1) == nil

      # Third value should be average of first 3: (1.0 + 2.0 + 3.0) / 3 = 2.0
      assert Enum.at(result, 2) == 2.0

      # Fourth value should be average of 2,3,4: (2.0 + 3.0 + 4.0) / 3 = 3.0
      assert Enum.at(result, 3) == 3.0

      # Length should match input
      assert length(result) == length(data)
    end

    test "handles period of 2" do
      data = [1.0, 2.0, 3.0, 4.0]
      assert {:ok, result} = Overlap.sma(data, 2)

      assert Enum.at(result, 0) == nil
      assert Enum.at(result, 1) == 1.5
      assert Enum.at(result, 2) == 2.5
      assert Enum.at(result, 3) == 3.5
    end

    test "handles period equal to data length" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      assert {:ok, result} = Overlap.sma(data, 5)

      # First 4 should be nil
      assert Enum.slice(result, 0..3) == [nil, nil, nil, nil]

      # Last should be average of all: 3.0
      assert Enum.at(result, 4) == 3.0
    end

    test "returns error for period < 2" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = Overlap.sma(data, 1)
      assert reason =~ "Period must be >= 2"
    end

    test "returns error for non-integer period" do
      data = [1.0, 2.0, 3.0]
      assert {:error, reason} = Overlap.sma(data, 3.5)
      assert reason =~ "Period must be an integer"
    end

    test "handles insufficient data (period > data length)" do
      data = [1.0, 2.0]
      assert {:ok, result} = Overlap.sma(data, 5)

      # All values should be nil since we don't have enough data
      assert result == [nil, nil]
    end

    test "handles empty list" do
      assert {:ok, result} = Overlap.sma([], 3)
      assert result == []
    end
  end

  describe "sma/2 with DataSeries input" do
    test "returns DataSeries with SMA values in newest-first order" do
      ds =
        DataSeries.new()
        |> DataSeries.add(1.0)
        |> DataSeries.add(2.0)
        |> DataSeries.add(3.0)
        |> DataSeries.add(4.0)
        |> DataSeries.add(5.0)

      assert {:ok, result_ds} = Overlap.sma(ds, 3)
      assert %DataSeries{} = result_ds

      values = DataSeries.values(result_ds)

      # DataSeries stores newest-first: [5.0, 4.0, 3.0, 2.0, 1.0]
      # After reversal for calculation: [1.0, 2.0, 3.0, 4.0, 5.0]
      # SMA result (oldest-first): [nil, nil, 2.0, 3.0, 4.0]
      # Reversed back (newest-first): [4.0, 3.0, 2.0, nil, nil]

      assert Enum.at(values, 0) == 4.0
      assert Enum.at(values, 1) == 3.0
      assert Enum.at(values, 2) == 2.0
      assert Enum.at(values, 3) == nil
      assert Enum.at(values, 4) == nil
    end

    test "preserves DataSeries max_size" do
      ds = DataSeries.new(max_size: 10)
      ds = DataSeries.add(ds, 1.0)
      ds = DataSeries.add(ds, 2.0)
      ds = DataSeries.add(ds, 3.0)

      assert {:ok, result_ds} = Overlap.sma(ds, 2)
      assert %DataSeries{max_size: 10} = result_ds
    end

    test "handles empty DataSeries" do
      ds = DataSeries.new()
      assert {:ok, result_ds} = Overlap.sma(ds, 3)
      assert DataSeries.values(result_ds) == []
    end
  end

  describe "sma/2 with TimeSeries input" do
    test "returns TimeSeries with SMA values in newest-first order" do
      base_time = ~U[2024-01-01 00:00:00.000000Z]

      ts =
        TimeSeries.new()
        |> TimeSeries.add(DateTime.add(base_time, 0, :second), 1.0)
        |> TimeSeries.add(DateTime.add(base_time, 60, :second), 2.0)
        |> TimeSeries.add(DateTime.add(base_time, 120, :second), 3.0)
        |> TimeSeries.add(DateTime.add(base_time, 180, :second), 4.0)
        |> TimeSeries.add(DateTime.add(base_time, 240, :second), 5.0)

      assert {:ok, result_ts} = Overlap.sma(ts, 3)
      assert %TimeSeries{} = result_ts

      values = TimeSeries.values(result_ts)
      keys = TimeSeries.keys(result_ts)

      # Same calculation as DataSeries test
      assert Enum.at(values, 0) == 4.0
      assert Enum.at(values, 1) == 3.0
      assert Enum.at(values, 2) == 2.0
      assert Enum.at(values, 3) == nil
      assert Enum.at(values, 4) == nil

      # Keys should be preserved
      assert length(keys) == 5
      assert Enum.all?(keys, &match?(%DateTime{}, &1))
    end

    test "preserves DateTime keys in correct order" do
      ts =
        TimeSeries.new()
        |> TimeSeries.add(~U[2024-01-01 09:00:00.000000Z], 100.0)
        |> TimeSeries.add(~U[2024-01-01 09:01:00.000000Z], 101.0)
        |> TimeSeries.add(~U[2024-01-01 09:02:00.000000Z], 102.0)
        |> TimeSeries.add(~U[2024-01-01 09:03:00.000000Z], 103.0)

      original_keys = TimeSeries.keys(ts)

      assert {:ok, result_ts} = Overlap.sma(ts, 2)
      result_keys = TimeSeries.keys(result_ts)

      # Keys should be identical
      assert result_keys == original_keys
    end

    test "handles empty TimeSeries" do
      ts = TimeSeries.new()
      assert {:ok, result_ts} = Overlap.sma(ts, 3)
      assert TimeSeries.values(result_ts) == []
    end
  end
end
