defmodule TheoryCraftTA.HT_TRENDLINETest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraft.{DataSeries, TimeSeries}

  doctest TheoryCraftTA.Native.Overlap.HT_TRENDLINE
  doctest TheoryCraftTA.Elixir.Overlap.HT_TRENDLINE
  doctest TheoryCraftTA.Native.Overlap.HT_TRENDLINEState
  doctest TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState

  @backends %{
    native: TheoryCraftTA.Native.Overlap.HT_TRENDLINE,
    elixir: TheoryCraftTA.Elixir.Overlap.HT_TRENDLINE
  }

  ## Tests for HT_TRENDLINE (Hilbert Transform - Instantaneous Trendline)

  for {backend_name, backend_module} <- @backends do
    @backend_module backend_module

    describe "#{backend_name} - ht_trendline/1 with list input" do
      test "calculates correctly with 100 points" do
        data = test_data_100()
        expected = expected_output_100()

        assert {:ok, result} = @backend_module.ht_trendline(data)

        # First 63 values should be nil (lookback period)
        for i <- 0..62 do
          assert Enum.at(result, i) == nil
        end

        # Check valid values (from index 63 onwards)
        for i <- 63..99 do
          assert_in_delta Enum.at(result, i), Enum.at(expected, i), 0.0001
        end
      end

      test "returns all nil for data length < 64" do
        data = Enum.take(test_data_100(), 63)
        assert {:ok, result} = @backend_module.ht_trendline(data)

        # All values should be nil
        assert Enum.all?(result, &(&1 == nil))
      end

      test "returns first valid value at index 63 for exactly 64 points" do
        data = Enum.take(test_data_100(), 64)
        expected = Enum.take(expected_output_100(), 64)

        assert {:ok, result} = @backend_module.ht_trendline(data)

        # First 63 values should be nil
        for i <- 0..62 do
          assert Enum.at(result, i) == nil
        end

        # Index 63 should have the first valid value
        assert_in_delta Enum.at(result, 63), Enum.at(expected, 63), 0.0001
      end

      test "returns empty for empty input" do
        assert {:ok, []} = @backend_module.ht_trendline([])
      end
    end

    describe "#{backend_name} - ht_trendline/1 with DataSeries input" do
      test "returns DataSeries with HT_TRENDLINE values in newest-first order" do
        data = test_data_100()
        expected = expected_output_100()

        ds = Enum.reduce(data, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

        assert {:ok, result_ds} = @backend_module.ht_trendline(ds)
        assert %DataSeries{} = result_ds

        values = DataSeries.values(result_ds)

        # DataSeries stores newest-first, so reverse expected for comparison
        expected_reversed = Enum.reverse(expected)

        for i <- 0..99 do
          if Enum.at(expected_reversed, i) == nil do
            assert Enum.at(values, i) == nil
          else
            assert_in_delta Enum.at(values, i), Enum.at(expected_reversed, i), 0.0001
          end
        end
      end

      test "preserves DataSeries max_size" do
        ds = DataSeries.new(max_size: 10)
        ds = DataSeries.add(ds, 1.0)
        ds = DataSeries.add(ds, 2.0)
        ds = DataSeries.add(ds, 3.0)

        assert {:ok, result_ds} = @backend_module.ht_trendline(ds)
        assert %DataSeries{max_size: 10} = result_ds
      end

      test "returns empty DataSeries for empty input" do
        ds = DataSeries.new()
        assert {:ok, result_ds} = @backend_module.ht_trendline(ds)
        assert %DataSeries{} = result_ds
        assert DataSeries.values(result_ds) == []
      end
    end

    describe "#{backend_name} - ht_trendline/1 with TimeSeries input" do
      test "returns TimeSeries with HT_TRENDLINE values in newest-first order" do
        base_time = ~U[2024-01-01 00:00:00.000000Z]
        data = test_data_100()
        expected = expected_output_100()

        ts =
          data
          |> Enum.with_index()
          |> Enum.reduce(TimeSeries.new(), fn {val, i}, acc ->
            TimeSeries.add(acc, DateTime.add(base_time, i * 60, :second), val)
          end)

        assert {:ok, result_ts} = @backend_module.ht_trendline(ts)
        assert %TimeSeries{} = result_ts

        values = TimeSeries.values(result_ts)
        keys = TimeSeries.keys(result_ts)

        # TimeSeries stores newest-first, so reverse expected for comparison
        expected_reversed = Enum.reverse(expected)

        for i <- 0..99 do
          if Enum.at(expected_reversed, i) == nil do
            assert Enum.at(values, i) == nil
          else
            assert_in_delta Enum.at(values, i), Enum.at(expected_reversed, i), 0.0001
          end
        end

        # Keys should be preserved
        assert length(keys) == 100
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

        assert {:ok, result_ts} = @backend_module.ht_trendline(ts)
        result_keys = TimeSeries.keys(result_ts)

        assert result_keys == original_keys
      end

      test "returns empty TimeSeries for empty input" do
        ts = TimeSeries.new()
        assert {:ok, result_ts} = @backend_module.ht_trendline(ts)
        assert %TimeSeries{} = result_ts
        assert TimeSeries.values(result_ts) == []
      end
    end
  end

  ## Property-based testing

  @tag :native_backend
  describe "property-based testing: Native vs Elixir backends for ht_trendline" do
    property "Native and Elixir backends produce identical results for lists" do
      check all(data <- list_of(float(min: 1.0, max: 1000.0), min_length: 64, max_length: 100)) do
        # Test with Native backend directly
        {:ok, native_result} = TheoryCraftTA.Native.Overlap.HT_TRENDLINE.ht_trendline(data)

        # Test with Elixir backend directly
        {:ok, elixir_result} = TheoryCraftTA.Elixir.Overlap.HT_TRENDLINE.ht_trendline(data)

        # Results should be identical (within floating point precision)
        assert_lists_equal(native_result, elixir_result)
      end
    end

    property "Native and Elixir backends produce identical results for DataSeries" do
      check all(values <- list_of(float(min: 1.0, max: 1000.0), min_length: 64, max_length: 100)) do
        ds = Enum.reduce(values, DataSeries.new(), fn val, acc -> DataSeries.add(acc, val) end)

        # Test with Native backend directly
        {:ok, native_result_ds} = TheoryCraftTA.Native.Overlap.HT_TRENDLINE.ht_trendline(ds)
        native_result = DataSeries.values(native_result_ds)

        # Test with Elixir backend directly
        {:ok, elixir_result_ds} = TheoryCraftTA.Elixir.Overlap.HT_TRENDLINE.ht_trendline(ds)
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

  defp test_data_100 do
    [
      87.45401188473625,
      145.07143064099162,
      123.1993941811405,
      109.86584841970367,
      65.60186404424365,
      65.59945203362027,
      55.80836121681995,
      136.6176145774935,
      110.11150117432088,
      120.80725777960456,
      52.05844942958024,
      146.99098521619942,
      133.24426408004217,
      71.23391106782762,
      68.18249672071006,
      68.34045098534338,
      80.42422429595376,
      102.4756431632238,
      93.19450186421157,
      79.1229140198042,
      111.18528947223794,
      63.94938606520418,
      79.21446485352182,
      86.63618432936917,
      95.6069984217036,
      128.51759613930136,
      69.96737821583598,
      101.42344384136116,
      109.24145688620425,
      54.64504127199977,
      110.75448519014384,
      67.05241236872915,
      56.50515929852795,
      144.88855372533334,
      146.56320330745592,
      130.8397348116461,
      80.46137691733708,
      59.76721140063839,
      118.42330265121569,
      94.01524937396013,
      62.20382348447788,
      99.51769101112703,
      53.43885211152184,
      140.9320402078782,
      75.8779981600017,
      116.2522284353982,
      81.1711076089411,
      102.00680211778108,
      104.67102793432797,
      68.4854455525527,
      146.95846277645586,
      127.51328233611146,
      143.9498941564189,
      139.4827350427649,
      109.78999788110852,
      142.18742350231167,
      58.84925020519195,
      69.59828624191452,
      54.52272889105381,
      82.53303307632643,
      88.8677289689482,
      77.13490317738959,
      132.87375091519294,
      85.67533266935894,
      78.09345096873807,
      104.26960831582485,
      64.09242249747626,
      130.21969807540398,
      57.45506436797708,
      148.68869366005174,
      127.22447692966574,
      69.87156815341724,
      50.55221171236024,
      131.54614284548342,
      120.68573438476172,
      122.90071680409874,
      127.12703466859458,
      57.40446517340904,
      85.84657285442725,
      61.58690595251297,
      136.31034258755935,
      112.3298126827558,
      83.08980248526493,
      56.355835028602364,
      81.09823217156622,
      82.51833220267471,
      122.96061783380641,
      113.75574713552132,
      138.72127425763267,
      97.22149251619493,
      61.95942459383017,
      121.3244787222995,
      126.07850486168974,
      106.12771975694963,
      127.0967179954561,
      99.37955963643907,
      102.2732829381994,
      92.75410183585495,
      52.54191267440952,
      60.78914269933044
    ]
  end

  defp expected_output_100 do
    [
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      101.32768435501472,
      101.02853465846454,
      101.00442474787943,
      100.64500293791914,
      100.11439328556045,
      98.08661209843945,
      95.61825652550883,
      94.39131041501957,
      92.00478305834228,
      90.92615628228899,
      92.41468729163023,
      94.67362417747816,
      97.44772206587577,
      100.48369743948626,
      100.17915029605436,
      99.56777932493758,
      98.25886702665356,
      99.34187017641295,
      100.05971863638804,
      99.85980032465685,
      97.42319323127103,
      94.96120243566449,
      93.79422097478613,
      95.41160541182764,
      96.54694222501236,
      97.80576042968198,
      97.72159855231426,
      95.43997405855006,
      95.631790596181,
      96.66810713489272,
      97.88610776255936,
      99.90287636777062,
      101.90867932786205,
      102.32814124932614,
      102.20218971577938,
      100.44267275536716,
      98.54115001579731
    ]
  end
end
