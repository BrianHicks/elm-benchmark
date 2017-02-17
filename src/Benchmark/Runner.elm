module Benchmark.Runner exposing (BenchmarkProgram, program)

{-| HTML Benchmark Runner

@docs program, BenchmarkProgram
-}

import Benchmark exposing (Benchmark)
import Benchmark.Internal as Internal
import Benchmark.Reporting as Reporting exposing (Report, Stats)
import Html exposing (Html)
import Html.Attributes as A
import Json.Encode as Encode
import List.Extra as List
import Process
import Task exposing (Task)
import Time exposing (Time)


type alias Model =
    { running : Bool
    , benchmark : Benchmark
    }


breakForRender : Task x a -> Task x a
breakForRender task =
    Task.andThen (\_ -> task) (Process.sleep Time.millisecond)


next : Benchmark -> Maybe (Cmd Msg)
next =
    Benchmark.nextTask
        >> Maybe.map breakForRender
        >> Maybe.map (Task.perform Update)


init : Benchmark -> ( Model, Cmd Msg )
init benchmark =
    update
        (Update benchmark)
        { benchmark = benchmark
        , running = True
        }


type Msg
    = Update Benchmark


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Update benchmark ->
            case next benchmark of
                Just cmd ->
                    ( { model
                        | benchmark = benchmark
                        , running = True
                      }
                    , cmd
                    )

                Nothing ->
                    ( { model
                        | benchmark = benchmark
                        , running = False
                      }
                    , Cmd.none
                    )


result : Reporting.Status -> Maybe Stats
result status =
    case status of
        Reporting.Success stats ->
            Just stats

        _ ->
            Nothing


percentChange : Float -> String
percentChange pct =
    pct
        |> (*) 10000
        |> round
        |> toFloat
        |> flip (/) 100
        |> (\i ->
                case compare i 0 of
                    GT ->
                        "+" ++ toString i ++ "%"

                    _ ->
                        toString i ++ "%"
           )


humanizeTime : Time -> String
humanizeTime =
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
        Time.inSeconds >> helper [ "s", "ms", "ns", "µs" ]


humanizeInt : Int -> String
humanizeInt =
    toString
        >> String.reverse
        >> String.toList
        >> List.greedyGroupsOf 3
        >> List.map String.fromList
        >> String.join ","
        >> String.reverse


attrs : List ( String, String ) -> Html msg
attrs list =
    let
        row : ( String, String ) -> Html msg
        row ( caption, value ) =
            Html.tr
                []
                [ Html.th [ A.style [ ( "text-align", "right" ) ] ] [ Html.text caption ]
                , Html.td [] [ Html.text value ]
                ]
    in
        Html.table
            []
            (List.map row list)


name : Report -> String
name benchmark =
    case benchmark of
        Reporting.Benchmark name _ ->
            name

        Reporting.Compare cname a b ->
            cname ++ ": " ++ name a ++ " vs " ++ name b

        Reporting.Group name _ ->
            name


benchmarkView : Report -> Html Msg
benchmarkView benchmark =
    let
        humanizeStatus : Reporting.Status -> String
        humanizeStatus status =
            case status of
                Reporting.ToSize time ->
                    "Needs sizing into " ++ humanizeTime time

                Reporting.Pending runs ->
                    "Waiting for " ++ humanizeInt runs ++ " runs"

                Reporting.Failure error ->
                    "Error: " ++ toString error

                Reporting.Success _ ->
                    "Complete"
    in
        case benchmark of
            Reporting.Benchmark name status ->
                Html.section
                    []
                    [ Html.h1 [] [ Html.text <| "Benchmark: " ++ name ]
                    , case status of
                        Reporting.Success stats ->
                            attrs
                                [ ( "ops/sec", humanizeInt <| Reporting.operationsPerSecond stats )
                                , ( "mean runtime", humanizeTime <| Reporting.meanRuntime stats )
                                , ( "total runtime", humanizeTime <| stats.runtime )
                                , ( "sample size", humanizeInt <| stats.operations )
                                ]

                        _ ->
                            attrs [ ( "status", humanizeStatus status ) ]
                    ]

            Reporting.Compare _ a b ->
                let
                    content =
                        case ( a, b ) of
                            ( Reporting.Benchmark namea statusa, Reporting.Benchmark nameb statusb ) ->
                                Html.div []
                                    [ case ( statusa, statusb ) of
                                        ( Reporting.Success statsa, Reporting.Success statsb ) ->
                                            let
                                                head caption =
                                                    Html.th [] [ Html.text caption ]

                                                rowHead caption =
                                                    Html.th
                                                        [ A.style [ ( "text-align", "right" ) ] ]
                                                        [ Html.text caption ]

                                                cell caption =
                                                    Html.td [] [ Html.text caption ]

                                                table rows =
                                                    Html.table []
                                                        [ Html.thead []
                                                            [ head ""
                                                            , head namea
                                                            , head nameb
                                                            , head "delta"
                                                            ]
                                                        , Html.tbody []
                                                            (rows |> List.map (Html.tr []))
                                                        ]
                                            in
                                                table
                                                    [ [ rowHead "ops/second"
                                                      , cell <| humanizeInt <| Reporting.operationsPerSecond statsa
                                                      , cell <| humanizeInt <| Reporting.operationsPerSecond statsb
                                                      , cell <| percentChange <| Reporting.compareOperationsPerSecond statsb statsa
                                                      ]
                                                    , [ rowHead "mean runtime"
                                                      , cell <| humanizeTime <| Reporting.meanRuntime statsa
                                                      , cell <| humanizeTime <| Reporting.meanRuntime statsb
                                                      , cell <| percentChange <| Reporting.compareMeanRuntime statsb statsa
                                                      ]
                                                    , [ rowHead "total runtime"
                                                      , cell <| humanizeTime statsa.runtime
                                                      , cell <| humanizeTime statsb.runtime
                                                      , cell ""
                                                      ]
                                                    , [ rowHead "sample size"
                                                      , cell <| humanizeInt statsa.operations
                                                      , cell <| humanizeInt statsb.operations
                                                      , cell ""
                                                      ]
                                                    ]

                                        _ ->
                                            Html.table
                                                []
                                                [ Html.tr []
                                                    [ Html.th [] [ Html.text namea ]
                                                    , Html.td [] [ Html.text <| humanizeStatus statusa ]
                                                    ]
                                                , Html.tr []
                                                    [ Html.th [] [ Html.text nameb ]
                                                    , Html.td [] [ Html.text <| humanizeStatus statusb ]
                                                    ]
                                                ]
                                    ]

                            _ ->
                                Html.div
                                    [ A.class "invalid" ]
                                    [ Html.p [] [ Html.text "Sorry, I can't compare these kinds of benchmarks directly." ]
                                    , Html.p [] [ Html.text "Here are the serialized values so you can do it yourself:" ]
                                    , Html.pre
                                        [ A.style
                                            [ ( "background-color", "#EEE" )
                                            , ( "border-radius", "5px" )
                                            , ( "padding", "5px" )
                                            ]
                                        ]
                                        [ Html.code []
                                            [ benchmark
                                                |> Reporting.encoder
                                                |> Encode.encode 2
                                                |> Html.text
                                            ]
                                        ]
                                    ]
                in
                    Html.section
                        []
                        [ Html.h1 [] [ Html.text <| "Comparing " ++ name benchmark ]
                        , content
                        ]

            Reporting.Group name benchmarks ->
                Html.section
                    []
                    [ Html.h1 [] [ Html.text <| "Group: " ++ name ]
                    , Html.ol [] (List.map benchmarkView benchmarks)
                    ]


view : Model -> Html Msg
view model =
    Html.div
        []
        [ Html.p
            []
            [ if model.running then
                Html.text "Benchmark Running"
              else
                Html.text "Benchmark Finished"
            ]
        , model.benchmark
            |> Reporting.fromBenchmark
            |> benchmarkView
        ]


{-| Create a runner program from a benchmark. For example:

    main : BenchmarkProgram
    main =
        Runner.program <|
            Benchmark.group "your benchmarks"
                [ -- your benchmarks here
                ]
-}
program : Benchmark -> BenchmarkProgram
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
