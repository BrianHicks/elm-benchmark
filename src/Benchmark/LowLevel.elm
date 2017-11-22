module Benchmark.LowLevel
    exposing
        ( Error(..)
        , Operation
        , findSampleSize
        , operation
        , sample
        , warmup
        )

{-| Low Level Elm Benchmarking API

This API exposes the raw tasks necessary to create higher-level benchmarking
abstractions.

As a user, you're probably not going to need to use this library. Take a look at
`Benchmark` instead, it has the user-friendly primitives. If you _do_ find
yourself using this library often, please [open an issue on
`elm-benchmark`](https://github.com/BrianHicks/elm-benchmark/issues/new) and
we'll find a way to make your use case friendlier.


# Operations

@docs Operation, operation


## Measuring Operations

@docs warmup, findSampleSize, sample, Error

-}

import Benchmark.Math as Math
import Native.Benchmark
import Process
import Task exposing (Task)
import Time exposing (Time)


{-| An operation to benchmark. Use [`operation`](#operation) to construct these.
-}
type Operation
    = Operation


{-| Make an `Operation`, given a function that runs the code you want to
benchmark when given a unit (`()`.)
-}
operation : (() -> a) -> Operation
operation =
    Native.Benchmark.operation



-- running benchmarks


{-| Error states that can terminate a sampling run.
-}
type Error
    = StackOverflow
    | UnknownError String
    | DidNotStabilize


{-| Run a benchmark a number of times. The returned value is the total time it
took for the given number of runs.

In the browser, high-resolution timing data from these functions comes from the
[Performance API](https://developer.mozilla.org/en-US/docs/Web/API/Performance)
and is accurate to 5µs. If `performance.now` is unavailable, it will fall back
to [Date](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date),
accurate to 1ms.

-}
sample : Int -> Operation -> Task Error Time
sample n operation =
    Native.Benchmark.sample n operation


{-| Warm up the JIT for a benchmarking run. You should call this before calling
[`findSampleSize`](#findSampleSize) or trusting the times coming out of
[`measure`](#measure).

If we don't warm up the JIT beforehand, it will slow down your benchmark and
result in inaccurate data. (By the way, [Mozilla has an excellent
explanation](https://hacks.mozilla.org/2017/02/a-crash-course-in-just-in-time-jit-compilers/)
of how this all works.)

-}
warmup : Operation -> Task Error ()
warmup operation =
    let
        toCollect =
            Time.second

        sampleSize =
            10000

        helper : Float -> Task Error ()
        helper soFar =
            if soFar >= toCollect then
                Task.succeed ()
            else
                sample sampleSize operation
                    |> Task.map ((+) soFar)
                    |> Task.andThen helper
    in
    helper 0


findSampleSizeWithMinimum : Time -> Operation -> Task Error Int
findSampleSizeWithMinimum minimumRuntime operation =
    let
        sampleSize : Int -> Int
        sampleSize i =
            i * 1000

        resample : Int -> Time -> Task Error Int
        resample iteration total =
            if total < minimumRuntime then
                sample (sampleSize iteration) operation
                    -- avoid large outliers by taking the lowest of several samples
                    |> List.repeat 3
                    |> Task.sequence
                    |> Task.map (List.minimum >> Maybe.withDefault 0)
                    |> Task.andThen (resample (iteration + 1))
            else
                Task.succeed (sampleSize iteration)
    in
    resample 1 0
        |> Task.map standardizeSampleSize


defaultMinimum : Time
defaultMinimum =
    1 * Time.millisecond


{-| Find an appropriate sample size for benchmarking. This should be much
greater than the clock resolution (5µs in the browser) to make sure we get good
data.

We do this by starting at sample size 1. If that doesn't pass our threshold, we
multiply by [the golden ratio](https://en.wikipedia.org/wiki/Golden_ratio) and
try again until we get a large enough sample.

In addition, we want the sample size to be more-or-less the same across runs,
despite small differences in measured fit. We do this by rounding to the nearest
order of magnitude. So, for example, if the sample size is 1,234 we round to
1,000. If it's 8,800, we round to 9,000.

-}
findSampleSize : Operation -> Task Error Int
findSampleSize =
    findSampleSizeWithMinimum defaultMinimum


standardizeSampleSize : Int -> Int
standardizeSampleSize sampleSize =
    let
        helper : Int -> Int -> Int
        helper rough magnitude =
            if rough > 10 then
                helper (toFloat rough / 10 |> round) (magnitude * 10)
            else
                rough * magnitude
    in
    helper sampleSize 1
