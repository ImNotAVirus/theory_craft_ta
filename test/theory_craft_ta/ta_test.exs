defmodule TA.Test do
  use ExUnit.Case, async: true

  require TA

  describe "sma/3" do
    test "with accessor syntax includes source" do
      spec = TA.sma(eurusd[:close], 14, name: "sma14")

      assert spec ==
               {TheoryCraftTA.Overlap.SMA,
                [period: 14, data: "eurusd", source: :close, name: "sma14"]}
    end

    test "without accessor omits source" do
      spec = TA.sma("eurusd", 14, name: "sma14")
      assert spec == {TheoryCraftTA.Overlap.SMA, [period: 14, data: "eurusd", name: "sma14"]}
    end

    test "with variable accessor" do
      spec = TA.sma(eurusd, 14, name: "sma14")
      assert spec == {TheoryCraftTA.Overlap.SMA, [period: 14, data: "eurusd", name: "sma14"]}
    end

    test "additional options are preserved" do
      spec = TA.sma(eurusd[:close], 14, name: "sma14", bar_name: "eurusd_m1")

      assert spec ==
               {TheoryCraftTA.Overlap.SMA,
                [period: 14, data: "eurusd", source: :close, name: "sma14", bar_name: "eurusd_m1"]}
    end

    test "with different source field" do
      spec = TA.sma(eurusd[:high], 14, name: "sma14")

      assert spec ==
               {TheoryCraftTA.Overlap.SMA,
                [period: 14, data: "eurusd", source: :high, name: "sma14"]}
    end
  end

  describe "ema/3" do
    test "with accessor syntax" do
      spec = TA.ema(eurusd[:close], 20, name: "ema20")

      assert spec ==
               {TheoryCraftTA.Overlap.EMA,
                [period: 20, data: "eurusd", source: :close, name: "ema20"]}
    end

    test "without accessor" do
      spec = TA.ema("eurusd", 20, name: "ema20")
      assert spec == {TheoryCraftTA.Overlap.EMA, [period: 20, data: "eurusd", name: "ema20"]}
    end
  end

  describe "wma/3" do
    test "with accessor syntax" do
      spec = TA.wma(eurusd[:close], 10, name: "wma10")

      assert spec ==
               {TheoryCraftTA.Overlap.WMA,
                [period: 10, data: "eurusd", source: :close, name: "wma10"]}
    end
  end

  describe "dema/3" do
    test "with accessor syntax" do
      spec = TA.dema(eurusd[:close], 14, name: "dema14")

      assert spec ==
               {TheoryCraftTA.Overlap.DEMA,
                [period: 14, data: "eurusd", source: :close, name: "dema14"]}
    end
  end

  describe "tema/3" do
    test "with accessor syntax" do
      spec = TA.tema(eurusd[:close], 14, name: "tema14")

      assert spec ==
               {TheoryCraftTA.Overlap.TEMA,
                [period: 14, data: "eurusd", source: :close, name: "tema14"]}
    end
  end

  describe "trima/3" do
    test "with accessor syntax" do
      spec = TA.trima(eurusd[:close], 14, name: "trima14")

      assert spec ==
               {TheoryCraftTA.Overlap.TRIMA,
                [period: 14, data: "eurusd", source: :close, name: "trima14"]}
    end
  end

  describe "midpoint/3" do
    test "with accessor syntax" do
      spec = TA.midpoint(eurusd[:close], 14, name: "midpoint14")

      assert spec ==
               {TheoryCraftTA.Overlap.MIDPOINT,
                [period: 14, data: "eurusd", source: :close, name: "midpoint14"]}
    end
  end

  describe "t3/4" do
    test "with accessor syntax" do
      spec = TA.t3(eurusd[:close], 5, 0.7, name: "t3")

      assert spec ==
               {TheoryCraftTA.Overlap.T3,
                [period: 5, vfactor: 0.7, data: "eurusd", source: :close, name: "t3"]}
    end

    test "without accessor" do
      spec = TA.t3("eurusd", 5, 0.7, name: "t3")

      assert spec ==
               {TheoryCraftTA.Overlap.T3, [period: 5, vfactor: 0.7, data: "eurusd", name: "t3"]}
    end

    test "with additional options" do
      spec = TA.t3(eurusd[:close], 5, 0.7, name: "t3", bar_name: "eurusd_m1")

      assert spec ==
               {TheoryCraftTA.Overlap.T3,
                [
                  period: 5,
                  vfactor: 0.7,
                  data: "eurusd",
                  source: :close,
                  name: "t3",
                  bar_name: "eurusd_m1"
                ]}
    end
  end
end
