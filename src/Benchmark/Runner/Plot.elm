module Benchmark.Runner.Plot exposing (color, plot)

import Html exposing (Html)
import Plot exposing (..)


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


circleForNthClass : Int -> ( Float, Float ) -> DataPoint msg
circleForNthClass n =
    color n
        |> viewCircle 5
        |> dot
        |> uncurry


series : Series (List (List ( Float, Float ))) msg
series =
    { axis = Plot.normalAxis
    , interpolation = None
    , toDataPoints =
        \points ->
            points
                |> List.indexedMap
                    (\n points ->
                        List.map (circleForNthClass n) points
                    )
                |> List.concat
    }


removeLast : List a -> List a
removeLast items =
    case items of
        [] ->
            []

        a :: b :: [] ->
            [ a ]

        a :: bs ->
            a :: removeLast bs


plot : List (List ( Float, Float )) -> Html msg
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
                                |> removeLast
                                |> List.map simpleTick
                        , labels =
                            summary
                                |> decentPositions
                                |> remove 0
                                |> List.indexedMap (\n label -> ( n % 2 == 0, label ))
                                |> List.filter Tuple.first
                                |> List.map Tuple.second
                                |> removeLast
                                |> List.map simpleLabel
                        , flipAnchor = False
                        }
        }
        [ series ]
        points
