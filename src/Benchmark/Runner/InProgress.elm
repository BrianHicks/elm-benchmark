module Benchmark.Runner.InProgress exposing (Class, styles, view)

import Benchmark.Reporting as Reporting exposing (Report)
import Benchmark.Runner.Reporting exposing (Path, paths)
import Benchmark.Runner.Text as Text
import Element exposing (..)
import Element.Attributes exposing (..)
import Style exposing (..)
import Style.Sheet as Sheet


view : Report -> Element Class variation msg
view report =
    report
        |> paths
        |> List.map singleProgress
        |> (::) (Text.hero TextClass "Benchmarks Running")
        |> column Unstyled []


singleProgress : Path -> Element Class variation msg
singleProgress path =
    text <| toString path


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
