defmodule TheoryCraftTATest do
  use ExUnit.Case
  doctest TheoryCraftTA

  test "greets the world" do
    assert TheoryCraftTA.hello() == :world
  end
end
