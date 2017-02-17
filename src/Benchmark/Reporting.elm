module Benchmark.Reporting
    exposing
        ( Report(..)
        , Status(..)
        , Stats
        , stats
        , compareMeanRuntime
        , meanRuntime
        , operationsPerSecond
        , compareOperationsPerSecond
        , fromBenchmark
        , encoder
        )

{-| Provide statistics for benchmarks

@docs Report, Status, Stats, stats

# ???
@docs fromBenchmark

# Analysis
@docs meanRuntime, compareMeanRuntime

@docs operationsPerSecond, compareOperationsPerSecond

# Interop
@docs encoder
-}

import Benchmark.Internal as Internal
import Benchmark.LowLevel as LowLevel
import Json.Encode as Encode exposing (Value)
import Time exposing (Time)


{-| TODO: docs
-}
type Report
    = Benchmark String Status
    | Group String (List Report)
    | Compare String Report Report


{-| TODO: docs
-}
type Status
    = ToSize Time
    | Pending Int
    | Failure LowLevel.Error
    | Success Stats


{-| Stats returned from a successful benchmarking stats
-}
type alias Stats =
    { operations : Int
    , runtime : Time
    }


{-| Calculate stats from a sample size and total runtime
-}
stats : Int -> Time -> Stats
stats =
    Stats


{-| Calculate mean runtime
-}
meanRuntime : Stats -> Time
meanRuntime stats =
    stats.runtime / toFloat stats.operations


{-| Compare mean runtimes, given as a percentage difference of the first to the
second
-}
compareMeanRuntime : Stats -> Stats -> Float
compareMeanRuntime a b =
    meanRuntime a / meanRuntime b - 1


{-| Calculate operations per second
-}
operationsPerSecond : Stats -> Int
operationsPerSecond stats =
    toFloat stats.operations * (Time.second / stats.runtime) |> round


{-| Compare operations per second, given as a percentage difference of the first
to the second
-}
compareOperationsPerSecond : Stats -> Stats -> Float
compareOperationsPerSecond a b =
    (toFloat <| operationsPerSecond a) / (toFloat <| operationsPerSecond b) - 1



-- Interop


{-| TODO: docs
-}
fromBenchmark : Internal.Benchmark -> Report
fromBenchmark internal =
    let
        fromStatus : Internal.Status -> Status
        fromStatus internal =
            case internal of
                Internal.ToSize time ->
                    ToSize time

                Internal.Pending n ->
                    Pending n

                Internal.Failure error ->
                    Failure error

                Internal.Success ( runs, time ) ->
                    Success <| stats runs time
    in
        case internal of
            Internal.Benchmark name _ status ->
                Benchmark name <| fromStatus status

            Internal.Group name benchmarks ->
                Group name <| List.map fromBenchmark benchmarks

            Internal.Compare name a b ->
                Compare name (fromBenchmark a) (fromBenchmark b)


{-| convert a Report to a JSON value
-}
encoder : Report -> Value
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

                Failure error ->
                    Encode.object
                        [ ( "_stage", Encode.string "failure" )
                        , case error of
                            LowLevel.StackOverflow ->
                                ( "message", Encode.string "stack overflow" )

                            LowLevel.UnknownError msg ->
                                ( "message", Encode.string msg )
                        ]

                Success run ->
                    Encode.object
                        [ ( "_stage", Encode.string "success" )
                        , ( "sampleSize", Encode.int run.operations )
                        , ( "totalRuntime", Encode.float run.runtime )
                        ]
    in
        case benchmark of
            Benchmark name status ->
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
