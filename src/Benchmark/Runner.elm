module Benchmark.Runner exposing (program, BenchmarkProgram)

{-| HTML Benchmark Runner

@docs program, BenchmarkProgram
-}

import Benchmark exposing (Benchmark)
import Benchmark.LowLevel exposing (Error)
import Html exposing (Html)


type alias Model =
    Result Error Benchmark


init : Benchmark -> ( Model, Cmd Msg )
init benchmark =
    ( Ok benchmark, Benchmark.run benchmark Finished )


type Msg
    = Finished Model


update : Msg -> Model -> ( Model, Cmd Msg )
update cmd model =
    case cmd of
        Finished new ->
            ( new, Cmd.none )


benchmarkView : Benchmark -> Html Msg
benchmarkView benchmark =
    let
        statusView : String -> Benchmark.Status -> Html Msg
        statusView name status =
            case status of
                Benchmark.NoRunner ->
                    Html.p [] [ Html.text "Runner not set" ]

                Benchmark.Pending _ ->
                    Html.p [] [ Html.text "Pending" ]

                Benchmark.Complete (Err err) ->
                    Html.p [] [ Html.text <| "Benchmark \"" ++ name ++ "\" failed: " ++ toString err ]

                Benchmark.Complete (Ok ( sampleSize, meanTime )) ->
                    Html.dl []
                        [ Html.dt [] [ Html.text "Sample Size" ]
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

            Benchmark.Comparison name a b ->
                Html.section
                    []
                    [ Html.h1 [] [ Html.text <| "Comparison: " ++ name ]
                    , benchmarkView a
                    , benchmarkView b
                    ]

            Benchmark.Suite name benchmarks ->
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
view model =
    case model of
        Ok benchmark ->
            Html.div [] [ benchmarkView benchmark ]

        Err err ->
            Html.p [] [ Html.text <| "Error executing benchmark: " ++ toString err ]


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
