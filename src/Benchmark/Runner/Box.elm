module Benchmark.Runner.Box exposing (..)

import Color
import Style exposing (..)
import Style.Color as Color
import Style.Font as Font
import Style.Shadow as Shadow


spaceBetweenSections : Float
spaceBetweenSections =
    25


barPaddingX : Float
barPaddingX =
    15


barPaddingY : Float
barPaddingY =
    7


style : List (Property class variation)
style =
    [ Color.background (Color.rgb 248 248 248)
    , Shadow.box
        { offset = ( 0, 1 )
        , size = 0
        , blur = 2
        , color = Color.rgba 15 30 45 0.1
        }
    , Font.size 24
    ]
