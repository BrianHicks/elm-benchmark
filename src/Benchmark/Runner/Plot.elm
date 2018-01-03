module Benchmark.Runner.Plot exposing (color, plot)

import Benchmark.Samples as Samples
import Html exposing (Html)
import Plot exposing (..)


type alias Class =
    ( List Samples.Point, List Samples.Point )


colors : List String
colors =
    List.range 0 8
        |> List.map ((*) (360 // 10))
        |> List.map ((+) 204)
        |> List.map (flip (%) 360)
        |> List.map (\deg -> "hsl(" ++ toString deg ++ ", 71%, 61%)")


color : Int -> String
color n =
    (n % List.length colors)
        |> flip List.drop colors
        |> List.head
        |> Maybe.withDefault "black"


dimCircleForNthClass : Int -> Samples.Point -> DataPoint msg
dimCircleForNthClass n =
    viewCircle 5 "gray"
        |> dot
        |> uncurry


circleForNthClass : Int -> Samples.Point -> DataPoint msg
circleForNthClass n =
    color n
        |> viewCircle 5
        |> dot
        |> uncurry


series : Series (List Class) msg
series =
    { axis = Plot.normalAxis
    , interpolation = None
    , toDataPoints =
        \points ->
            points
                |> List.indexedMap
                    (\n ( points, outliers ) ->
                        (++)
                            (List.map (circleForNthClass n) points)
                            (List.map (dimCircleForNthClass n) outliers)
                    )
                |> List.concat
    }


plot : List Class -> Html msg
plot points =
    viewSeriesCustom
        { defaultSeriesPlotCustomizations
            | horizontalAxis =
                customAxis <|
                    \summary ->
                        { position = closestToZero
                        , axisLine = Just (simpleLine summary)
                        , ticks =
                            summary
                                |> decentPositions
                                |> remove 0
                                |> List.map simpleTick
                        , labels =
                            summary
                                |> decentPositions
                                |> remove 0
                                |> List.indexedMap (\n label -> ( n % 3 == 0, label ))
                                |> List.filter Tuple.first
                                |> List.map Tuple.second
                                |> List.map simpleLabel
                        , flipAnchor = False
                        }
        }
        [ series ]
        points
