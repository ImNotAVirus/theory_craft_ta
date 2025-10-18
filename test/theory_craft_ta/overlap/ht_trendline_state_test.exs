defmodule TheoryCraftTA.State.HT_TRENDLINETest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @backend TheoryCraftTA.Native.Overlap.HT_TRENDLINEState

  ## Tests

  describe "init/0" do
    test "initializes successfully" do
      assert {:ok, _state} = @backend.init()
    end
  end

  describe "next/3 - APPEND mode" do
    test "returns nil during warmup period (63 bars)" do
      {:ok, state} = @backend.init()

      {_state, results} =
        Enum.reduce(1..63, {state, []}, fn i, {st, res} ->
          {:ok, ht_val, new_state} = @backend.next(st, i * 1.0, true)
          {new_state, [ht_val | res]}
        end)

      results_reversed = Enum.reverse(results)

      for i <- 0..62 do
        assert Enum.at(results_reversed, i) == nil
      end
    end

    test "produces first value at bar 64" do
      {:ok, state} = @backend.init()
      data = test_data_100()

      {_state, result_64} =
        Enum.reduce(Enum.take(data, 64), {state, nil}, fn val, {st, _} ->
          {:ok, ht_val, new_state} = @backend.next(st, val, true)
          {new_state, ht_val}
        end)

      assert result_64 != nil
      assert is_float(result_64)
      assert_in_delta result_64, 102.09667274473497, 0.0001
    end

    test "produces correct values with full dataset" do
      {:ok, state} = @backend.init()
      data = test_data_100()
      expected = expected_output_100()

      {_state, results} =
        Enum.reduce(data, {state, []}, fn val, {st, res} ->
          {:ok, ht_val, new_state} = @backend.next(st, val, true)
          {new_state, [ht_val | res]}
        end)

      results_reversed = Enum.reverse(results)

      for i <- 0..62 do
        assert Enum.at(results_reversed, i) == nil
      end

      for i <- 63..99 do
        expected_val = Enum.at(expected, i)
        actual_val = Enum.at(results_reversed, i)

        if expected_val == nil do
          assert actual_val == nil
        else
          assert_in_delta actual_val, expected_val, 0.0001
        end
      end
    end
  end

  describe "next/3 - UPDATE mode" do
    test "allows updating the last value" do
      {:ok, state} = @backend.init()
      data = test_data_100()

      {state_63, _} =
        Enum.reduce(Enum.take(data, 63), {state, []}, fn val, {st, res} ->
          {:ok, ht_val, new_state} = @backend.next(st, val, true)
          {new_state, [ht_val | res]}
        end)

      {:ok, val1, state_64} = @backend.next(state_63, 100.0, true)
      assert val1 != nil

      {:ok, val2, _state_updated} = @backend.next(state_64, 110.0, false)
      assert val2 != nil
      assert val1 != val2
    end
  end

  @tag :native_backend
  property "state-based produces same results as batch" do
    check all(
            data_length <- integer(64..150),
            data <- list_of(float(min: 10.0, max: 200.0), length: data_length)
          ) do
      {:ok, batch_result} = TheoryCraftTA.Native.Overlap.HT_TRENDLINE.ht_trendline(data)

      {:ok, state} = @backend.init()

      {_state, state_results} =
        Enum.reduce(data, {state, []}, fn val, {st, res} ->
          {:ok, ht_val, new_state} = @backend.next(st, val, true)
          {new_state, [ht_val | res]}
        end)

      state_results_reversed = Enum.reverse(state_results)

      for i <- 0..(length(data) - 1) do
        batch_val = Enum.at(batch_result, i)
        state_val = Enum.at(state_results_reversed, i)

        if batch_val == nil do
          assert state_val == nil
        else
          assert_in_delta state_val, batch_val, 0.0001
        end
      end
    end
  end

  ## Private helper functions

  defp test_data_100 do
    [
      87.454011884736246,
      145.071430640991622,
      123.199394181140505,
      109.865848419703667,
      65.601864044243655,
      65.599452033620267,
      55.808361216819947,
      136.617614577493498,
      110.111501174320878,
      120.807257779604555,
      52.058449429580243,
      146.990985216199419,
      133.244264080042171,
      71.233911067827620,
      68.182496720710063,
      68.340450985343381,
      80.424224295953763,
      102.475643163223793,
      93.194501864211574,
      79.122914019804199,
      86.636184329369172,
      122.690794817988899,
      120.279968687033022,
      91.463668509479379,
      103.878996799717517,
      144.752575021588873,
      75.808631330850512,
      115.488267142559963,
      77.696590753216675,
      77.636038968424356,
      121.612120881769728,
      83.524902647862555,
      110.639296242152152,
      117.410640826351471,
      129.065547391708032,
      117.390632246266282,
      138.999699454308690,
      103.061275099958795,
      125.053275117996891,
      113.098780814499121,
      104.711804210608094,
      117.042717976787685,
      147.799850394493095,
      148.802484409071560,
      96.990104699628968,
      117.551477976550339,
      133.060934787244301,
      133.890043820616001,
      69.876224456542150,
      92.085865012792803,
      142.979164706850664,
      66.933778210881154,
      71.750129561412671,
      109.613528586354748,
      103.859158690531311,
      103.560659192286124,
      79.490326603062928,
      82.475875083607948,
      140.889406960816945,
      125.912783768054798,
      133.797328372039058,
      99.755577679192816,
      87.450086168943027,
      79.270412234912641,
      79.902604849985629,
      101.343586186849109,
      136.775862968722232,
      125.485244596764498,
      124.656720154396892,
      121.516695226721670,
      136.024929983378886,
      84.085636739894960,
      136.939717584098229,
      82.029369605515921,
      136.893066701385127,
      131.766663806880895,
      71.546437287679780,
      105.764680476226929,
      95.900233954942034,
      128.360501524067862,
      72.165888172637892,
      91.073364854789319,
      92.076320764516476,
      99.867392456917435,
      147.233313909123800,
      112.931754529265555,
      125.046450753433536,
      59.674531835802734,
      82.467442712997524,
      61.959424593830171,
      121.324478722299503,
      126.078504861689737,
      106.127719756949631,
      127.096717995456103,
      99.379559636439069,
      102.273282938199401,
      92.754101835854954,
      52.541912674409517,
      60.789142699330441
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
      102.09667274473497,
      101.11843441321821,
      99.58014323546246,
      100.51007170828991,
      102.70348702303735,
      104.83299837219674,
      106.6794856272323,
      108.31509589097641,
      109.49170023415056,
      111.65560498379011,
      111.52203567085758,
      111.4366864166229,
      111.49959948986505,
      110.9979747672202,
      112.6222771248301,
      113.6133871367277,
      113.99493219206529,
      112.02165677199325,
      109.23415717299864,
      105.8757981364731,
      104.26195829685803,
      104.01345082720395,
      105.19766108458109,
      105.87840807913543,
      103.77999133283838,
      102.40179782297075,
      99.91439043010625,
      99.24798284928788,
      100.0618461425931,
      100.0494564587407,
      101.84710854648165,
      103.23260960689215,
      104.41211199857062,
      104.97888848643917,
      102.12192419664667,
      98.30135288824417
    ]
  end
end
