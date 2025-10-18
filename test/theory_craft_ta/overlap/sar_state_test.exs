defmodule TheoryCraftTA.SARStateTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  ## Setup

  @moduletag :sar_state
  @moduletag timeout: 120_000

  describe "elixir backend - init" do
    @describetag backend: :elixir

    setup do
      Application.put_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Elixir)
      :ok
    end

    test "creates state with default parameters" do
      assert {:ok, state} = TheoryCraftTA.sar_state_init()
      assert state != nil
    end

    test "creates state with custom acceleration and maximum" do
      assert {:ok, state} = TheoryCraftTA.sar_state_init(0.03, 0.25)
      assert state != nil
    end

    test "raises for invalid acceleration (negative)" do
      assert {:error, reason} = TheoryCraftTA.sar_state_init(-0.01, 0.2)
      assert reason =~ "acceleration must be positive"
    end

    test "raises for invalid acceleration (zero)" do
      assert {:error, reason} = TheoryCraftTA.sar_state_init(0.0, 0.2)
      assert reason =~ "acceleration must be positive"
    end

    test "raises for invalid maximum (negative)" do
      assert {:error, reason} = TheoryCraftTA.sar_state_init(0.02, -0.2)
      assert reason =~ "maximum must be positive"
    end

    test "raises for invalid maximum (zero)" do
      assert {:error, reason} = TheoryCraftTA.sar_state_init(0.02, 0.0)
      assert reason =~ "maximum must be positive"
    end

    test "raises for acceleration > maximum" do
      assert {:error, reason} = TheoryCraftTA.sar_state_init(0.25, 0.2)
      assert reason =~ "acceleration must be less than or equal to maximum"
    end
  end

  describe "elixir backend - next/4 (APPEND mode)" do
    @describetag backend: :elixir

    setup do
      Application.put_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Elixir)
      :ok
    end

    test "warmup period returns nil for first bar", %{} do
      {:ok, state} = TheoryCraftTA.sar_state_init()

      {:ok, result, _new_state} = TheoryCraftTA.sar_state_next(state, 10.0, 8.0, true)

      assert result == nil
    end

    test "produces correct SAR values for uptrend in APPEND mode", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

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

      {:ok, state} = TheoryCraftTA.sar_state_init()

      {:ok, results, _final_state} =
        Enum.zip(high, low)
        |> Enum.map_reduce(state, fn {h, l}, st ->
          {:ok, result, new_st} = TheoryCraftTA.sar_state_next(st, h, l, true)
          {result, new_st}
        end)

      assert length(results) == length(expected)

      results
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "produces correct SAR values for downtrend in APPEND mode", %{} do
      high = [19.0, 18.0, 17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0]
      low = [17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0]

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

      {:ok, state} = TheoryCraftTA.sar_state_init()

      {:ok, results, _final_state} =
        Enum.zip(high, low)
        |> Enum.map_reduce(state, fn {h, l}, st ->
          {:ok, result, new_st} = TheoryCraftTA.sar_state_next(st, h, l, true)
          {result, new_st}
        end)

      assert length(results) == length(expected)

      results
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "handles trend reversal correctly in APPEND mode", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 13.5, 12.5, 11.5, 10.5, 9.5]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 11.5, 10.5, 9.5, 8.5, 7.5]

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

      {:ok, state} = TheoryCraftTA.sar_state_init()

      {:ok, results, _final_state} =
        Enum.zip(high, low)
        |> Enum.map_reduce(state, fn {h, l}, st ->
          {:ok, result, new_st} = TheoryCraftTA.sar_state_next(st, h, l, true)
          {result, new_st}
        end)

      assert length(results) == length(expected)

      results
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "works with custom acceleration and maximum in APPEND mode", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

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

      {:ok, state} = TheoryCraftTA.sar_state_init(0.03, 0.25)

      {:ok, results, _final_state} =
        Enum.zip(high, low)
        |> Enum.map_reduce(state, fn {h, l}, st ->
          {:ok, result, new_st} = TheoryCraftTA.sar_state_next(st, h, l, true)
          {result, new_st}
        end)

      assert length(results) == length(expected)

      results
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end
  end

  describe "elixir backend - next/4 (UPDATE mode)" do
    @describetag backend: :elixir

    setup do
      Application.put_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Elixir)
      :ok
    end

    test "UPDATE mode recalculates last value correctly", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0]

      {:ok, state} = TheoryCraftTA.sar_state_init()

      # Build state with APPEND
      {:ok, results, state} =
        Enum.zip(high, low)
        |> Enum.map_reduce(state, fn {h, l}, st ->
          {:ok, result, new_st} = TheoryCraftTA.sar_state_next(st, h, l, true)
          {result, new_st}
        end)

      # Last result from APPEND
      last_result = List.last(results)
      assert_in_delta last_result, 8.944180480000002, 0.0001

      # UPDATE with same values should give same result
      {:ok, updated_result, _new_state} = TheoryCraftTA.sar_state_next(state, 14.0, 12.0, false)
      assert_in_delta updated_result, last_result, 0.0001

      # UPDATE with different values
      {:ok, updated_result2, _new_state2} = TheoryCraftTA.sar_state_next(state, 14.5, 12.5, false)
      # Result should be different
      assert abs(updated_result2 - last_result) > 0.0001
    end
  end

  describe "native backend - init" do
    @describetag backend: :native
    @describetag :native_backend

    setup do
      Application.put_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Native)
      :ok
    end

    test "creates state with default parameters" do
      assert {:ok, state} = TheoryCraftTA.sar_state_init()
      assert state != nil
    end

    test "creates state with custom acceleration and maximum" do
      assert {:ok, state} = TheoryCraftTA.sar_state_init(0.03, 0.25)
      assert state != nil
    end

    test "raises for invalid acceleration (negative)" do
      assert {:error, reason} = TheoryCraftTA.sar_state_init(-0.01, 0.2)
      assert reason =~ "acceleration must be positive"
    end

    test "raises for invalid acceleration (zero)" do
      assert {:error, reason} = TheoryCraftTA.sar_state_init(0.0, 0.2)
      assert reason =~ "acceleration must be positive"
    end

    test "raises for invalid maximum (negative)" do
      assert {:error, reason} = TheoryCraftTA.sar_state_init(0.02, -0.2)
      assert reason =~ "maximum must be positive"
    end

    test "raises for invalid maximum (zero)" do
      assert {:error, reason} = TheoryCraftTA.sar_state_init(0.02, 0.0)
      assert reason =~ "maximum must be positive"
    end

    test "raises for acceleration > maximum" do
      assert {:error, reason} = TheoryCraftTA.sar_state_init(0.25, 0.2)
      assert reason =~ "acceleration must be less than or equal to maximum"
    end
  end

  describe "native backend - next/4 (APPEND mode)" do
    @describetag backend: :native
    @describetag :native_backend

    setup do
      Application.put_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Native)
      :ok
    end

    test "warmup period returns nil for first bar", %{} do
      {:ok, state} = TheoryCraftTA.sar_state_init()

      {:ok, result, _new_state} = TheoryCraftTA.sar_state_next(state, 10.0, 8.0, true)

      assert result == nil
    end

    test "produces correct SAR values for uptrend in APPEND mode", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

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

      {:ok, state} = TheoryCraftTA.sar_state_init()

      {:ok, results, _final_state} =
        Enum.zip(high, low)
        |> Enum.map_reduce(state, fn {h, l}, st ->
          {:ok, result, new_st} = TheoryCraftTA.sar_state_next(st, h, l, true)
          {result, new_st}
        end)

      assert length(results) == length(expected)

      results
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "produces correct SAR values for downtrend in APPEND mode", %{} do
      high = [19.0, 18.0, 17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0]
      low = [17.0, 16.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 8.0]

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

      {:ok, state} = TheoryCraftTA.sar_state_init()

      {:ok, results, _final_state} =
        Enum.zip(high, low)
        |> Enum.map_reduce(state, fn {h, l}, st ->
          {:ok, result, new_st} = TheoryCraftTA.sar_state_next(st, h, l, true)
          {result, new_st}
        end)

      assert length(results) == length(expected)

      results
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "handles trend reversal correctly in APPEND mode", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 13.5, 12.5, 11.5, 10.5, 9.5]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 11.5, 10.5, 9.5, 8.5, 7.5]

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

      {:ok, state} = TheoryCraftTA.sar_state_init()

      {:ok, results, _final_state} =
        Enum.zip(high, low)
        |> Enum.map_reduce(state, fn {h, l}, st ->
          {:ok, result, new_st} = TheoryCraftTA.sar_state_next(st, h, l, true)
          {result, new_st}
        end)

      assert length(results) == length(expected)

      results
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end

    test "works with custom acceleration and maximum in APPEND mode", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]

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

      {:ok, state} = TheoryCraftTA.sar_state_init(0.03, 0.25)

      {:ok, results, _final_state} =
        Enum.zip(high, low)
        |> Enum.map_reduce(state, fn {h, l}, st ->
          {:ok, result, new_st} = TheoryCraftTA.sar_state_next(st, h, l, true)
          {result, new_st}
        end)

      assert length(results) == length(expected)

      results
      |> Enum.zip(expected)
      |> Enum.each(fn
        {nil, nil} -> :ok
        {val, exp} -> assert_in_delta val, exp, 0.0001
      end)
    end
  end

  describe "native backend - next/4 (UPDATE mode)" do
    @describetag backend: :native
    @describetag :native_backend

    setup do
      Application.put_env(:theory_craft_ta, :default_backend, TheoryCraftTA.Native)
      :ok
    end

    test "UPDATE mode recalculates last value correctly", %{} do
      high = [10.0, 11.0, 12.0, 13.0, 14.0]
      low = [8.0, 9.0, 10.0, 11.0, 12.0]

      {:ok, state} = TheoryCraftTA.sar_state_init()

      # Build state with APPEND
      {:ok, results, state} =
        Enum.zip(high, low)
        |> Enum.map_reduce(state, fn {h, l}, st ->
          {:ok, result, new_st} = TheoryCraftTA.sar_state_next(st, h, l, true)
          {result, new_st}
        end)

      # Last result from APPEND
      last_result = List.last(results)
      assert_in_delta last_result, 8.944180480000002, 0.0001

      # UPDATE with same values should give same result
      {:ok, updated_result, _new_state} = TheoryCraftTA.sar_state_next(state, 14.0, 12.0, false)
      assert_in_delta updated_result, last_result, 0.0001

      # UPDATE with different values
      {:ok, updated_result2, _new_state2} = TheoryCraftTA.sar_state_next(state, 14.5, 12.5, false)
      # Result should be different
      assert abs(updated_result2 - last_result) > 0.0001
    end
  end

  describe "property-based testing: APPEND mode equals batch" do
    @describetag :native_backend

    property "elixir - APPEND mode produces same results as batch" do
      check all(
              high <- list_of(float(min: 100.0, max: 200.0), min_length: 5, max_length: 30),
              low <- list_of(float(min: 50.0, max: 99.0), min_length: 5, max_length: 30),
              acceleration <- float(min: 0.01, max: 0.1),
              maximum <- float(min: 0.1, max: 0.3),
              length(high) == length(low),
              acceleration <= maximum
            ) do
        batch_module = TheoryCraftTA.Elixir.Overlap.SAR
        state_module = TheoryCraftTA.Elixir.Overlap.SARState

        {:ok, batch_result} = batch_module.sar(high, low, acceleration, maximum)

        {:ok, state} = state_module.init(acceleration, maximum)

        {:ok, state_results, _final_state} =
          Enum.zip(high, low)
          |> Enum.map_reduce(state, fn {h, l}, st ->
            {:ok, result, new_st} = state_module.next(st, h, l, true)
            {result, new_st}
          end)

        assert length(batch_result) == length(state_results)

        Enum.zip(batch_result, state_results)
        |> Enum.each(fn
          {nil, nil} ->
            :ok

          {batch_val, state_val} ->
            assert_in_delta batch_val, state_val, 0.0001
        end)
      end
    end

    property "native - APPEND mode produces same results as batch" do
      check all(
              high <- list_of(float(min: 100.0, max: 200.0), min_length: 5, max_length: 30),
              low <- list_of(float(min: 50.0, max: 99.0), min_length: 5, max_length: 30),
              acceleration <- float(min: 0.01, max: 0.1),
              maximum <- float(min: 0.1, max: 0.3),
              length(high) == length(low),
              acceleration <= maximum
            ) do
        batch_module = TheoryCraftTA.Native.Overlap.SAR
        state_module = TheoryCraftTA.Native.Overlap.SARState

        {:ok, batch_result} = batch_module.sar(high, low, acceleration, maximum)

        {:ok, state} = state_module.init(acceleration, maximum)

        {:ok, state_results, _final_state} =
          Enum.zip(high, low)
          |> Enum.map_reduce(state, fn {h, l}, st ->
            {:ok, result, new_st} = state_module.next(st, h, l, true)
            {result, new_st}
          end)

        assert length(batch_result) == length(state_results)

        Enum.zip(batch_result, state_results)
        |> Enum.each(fn
          {nil, nil} ->
            :ok

          {batch_val, state_val} ->
            assert_in_delta batch_val, state_val, 0.0001
        end)
      end
    end
  end
end
