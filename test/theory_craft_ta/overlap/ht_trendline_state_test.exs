defmodule TheoryCraftTA.State.HT_TRENDLINETest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState, as: ElixirHT
  alias TheoryCraftTA.Native.Overlap.HT_TRENDLINEState, as: NativeHT

  doctest TheoryCraftTA.Elixir.Overlap.HT_TRENDLINEState
  doctest TheoryCraftTA.Native.Overlap.HT_TRENDLINEState

  @backends [
    {ElixirHT, "Elixir"},
    {NativeHT, "Native"}
  ]

  ## Setup

  describe "init/0" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: initializes successfully" do
        assert {:ok, _state} = @backend.init()
      end
    end

    test "Elixir: initializes with correct default values" do
      assert {:ok, state} = ElixirHT.init()
      assert state.lookback_count == 0
      assert state.buffer == []
    end
  end

  ## Tests

  describe "next/3 - APPEND mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: returns nil during warmup period (63 bars)" do
        {:ok, state} = @backend.init()

        # Process first 63 bars
        {state63, results} =
          Enum.reduce(1..63, {state, []}, fn i, {st, res} ->
            {:ok, ht_val, new_state} = @backend.next(st, i * 1.0, true)
            {new_state, [ht_val | res]}
          end)

        # All 63 values should be nil
        assert Enum.all?(results, &(&1 == nil))

        # 64th bar should produce first value
        {:ok, ht64, _state64} = @backend.next(state63, 64.0, true)
        assert is_float(ht64)
      end

      test "#{name}: calculates HT_TRENDLINE correctly after warmup" do
        {:ok, state} = @backend.init()

        test_data = test_data_100()

        {_final_state, results} =
          Enum.reduce(test_data, {state, []}, fn value, {st, res} ->
            {:ok, ht_val, new_state} = @backend.next(st, value, true)
            {new_state, [ht_val | res]}
          end)

        results = Enum.reverse(results)
        expected = expected_output_100()

        # First 63 should be nil
        for i <- 0..62 do
          assert Enum.at(results, i) == nil
        end

        # After warmup, should match expected values
        for i <- 63..99 do
          assert_in_delta Enum.at(results, i), Enum.at(expected, i), 0.0001
        end
      end
    end
  end

  describe "next/3 - UPDATE mode" do
    for {backend, name} <- @backends do
      @backend backend

      test "#{name}: updates last value in buffer" do
        {:ok, state} = @backend.init()

        test_data = test_data_100()

        # Build state with all 100 values
        {state100, _results} =
          Enum.reduce(test_data, {state, []}, fn value, {st, res} ->
            {:ok, ht_val, new_state} = @backend.next(st, value, true)
            {new_state, [ht_val | res]}
          end)

        # Get baseline value
        {:ok, baseline, _state_check} = @backend.next(state100, 999.0, false)

        # UPDATE mode: replace last value with different value
        {:ok, ht_update1, state101} = @backend.next(state100, 150.0, false)
        assert is_float(ht_update1)

        # Value should change when we update with different value
        {:ok, ht_update2, _state102} = @backend.next(state101, 50.0, false)
        assert is_float(ht_update2)

        # Updates should produce different values (HT is sensitive to last value)
        assert abs(ht_update1 - ht_update2) > 0.01 or
                 abs(ht_update1 - baseline) > 0.01
      end
    end

    test "Elixir: UPDATE mode doesn't increment lookback" do
      {:ok, state} = ElixirHT.init()

      test_data = Enum.take(test_data_100(), 70)

      # Build state
      {state70, _} =
        Enum.reduce(test_data, {state, []}, fn value, {st, res} ->
          {:ok, ht_val, new_state} = ElixirHT.next(st, value, true)
          {new_state, [ht_val | res]}
        end)

      initial_lookback = state70.lookback_count

      {:ok, _ht, state71} = ElixirHT.next(state70, 105.0, false)
      assert state71.lookback_count == initial_lookback

      {:ok, _ht, state72} = ElixirHT.next(state71, 115.0, false)
      assert state72.lookback_count == initial_lookback
    end
  end

  ## Property-based tests

  @tag :native_backend
  describe "property: state-based APPEND matches batch calculation" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: APPEND mode matches batch HT_TRENDLINE" do
        check all(data <- list_of(float(min: 1.0, max: 1000.0), min_length: 70, max_length: 100)) do
          # Calculate batch HT_TRENDLINE
          {:ok, batch_result} = TheoryCraftTA.ht_trendline(data)

          # Calculate with state (APPEND only - each value = new bar)
          {:ok, state} = @backend.init()

          {_final_state, incremental_results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, ht_value, new_state} = @backend.next(st, value, true)
              {new_state, [ht_value | results]}
            end)

          incremental_results = Enum.reverse(incremental_results)

          # Compare results
          assert length(batch_result) == length(incremental_results)

          Enum.zip(batch_result, incremental_results)
          |> Enum.each(fn
            {nil, nil} ->
              :ok

            {batch_val, incr_val} when is_float(batch_val) and is_float(incr_val) ->
              assert_in_delta(batch_val, incr_val, 0.0001)

            _ ->
              flunk("Mismatch in batch vs incremental results")
          end)
        end
      end
    end
  end

  @tag :native_backend
  describe "property: UPDATE mode behaves correctly" do
    for {backend, name} <- @backends do
      @backend backend

      property "#{name}: UPDATE recalculates with replaced last value" do
        check all(
                data <- list_of(float(min: 1.0, max: 1000.0), min_length: 70, max_length: 100),
                update_values <-
                  list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 5)
              ) do
          {:ok, state} = @backend.init()

          # Build state with all data
          {final_state, _results} =
            Enum.reduce(data, {state, []}, fn value, {st, results} ->
              {:ok, ht_value, new_state} = @backend.next(st, value, true)
              {new_state, [ht_value | results]}
            end)

          # Apply multiple UPDATE operations
          {updated_state, update_hts} =
            Enum.reduce(update_values, {final_state, []}, fn value, {st, hts} ->
              {:ok, ht, new_st} = @backend.next(st, value, false)
              {new_st, [ht | hts]}
            end)

          # For Elixir backend, verify lookback didn't change
          if @backend == ElixirHT do
            assert updated_state.lookback_count == final_state.lookback_count
          end

          # All HT values should be valid floats
          assert Enum.all?(update_hts, &is_float/1)
        end
      end
    end
  end

  ## Private helper functions

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
