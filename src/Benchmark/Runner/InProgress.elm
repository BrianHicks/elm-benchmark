module Benchmark.Runner.InProgress exposing (Class, styles, view)

import Benchmark.Reporting as Reporting exposing (Report)
import Benchmark.Runner.Reporting exposing (Path, paths)
import Element exposing (..)
import Style exposing (..)


view : Report -> Element Class variation msg
view report =
    report
        |> paths
        |> List.map singleProgress
        |> column Unstyled []


singleProgress : Path -> Element Class variation msg
singleProgress path =
    text <| toString path


type Class
    = Unstyled


styles : List (Style Class variation)
styles =
    [ style Unstyled [] ]
