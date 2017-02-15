module Benchmark.Stats
    exposing
        ( Stats
        , stats
        , compareMeanRuntime
        , meanRuntime
        , operationsPerSecond
        , compareOperationsPerSecond
        )

{-| Provide statistics for benchmarks

@docs Stats, stats

# Analysis
@docs meanRuntime, compareMeanRuntime

@docs operationsPerSecond, compareOperationsPerSecond
-}

import Time exposing (Time)


{-| Stats returned from a successful benchmarking stats

TODO: should the types here be exposed?
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
