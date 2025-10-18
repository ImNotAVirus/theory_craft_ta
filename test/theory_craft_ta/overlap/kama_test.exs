defmodule TheoryCraftTA.KAMATest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{DataSeries, TimeSeries}

  doctest TheoryCraftTA.Native.Overlap.KAMA
  doctest TheoryCraftTA.Elixir.Overlap.KAMA
  doctest TheoryCraftTA.Native.Overlap.KAMAState
  doctest TheoryCraftTA.Elixir.Overlap.KAMAState

  @backends %{
    native: TheoryCraftTA.Native.Overlap.KAMA,
    elixir: TheoryCraftTA.Elixir.Overlap.KAMA
  }

  ## Tests for KAMA (Kaufman Adaptive Moving Average)

  for {backend_name, backend_module} <- @backends do
    @backend_module backend_module

    describe "#{backend_name} - kama/2 with list input" do
      test "calculates correctly with period=5, ascending data" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]

        # Python result: [nan nan nan nan nan 5.44444444 6.13580247 6.96433471 7.86907484 8.81615269]
        assert {:ok, result} = @backend_module.kama(data, 5)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        assert Enum.at(result, 4) == nil
        assert_in_delta Enum.at(result, 5), 5.44444444, 0.001
        assert_in_delta Enum.at(result, 6), 6.13580247, 0.001
        assert_in_delta Enum.at(result, 7), 6.96433471, 0.001
        assert_in_delta Enum.at(result, 8), 7.86907484, 0.001
        assert_in_delta Enum.at(result, 9), 8.81615269, 0.001
      end

      test "calculates correctly with period=5, descending data" do
        data = [10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0]

        # Python result: [nan nan nan nan nan 5.55555556 4.86419753 4.03566529 3.13092516 2.18384731]
        assert {:ok, result} = @backend_module.kama(data, 5)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        assert Enum.at(result, 4) == nil
        assert_in_delta Enum.at(result, 5), 5.55555556, 0.001
        assert_in_delta Enum.at(result, 6), 4.86419753, 0.001
        assert_in_delta Enum.at(result, 7), 4.03566529, 0.001
        assert_in_delta Enum.at(result, 8), 3.13092516, 0.001
        assert_in_delta Enum.at(result, 9), 2.18384731, 0.001
      end

      test "handles flat data (no volatility)" do
        data = List.duplicate(100.0, 20)
        assert {:ok, result} = @backend_module.kama(data, 10)

        # First 10 values are nil (lookback period)
        for i <- 0..9 do
          assert Enum.at(result, i) == nil
        end

        # After warmup, all values should be 100.0
        for i <- 10..19 do
          assert_in_delta Enum.at(result, i), 100.0, 0.001
        end
      end

      test "handles volatile data" do
        data = [1.0, 5.0, 2.0, 8.0, 3.0, 7.0, 4.0, 6.0, 5.0, 5.5]

        # Python result: [nan nan nan nan nan 3.20928613 3.21615298 3.31137477 3.36913438 3.46122251]
        assert {:ok, result} = @backend_module.kama(data, 5)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        assert Enum.at(result, 4) == nil
        assert_in_delta Enum.at(result, 5), 3.20928613, 0.001
        assert_in_delta Enum.at(result, 6), 3.21615298, 0.001
        assert_in_delta Enum.at(result, 7), 3.31137477, 0.001
        assert_in_delta Enum.at(result, 8), 3.36913438, 0.001
        assert_in_delta Enum.at(result, 9), 3.46122251, 0.001
      end

      test "handles period=2 (minimum valid)" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        assert {:ok, result} = @backend_module.kama(data, 2)

        # KAMA with period 2
        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert is_float(Enum.at(result, 2))
        assert is_float(Enum.at(result, 3))
        assert is_float(Enum.at(result, 4))
      end

      test "raises for period=1" do
        data = [1.0, 2.0, 3.0]
        assert {:error, reason} = @backend_module.kama(data, 1)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for KAMA"
        end
      end

      test "raises for period=0" do
        data = [1.0, 2.0, 3.0]
        assert {:error, reason} = @backend_module.kama(data, 0)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for KAMA"
        end
      end

      test "raises for negative period" do
        data = [1.0, 2.0, 3.0]
        assert {:error, reason} = @backend_module.kama(data, -1)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for KAMA"
        end
      end

      if backend_name == :elixir do
        test "raises FunctionClauseError for float period" do
          data = [1.0, 2.0, 3.0]
          # Elixir backend: FunctionClauseError (no guards)
          assert_raise FunctionClauseError, fn ->
            @backend_module.kama(data, 2.5)
          end
        end
      else
        test "raises ArgumentError for float period" do
          data = [1.0, 2.0, 3.0]
          # Native backend: ArgumentError (Rustler type conversion)
          assert_raise ArgumentError, fn ->
            @backend_module.kama(data, 2.5)
          end
        end
      end

      test "returns empty for empty input" do
        # Python result: []
        assert {:ok, []} = @backend_module.kama([], 5)
      end

      test "handles insufficient data (period > data length)" do
        data = [1.0, 2.0]
        # Python with period=10: [nan nan]
        assert {:ok, result} = @backend_module.kama(data, 10)
        assert result == [nil, nil]
      end

      test "handles period equal to data length" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        assert {:ok, result} = @backend_module.kama(data, 5)

        # All values before last should be nil
        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        # Last value should be calculated
        assert is_float(Enum.at(result, 4))
      end
    end

    describe "#{backend_name} - kama/2 with DataSeries input" do
      test "returns DataSeries with KAMA values in newest-first order" do
        ds =
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

        assert {:ok, result_ds} = @backend_module.kama(ds, 5)
        assert %DataSeries{} = result_ds

        values = DataSeries.values(result_ds)

        # DataSeries stores newest-first: [10.0, 9.0, ..., 1.0]
        # After reversal for calculation: [1.0, 2.0, ..., 10.0]
        # KAMA result (oldest-first): [nil, nil, nil, nil, nil, 5.444..., 6.135..., 6.964..., 7.869..., 8.816...]
        # Reversed back (newest-first): [8.816..., 7.869..., 6.964..., 6.135..., 5.444..., nil, nil, nil, nil, nil]

        assert_in_delta Enum.at(values, 0), 8.81615269, 0.001
        assert_in_delta Enum.at(values, 1), 7.86907484, 0.001
        assert_in_delta Enum.at(values, 2), 6.96433471, 0.001
        assert_in_delta Enum.at(values, 3), 6.13580247, 0.001
        assert_in_delta Enum.at(values, 4), 5.44444444, 0.001
        assert Enum.at(values, 5) == nil
        assert Enum.at(values, 6) == nil
        assert Enum.at(values, 7) == nil
        assert Enum.at(values, 8) == nil
        assert Enum.at(values, 9) == nil
      end

      test "preserves DataSeries max_size" do
        ds = DataSeries.new(max_size: 10)
        ds = DataSeries.add(ds, 1.0)
        ds = DataSeries.add(ds, 2.0)
        ds = DataSeries.add(ds, 3.0)

        assert {:ok, result_ds} = @backend_module.kama(ds, 2)
        assert %DataSeries{max_size: 10} = result_ds
      end

      test "returns empty DataSeries for empty input" do
        ds = DataSeries.new()
        # Like Python: empty input → empty output
        assert {:ok, result_ds} = @backend_module.kama(ds, 5)
        assert %DataSeries{} = result_ds
        assert DataSeries.values(result_ds) == []
      end
    end

    describe "#{backend_name} - kama/2 with TimeSeries input" do
      test "returns TimeSeries with KAMA values in newest-first order" do
        base_time = ~U[2024-01-01 00:00:00.000000Z]

        ts =
          TimeSeries.new()
          |> TimeSeries.add(DateTime.add(base_time, 0, :second), 1.0)
          |> TimeSeries.add(DateTime.add(base_time, 60, :second), 2.0)
          |> TimeSeries.add(DateTime.add(base_time, 120, :second), 3.0)
          |> TimeSeries.add(DateTime.add(base_time, 180, :second), 4.0)
          |> TimeSeries.add(DateTime.add(base_time, 240, :second), 5.0)
          |> TimeSeries.add(DateTime.add(base_time, 300, :second), 6.0)
          |> TimeSeries.add(DateTime.add(base_time, 360, :second), 7.0)
          |> TimeSeries.add(DateTime.add(base_time, 420, :second), 8.0)
          |> TimeSeries.add(DateTime.add(base_time, 480, :second), 9.0)
          |> TimeSeries.add(DateTime.add(base_time, 540, :second), 10.0)

        assert {:ok, result_ts} = @backend_module.kama(ts, 5)
        assert %TimeSeries{} = result_ts

        values = TimeSeries.values(result_ts)
        keys = TimeSeries.keys(result_ts)

        # Same calculation as DataSeries test
        assert_in_delta Enum.at(values, 0), 8.81615269, 0.001
        assert_in_delta Enum.at(values, 1), 7.86907484, 0.001
        assert_in_delta Enum.at(values, 2), 6.96433471, 0.001
        assert_in_delta Enum.at(values, 3), 6.13580247, 0.001
        assert_in_delta Enum.at(values, 4), 5.44444444, 0.001
        assert Enum.at(values, 5) == nil
        assert Enum.at(values, 6) == nil
        assert Enum.at(values, 7) == nil
        assert Enum.at(values, 8) == nil
        assert Enum.at(values, 9) == nil

        # Keys should be preserved
        assert length(keys) == 10
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

        assert {:ok, result_ts} = @backend_module.kama(ts, 2)
        result_keys = TimeSeries.keys(result_ts)

        # Keys should be identical
        assert result_keys == original_keys
      end

      test "returns empty TimeSeries for empty input" do
        ts = TimeSeries.new()
        # Like Python: empty input → empty output
        assert {:ok, result_ts} = @backend_module.kama(ts, 5)
        assert %TimeSeries{} = result_ts
        assert TimeSeries.values(result_ts) == []
      end
    end
  end

  ## Property-based testing

  @tag :native_backend
  describe "property-based testing: Native vs Elixir backends for kama" do
    property "Native and Elixir backends produce identical results for lists" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 100),
              period <- integer(2..10)
            ) do
        # Ensure we have enough data for the period
        data = if length(data) < period, do: data ++ List.duplicate(50.0, period), else: data

        # Test with Native backend directly
        {:ok, native_result} = TheoryCraftTA.Native.Overlap.KAMA.kama(data, period)

        # Test with Elixir backend directly
        {:ok, elixir_result} = TheoryCraftTA.Elixir.Overlap.KAMA.kama(data, period)

        # Results should be identical (within floating point precision)
        assert_lists_equal(native_result, elixir_result)
      end
    end

    property "Native and Elixir backends produce identical results for DataSeries" do
      check all(
              values <- list_of(float(min: 1.0, max: 1000.0), min_length: 5, max_length: 50),
              period <- integer(2..5)
            ) do
        ds = Enum.reduce(values, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

        # Test with Native backend directly
        {:ok, native_result_ds} = TheoryCraftTA.Native.Overlap.KAMA.kama(ds, period)
        native_result = DataSeries.values(native_result_ds)

        # Test with Elixir backend directly
        {:ok, elixir_result_ds} = TheoryCraftTA.Elixir.Overlap.KAMA.kama(ds, period)
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
