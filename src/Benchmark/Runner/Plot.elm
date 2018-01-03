module Benchmark.Runner.Plot exposing (color, plot, toCss)

import Benchmark.Samples as Samples
import Color exposing (Color)
import Html exposing (Html)
import Plot exposing (..)


type alias Class =
    ( List Samples.Point, List Samples.Point )


colors : List Color
colors =
    List.range 0 8
        |> List.map ((*) (360 // 10))
        |> List.map ((+) 204)
        |> List.map (flip (%) 360)
        |> List.map (\deg -> Color.hsl (degrees <| toFloat deg) 0.71 0.61)


dim : Color -> Color
dim color =
    let
        { hue, saturation, lightness } =
            Color.toHsl color
    in
    Color.hsla hue saturation lightness 0.5


toCss : Color -> String
toCss color =
    let
        { hue, saturation, lightness, alpha } =
            Color.toHsl color
    in
    "hsla("
        ++ toString (hue * (180 / pi))
        ++ ","
        ++ toString (saturation * 100)
        ++ "%,"
        ++ toString (lightness * 100)
        ++ "%,"
        ++ toString alpha
        ++ ")"


color : Int -> Color
color n =
    (n % List.length colors)
        |> flip List.drop colors
        |> List.head
        |> Maybe.withDefault Color.black


dimCircleForNthClass : Int -> Samples.Point -> DataPoint msg
dimCircleForNthClass n =
    color n
        |> dim
        |> toCss
        |> viewCircle 4.5
        |> dot
        |> uncurry


circleForNthClass : Int -> Samples.Point -> DataPoint msg
circleForNthClass n =
    color n
        |> toCss
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
