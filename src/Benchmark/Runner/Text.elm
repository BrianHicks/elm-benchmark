module Benchmark.Runner.Text exposing (..)

import Color
import Element exposing (..)
import Element.Attributes exposing (..)
import Style exposing (..)
import Style.Color as Color
import Style.Font as Font exposing (..)


{-| define the base body font style here for consistency's sake
-}
body : List (Property class variation)
body =
    [ typeface
        [ font "Helvetica Neue"
        , font "Helvetica"
        , font "Arial"
        , sansSerif
        ]
    , Color.text (Color.rgb 15 30 45)
    ]


hero : (Class -> class) -> String -> Element class variation msg
hero class caption =
    node "h1" <|
        el (class Hero)
            [ width (percent 100)
            , paddingBottom 20
            ]
            (text caption)


path : (Class -> class) -> List String -> Element class variation msg
path class parts =
    parts
        |> String.join " / "
        |> text
        |> el (class Path) [ paddingBottom 3 ]


type Class
    = Hero
    | Path


styles : List (Style Class variation)
styles =
    [ style Hero
        [ Font.center
        , Font.size 48
        ]
    , style Path
        [ Font.alignLeft
        , Font.size 18
        ]
    ]
