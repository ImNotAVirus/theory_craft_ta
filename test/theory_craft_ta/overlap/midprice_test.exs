defmodule TheoryCraftTA.MIDPRICETest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{DataSeries, TimeSeries}

  doctest TheoryCraftTA.Native.Overlap.MIDPRICE
  doctest TheoryCraftTA.Elixir.Overlap.MIDPRICE
  doctest TheoryCraftTA.Native.Overlap.MIDPRICEState
  doctest TheoryCraftTA.Elixir.Overlap.MIDPRICEState

  @backends %{
    native: TheoryCraftTA.Native.Overlap.MIDPRICE,
    elixir: TheoryCraftTA.Elixir.Overlap.MIDPRICE
  }

  ## Tests for MIDPRICE (Midpoint Price over period)

  for {backend_name, backend_module} <- @backends do
    @backend_module backend_module

    describe "#{backend_name} - midprice/3 with list input" do
      test "calculates correctly with period=3" do
        high = [10.0, 11.0, 12.0, 13.0, 14.0]
        low = [8.0, 9.0, 10.0, 11.0, 12.0]
        # Python result: [nan nan 10. 11. 12.]
        assert {:ok, result} = @backend_module.midprice(high, low, 3)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert_in_delta Enum.at(result, 2), 10.0, 0.001
        assert_in_delta Enum.at(result, 3), 11.0, 0.001
        assert_in_delta Enum.at(result, 4), 12.0, 0.001
      end

      test "handles period=2 (minimum valid)" do
        high = [100.0, 101.0, 102.0, 103.0, 104.0]
        low = [98.0, 99.0, 100.0, 101.0, 102.0]
        # Python result: [  nan  99.5 100.5 101.5 102.5]
        assert {:ok, result} = @backend_module.midprice(high, low, 2)

        assert Enum.at(result, 0) == nil
        assert_in_delta Enum.at(result, 1), 99.5, 0.001
        assert_in_delta Enum.at(result, 2), 100.5, 0.001
        assert_in_delta Enum.at(result, 3), 101.5, 0.001
        assert_in_delta Enum.at(result, 4), 102.5, 0.001
      end

      test "calculates correctly for varying data" do
        high = [10.0, 11.0, 12.0, 11.0, 10.0, 9.0, 10.0, 11.0]
        low = [8.0, 9.0, 10.0, 9.0, 8.0, 7.0, 8.0, 9.0]
        # Python result: [ nan  nan 10.  10.5 10.   9.   8.5  9. ]
        assert {:ok, result} = @backend_module.midprice(high, low, 3)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert_in_delta Enum.at(result, 2), 10.0, 0.001
        assert_in_delta Enum.at(result, 3), 10.5, 0.001
        assert_in_delta Enum.at(result, 4), 10.0, 0.001
        assert_in_delta Enum.at(result, 5), 9.0, 0.001
        assert_in_delta Enum.at(result, 6), 8.5, 0.001
        assert_in_delta Enum.at(result, 7), 9.0, 0.001
      end

      test "raises for period=1" do
        high = [10.0, 11.0, 12.0]
        low = [8.0, 9.0, 10.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.midprice(high, low, 1)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2"
        end
      end

      test "raises for period=0" do
        high = [10.0, 11.0, 12.0]
        low = [8.0, 9.0, 10.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.midprice(high, low, 0)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2"
        end
      end

      test "raises for negative period" do
        high = [10.0, 11.0, 12.0]
        low = [8.0, 9.0, 10.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.midprice(high, low, -1)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2"
        end
      end

      test "raises for mismatched high/low lengths" do
        high = [10.0, 11.0, 12.0]
        low = [8.0, 9.0]

        assert {:error, reason} = @backend_module.midprice(high, low, 2)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Input arrays must have the same length"
        else
          assert reason =~ "high and low must have the same length"
        end
      end

      if backend_name == :elixir do
        test "raises FunctionClauseError for float period" do
          high = [10.0, 11.0, 12.0]
          low = [8.0, 9.0, 10.0]
          # Elixir backend: FunctionClauseError (no guards)
          assert_raise FunctionClauseError, fn ->
            @backend_module.midprice(high, low, 2.5)
          end
        end
      else
        test "raises ArgumentError for float period" do
          high = [10.0, 11.0, 12.0]
          low = [8.0, 9.0, 10.0]
          # Native backend: ArgumentError (Rustler type conversion)
          assert_raise ArgumentError, fn ->
            @backend_module.midprice(high, low, 2.5)
          end
        end
      end

      test "returns empty for empty input" do
        # Python result: []
        assert {:ok, []} = @backend_module.midprice([], [], 3)
      end

      test "handles insufficient data (period > data length)" do
        high = [10.0, 11.0]
        low = [8.0, 9.0]
        # Python with period=5: [nan nan]
        assert {:ok, result} = @backend_module.midprice(high, low, 5)
        assert result == [nil, nil]
      end

      test "handles period equal to data length" do
        high = [10.0, 11.0, 12.0, 13.0, 14.0]
        low = [8.0, 9.0, 10.0, 11.0, 12.0]
        # Python result: [nan nan nan nan 11.]
        assert {:ok, result} = @backend_module.midprice(high, low, 5)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        assert_in_delta Enum.at(result, 4), 11.0, 0.001
      end
    end

    describe "#{backend_name} - midprice/3 with DataSeries input" do
      test "returns DataSeries with MIDPRICE values in newest-first order" do
        high_ds =
          DataSeries.new()
          |> DataSeries.add(10.0)
          |> DataSeries.add(11.0)
          |> DataSeries.add(12.0)
          |> DataSeries.add(13.0)
          |> DataSeries.add(14.0)

        low_ds =
          DataSeries.new()
          |> DataSeries.add(8.0)
          |> DataSeries.add(9.0)
          |> DataSeries.add(10.0)
          |> DataSeries.add(11.0)
          |> DataSeries.add(12.0)

        assert {:ok, result_ds} = @backend_module.midprice(high_ds, low_ds, 3)
        assert %DataSeries{} = result_ds

        values = DataSeries.values(result_ds)

        # DataSeries stores newest-first: [14.0, 13.0, 12.0, 11.0, 10.0] / [12.0, 11.0, 10.0, 9.0, 8.0]
        # After reversal for calculation: [10.0, 11.0, 12.0, 13.0, 14.0] / [8.0, 9.0, 10.0, 11.0, 12.0]
        # MIDPRICE result (oldest-first): [nil, nil, 10.0, 11.0, 12.0]
        # Reversed back (newest-first): [12.0, 11.0, 10.0, nil, nil]

        assert_in_delta Enum.at(values, 0), 12.0, 0.001
        assert_in_delta Enum.at(values, 1), 11.0, 0.001
        assert_in_delta Enum.at(values, 2), 10.0, 0.001
        assert Enum.at(values, 3) == nil
        assert Enum.at(values, 4) == nil
      end

      test "preserves DataSeries max_size" do
        high_ds = DataSeries.new(max_size: 10)
        high_ds = DataSeries.add(high_ds, 10.0)
        high_ds = DataSeries.add(high_ds, 11.0)
        high_ds = DataSeries.add(high_ds, 12.0)

        low_ds = DataSeries.new(max_size: 10)
        low_ds = DataSeries.add(low_ds, 8.0)
        low_ds = DataSeries.add(low_ds, 9.0)
        low_ds = DataSeries.add(low_ds, 10.0)

        assert {:ok, result_ds} = @backend_module.midprice(high_ds, low_ds, 2)
        assert %DataSeries{max_size: 10} = result_ds
      end

      test "returns empty DataSeries for empty input" do
        high_ds = DataSeries.new()
        low_ds = DataSeries.new()
        # Like Python: empty input → empty output
        assert {:ok, result_ds} = @backend_module.midprice(high_ds, low_ds, 3)
        assert %DataSeries{} = result_ds
        assert DataSeries.values(result_ds) == []
      end
    end

    describe "#{backend_name} - midprice/3 with TimeSeries input" do
      test "returns TimeSeries with MIDPRICE values in newest-first order" do
        base_time = ~U[2024-01-01 00:00:00.000000Z]

        high_ts =
          TimeSeries.new()
          |> TimeSeries.add(DateTime.add(base_time, 0, :second), 10.0)
          |> TimeSeries.add(DateTime.add(base_time, 60, :second), 11.0)
          |> TimeSeries.add(DateTime.add(base_time, 120, :second), 12.0)
          |> TimeSeries.add(DateTime.add(base_time, 180, :second), 13.0)
          |> TimeSeries.add(DateTime.add(base_time, 240, :second), 14.0)

        low_ts =
          TimeSeries.new()
          |> TimeSeries.add(DateTime.add(base_time, 0, :second), 8.0)
          |> TimeSeries.add(DateTime.add(base_time, 60, :second), 9.0)
          |> TimeSeries.add(DateTime.add(base_time, 120, :second), 10.0)
          |> TimeSeries.add(DateTime.add(base_time, 180, :second), 11.0)
          |> TimeSeries.add(DateTime.add(base_time, 240, :second), 12.0)

        assert {:ok, result_ts} = @backend_module.midprice(high_ts, low_ts, 3)
        assert %TimeSeries{} = result_ts

        values = TimeSeries.values(result_ts)
        keys = TimeSeries.keys(result_ts)

        # Same calculation as DataSeries test
        assert_in_delta Enum.at(values, 0), 12.0, 0.001
        assert_in_delta Enum.at(values, 1), 11.0, 0.001
        assert_in_delta Enum.at(values, 2), 10.0, 0.001
        assert Enum.at(values, 3) == nil
        assert Enum.at(values, 4) == nil

        # Keys should be preserved
        assert length(keys) == 5
        assert Enum.all?(keys, &match?(%DateTime{}, &1))
      end

      test "preserves DateTime keys in correct order" do
        high_ts =
          TimeSeries.new()
          |> TimeSeries.add(~U[2024-01-01 09:00:00.000000Z], 100.0)
          |> TimeSeries.add(~U[2024-01-01 09:01:00.000000Z], 101.0)
          |> TimeSeries.add(~U[2024-01-01 09:02:00.000000Z], 102.0)
          |> TimeSeries.add(~U[2024-01-01 09:03:00.000000Z], 103.0)

        low_ts =
          TimeSeries.new()
          |> TimeSeries.add(~U[2024-01-01 09:00:00.000000Z], 98.0)
          |> TimeSeries.add(~U[2024-01-01 09:01:00.000000Z], 99.0)
          |> TimeSeries.add(~U[2024-01-01 09:02:00.000000Z], 100.0)
          |> TimeSeries.add(~U[2024-01-01 09:03:00.000000Z], 101.0)

        original_keys = TimeSeries.keys(high_ts)

        assert {:ok, result_ts} = @backend_module.midprice(high_ts, low_ts, 2)
        result_keys = TimeSeries.keys(result_ts)

        # Keys should be identical
        assert result_keys == original_keys
      end

      test "returns empty TimeSeries for empty input" do
        high_ts = TimeSeries.new()
        low_ts = TimeSeries.new()
        # Like Python: empty input → empty output
        assert {:ok, result_ts} = @backend_module.midprice(high_ts, low_ts, 3)
        assert %TimeSeries{} = result_ts
        assert TimeSeries.values(result_ts) == []
      end
    end
  end

  ## Property-based testing

  describe "property-based testing: Native vs Elixir backends for midprice" do
    @tag :native_backend
    property "Native and Elixir backends produce identical results for lists" do
      check all(
              high <- list_of(float(min: 50.0, max: 150.0), min_length: 2, max_length: 100),
              period <- integer(2..10)
            ) do
        # Ensure we have enough data for the period
        high = if length(high) < period, do: high ++ List.duplicate(100.0, period), else: high
        # Generate low prices that are always less than high
        low = Enum.map(high, fn h -> h - :rand.uniform() * 10.0 end)

        # Test with Native backend directly
        {:ok, native_result} = TheoryCraftTA.Native.Overlap.MIDPRICE.midprice(high, low, period)

        # Test with Elixir backend directly
        {:ok, elixir_result} =
          TheoryCraftTA.Elixir.Overlap.MIDPRICE.midprice(high, low, period)

        # Results should be identical (within floating point precision)
        assert_lists_equal(native_result, elixir_result)
      end
    end

    @tag :native_backend
    property "Native and Elixir backends produce identical results for DataSeries" do
      check all(
              high_values <- list_of(float(min: 50.0, max: 150.0), min_length: 5, max_length: 50),
              period <- integer(2..5)
            ) do
        # Generate low prices that are always less than high
        low_values = Enum.map(high_values, fn h -> h - :rand.uniform() * 10.0 end)

        high_ds =
          Enum.reduce(high_values, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

        low_ds =
          Enum.reduce(low_values, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

        # Test with Native backend directly
        {:ok, native_result_ds} =
          TheoryCraftTA.Native.Overlap.MIDPRICE.midprice(high_ds, low_ds, period)

        native_result = DataSeries.values(native_result_ds)

        # Test with Elixir backend directly
        {:ok, elixir_result_ds} =
          TheoryCraftTA.Elixir.Overlap.MIDPRICE.midprice(high_ds, low_ds, period)

        elixir_result = DataSeries.values(elixir_result_ds)

        assert_lists_equal(native_result, elixir_result)
      end
    end
  end

  ## Private helper functions

  defp assert_lists_equal(list1, list2) do
    assert length(list1) == length(list2)

    Enum.zip(list1, list2)
    |> Enum.each(fn
      {nil, nil} ->
        :ok

      {val1, val2} when is_float(val1) and is_float(val2) ->
        assert_in_delta(val1, val2, 0.0001)

      {val1, val2} ->
        assert val1 == val2
    end)
  end
end
