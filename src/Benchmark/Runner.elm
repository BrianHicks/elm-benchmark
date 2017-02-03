module Benchmark.Runner exposing (..)

{-| HTML Benchmark Runner

@docs program, BenchmarkProgram
-}

import Benchmark exposing (Benchmark)
import Html exposing (Html)
import Process
import Task exposing (Task)
import Time


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

                Benchmark.Success ( sampleSize, meanTime ) ->
                    Html.dl []
                        [ Html.dt [] [ Html.text "Operation Size" ]
                        , Html.dd [] [ Html.text <| toString sampleSize ++ " runs" ]
                        , Html.dt [] [ Html.text "Mean Run Time" ]
                        , Html.dd [] [ Html.text <| toString meanTime ++ " ms/run" ]
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
