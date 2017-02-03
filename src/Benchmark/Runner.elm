module Benchmark.Runner exposing (..)

{-| HTML Benchmark Runner

@docs program, BenchmarkProgram
-}

import Benchmark exposing (Benchmark)
import Html exposing (Html)
import Process
import Task exposing (Task)
import Time exposing (Time)


type alias Model =
    Benchmark


breakForRender : Task x a -> Task x a
breakForRender task =
    Task.andThen (\_ -> task) (Process.sleep Time.millisecond)


next : Benchmark -> Cmd Msg
next =
    Benchmark.nextTask
        >> Maybe.map breakForRender
        >> Maybe.map (Task.perform Update)
        >> Maybe.withDefault Cmd.none


init : Benchmark -> ( Model, Cmd Msg )
init benchmark =
    ( benchmark, next benchmark )


type Msg
    = Update Benchmark


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Update benchmark ->
            ( benchmark, next benchmark )


benchmarkView : Benchmark -> Html Msg
benchmarkView benchmark =
    let
        statusView : String -> Benchmark.Status -> Html Msg
        statusView name status =
            case status of
                Benchmark.ToSize (Benchmark.Timebox time) ->
                    Html.p [] [ Html.text <| "Needs sizing into " ++ toString (Time.inSeconds time) ++ " second(s)" ]

                Benchmark.Pending n ->
                    Html.p [] [ Html.text <| toString n ++ " iterations pending" ]

                Benchmark.Failure err ->
                    Html.p [] [ Html.text <| "Benchmark \"" ++ name ++ "\" failed: " ++ toString err ]

                Benchmark.Success ( sampleSize, totalTime ) ->
                    Html.table []
                        [ Html.thead []
                            [ Html.tr []
                                [ Html.th [] [ Html.text "Operation Size" ]
                                , Html.th [] [ Html.text "Total Run Time" ]
                                , Html.th [] [ Html.text "Mean Run Time" ]
                                ]
                            ]
                        , Html.tbody []
                            [ Html.tr []
                                [ Html.td [] [ Html.text <| toString sampleSize ++ " runs" ]
                                , Html.td [] [ Html.text <| humanFriendlyTime totalTime ]
                                , Html.td [] [ Html.text <| humanFriendlyTime <| totalTime / toFloat sampleSize ]
                                ]
                            ]
                        ]
    in
        case benchmark of
            Benchmark.Benchmark name _ status ->
                Html.section []
                    [ Html.h1 [] [ Html.text <| "Benchmark: " ++ name ]
                    , statusView name status
                    ]

            Benchmark.Group name benchmarks ->
                Html.section
                    []
                    [ Html.h1 [] [ Html.text <| "Suite: " ++ name ]
                    , benchmarks
                        |> List.map
                            (benchmarkView
                                >> (\x -> Html.li [] [ x ])
                            )
                        |> Html.ul []
                    ]

            Benchmark.Compare a b ->
                Html.section
                    []
                    ([ Html.h1 [] [ Html.text <| "Comparison: " ++ Benchmark.name benchmark ]
                     , benchmarkView a
                     , benchmarkView b
                     ]
                        ++ (Benchmark.compareStats a b
                                |> Maybe.map
                                    (\( meana, meanb, diff ) ->
                                        [ Html.table []
                                            [ Html.thead []
                                                [ Html.tr []
                                                    [ Html.th [] [ Html.text <| Benchmark.name a ]
                                                    , Html.th [] [ Html.text <| Benchmark.name b ]
                                                    , Html.th [] [ Html.text "Percent Difference" ]
                                                    ]
                                                ]
                                            , Html.tbody []
                                                [ Html.tr []
                                                    [ Html.td [] [ Html.text <| humanFriendlyTime meana ]
                                                    , Html.td [] [ Html.text <| humanFriendlyTime meanb ]
                                                    , Html.td [] [ Html.text <| percent diff ]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    )
                                |> Maybe.withDefault []
                           )
                    )


percent : Float -> String
percent pct =
    pct
        * 100
        |> round
        |> toFloat
        |> flip (/) 100
        |> toString
        |> flip (++) "%"


humanFriendlyTime : Time -> String
humanFriendlyTime =
    let
        chopToThousandth : Float -> Float
        chopToThousandth =
            (*) 1000 >> round >> toFloat >> flip (/) 1000

        helper : List String -> Float -> String
        helper units time =
            case units of
                unit :: [] ->
                    toString (chopToThousandth time) ++ unit

                unit :: rest ->
                    if time > 1 then
                        toString (chopToThousandth time) ++ unit
                    else
                        helper rest (time * 1000)

                _ ->
                    toString time ++ " of unknown unit"
    in
        helper [ "s", "ns", "µs" ] << Time.inSeconds


view : Model -> Html Msg
view =
    benchmarkView


{-| Create a runner program from a benchmark
-}
program : Benchmark -> Program Never Model Msg
program benchmark =
    Html.program
        { init = init benchmark
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }


{-| -}
type alias BenchmarkProgram =
    Program Never Model Msg
