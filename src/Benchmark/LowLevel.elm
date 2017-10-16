module Benchmark.LowLevel
    exposing
        ( Benchmark
        , Error(..)
        , benchmark
        , findSampleSize
        , name
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


# Benchmarks

@docs Benchmark, benchmark, name


# Measuring

@docs warmup, findSampleSize, sample, Error

-}

import Native.Benchmark
import Task exposing (Task)
import Time exposing (Time)


{-| A low-level representation of a benchmarking operation. Each named benchmark
contains a single function call.
-}
type Benchmark
    = Benchmark String Operation


{-| Create a benchmark, given a name and a testing function.
-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    Benchmark name (operation fn)


{-| get the name of a benchmark, for display purposes
-}
name : Benchmark -> String
name (Benchmark name _) =
    name



-- running benchmarks


{-| Error states that can terminate a sampling run.
-}
type Error
    = StackOverflow
    | UnknownError String


{-| Run a benchmark a number of times. The returned value is the total time it
took for the given number of runs.

In the browser, high-resolution timing data from these functions comes from the
[Performance API](https://developer.mozilla.org/en-US/docs/Web/API/Performance)
and is accurate to 5µs. If `performance.now` is unavailable, it will fall back
to [Date](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date),
accurate to 1ms.

-}
sample : Int -> Benchmark -> Task Error Time
sample n (Benchmark _ operation) =
    Native.Benchmark.sample n operation


{-| Warm up the JIT for a benchmarking run. You should call this before calling
[`findSampleSize`](#findSampleSize) or trusting the times coming out of
[`measure`](#measure).

If we don't warm up the JIT beforehand, it will slow down your benchmark and
result in inaccurate data. (By the way, [Mozilla has an excellent
explanation](https://hacks.mozilla.org/2017/02/a-crash-course-in-just-in-time-jit-compilers/)
of how this all works.)

-}
warmup : Benchmark -> Task Error ()
warmup =
    sample 1000
        >> Task.map (always ())


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
findSampleSize : Benchmark -> Task Error Int
findSampleSize benchmark =
    let
        initialSampleSize =
            1

        minimumRuntime =
            50 * Time.millisecond

        resample : Int -> Time -> Task Error Int
        resample size total =
            if total < minimumRuntime then
                let
                    new =
                        ceiling <| toFloat size * 1.618103
                in
                sample new benchmark
                    |> Task.andThen (resample new)
            else
                Task.succeed size
    in
    sample initialSampleSize benchmark
        |> Task.andThen (resample initialSampleSize)
        |> Task.map standardizeSampleSize


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



-- Internal stuff!


{-| Operation is a slim wrapper over (() -> a). We need it though, because
otherwise `Benchmark` would be `Benchmark a`, and tons of operations would get
more difficult.
-}
type Operation
    = Operation


operation : (() -> a) -> Operation
operation =
    Native.Benchmark.operation
