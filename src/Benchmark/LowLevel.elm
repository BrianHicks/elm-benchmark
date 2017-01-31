module Benchmark.LowLevel
    exposing
        ( Error(..)
        , measure
        , measure1
        , measure2
        , measure3
        , measure4
        , measure5
        , measure6
        , measure7
        , measure8
        , runTimes
        )

{-| Low Level Elm Benchmarking API

This API exposes the raw tasks necessary to create higher-level benchmarking abstractions.

# Error Handling
@docs Error

# Running
@docs measure, measure1, measure2,  measure3, measure4, measure5, measure6, measure7, measure8, runTimes

# Measuring
@docs runTimes
-}

import Native.Benchmark
import Task exposing (Task)
import Time exposing (Time)


{-| -}
type Error
    = StackOverflow
    | UnknownError String


{-| Measure the run time of a function.

High-resolution timing data from these functions comes from the [Performance
API](https://developer.mozilla.org/en-US/docs/Web/API/Performance). If
`performance.now` is unavailble, it will fall back to
[Date](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date).
-}
measure : (() -> a) -> Task Error Time
measure =
    Native.Benchmark.measure


{-| Measure the run time of a function with a single argument.

See docs for [`measure`](#measure).
-}
measure1 : (a -> b) -> a -> Task Error Time
measure1 =
    Native.Benchmark.measure1


{-| Measure the run time of a function with two arguments.

See docs for [`measure`](#measure).
-}
measure2 : (a -> b -> c) -> a -> b -> Task Error Time
measure2 =
    Native.Benchmark.measure2


{-| Measure the run time of a function with three arguments.

See docs for [`measure`](#measure).
-}
measure3 : (a -> b -> c -> d) -> a -> b -> c -> Task Error Time
measure3 =
    Native.Benchmark.measure3


{-| Measure the run time of a function with four arguments.

See docs for [`measure`](#measure).
-}
measure4 : (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Task Error Time
measure4 =
    Native.Benchmark.measure4


{-| Measure the run time of a function with five arguments.

See docs for [`measure`](#measure).
-}
measure5 : (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Task Error Time
measure5 =
    Native.Benchmark.measure5


{-| Measure the run time of a function with six arguments.

See docs for [`measure`](#measure).
-}
measure6 : (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Task Error Time
measure6 =
    Native.Benchmark.measure6


{-| Measure the run time of a function with seven arguments.

See docs for [`measure`](#measure).
-}
measure7 : (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Task Error Time
measure7 =
    Native.Benchmark.measure7


{-| Measure the run time of a function with eight arguments.

See docs for [`measure`](#measure).
-}
measure8 : (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Task Error Time
measure8 =
    Native.Benchmark.measure8


{-| Run a benchmark a specified number of times.
-}
runTimes : Int -> Task Error Time -> Task Error (List Time)
runTimes n benchmark =
    List.range 1 n
        |> List.map (\_ -> benchmark)
        |> Task.sequence
