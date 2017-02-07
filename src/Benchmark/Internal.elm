module Benchmark.Internal exposing (..)

import Benchmark.LowLevel as LowLevel exposing (Error, Operation)
import Benchmark.Stats exposing (Stats)
import Json.Encode as Encode exposing (Value)
import Time exposing (Time)


type Benchmark
    = Benchmark String Operation Status
    | Group String (List Benchmark)
    | Compare String Benchmark Benchmark


{-| The status of a benchmarking run.
-}
type Status
    = ToSize Time
    | Pending Int
    | Complete (Result Error Stats)


benchmark : String -> Operation -> Benchmark
benchmark name operation =
    Benchmark name operation <| ToSize <| 5 * Time.second



-- Serialization


{-| convert a Benchmark to a JSON value
-}
encode : Benchmark -> Value
encode benchmark =
    let
        encodeStatus : Status -> Value
        encodeStatus status =
            case status of
                ToSize time ->
                    Encode.object
                        [ ( "_stage", Encode.string "toSize" )
                        , ( "time", time |> Time.inMilliseconds |> Encode.float )
                        ]

                Pending runs ->
                    Encode.object
                        [ ( "_stage", Encode.string "pending" )
                        , ( "runs", Encode.int runs )
                        ]

                Complete (Err error) ->
                    Encode.object
                        [ ( "_stage", Encode.string "complete" )
                        , ( "_status", Encode.string "error" )
                        , case error of
                            LowLevel.StackOverflow ->
                                ( "message", Encode.string "stack overflow" )

                            LowLevel.UnknownError msg ->
                                ( "message", Encode.string msg )
                        ]

                Complete (Ok stats) ->
                    Encode.object
                        [ ( "_stage", Encode.string "complete" )
                        , ( "_status", Encode.string "success" )
                        , ( "sampleSize", Encode.int stats.sampleSize )
                        , ( "totalRuntime", Encode.float stats.totalRuntime )
                        , ( "meanRuntime", Encode.float stats.meanRuntime )
                        , ( "operationsPerSecond", Encode.int stats.operationsPerSecond )
                        ]
    in
        case benchmark of
            Benchmark name _ status ->
                Encode.object
                    [ ( "_kind", Encode.string "benchmark" )
                    , ( "name", Encode.string name )
                    , ( "status", encodeStatus status )
                    ]

            Compare name a b ->
                Encode.object
                    [ ( "_kind", Encode.string "compare" )
                    , ( "name", Encode.string name )
                    , ( "a", encode a )
                    , ( "b", encode b )
                    ]

            Group name benchmarks ->
                Encode.object
                    [ ( "_kind", Encode.string "group" )
                    , ( "name", Encode.string name )
                    , ( "benchmarks", benchmarks |> List.map encode |> Encode.list )
                    ]
