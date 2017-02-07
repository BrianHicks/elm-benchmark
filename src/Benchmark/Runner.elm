module Benchmark.Runner exposing (BenchmarkProgram, program)

{-| HTML Benchmark Runner

@docs program, BenchmarkProgram
-}

import Benchmark exposing (Benchmark)
import Benchmark.Internal as Internal
import Benchmark.Stats as Stats exposing (Stats)
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


result : Internal.Status -> Maybe Stats
result status =
    case status of
        Internal.Complete (Ok stats) ->
            Just stats

        _ ->
            Nothing


percent : Float -> String
percent pct =
    pct
        |> flip (-) 1
        |> (*) 10000
        |> round
        |> toFloat
        |> flip (/) 100
        |> toString
        |> flip (++) "%"


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


name : Benchmark -> String
name benchmark =
    case benchmark of
        Internal.Benchmark name _ _ ->
            name

        Internal.Compare cname a b ->
            cname ++ ": " ++ name a ++ " vs " ++ name b

        Internal.Group name _ ->
            name


benchmarkView : Benchmark -> Html Msg
benchmarkView benchmark =
    let
        humanizeStatus : Internal.Status -> String
        humanizeStatus status =
            case status of
                Internal.ToSize time ->
                    "Needs sizing into " ++ humanizeTime time

                Internal.Pending runs ->
                    "Waiting for " ++ humanizeInt runs ++ " runs"

                Internal.Complete (Err error) ->
                    "Error: " ++ toString error

                Internal.Complete (Ok _) ->
                    "Complete"
    in
        case benchmark of
            Internal.Benchmark name _ status ->
                Html.section
                    []
                    [ Html.h1 [] [ Html.text <| "Benchmark: " ++ name ]
                    , case status of
                        Internal.Complete (Ok stats) ->
                            attrs
                                [ ( "sample size", humanizeInt stats.sampleSize )
                                , ( "total runtime", humanizeTime stats.totalRuntime )
                                , ( "mean runtime", humanizeTime stats.meanRuntime )
                                , ( "ops/sec", humanizeInt stats.operationsPerSecond )
                                ]

                        _ ->
                            attrs [ ( "status", humanizeStatus status ) ]
                    ]

            Internal.Compare _ a b ->
                let
                    content =
                        case ( a, b ) of
                            ( Internal.Benchmark namea _ statusa, Internal.Benchmark nameb _ statusb ) ->
                                Html.div []
                                    [ case ( statusa, statusb ) of
                                        ( Internal.Complete (Ok statsa), Internal.Complete (Ok statsb) ) ->
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
                                                    [ [ rowHead "sample size"
                                                      , cell <| humanizeInt statsa.sampleSize
                                                      , cell <| humanizeInt statsb.sampleSize
                                                      , cell ""
                                                      ]
                                                    , [ rowHead "total runtime"
                                                      , cell <| humanizeTime statsa.totalRuntime
                                                      , cell <| humanizeTime statsb.totalRuntime
                                                      , cell ""
                                                      ]
                                                    , [ rowHead "mean runtime"
                                                      , cell <| humanizeTime statsa.meanRuntime
                                                      , cell <| humanizeTime statsb.meanRuntime
                                                      , cell <| percent <| statsa.meanRuntime / statsb.meanRuntime
                                                      ]
                                                    , [ rowHead "ops/second"
                                                      , cell <| humanizeInt statsa.operationsPerSecond
                                                      , cell <| humanizeInt statsb.operationsPerSecond
                                                      , cell <| percent <| toFloat statsa.operationsPerSecond / toFloat statsb.operationsPerSecond
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
                                                |> Internal.encode
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

            Internal.Group name benchmarks ->
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
        , benchmarkView model.benchmark
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
