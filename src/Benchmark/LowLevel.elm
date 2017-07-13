module Benchmark.LowLevel
    exposing
        ( Error(..)
        , Operation
        , operation
        , sample
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


# Measuring

@docs Error, sample

-}

import Native.Benchmark
import Task exposing (Task)
import Time exposing (Time)


{-| Error states that can terminate a sample.
-}
type Error
    = StackOverflow
    | UnknownError String


{-| A low-level representation of a benchmarking operation. This contains a
single function call.

Create these using `operation` through `operation8` and take runtime samples
using `sample`.

**Note:** Small samples of `operation` through `operation8` produce results that
are close enough to be deceiving. Across large enough sample sizes, comparing
operations created with different functions will result in larger and larger
skews. Prefer `operation1` through `operation8` if you can (they're easier to
use) but if in doubt, stick everything in `operation`. Benchmark speed is not an
_absolute_ measure, but a _relative_ one. Make sure that you get your relations
right. See the chart in the README for more context.

-}
type Operation
    = Operation


{-| Create an operation.

See docs for [`Operation`](#Operation).

-}
operation : (() -> a) -> Operation
operation =
    Native.Benchmark.operation


{-| Run an operation a specified number of times. The returned value is the
total time it took for the given number of runs.

In the browser, high-resolution timing data from these functions comes from the
[Performance API](https://developer.mozilla.org/en-US/docs/Web/API/Performance)
and is accurate to 5µs. If `performance.now` is unavailable, it will fall back
to [Date](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date),
accurate to 1ms.

In alternative runners, consult the runner documentation for resolution
information.

-}
sample : Int -> Operation -> Task Error Time
sample =
    Native.Benchmark.sample
