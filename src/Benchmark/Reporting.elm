module Benchmark.Reporting
    exposing
        ( Report(..)
        , Stats
        , compareMeanRuntime
        , compareOperationsPerSecond
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

-}

import Benchmark.Benchmark as Benchmark exposing (Benchmark)
import Benchmark.Status as Status exposing (Status(..))
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
        Benchmark.Single name _ status ->
            Single name status

        Benchmark.Series name benchmarks ->
            benchmarks
                |> List.map (\( name, _, status ) -> ( name, status ))
                |> Series name

        Benchmark.Group name benchmarks ->
            Group name (List.map fromBenchmark benchmarks)
