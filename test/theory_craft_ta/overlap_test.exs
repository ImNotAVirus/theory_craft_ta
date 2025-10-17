defmodule TheoryCraftTA.OverlapTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{DataSeries, TimeSeries}

  @backends %{
    native: TheoryCraftTA.Native.Overlap,
    elixir: TheoryCraftTA.Elixir.Overlap
  }

  ## Tests for each backend

  for {backend_name, backend_module} <- @backends do
    @backend_module backend_module

    describe "#{backend_name} - sma/2 with list input" do
      test "calculates correctly with period=3" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        # Python result: [nan nan 2. 3. 4.]
        assert {:ok, result} = @backend_module.sma(data, 3)
        assert result == [nil, nil, 2.0, 3.0, 4.0]
      end

      test "handles period=2 (minimum valid)" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        # Python result: [nan 1.5 2.5 3.5 4.5]
        assert {:ok, result} = @backend_module.sma(data, 2)
        assert result == [nil, 1.5, 2.5, 3.5, 4.5]
      end

      test "raises for period=1" do
        data = [1.0, 2.0, 3.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.sma(data, 1)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for SMA"
        end
      end

      test "raises for period=0" do
        data = [1.0, 2.0, 3.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.sma(data, 0)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for SMA"
        end
      end

      test "raises for negative period" do
        data = [1.0, 2.0, 3.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.sma(data, -1)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for SMA"
        end
      end

      if backend_name == :elixir do
        test "raises FunctionClauseError for float period" do
          data = [1.0, 2.0, 3.0]
          # Elixir backend: FunctionClauseError (no guards)
          assert_raise FunctionClauseError, fn ->
            @backend_module.sma(data, 2.5)
          end
        end
      else
        test "raises ArgumentError for float period" do
          data = [1.0, 2.0, 3.0]
          # Native backend: ArgumentError (Rustler type conversion)
          assert_raise ArgumentError, fn ->
            @backend_module.sma(data, 2.5)
          end
        end
      end

      test "returns empty for empty input" do
        # Python result: []
        assert {:ok, []} = @backend_module.sma([], 3)
      end

      test "handles insufficient data (period > data length)" do
        data = [1.0, 2.0]
        # Python with period=5: [nan nan]
        assert {:ok, result} = @backend_module.sma(data, 5)
        assert result == [nil, nil]
      end

      test "handles period equal to data length" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        # Python result: [nan nan nan nan 3.]
        assert {:ok, result} = @backend_module.sma(data, 5)
        assert result == [nil, nil, nil, nil, 3.0]
      end

      test "calculates correctly for extended test data" do
        data = [1.0, 5.0, 3.0, 4.0, 7.0, 3.0, 8.0, 1.0, 4.0, 6.0]
        # Python result with period=2: [nan 3.0 4.0 3.5 5.5 5.0 5.5 4.5 2.5 5.0]
        assert {:ok, result} = @backend_module.sma(data, 2)

        assert Enum.at(result, 0) == nil
        assert_in_delta Enum.at(result, 1), 3.0, 0.001
        assert_in_delta Enum.at(result, 2), 4.0, 0.001
        assert_in_delta Enum.at(result, 3), 3.5, 0.001
        assert_in_delta Enum.at(result, 4), 5.5, 0.001
        assert_in_delta Enum.at(result, 5), 5.0, 0.001
        assert_in_delta Enum.at(result, 6), 5.5, 0.001
        assert_in_delta Enum.at(result, 7), 4.5, 0.001
        assert_in_delta Enum.at(result, 8), 2.5, 0.001
        assert_in_delta Enum.at(result, 9), 5.0, 0.001
      end
    end

    describe "#{backend_name} - sma/2 with DataSeries input" do
      test "returns DataSeries with SMA values in newest-first order" do
        ds =
          DataSeries.new()
          |> DataSeries.add(1.0)
          |> DataSeries.add(2.0)
          |> DataSeries.add(3.0)
          |> DataSeries.add(4.0)
          |> DataSeries.add(5.0)

        assert {:ok, result_ds} = @backend_module.sma(ds, 3)
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

        assert {:ok, result_ds} = @backend_module.sma(ds, 2)
        assert %DataSeries{max_size: 10} = result_ds
      end

      test "returns empty DataSeries for empty input" do
        ds = DataSeries.new()
        # Like Python: empty input → empty output
        assert {:ok, result_ds} = @backend_module.sma(ds, 3)
        assert %DataSeries{} = result_ds
        assert DataSeries.values(result_ds) == []
      end
    end

    describe "#{backend_name} - sma/2 with TimeSeries input" do
      test "returns TimeSeries with SMA values in newest-first order" do
        base_time = ~U[2024-01-01 00:00:00.000000Z]

        ts =
          TimeSeries.new()
          |> TimeSeries.add(DateTime.add(base_time, 0, :second), 1.0)
          |> TimeSeries.add(DateTime.add(base_time, 60, :second), 2.0)
          |> TimeSeries.add(DateTime.add(base_time, 120, :second), 3.0)
          |> TimeSeries.add(DateTime.add(base_time, 180, :second), 4.0)
          |> TimeSeries.add(DateTime.add(base_time, 240, :second), 5.0)

        assert {:ok, result_ts} = @backend_module.sma(ts, 3)
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

        assert {:ok, result_ts} = @backend_module.sma(ts, 2)
        result_keys = TimeSeries.keys(result_ts)

        # Keys should be identical
        assert result_keys == original_keys
      end

      test "returns empty TimeSeries for empty input" do
        ts = TimeSeries.new()
        # Like Python: empty input → empty output
        assert {:ok, result_ts} = @backend_module.sma(ts, 3)
        assert %TimeSeries{} = result_ts
        assert TimeSeries.values(result_ts) == []
      end
    end
  end

  ## Public API tests (using configured backend)

  describe "TheoryCraftTA.sma/2 - public API" do
    test "delegates to configured backend" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      assert {:ok, result} = TheoryCraftTA.sma(data, 3)

      assert Enum.at(result, 0) == nil
      assert Enum.at(result, 1) == nil
      assert Enum.at(result, 2) == 2.0
      assert Enum.at(result, 3) == 3.0
      assert Enum.at(result, 4) == 4.0
    end
  end

  describe "TheoryCraftTA.sma!/2 - bang version" do
    test "returns result directly on success" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      result = TheoryCraftTA.sma!(data, 3)

      assert is_list(result)
      assert Enum.at(result, 2) == 2.0
    end

    test "raises error for float period" do
      data = [1.0, 2.0, 3.0]

      # Backend-dependent: FunctionClauseError (Elixir) or ArgumentError (Native/Rustler)
      try do
        TheoryCraftTA.sma!(data, 3.5)
        flunk("Expected FunctionClauseError or ArgumentError")
      rescue
        _e in [FunctionClauseError, ArgumentError] -> assert true
      end
    end

    test "raises RuntimeError on invalid period (< 2)" do
      data = [1.0, 2.0, 3.0]
      # TA-Lib requires period >= 2 for SMA
      # Error message depends on configured backend
      assert_raise RuntimeError, ~r/SMA error/, fn ->
        TheoryCraftTA.sma!(data, 1)
      end
    end

    test "works with DataSeries" do
      ds =
        DataSeries.new()
        |> DataSeries.add(1.0)
        |> DataSeries.add(2.0)
        |> DataSeries.add(3.0)
        |> DataSeries.add(4.0)
        |> DataSeries.add(5.0)

      result_ds = TheoryCraftTA.sma!(ds, 3)

      assert %DataSeries{} = result_ds
    end

    test "works with TimeSeries" do
      base_time = ~U[2024-01-01 00:00:00.000000Z]

      ts =
        TimeSeries.new()
        |> TimeSeries.add(DateTime.add(base_time, 0, :second), 1.0)
        |> TimeSeries.add(DateTime.add(base_time, 60, :second), 2.0)
        |> TimeSeries.add(DateTime.add(base_time, 120, :second), 3.0)
        |> TimeSeries.add(DateTime.add(base_time, 180, :second), 4.0)
        |> TimeSeries.add(DateTime.add(base_time, 240, :second), 5.0)

      result_ts = TheoryCraftTA.sma!(ts, 3)

      assert %TimeSeries{} = result_ts
    end
  end

  ## Tests for EMA (Exponential Moving Average)

  for {backend_name, backend_module} <- @backends do
    @backend_module backend_module

    describe "#{backend_name} - ema/2 with list input" do
      test "calculates correctly with period=3" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        # Python result: [nan nan 2. 3. 4.]
        assert {:ok, result} = @backend_module.ema(data, 3)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert_in_delta Enum.at(result, 2), 2.0, 0.001
        assert_in_delta Enum.at(result, 3), 3.0, 0.001
        assert_in_delta Enum.at(result, 4), 4.0, 0.001
      end

      test "handles period=2 (minimum valid)" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        # Python result: [nan 1.5 2.5 3.5 4.5]
        assert {:ok, result} = @backend_module.ema(data, 2)

        assert Enum.at(result, 0) == nil
        assert_in_delta Enum.at(result, 1), 1.5, 0.001
        assert_in_delta Enum.at(result, 2), 2.5, 0.001
        assert_in_delta Enum.at(result, 3), 3.5, 0.001
        assert_in_delta Enum.at(result, 4), 4.5, 0.001
      end

      test "raises for period=1" do
        data = [1.0, 2.0, 3.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.ema(data, 1)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for EMA"
        end
      end

      test "raises for period=0" do
        data = [1.0, 2.0, 3.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.ema(data, 0)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for EMA"
        end
      end

      test "raises for negative period" do
        data = [1.0, 2.0, 3.0]
        # Python raises with error code 2 (BadParam)
        assert {:error, reason} = @backend_module.ema(data, -1)

        # Different error messages per backend
        if unquote(backend_name) == :native do
          assert reason =~ "Invalid parameters"
        else
          assert reason =~ "Invalid period: must be >= 2 for EMA"
        end
      end

      if backend_name == :elixir do
        test "raises FunctionClauseError for float period" do
          data = [1.0, 2.0, 3.0]
          # Elixir backend: FunctionClauseError (no guards)
          assert_raise FunctionClauseError, fn ->
            @backend_module.ema(data, 2.5)
          end
        end
      else
        test "raises ArgumentError for float period" do
          data = [1.0, 2.0, 3.0]
          # Native backend: ArgumentError (Rustler type conversion)
          assert_raise ArgumentError, fn ->
            @backend_module.ema(data, 2.5)
          end
        end
      end

      test "returns empty for empty input" do
        # Python result: []
        assert {:ok, []} = @backend_module.ema([], 3)
      end

      test "handles insufficient data (period > data length)" do
        data = [1.0, 2.0]
        # Python with period=5: [nan nan]
        assert {:ok, result} = @backend_module.ema(data, 5)
        assert result == [nil, nil]
      end

      test "handles period equal to data length" do
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        # Python result: [nan nan nan nan 3.]
        assert {:ok, result} = @backend_module.ema(data, 5)

        assert Enum.at(result, 0) == nil
        assert Enum.at(result, 1) == nil
        assert Enum.at(result, 2) == nil
        assert Enum.at(result, 3) == nil
        assert_in_delta Enum.at(result, 4), 3.0, 0.001
      end

      test "calculates correctly for extended test data" do
        data = [1.0, 5.0, 3.0, 4.0, 7.0, 3.0, 8.0, 1.0, 4.0, 6.0]

        # Python result with period=2: [nan 3.0 3.0 3.666667 5.888889 3.962963 6.654321 2.884774 3.628258 5.209419]
        assert {:ok, result} = @backend_module.ema(data, 2)

        assert Enum.at(result, 0) == nil
        assert_in_delta Enum.at(result, 1), 3.0, 0.001
        assert_in_delta Enum.at(result, 2), 3.0, 0.001
        assert_in_delta Enum.at(result, 3), 3.666667, 0.001
        assert_in_delta Enum.at(result, 4), 5.888889, 0.001
        assert_in_delta Enum.at(result, 5), 3.962963, 0.001
        assert_in_delta Enum.at(result, 6), 6.654321, 0.001
        assert_in_delta Enum.at(result, 7), 2.884774, 0.001
        assert_in_delta Enum.at(result, 8), 3.628258, 0.001
        assert_in_delta Enum.at(result, 9), 5.209419, 0.001
      end
    end

    describe "#{backend_name} - ema/2 with DataSeries input" do
      test "returns DataSeries with EMA values in newest-first order" do
        ds =
          DataSeries.new()
          |> DataSeries.add(1.0)
          |> DataSeries.add(2.0)
          |> DataSeries.add(3.0)
          |> DataSeries.add(4.0)
          |> DataSeries.add(5.0)

        assert {:ok, result_ds} = @backend_module.ema(ds, 3)
        assert %DataSeries{} = result_ds

        values = DataSeries.values(result_ds)

        # DataSeries stores newest-first: [5.0, 4.0, 3.0, 2.0, 1.0]
        # After reversal for calculation: [1.0, 2.0, 3.0, 4.0, 5.0]
        # EMA result (oldest-first): [nil, nil, 2.0, 3.0, 4.0]
        # Reversed back (newest-first): [4.0, 3.0, 2.0, nil, nil]

        assert_in_delta Enum.at(values, 0), 4.0, 0.001
        assert_in_delta Enum.at(values, 1), 3.0, 0.001
        assert_in_delta Enum.at(values, 2), 2.0, 0.001
        assert Enum.at(values, 3) == nil
        assert Enum.at(values, 4) == nil
      end

      test "preserves DataSeries max_size" do
        ds = DataSeries.new(max_size: 10)
        ds = DataSeries.add(ds, 1.0)
        ds = DataSeries.add(ds, 2.0)
        ds = DataSeries.add(ds, 3.0)

        assert {:ok, result_ds} = @backend_module.ema(ds, 2)
        assert %DataSeries{max_size: 10} = result_ds
      end

      test "returns empty DataSeries for empty input" do
        ds = DataSeries.new()
        # Like Python: empty input → empty output
        assert {:ok, result_ds} = @backend_module.ema(ds, 3)
        assert %DataSeries{} = result_ds
        assert DataSeries.values(result_ds) == []
      end
    end

    describe "#{backend_name} - ema/2 with TimeSeries input" do
      test "returns TimeSeries with EMA values in newest-first order" do
        base_time = ~U[2024-01-01 00:00:00.000000Z]

        ts =
          TimeSeries.new()
          |> TimeSeries.add(DateTime.add(base_time, 0, :second), 1.0)
          |> TimeSeries.add(DateTime.add(base_time, 60, :second), 2.0)
          |> TimeSeries.add(DateTime.add(base_time, 120, :second), 3.0)
          |> TimeSeries.add(DateTime.add(base_time, 180, :second), 4.0)
          |> TimeSeries.add(DateTime.add(base_time, 240, :second), 5.0)

        assert {:ok, result_ts} = @backend_module.ema(ts, 3)
        assert %TimeSeries{} = result_ts

        values = TimeSeries.values(result_ts)
        keys = TimeSeries.keys(result_ts)

        # Same calculation as DataSeries test
        assert_in_delta Enum.at(values, 0), 4.0, 0.001
        assert_in_delta Enum.at(values, 1), 3.0, 0.001
        assert_in_delta Enum.at(values, 2), 2.0, 0.001
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

        assert {:ok, result_ts} = @backend_module.ema(ts, 2)
        result_keys = TimeSeries.keys(result_ts)

        # Keys should be identical
        assert result_keys == original_keys
      end

      test "returns empty TimeSeries for empty input" do
        ts = TimeSeries.new()
        # Like Python: empty input → empty output
        assert {:ok, result_ts} = @backend_module.ema(ts, 3)
        assert %TimeSeries{} = result_ts
        assert TimeSeries.values(result_ts) == []
      end
    end
  end

  ## Property-based testing

  describe "property-based testing: Native vs Elixir backends for sma" do
    property "Native and Elixir backends produce identical results for lists" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 100),
              period <- integer(2..10)
            ) do
        # Ensure we have enough data for the period
        data = if length(data) < period, do: data ++ List.duplicate(50.0, period), else: data

        # Test with Native backend directly
        {:ok, native_result} = TheoryCraftTA.Native.Overlap.sma(data, period)

        # Test with Elixir backend directly
        {:ok, elixir_result} = TheoryCraftTA.Elixir.Overlap.sma(data, period)

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
        {:ok, native_result_ds} = TheoryCraftTA.Native.Overlap.sma(ds, period)
        native_result = DataSeries.values(native_result_ds)

        # Test with Elixir backend directly
        {:ok, elixir_result_ds} = TheoryCraftTA.Elixir.Overlap.sma(ds, period)
        elixir_result = DataSeries.values(elixir_result_ds)

        assert_lists_equal(native_result, elixir_result)
      end
    end
  end

  describe "property-based testing: Native vs Elixir backends for ema" do
    property "Native and Elixir backends produce identical results for lists" do
      check all(
              data <- list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 100),
              period <- integer(2..10)
            ) do
        # Ensure we have enough data for the period
        data = if length(data) < period, do: data ++ List.duplicate(50.0, period), else: data

        # Test with Native backend directly
        {:ok, native_result} = TheoryCraftTA.Native.Overlap.ema(data, period)

        # Test with Elixir backend directly
        {:ok, elixir_result} = TheoryCraftTA.Elixir.Overlap.ema(data, period)

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
        {:ok, native_result_ds} = TheoryCraftTA.Native.Overlap.ema(ds, period)
        native_result = DataSeries.values(native_result_ds)

        # Test with Elixir backend directly
        {:ok, elixir_result_ds} = TheoryCraftTA.Elixir.Overlap.ema(ds, period)
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
