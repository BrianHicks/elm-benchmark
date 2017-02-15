module Benchmark.Internal exposing (..)

import Benchmark.LowLevel as LowLevel exposing (Error, Operation)
import Benchmark.Stats as Stats exposing (Stats)
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
encoder : Benchmark -> Value
encoder benchmark =
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
                        [ ( "_stage", Encode.string "failure" )
                        , case error of
                            LowLevel.StackOverflow ->
                                ( "message", Encode.string "stack overflow" )

                            LowLevel.UnknownError msg ->
                                ( "message", Encode.string msg )
                        ]

                Complete (Ok run) ->
                    Encode.object
                        [ ( "_stage", Encode.string "success" )
                        , ( "sampleSize", Encode.int run.operations )
                        , ( "totalRuntime", Encode.float run.runtime )
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
                    , ( "a", encoder a )
                    , ( "b", encoder b )
                    ]

            Group name benchmarks ->
                Encode.object
                    [ ( "_kind", Encode.string "group" )
                    , ( "name", Encode.string name )
                    , ( "benchmarks", benchmarks |> List.map encoder |> Encode.list )
                    ]
