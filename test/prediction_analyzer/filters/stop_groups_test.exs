defmodule PredictionAnalyzer.Filters.StopGroupsTest do
  use ExUnit.Case, async: true
  alias PredictionAnalyzer.Filters.StopGroups

  describe "expand_groups/1" do
    test "replaces stop group IDs in a list with the matching set of stop IDs" do
      assert StopGroups.expand_groups(~w(stop1 _ashmont_branch stop2)) ==
               ~w(stop1 70085 70086 70087 70088 70089 70090 70091 70092 70093 70094 stop2)
    end
  end

  describe "group_names/0" do
    test "returns a list of group IDs and their friendly names" do
      assert StopGroups.group_names() |> hd() == {"Trunk stops", "_trunk"}
    end
  end
end
