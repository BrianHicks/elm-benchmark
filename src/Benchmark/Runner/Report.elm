module Benchmark.Runner.Report exposing (..)

import Benchmark.Reporting as Reporting exposing (Report(..))
import Benchmark.Runner.Text as Text
import Benchmark.Status as Status exposing (Status(..))
import Color
import Element exposing (..)
import Element.Attributes exposing (..)
import Json.Encode as Encode
import Style exposing (..)
import Style.Color as Color
import Style.Font as Font
import Style.Shadow as Shadow
import Style.Sheet as Sheet


view : Report -> Element Class variation msg
view report =
    report
        |> toString
        |> text
        |> List.singleton
        |> (::) (Text.hero TextClass "Benchmark Report")
        |> column Unstyled []


type Class
    = Unstyled
    | TextClass Text.Class


styles : List (Style Class variation)
styles =
    [ style Unstyled []
    , Text.styles
        |> Sheet.map TextClass identity
        |> Sheet.merge
    ]
