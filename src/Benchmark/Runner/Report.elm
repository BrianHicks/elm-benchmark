module Benchmark.Runner.Report exposing (..)

import Benchmark.Reporting as Reporting exposing (Report(..))
import Benchmark.Runner.Box as Box
import Benchmark.Runner.Humanize as Humanize
import Benchmark.Runner.Text as Text
import Benchmark.Samples as Samples
import Benchmark.Status as Status exposing (Status(..))
import Element exposing (..)
import Element.Attributes exposing (..)
import Style exposing (..)
import Style.Font as Font
import Style.Sheet as Sheet
import Time
import Trend.Linear as Trend exposing (Quick, Trend)


view : Report -> Element Class Variation msg
view report =
    report
        |> reports []
        |> (::) (Text.hero TextClass "Benchmark Report")
        |> column Unstyled []


reports : List String -> Report -> List (Element Class Variation msg)
reports reversedParents report =
    case report of
        Single name status ->
            [ singleReport
                (List.reverse reversedParents)
                name
                status
            ]

        Series name statuses ->
            [ text "TODO" ]

        Group name children ->
            children
                |> List.map (reports (name :: reversedParents))
                |> List.concat


singleReport : List String -> String -> Status -> Element Class Variation msg
singleReport parents name status =
    trendFromStatus status
        |> Maybe.map
            (\trend ->
                [ [ header Text "runs / second"
                  , trend
                        |> Trend.line
                        |> flip Trend.predictX Time.second
                        |> floor
                        |> Humanize.int
                        |> cell Text
                  ]
                , [ header Numeric "goodness of fit"
                  , trend
                        |> Trend.goodnessOfFit
                        |> Humanize.percent
                        |> cell Numeric
                  ]
                ]
            )
        |> Maybe.map (report parents name)
        |> Maybe.withDefault empty


report : List String -> String -> List (List (Element Class Variation msg)) -> Element Class Variation msg
report parents name tableContents =
    column Unstyled
        [ paddingTop Box.spaceBetweenSections ]
        [ Text.path TextClass parents
        , column Box
            [ paddingXY Box.barPaddingX Box.barPaddingY
            , width (px 500)
            ]
            [ text name
            , table
                Table
                [ width (percent 100)
                , paddingTop 10
                ]
                tableContents
            ]
        ]


trendFromStatus : Status -> Maybe (Trend Quick)
trendFromStatus status =
    case status of
        Success samples ->
            samples
                |> Samples.points
                |> Trend.quick
                -- TODO: care about Result?
                |> Result.toMaybe

        _ ->
            Nothing


header : Variation -> String -> Element Class Variation msg
header variation caption =
    el Header [ vary variation True ] (text caption)


cell : Variation -> String -> Element Class Variation msg
cell variation contents =
    el Cell [ vary variation True ] (text contents)


type Class
    = Unstyled
    | Box
    | Table
    | Header
    | Cell
    | TextClass Text.Class


type Variation
    = Numeric
    | Text


styles : List (Style Class Variation)
styles =
    [ style Unstyled []
    , style Box Box.style
    , style Table [ prop "font-feature-settings" "'tnum'" ]
    , style Header
        [ Font.bold
        , Font.size 12
        , variation Numeric [ Font.alignRight ]
        , variation Text [ Font.alignLeft ]
        ]
    , style Cell
        [ Font.size 18
        , variation Numeric [ Font.alignRight ]
        , variation Text [ Font.alignLeft ]
        ]
    , Text.styles
        |> Sheet.map TextClass identity
        |> Sheet.merge
    ]
