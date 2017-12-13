module Benchmark.Runner.Report exposing (..)

import Benchmark.Reporting as Reporting exposing (Report(..))
import Benchmark.Runner.Box as Box
import Benchmark.Runner.Text as Text
import Benchmark.Status as Status exposing (Status(..))
import Element exposing (..)
import Element.Attributes exposing (..)
import Style exposing (..)
import Style.Sheet as Sheet


view : Report -> Element Class variation msg
view report =
    report
        |> reports []
        |> (::) (Text.hero TextClass "Benchmark Report")
        |> column Unstyled []


reports : List String -> Report -> List (Element Class variation msg)
reports reversedParents report =
    case report of
        Single name status ->
            [ text "single" ]

        Series name statuses ->
            [ text "TODO" ]

        Group name children ->
            children
                |> List.map (reports (name :: reversedParents))
                |> List.concat


reportWithPath : List String -> List ( String, Status ) -> Element Class variation msg
reportWithPath parents children =
    column Unstyled
        [ paddingTop Box.spaceBetweenSections ]
        (Text.path TextClass parents
            :: List.map (uncurry report) children
        )


report : String -> Status -> Element Class variation msg
report name status =
    column Box
        [ paddingXY Box.barPaddingX Box.barPaddingY
        , width (percent 100)
        ]
        [ text name
        , text <| toString status
        ]


type Class
    = Unstyled
    | Box
    | TextClass Text.Class


styles : List (Style Class variation)
styles =
    [ style Unstyled []
    , Text.styles
        |> Sheet.map TextClass identity
        |> Sheet.merge
    ]
