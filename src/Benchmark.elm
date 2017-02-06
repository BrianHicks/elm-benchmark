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

import Benchmark.LowLevel as LowLevel exposing (Error(..), Operation)
import List.Extra as List
import Task exposing (Task)
import Time exposing (Time)
import Benchmark.Stats as Stats exposing (Stats)
import Benchmark.Internal as Internal


-- Benchmarks and Suites


{-| Benchmarks that contain potential, in-progress, and completed runs.

To make these, try [`benchmark`](#benchmark), [`describe`](#describe), or
[`compare`](#compare)
-}
type alias Benchmark =
    Internal.Benchmark


{-| Set the expected runtime for a [`Benchmark`](#Benchmark).

    benchmark2 "test" (+) 1 1 |> withRuntime Time.second

To do this, we take a small number of samples, then extrapolate to fit. This
means that the actual benchmarking runs will not fit *exactly* within the given
time, but we should be fairly close. In practice, expect actual runtime to
deviate up to about 30%.
-}
withRuntime : Time -> Benchmark -> Benchmark
withRuntime time benchmark =
    case benchmark of
        Internal.Benchmark name sample _ ->
            Internal.Benchmark name sample <| Internal.ToSize time

        Internal.Group name benchmarks ->
            Internal.Group name <| List.map (withRuntime time) benchmarks

        Internal.Compare a b ->
            Internal.Compare
                (withRuntime time a)
                (withRuntime time b)


{-| Set the exact number of runs to be benchmarked

    benchmark2 "test" (+) 1 1 |> withRuns 1000000
-}
withRuns : Int -> Benchmark -> Benchmark
withRuns n benchmark =
    case benchmark of
        Internal.Benchmark name sample _ ->
            Internal.Benchmark name sample <| Internal.Pending n

        Internal.Group name benchmarks ->
            Internal.Group name <| List.map (withRuns n) benchmarks

        Internal.Compare a b ->
            Internal.Compare
                (withRuns n a)
                (withRuns n b)



-- Creation


{-| Create a Group from a list of Benchmarks
-}
describe : String -> List Benchmark -> Benchmark
describe =
    Internal.Group


{-| Benchmark a function.

The first argument to the benchmark* functions is the name of the thing you're
measuring.

    benchmark "add" (\_ -> 1 + 1)

`benchmark1` through `benchmark8` have a nicer API which doesn't force you to
define anonymous functions. For example, the benchmark above can be defined as:

    benchmark2 "add" (+) 1 1
-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    Internal.benchmark name (LowLevel.operation fn)


{-| Benchmark a function with a single argument.

    benchmark1 "list head" List.head [1]

See the docs for [`benchmark`](#benchmark).
-}
benchmark1 : String -> (a -> b) -> a -> Benchmark
benchmark1 name fn a =
    Internal.benchmark name (LowLevel.operation1 fn a)


{-| Benchmark a function with two arguments.

    benchmark2 "dict get" Dict.get "a" (Dict.singleton "a" 1)

See the docs for [`benchmark`](#benchmark).
-}
benchmark2 : String -> (a -> b -> c) -> a -> b -> Benchmark
benchmark2 name fn a b =
    Internal.benchmark name (LowLevel.operation2 fn a b)


{-| Benchmark a function with three arguments.

    benchmark3 "dict insert" Dict.insert "b" 2 (Dict.singleton "a" 1)

See the docs for [`benchmark`](#benchmark).
-}
benchmark3 : String -> (a -> b -> c -> d) -> a -> b -> c -> Benchmark
benchmark3 name fn a b c =
    Internal.benchmark name (LowLevel.operation3 fn a b c)


{-| Benchmark a function with four arguments.

See the docs for [`benchmark`](#benchmark).
-}
benchmark4 : String -> (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Benchmark
benchmark4 name fn a b c d =
    Internal.benchmark name (LowLevel.operation4 fn a b c d)


{-| Benchmark a function with five arguments.

See the docs for [`benchmark`](#benchmark).
-}
benchmark5 : String -> (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Benchmark
benchmark5 name fn a b c d e =
    Internal.benchmark name (LowLevel.operation5 fn a b c d e)


{-| Benchmark a function with six arguments.

See the docs for [`benchmark`](#benchmark).
-}
benchmark6 : String -> (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Benchmark
benchmark6 name fn a b c d e f =
    Internal.benchmark name (LowLevel.operation6 fn a b c d e f)


{-| Benchmark a function with seven arguments.

See the docs for [`benchmark`](#benchmark).
-}
benchmark7 : String -> (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Benchmark
benchmark7 name fn a b c d e f g =
    Internal.benchmark name (LowLevel.operation7 fn a b c d e f g)


{-| Benchmark a function with eight arguments.

See the docs for [`benchmark`](#benchmark).
-}
benchmark8 : String -> (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Benchmark
benchmark8 name fn a b c d e f g h =
    Internal.benchmark name (LowLevel.operation8 fn a b c d e f g h)


{-| Specify that two benchmarks are meant to be directly compared.

    compare
        (benchmark2 "add" (+) 10 10)
        (benchmark2 "mul" (*) 10 2)
-}
compare : Benchmark -> Benchmark -> Benchmark
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

        Internal.Compare a b ->
            let
                taska =
                    nextTask a |> Maybe.map (Task.map (\a -> Internal.Compare a b))

                taskb =
                    nextTask b |> Maybe.map (Task.map (Internal.Compare a))
            in
                case taska of
                    Just _ ->
                        taska

                    Nothing ->
                        taskb


{-| Fit as many runs as possible into a Time.

To do this, we take a small number of samples, then extrapolate to fit. This
means that the actual benchmarking runs will not fit *exactly* within the given
time box, but we should be fairly close. In practice, expect actual runtime to
deviate up to about 30%.
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
