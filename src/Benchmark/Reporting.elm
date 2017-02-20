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
        , decoder
        )

{-| Reporting for Benchmarks

**Hey!**: You probably don't need this module unless you're implementing a runner.
Save yourself some trouble and use one of the existing runners.
TODO: links to those.

@docs Report, Status, Stats, stats

@docs fromBenchmark

# Analysis
@docs meanRuntime, compareMeanRuntime

@docs operationsPerSecond, compareOperationsPerSecond

# Serialization
@docs encoder, decoder
-}

import Benchmark.Internal as Internal
import Benchmark.LowLevel as LowLevel
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Time exposing (Time)


{-| Each tag of Report has a name and some other information about the structure
of a benchmarking run.
-}
type Report
    = Benchmark String Status
    | Group String (List Report)
    | Compare String Report Report


{-| The current status of a single benchmark.
-}
type Status
    = ToSize Time
    | Pending Time Int (List Time)
    | Failure LowLevel.Error
    | Success Stats


{-| Stats returned from a successful benchmarking run
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


{-| Get a report from a Benchmark.
-}
fromBenchmark : Internal.Benchmark -> Report
fromBenchmark internal =
    let
        fromStatus : Internal.Status -> Status
        fromStatus internal =
            case internal of
                Internal.ToSize time ->
                    ToSize time

                Internal.Pending time sampleSize samples ->
                    Pending time sampleSize samples

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

                Pending time sampleSize samples ->
                    Encode.object
                        [ ( "_stage", Encode.string "pending" )
                        , ( "time", Encode.float time )
                        , ( "sampleSize", Encode.int sampleSize )
                        , ( "samples"
                          , samples
                                |> List.map Encode.float
                                |> Encode.list
                          )
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


{-| parse a Report from a JSON value
-}
decoder : Decoder Report
decoder =
    let
        status : String -> Decoder Status
        status stage =
            case stage of
                "toSize" ->
                    Decode.map ToSize
                        (Decode.field "time" Decode.float)

                "pending" ->
                    Decode.map3 Pending
                        (Decode.field "time" Decode.float)
                        (Decode.field "sampleSize" Decode.int)
                        (Decode.field "samples" <| Decode.list Decode.float)

                "failure" ->
                    Decode.field "message" Decode.string
                        |> Decode.andThen
                            (\message ->
                                case message of
                                    "stack overflow" ->
                                        Failure LowLevel.StackOverflow |> Decode.succeed

                                    _ ->
                                        LowLevel.UnknownError message |> Failure |> Decode.succeed
                            )

                "success" ->
                    Decode.map Success <|
                        Decode.map2 stats
                            (Decode.field "sampleSize" Decode.int)
                            (Decode.field "totalRuntime" Decode.float)

                _ ->
                    Decode.fail ("I don't know how to decode the \"" ++ stage ++ "\" stage")

        report : String -> Decoder Report
        report kind =
            case kind of
                "benchmark" ->
                    Decode.map2 Benchmark
                        (Decode.field "name" Decode.string)
                        (Decode.field "status" <|
                            Decode.andThen status <|
                                Decode.field "_stage" Decode.string
                        )

                "compare" ->
                    Decode.map3 Compare
                        (Decode.field "name" Decode.string)
                        (Decode.field "a" <| Decode.lazy (\_ -> decoder))
                        (Decode.field "b" <| Decode.lazy (\_ -> decoder))

                "group" ->
                    Decode.map2 Group
                        (Decode.field "name" <| Decode.string)
                        (Decode.field "benchmarks" <| Decode.lazy (\_ -> Decode.list decoder))

                _ ->
                    Decode.fail ("I don't know how to decode a \"" ++ kind ++ "\"")
    in
        Decode.field "_kind" Decode.string
            |> Decode.andThen report
