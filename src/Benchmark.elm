module Benchmark
    exposing
        ( Benchmark
        , withRuntime
        , withRuns
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
@docs withRuntime, withRuns

# Running
@docs nextTask
-}

import Benchmark.Internal as Internal
import Benchmark.LowLevel as LowLevel exposing (Error(..), Operation)
import Benchmark.Stats as Stats exposing (Stats)
import List.Extra as List
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


{-| Set the exact number of runs to benchmarked. For example, to run a function
1 million times:

    benchmark1 "list head" List.head [1] |> withRuns 1000000

Doing this is generally not necessary; the runtime-based estimator will provide
consistent and reasonable results for all sizes of benchmarks without you having
to account for benchmark size or environmental concerns.
-}
withRuns : Int -> Benchmark -> Benchmark
withRuns n benchmark =
    case benchmark of
        Internal.Benchmark name sample _ ->
            Internal.Benchmark name sample <| Internal.Pending n

        Internal.Group name benchmarks ->
            Internal.Group name <| List.map (withRuns n) benchmarks

        Internal.Compare name a b ->
            Internal.Compare name
                (withRuns n a)
                (withRuns n b)



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


mapFirst : (a -> Maybe b) -> List a -> Maybe b
mapFirst fn list =
    case list of
        [] ->
            Nothing

        first :: rest ->
            case fn first of
                Just thing ->
                    Just thing

                Nothing ->
                    mapFirst fn rest


{-| Get the next benchmarking task. This is only useful for writing runners. Try
using `Benchmark.Runner.program` instead.
-}
nextTask : Benchmark -> Maybe (Task Never Benchmark)
nextTask benchmark =
    case benchmark of
        Internal.Benchmark name sample status ->
            case status of
                Internal.ToSize time ->
                    timebox time sample
                        |> Task.map (Internal.Pending >> Internal.Benchmark name sample)
                        |> Task.onError (Err >> Internal.Complete >> Internal.Benchmark name sample >> Task.succeed)
                        |> Just

                Internal.Pending n ->
                    LowLevel.sample n sample
                        |> Task.map (Stats.stats n >> Ok >> Internal.Complete >> Internal.Benchmark name sample)
                        |> Task.onError (Err >> Internal.Complete >> Internal.Benchmark name sample >> Task.succeed)
                        |> Just

                _ ->
                    Nothing

        Internal.Group name benchmarks ->
            benchmarks
                |> List.indexedMap (,)
                |> mapFirst
                    (\( i, benchmark ) ->
                        nextTask benchmark
                            |> Maybe.map ((,) i)
                    )
                |> Maybe.map
                    (\( i, task ) ->
                        task
                            |> Task.map (\benchmark -> List.setAt i benchmark benchmarks)
                            |> Task.map (Maybe.map (Internal.Group name))
                            |> Task.map (Maybe.withDefault benchmark)
                    )

        Internal.Compare name a b ->
            let
                taska =
                    nextTask a |> Maybe.map (Task.map (\a -> Internal.Compare name a b))

                taskb =
                    nextTask b |> Maybe.map (Task.map (Internal.Compare name a))
            in
                case taska of
                    Just _ ->
                        taska

                    Nothing ->
                        taskb


{-| Fit as many runs as possible into a Time.
-}
timebox : Time -> Operation -> Task Error Int
timebox box operation =
    let
        initialSampleSize =
            100

        minimumRuntime =
            max
                (box * 0.05)
                Time.millisecond

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
            box / single * 1.3 |> ceiling
    in
        sample initialSampleSize |> Task.map fit
