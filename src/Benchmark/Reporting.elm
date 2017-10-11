module Benchmark.Reporting
    exposing
        ( Report(..)
        , Stats
        , compareMeanRuntime
        , compareOperationsPerSecond
        , decoder
        , encoder
        , fromBenchmark
        , meanRuntime
        , operationsPerSecond
        , stats
        , totalOperations
        , totalRuntime
        )

{-| Reporting for Benchmarks

@docs Report, Stats, stats

@docs fromBenchmark


# Analysis

@docs totalOperations, totalRuntime

@docs meanRuntime, compareMeanRuntime

@docs operationsPerSecond, compareOperationsPerSecond


# Serialization

@docs encoder, decoder

-}

import Benchmark.Benchmark as Benchmark exposing (Benchmark)
import Benchmark.LowLevel as LowLevel
import Benchmark.Status as Status exposing (Status(..))
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Time exposing (Time)


{-| Reports are the public version of Benchmarks.

Each tag of Report has a name and some other information about the structure of
a benchmarking run.

-}
type Report
    = Single String Status
    | Series String (List ( String, Status ))
    | Group String (List Report)


{-| Stats returned from a successful benchmarking run
-}
type alias Stats =
    { sampleSize : Int
    , samples : List Time
    }


{-| Calculate stats from a sample size and total runtime
-}
stats : Int -> List Time -> Stats
stats =
    Stats


mean : List Float -> Float
mean numbers =
    List.sum numbers / toFloat (List.length numbers)


stddev : List Float -> Float
stddev numbers =
    let
        thisMean =
            mean numbers
    in
    numbers
        |> List.map (\n -> (n - thisMean) ^ 2)
        |> mean
        |> sqrt


{-| total number of samples
-}
totalOperations : Stats -> Int
totalOperations stats =
    stats.sampleSize * List.length stats.samples


{-| total runtime
-}
totalRuntime : Stats -> Time
totalRuntime stats =
    List.sum stats.samples


{-| Calculate mean runtime. The returned value is `(runtime, stddev)`
-}
meanRuntime : Stats -> ( Time, Time )
meanRuntime stats =
    let
        meanStddev =
            stats.samples
                |> List.map (\sample -> sample / toFloat stats.sampleSize)
                |> stddev

        mean =
            totalRuntime stats / toFloat (totalOperations stats)
    in
    ( mean, meanStddev )


{-| Compare mean runtimes, given as a percentage difference of the first to the
second
-}
compareMeanRuntime : Stats -> Stats -> Float
compareMeanRuntime a b =
    (meanRuntime a |> Tuple.first) / (meanRuntime b |> Tuple.first) - 1


{-| Calculate operations per second. The returned value is `(meanOpsPerSec, stddev)`
-}
operationsPerSecond : Stats -> ( Float, Float )
operationsPerSecond stats =
    let
        opsPerSec =
            stats.samples
                |> List.map (\sample -> toFloat stats.sampleSize * (Time.second / sample))
    in
    ( mean opsPerSec, stddev opsPerSec )


{-| Compare operations per second, given as a percentage difference of the first
to the second
-}
compareOperationsPerSecond : Stats -> Stats -> Float
compareOperationsPerSecond a b =
    (operationsPerSecond a |> Tuple.first) / (operationsPerSecond b |> Tuple.first) - 1



-- Interop


{-| Get a report from a Benchmark.
-}
fromBenchmark : Benchmark -> Report
fromBenchmark internal =
    case internal of
        Benchmark.Single benchmark status ->
            Single (LowLevel.name benchmark) status

        Benchmark.Series name benchmarks ->
            benchmarks
                |> List.map (Tuple.mapFirst LowLevel.name)
                |> Series name

        Benchmark.Group name benchmarks ->
            Group name (List.map fromBenchmark benchmarks)


{-| convert a Report to a JSON value
-}
encoder : Report -> Value
encoder report =
    let
        encodeStatus : Status -> Value
        encodeStatus status =
            case status of
                ToSize time ->
                    Encode.object
                        [ ( "_stage", Encode.string "toSize" )
                        , ( "time", time |> Time.inMilliseconds |> Encode.float )
                        ]

                Pending sampleSize time samples ->
                    Encode.object
                        [ ( "_stage", Encode.string "pending" )
                        , ( "sampleSize", Encode.int sampleSize )
                        , ( "time", Encode.float time )
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

                Success sampleSize samples ->
                    Encode.object
                        [ ( "_stage", Encode.string "success" )
                        , ( "sampleSize", Encode.int sampleSize )
                        , ( "samples", Encode.list <| List.map Encode.float samples )
                        ]

        encodeReport : Report -> Value
        encodeReport report =
            case report of
                Single name status ->
                    Encode.object
                        [ ( "_kind", Encode.string "single" )
                        , ( "name", Encode.string name )
                        , ( "status", encodeStatus status )
                        ]

                Series name benchmarks ->
                    Encode.object
                        [ ( "_kind", Encode.string "series" )
                        , ( "name", Encode.string name )
                        , ( "benchmarks"
                          , benchmarks
                                |> List.map
                                    (\( name, status ) ->
                                        Encode.object
                                            [ ( "name", Encode.string name )
                                            , ( "status", encodeStatus status )
                                            ]
                                    )
                                |> Encode.list
                          )
                        ]

                Group name benchmarks ->
                    Encode.object
                        [ ( "_kind", Encode.string "group" )
                        , ( "name", Encode.string name )
                        , ( "benchmarks", benchmarks |> List.map encodeReport |> Encode.list )
                        ]
    in
    Encode.object
        [ ( "version", Encode.int 2 )
        , ( "report", encodeReport report )
        ]


{-| parse a Report from a JSON value
-}
decoder : Decoder Report
decoder =
    Decode.field "version" Decode.int
        |> Decode.andThen
            (\version ->
                case version of
                    2 ->
                        Decode.field "report" version2Decoder

                    _ ->
                        Decode.fail <| "I don't know how to decode version " ++ toString version
            )


status : Decoder Status
status =
    let
        inner : String -> Decoder Status
        inner stage =
            case stage of
                "toSize" ->
                    Decode.map ToSize
                        (Decode.field "time" Decode.float)

                "pending" ->
                    Decode.map3 Pending
                        (Decode.field "sampleSize" Decode.int)
                        (Decode.field "time" Decode.float)
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
                    Decode.map2 Success
                        (Decode.field "sampleSize" Decode.int)
                        (Decode.field "samples" <| Decode.list Decode.float)

                _ ->
                    Decode.fail ("I don't know how to decode the \"" ++ stage ++ "\" stage")
    in
    Decode.field "_stage" Decode.string
        |> Decode.andThen inner


version2Decoder : Decoder Report
version2Decoder =
    let
        report : String -> Decoder Report
        report kind =
            case kind of
                "single" ->
                    Decode.map2 Single
                        (Decode.field "name" Decode.string)
                        (Decode.field "status" status)

                "series" ->
                    Decode.map2 Series
                        (Decode.field "name" Decode.string)
                        (Decode.field "benchmarks" <|
                            Decode.list <|
                                Decode.map2 (,)
                                    (Decode.field "name" Decode.string)
                                    (Decode.field "status" status)
                        )

                "group" ->
                    Decode.map2 Group
                        (Decode.field "name" <| Decode.string)
                        (Decode.field "benchmarks" <| Decode.lazy (\_ -> Decode.list version2Decoder))

                _ ->
                    Decode.fail ("I don't know how to decode a \"" ++ kind ++ "\"")
    in
    Decode.field "_kind" Decode.string
        |> Decode.andThen report
