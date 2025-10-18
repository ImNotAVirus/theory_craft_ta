defmodule TheoryCraftTA.T3Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{DataSeries, TimeSeries}

  doctest TheoryCraftTA.Native.Overlap.T3
  doctest TheoryCraftTA.Elixir.Overlap.T3
  doctest TheoryCraftTA.Native.Overlap.T3State
  doctest TheoryCraftTA.Elixir.Overlap.T3State

  @backends %{
    native: TheoryCraftTA.Native.Overlap.T3,
    elixir: TheoryCraftTA.Elixir.Overlap.T3
  }

  ## Tests for T3 (Triple Exponential Moving Average T3)

  for {backend_name, backend_module} <- @backends do
    @backend_module backend_module

    describe "#{backend_name} - t3/3 with list input" do
      test "returns all nils for [1.0, 2.0, 3.0, 4.0, 5.0] period=3" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        # Python result: [nan nan nan nan nan]
        assert {:ok, result} = @backend_module.t3(data, 3, 0.7)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        assert Enum.at(result, 4) == nil
      end

      test "returns all nils for [1.0, 2.0, 3.0, 4.0, 5.0] period=2" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        # Python result: [nan nan nan nan nan]
        assert {:ok, result} = @backend_module.t3(data, 2, 0.7)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        assert Enum.at(result, 4) == nil
      end

      test "calculates correctly for extended test data with period=2" do
        data = [1.0, 5.0, 3.0, 4.0, 7.0, 3.0, 8.0, 1.0, 4.0, 6.0]

        # Python result with period=2: [nan nan nan nan nan nan 6.33673769 3.68369497 3.39703406 4.80587282]
        assert {:ok, result} = @backend_module.t3(data, 2, 0.7)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        assert Enum.at(result, 4) == nil
        assert Enum.at(result, 5) == nil
        assert_in_delta Enum.at(result, 6), 6.33673769, 0.001
        assert_in_delta Enum.at(result, 7), 3.68369497, 0.001
        assert_in_delta Enum.at(result, 8), 3.39703406, 0.001
        assert_in_delta Enum.at(result, 9), 4.80587282, 0.001
      end

      test "handles period=2 (minimum valid)" do
        data = [1.0, 5.0, 3.0, 4.0, 7.0, 3.0, 8.0, 1.0, 4.0, 6.0]
        # Python result: [nan nan nan nan nan nan 6.33673769 3.68369497 3.39703406 4.80587282]
        assert {:ok, result} = @backend_module.t3(data, 2, 0.7)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        assert Enum.at(result, 4) == nil
        assert Enum.at(result, 5) == nil
        assert_in_delta Enum.at(result, 6), 6.33673769, 0.001
        assert_in_delta Enum.at(result, 7), 3.68369497, 0.001
        assert_in_delta Enum.at(result, 8), 3.39703406, 0.001
        assert_in_delta Enum.at(result, 9), 4.80587282, 0.001
      end

      test "raises for period=1" do
        data = [1.0, 2.0, 3.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.t3(data, 1, 0.7)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for T3"
        end
      end

      test "raises for period=0" do
        data = [1.0, 2.0, 3.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.t3(data, 0, 0.7)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for T3"
        end
      end

      test "raises for negative period" do
        data = [1.0, 2.0, 3.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.t3(data, -1, 0.7)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for T3"
        end
      end

      if backend_name == :elixir do
        test "raises FunctionClauseError for float period" do
          data = [1.0, 2.0, 3.0]
          # Elixir backend: FunctionClauseError (no guards)
          assert_raise FunctionClauseError, fn ->
            @backend_module.t3(data, 2.5, 0.7)
          end
        end
      else
        test "raises ArgumentError for float period" do
          data = [1.0, 2.0, 3.0]
          # Native backend: ArgumentError (Rustler type conversion)
          assert_raise ArgumentError, fn ->
            @backend_module.t3(data, 2.5, 0.7)
          end
        end
      end

      test "returns empty for empty input" do
        # Python result: []
        assert {:ok, []} = @backend_module.t3([], 3, 0.7)
      end

      test "handles insufficient data (period > data length)" do
        data = [1.0, 2.0]
        # Python with period=5: [nan nan]
        assert {:ok, result} = @backend_module.t3(data, 5, 0.7)
        assert result == [nil, nil]
      end

      test "handles period equal to data length" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        # T3 has unstable period, all nils
        assert {:ok, result} = @backend_module.t3(data, 5, 0.7)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        assert Enum.at(result, 4) == nil
      end
    end

    describe "#{backend_name} - t3/3 with DataSeries input" do
      test "returns DataSeries with T3 values in newest-first order" do
        ds =
          DataSeries.new()
          |> DataSeries.add(1.0)
          |> DataSeries.add(5.0)
          |> DataSeries.add(3.0)
          |> DataSeries.add(4.0)
          |> DataSeries.add(7.0)
          |> DataSeries.add(3.0)
          |> DataSeries.add(8.0)
          |> DataSeries.add(1.0)
          |> DataSeries.add(4.0)
          |> DataSeries.add(6.0)

        assert {:ok, result_ds} = @backend_module.t3(ds, 2, 0.7)
        assert %DataSeries{} = result_ds

        values = DataSeries.values(result_ds)

        # DataSeries stores newest-first: [6.0, 4.0, 1.0, 8.0, 3.0, 7.0, 4.0, 3.0, 5.0, 1.0]
        # After reversal for calculation: [1.0, 5.0, 3.0, 4.0, 7.0, 3.0, 8.0, 1.0, 4.0, 6.0]
        # T3 result (oldest-first): [nil, nil, nil, nil, nil, nil, 6.33673769, 3.68369497, 3.39703406, 4.80587282]
        # Reversed back (newest-first): [4.80587282, 3.39703406, 3.68369497, 6.33673769, nil, nil, nil, nil, nil, nil]

        assert_in_delta Enum.at(values, 0), 4.80587282, 0.001
        assert_in_delta Enum.at(values, 1), 3.39703406, 0.001
        assert_in_delta Enum.at(values, 2), 3.68369497, 0.001
        assert_in_delta Enum.at(values, 3), 6.33673769, 0.001
        assert Enum.at(values, 4) == nil
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

        assert {:ok, result_ds} = @backend_module.t3(ds, 2, 0.7)
        assert %DataSeries{max_size: 10} = result_ds
      end

      test "returns empty DataSeries for empty input" do
        ds = DataSeries.new()
        # Like Python: empty input → empty output
        assert {:ok, result_ds} = @backend_module.t3(ds, 3, 0.7)
        assert %DataSeries{} = result_ds
        assert DataSeries.values(result_ds) == []
      end
    end

    describe "#{backend_name} - t3/3 with TimeSeries input" do
      test "returns TimeSeries with T3 values in newest-first order" do
        base_time = ~U[2024-01-01 00:00:00.000000Z]

        ts =
          TimeSeries.new()
          |> TimeSeries.add(DateTime.add(base_time, 0, :second), 1.0)
          |> TimeSeries.add(DateTime.add(base_time, 60, :second), 5.0)
          |> TimeSeries.add(DateTime.add(base_time, 120, :second), 3.0)
          |> TimeSeries.add(DateTime.add(base_time, 180, :second), 4.0)
          |> TimeSeries.add(DateTime.add(base_time, 240, :second), 7.0)
          |> TimeSeries.add(DateTime.add(base_time, 300, :second), 3.0)
          |> TimeSeries.add(DateTime.add(base_time, 360, :second), 8.0)
          |> TimeSeries.add(DateTime.add(base_time, 420, :second), 1.0)
          |> TimeSeries.add(DateTime.add(base_time, 480, :second), 4.0)
          |> TimeSeries.add(DateTime.add(base_time, 540, :second), 6.0)

        assert {:ok, result_ts} = @backend_module.t3(ts, 2, 0.7)
        assert %TimeSeries{} = result_ts

        values = TimeSeries.values(result_ts)
        keys = TimeSeries.keys(result_ts)

        # Same calculation as DataSeries test
        assert_in_delta Enum.at(values, 0), 4.80587282, 0.001
        assert_in_delta Enum.at(values, 1), 3.39703406, 0.001
        assert_in_delta Enum.at(values, 2), 3.68369497, 0.001
        assert_in_delta Enum.at(values, 3), 6.33673769, 0.001
        assert Enum.at(values, 4) == nil
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

        assert {:ok, result_ts} = @backend_module.t3(ts, 2, 0.7)
        result_keys = TimeSeries.keys(result_ts)

        # Keys should be identical
        assert result_keys == original_keys
      end

      test "returns empty TimeSeries for empty input" do
        ts = TimeSeries.new()
        # Like Python: empty input → empty output
        assert {:ok, result_ts} = @backend_module.t3(ts, 3, 0.7)
        assert %TimeSeries{} = result_ts
        assert TimeSeries.values(result_ts) == []
      end
    end
  end

  ## Property-based testing

  describe "property-based testing: Native vs Elixir backends for t3" do
    @tag :native_backend
    property "Native and Elixir backends produce identical results for lists" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 10, max_length: 100),
              period <- integer(2..10),
              vfactor <- float(min: 0.0, max: 1.0)
            ) do
        # Ensure we have enough data for the period
        data = if length(data) < period, do: data ++ List.duplicate(50.0, period), else: data

        # Test with Native backend directly
        {:ok, native_result} = TheoryCraftTA.Native.Overlap.T3.t3(data, period, vfactor)

        # Test with Elixir backend directly
        {:ok, elixir_result} = TheoryCraftTA.Elixir.Overlap.T3.t3(data, period, vfactor)

        # Results should be identical (within floating point precision)
        assert_lists_equal(native_result, elixir_result)
      end
    end

    @tag :native_backend
    property "Native and Elixir backends produce identical results for DataSeries" do
      check all(
              values <- list_of(float(min: 1.0, max: 1000.0), min_length: 15, max_length: 50),
              period <- integer(2..5),
              vfactor <- float(min: 0.0, max: 1.0)
            ) do
        ds = Enum.reduce(values, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

        # Test with Native backend directly
        {:ok, native_result_ds} = TheoryCraftTA.Native.Overlap.T3.t3(ds, period, vfactor)
        native_result = DataSeries.values(native_result_ds)

        # Test with Elixir backend directly
        {:ok, elixir_result_ds} = TheoryCraftTA.Elixir.Overlap.T3.t3(ds, period, vfactor)
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
