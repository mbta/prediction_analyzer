defmodule PredictionAnalyzerWeb.ViewHelpersTest do
  use PredictionAnalyzerWeb.ConnCase, async: true

  alias PredictionAnalyzerWeb.ViewHelpers

  test "button_class/2" do
    assert ViewHelpers.button_class(%{params: %{"filters" => %{"route_id" => "Blue"}}}, "Blue") =~
             "mode-button"

    assert ViewHelpers.button_class(%{params: %{"filters" => %{"route_id" => "Blue"}}}, "Red") =~
             "mode-button"

    assert ViewHelpers.button_class(%{}, "Red") =~ "mode-button"

    assert ViewHelpers.button_class(%{}, "") =~ "mode-button"
  end
end
