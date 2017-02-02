module Benchmark.LowLevel
    exposing
        ( Error(..)
        , Sample
        , sample
        , sample1
        , sample2
        , sample3
        , sample4
        , sample5
        , sample6
        , sample7
        , sample8
        , takeSamples
        )

{-| Low Level Elm Benchmarking API

This API exposes the raw tasks necessary to create higher-level benchmarking abstractions.

# Error Handling
@docs Error

# Running
@docs Sample, sample, sample1, sample2,  sample3, sample4, sample5, sample6, sample7, sample8, runTimes

# Measuring
@docs runTimes
-}

import Native.Benchmark
import Task exposing (Task)
import Time exposing (Time)


{-| Error states that can terminate a sample.
-}
type Error
    = StackOverflow
    | RunnerNotSet
      -- TODO: move to Benchmark?
    | UnknownError String


type Sample
    = Sample


{-| Measure the run time of a function. This uses Thunks, which come with a
certain amount of runtime overhead. Prefer using `sample1` through `sample8` if
you can; they will give you more accurate results.
-}
sample : (() -> a) -> Sample
sample =
    Native.Benchmark.sample


{-| Create a sample for a function with a single argument.

See docs for [`sample`](#sample).
-}
sample1 : (a -> b) -> a -> Sample
sample1 =
    Native.Benchmark.sample1


{-| Create a sample for a function with two arguments.

See docs for [`sample`](#sample).
-}
sample2 : (a -> b -> c) -> a -> b -> Sample
sample2 =
    Native.Benchmark.sample2


{-| Create a sample for a function with three arguments.

See docs for [`sample`](#sample).
-}
sample3 : (a -> b -> c -> d) -> a -> b -> c -> Sample
sample3 =
    Native.Benchmark.sample3


{-| Create a sample for a function with four arguments.

See docs for [`sample`](#sample).
-}
sample4 : (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Sample
sample4 =
    Native.Benchmark.sample4


{-| Create a sample for a function with five arguments.

See docs for [`sample`](#sample).
-}
sample5 : (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Sample
sample5 =
    Native.Benchmark.sample5


{-| Create a sample for a function with six arguments.

See docs for [`sample`](#sample).
-}
sample6 : (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Sample
sample6 =
    Native.Benchmark.sample6


{-| Create a sample for a function with seven arguments.

See docs for [`sample`](#sample).
-}
sample7 : (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Sample
sample7 =
    Native.Benchmark.sample7


{-| Create a sample for a function with eight arguments.

See docs for [`sample`](#sample).
-}
sample8 : (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Sample
sample8 =
    Native.Benchmark.sample8


{-| Run a sample a specified number of times. The returned value is the total
time it took for the given number of runs.

High-resolution timing data from these functions comes from the [Performance
API](https://developer.mozilla.org/en-US/docs/Web/API/Performance). If
`performance.now` is unavailble, it will fall back to
[Date](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date).
-}
takeSamples : Int -> Sample -> Task Error Time
takeSamples =
    Native.Benchmark.takeSamples
