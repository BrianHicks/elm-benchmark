module Benchmark
    exposing
        ( Benchmark
        , withRuntime
        , describe
        , benchmark
        , benchmark1
        , benchmark2
        , benchmark3
        , benchmark4
        , benchmark5
        , benchmark6
        , benchmark7
        , benchmark8
        , compare
        , nextTask
        )

{-| Benchmark Elm Programs

Benchmarks represent a runnable operation.

@docs Benchmark

# Creating Benchmarks
@docs benchmark, benchmark1, benchmark2, benchmark3, benchmark4, benchmark5, benchmark6, benchmark7, benchmark8, describe, compare

# Sizing
@docs withRuntime

# Running
@docs nextTask
-}

import Benchmark.Internal as Internal
import Benchmark.LowLevel as LowLevel exposing (Error(..), Operation)
import Task exposing (Task)
import Time exposing (Time)


-- Benchmarks and Suites


{-| Benchmarks that contain potential, in-progress, and completed runs.

To make these, try [`benchmark`](#benchmark), [`describe`](#describe), or
[`compare`](#compare)
-}
type alias Benchmark =
    Internal.Benchmark


{-| Set the expected runtime for a [`Benchmark`](#Benchmark). This is the
default method of determining benchmark run size.

For example, to set the expected runtime to 1 second (away from the default of 5
seconds):

    benchmark1 "list head" List.head [1] |> withRuntime Time.second

This works with all the kinds of benchmarks you can create. If you provide a
composite benchmark (a group or comparison) the same expected runtime will be
set for all members.

Note that this sets the *expected* runtime, not *actual* runtime. We take a
small number of samples, then extrapolate to fit. This means that the actual
benchmarking runs will not fit *exactly* within the given time, but we should be
fairly close. In practice, expect actual runtime to deviate up to about 30%.
However, these actual runtimes should be fairly consistent between runs. NB:
Larger expected runtimes tend to yield more accurate actual runtimes.
-}
withRuntime : Time -> Benchmark -> Benchmark
withRuntime time benchmark =
    case benchmark of
        Internal.Benchmark name sample _ ->
            Internal.Benchmark name sample <| Internal.ToSize time

        Internal.Group name benchmarks ->
            Internal.Group name <| List.map (withRuntime time) benchmarks

        Internal.Compare name a b ->
            Internal.Compare name
                (withRuntime time a)
                (withRuntime time b)



-- Creation


{-| Group a number of benchmarks together. Grouping benchmarks using `describe`
will never effect measurement, only organization.

You'll typically have at least one call to this in your benchmark program, at
the top level:

    describe "your program"
        [ -- all your benchmarks
        ]
-}
describe : String -> List Benchmark -> Benchmark
describe =
    Internal.Group


{-| Benchmark a function.

The first argument to the benchmark* functions is the name of the thing you're
measuring.

    benchmark "list head" (\_ -> List.head [1])

`benchmark1` through `benchmark8` have a nicer API which doesn't force you to
define anonymous functions. For example, the benchmark above can be defined as:

    benchmark1 "list head" List.head [1]
-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    Internal.benchmark name (LowLevel.operation fn)


{-| Benchmark a function with a single argument.

    benchmark1 "list head" List.head [1]

See the docs for [`benchmark`](#benchmark) for why this exists.
-}
benchmark1 : String -> (a -> b) -> a -> Benchmark
benchmark1 name fn a =
    Internal.benchmark name (LowLevel.operation1 fn a)


{-| Benchmark a function with two arguments.

    benchmark2 "dict get" Dict.get "a" (Dict.singleton "a" 1)

See the docs for [`benchmark`](#benchmark) for why this exists.
-}
benchmark2 : String -> (a -> b -> c) -> a -> b -> Benchmark
benchmark2 name fn a b =
    Internal.benchmark name (LowLevel.operation2 fn a b)


{-| Benchmark a function with three arguments.

    benchmark3 "dict insert" Dict.insert "b" 2 (Dict.singleton "a" 1)

See the docs for [`benchmark`](#benchmark) for why this exists.
-}
benchmark3 : String -> (a -> b -> c -> d) -> a -> b -> c -> Benchmark
benchmark3 name fn a b c =
    Internal.benchmark name (LowLevel.operation3 fn a b c)


{-| Benchmark a function with four arguments.

See the docs for [`benchmark`](#benchmark) for why this exists.
-}
benchmark4 : String -> (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Benchmark
benchmark4 name fn a b c d =
    Internal.benchmark name (LowLevel.operation4 fn a b c d)


{-| Benchmark a function with five arguments.

See the docs for [`benchmark`](#benchmark) for why this exists.
-}
benchmark5 : String -> (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Benchmark
benchmark5 name fn a b c d e =
    Internal.benchmark name (LowLevel.operation5 fn a b c d e)


{-| Benchmark a function with six arguments.

See the docs for [`benchmark`](#benchmark) for why this exists.
-}
benchmark6 : String -> (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Benchmark
benchmark6 name fn a b c d e f =
    Internal.benchmark name (LowLevel.operation6 fn a b c d e f)


{-| Benchmark a function with seven arguments.

See the docs for [`benchmark`](#benchmark) for why this exists.
-}
benchmark7 : String -> (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Benchmark
benchmark7 name fn a b c d e f g =
    Internal.benchmark name (LowLevel.operation7 fn a b c d e f g)


{-| Benchmark a function with eight arguments.

See the docs for [`benchmark`](#benchmark) for why this exists.
-}
benchmark8 : String -> (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Benchmark
benchmark8 name fn a b c d e f g h =
    Internal.benchmark name (LowLevel.operation8 fn a b c d e f g h)


{-| Specify that two benchmarks are meant to be directly compared.

As with [`benchmark`](#benchmark), the first argument is the name for the
comparison.

    compare "initialize"
        (benchmark2 "HAMT" HAMT.initialize 10000 identity)
        (benchmark2 "Core" Array.initialize 10000 identity)
-}
compare : String -> Benchmark -> Benchmark -> Benchmark
compare =
    Internal.Compare



-- Runners


{-| Find an appropriate sample size for benchmarking. This should be much
greater than the clock resolution (5µs in the browser) to make sure we get good
data.
-}
findSampleSize : Operation -> Task Error Int
findSampleSize operation =
    let
        initialSampleSize =
            100

        minimumRuntime =
            100 * Time.millisecond

        sample : Int -> Task Error Time
        sample size =
            LowLevel.sample size operation
                |> Task.andThen (resample size)

        -- increase the sample size by powers of 10 until we meet the minimum runtime
        resample : Int -> Time -> Task Error Time
        resample size total =
            if total < minimumRuntime then
                sample (size * 10)
            else
                total / toFloat size |> Task.succeed

        fit : Time -> Int
        fit single =
            minimumRuntime / single |> ceiling
    in
        sample initialSampleSize |> Task.map fit


{-| We want the sample size to be more-or-less the same across runs, despite
small differences in measured fit.
-}
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


{-| Get the next benchmarking task. This is only useful for writing runners. Try
using `Benchmark.Runner.program` instead.
-}
nextTask : Benchmark -> Maybe (Task Never Benchmark)
nextTask benchmark =
    case benchmark of
        Internal.Benchmark name sample status ->
            case status of
                Internal.ToSize time ->
                    findSampleSize sample
                        |> Task.map standardizeSampleSize
                        |> Task.map (\sampleSize -> Internal.Pending time sampleSize [])
                        |> Task.map (Internal.Benchmark name sample)
                        |> Task.onError (Internal.Failure >> Internal.Benchmark name sample >> Task.succeed)
                        |> Just

                Internal.Pending target sampleSize samples ->
                    if List.sum samples < target then
                        LowLevel.sample sampleSize sample
                            |> Task.map (flip (::) samples >> Internal.Pending target sampleSize >> Internal.Benchmark name sample)
                            |> Task.onError (Internal.Failure >> Internal.Benchmark name sample >> Task.succeed)
                            |> Just
                    else
                        Internal.Success ( sampleSize, samples )
                            |> Internal.Benchmark name sample
                            |> Task.succeed
                            |> Just

                _ ->
                    Nothing

        Internal.Group name benchmarks ->
            let
                tasks =
                    List.map nextTask benchmarks

                isNothing m =
                    m == Nothing
            in
                if List.all isNothing tasks then
                    Nothing
                else
                    tasks
                        |> List.map2
                            (\benchmark task ->
                                task |> Maybe.withDefault (Task.succeed benchmark)
                            )
                            benchmarks
                        |> Task.sequence
                        |> Task.map (Internal.Group name)
                        |> Just

        Internal.Compare name a b ->
            case ( nextTask a, nextTask b ) of
                ( Nothing, Nothing ) ->
                    Nothing

                ( taska, taskb ) ->
                    Just <|
                        Task.map2
                            (Internal.Compare name)
                            (taska |> Maybe.withDefault (Task.succeed a))
                            (taskb |> Maybe.withDefault (Task.succeed b))
