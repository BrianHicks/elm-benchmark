module Benchmark.Stats
    exposing
        ( Stats
        , run
        , compareMeanRuntime
        , meanRuntime
        , operationsPerSecond
        , compareOperationsPerSecond
        )

{-| Provide statistics for benchmarks

@docs Stats, stats, compare

-}

import Time exposing (Time)


{-| Stats returned from a successful benchmarking run
-}
type alias Stats =
    { operations : Int
    , runtime : Time
    }


{-| Calculate stats from a sample size and total runtime
-}
run : Int -> Time -> Stats
run =
    Stats


meanRuntime : Stats -> Time
meanRuntime run =
    run.runtime / toFloat run.operations


{-| Compare stats from two successful benchmarks.
-}
compareMeanRuntime : Stats -> Stats -> Float
compareMeanRuntime a b =
    meanRuntime a / meanRuntime b - 1


operationsPerSecond : Stats -> Int
operationsPerSecond run =
    toFloat run.operations * (Time.second / run.runtime) |> round


compareOperationsPerSecond : Stats -> Stats -> Float
compareOperationsPerSecond a b =
    (toFloat <| operationsPerSecond a) / (toFloat <| operationsPerSecond b) - 1
