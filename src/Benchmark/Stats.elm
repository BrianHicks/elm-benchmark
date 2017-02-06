module Benchmark.Stats exposing (Stats, stats, compare)

{-| Provide statistics for benchmarks

@docs Stats, stats, compare

-}

import Time exposing (Time)


{-| Stats returned from a successful benchmarking run
-}
type alias Stats =
    { sampleSize : Int
    , totalRuntime : Time
    , meanRuntime : Time
    , operationsPerSecond : Int
    }


{-| Calculate stats from a sample size and total runtime
-}
stats : Int -> Time -> Stats
stats operations runtime =
    { sampleSize = operations
    , totalRuntime = runtime
    , meanRuntime = runtime / toFloat operations
    , operationsPerSecond = (toFloat operations) * (Time.second / runtime) |> round
    }


{-| Compare stats from two successful benchmarks.
-}
compare : Stats -> Stats -> Float
compare a b =
    a.meanRuntime / b.meanRuntime
