module Benchmark
    exposing
        ( Benchmark(..)
        , Status(..)
        , Stats
        , SizingMethod(..)
        , withSizingMethod
        , defaultSizingMethod
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
        , nextTask
        )

{-| Benchmark Elm Programs

# Benchmarks and Suites
@docs Benchmark, Status

## Analysis
@docs Stats

## Sizing
@docs SizingMethod, withSizingMethod, defaultSizingMethod

# Creation
@docs describe, benchmark, benchmark1, benchmark2, benchmark3, benchmark4, benchmark5, benchmark6, benchmark7, benchmark8

# Running
@docs run, size, timebox
-}

import Benchmark.LowLevel as LowLevel exposing (Error(..), Operation)
import List.Extra as List
import Task exposing (Task)
import Time exposing (Time)


-- Benchmarks and Suites
-- TODO: Status should have Running, when we can output status


{-| The status of a benchmark run
-}
type Status
    = ToSize SizingMethod
    | Pending Int
    | Success Stats
    | Failure Error


{-| Benchmarks in various groupings
-}
type Benchmark
    = Benchmark String Operation Status
    | Group String (List Benchmark)


{-| Stats returned from a successful benchmarking run
-}
type alias Stats =
    ( Int, Time )


stats : Int -> Time -> Stats
stats sampleSize totalRuntime =
    ( sampleSize, totalRuntime )


{-| Methods to get the number size of a benchmarking run
-}
type SizingMethod
    = Timebox Time


{-| Set the sizing method for a [`Benchmark`](#Benchmark)
-}
withSizingMethod : SizingMethod -> Benchmark -> Benchmark
withSizingMethod method benchmark =
    case benchmark of
        Benchmark name sample status ->
            Benchmark name sample <| ToSize method

        Group name benchmarks ->
            Group name <| List.map (withSizingMethod method) benchmarks


{-| The default sizing method for benchmarks. This is automatically set on
Benchmarks from `benchmark` through `benchmark9`. It is defined as:

     Timebox Time.second
-}
defaultSizingMethod : SizingMethod
defaultSizingMethod =
    Timebox Time.second



-- Creation


{-| Create a Group from a list of Benchmarks
-}
describe : String -> List Benchmark -> Benchmark
describe =
    Group


benchmarkInternal : String -> Operation -> Benchmark
benchmarkInternal name operation =
    Benchmark name operation (ToSize defaultSizingMethod)


{-| Benchmark a function. This uses Thunks to measure, so you can use any number
of arguments. That said, it won't be as accurate as using `benchmark1` through
`benchmark8` because of the overhead involved in resolving the Thunk.

The first argument to the benchmark* functions is the name of the thing you're
measuring.
-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    benchmarkInternal name (LowLevel.operation fn)


{-| Benchmark a function with a single argument.

    benchmark1 "list head" List.head [1]

See also the docs for [`benchmark`](#benchmark).
-}
benchmark1 : String -> (a -> b) -> a -> Benchmark
benchmark1 name fn a =
    benchmarkInternal name (LowLevel.operation1 fn a)


{-| Benchmark a function with two arguments.

    benchmark2 "dict get" Dict.get "a" (Dict.singleton "a" 1)

See also the docs for [`benchmark`](#benchmark).
-}
benchmark2 : String -> (a -> b -> c) -> a -> b -> Benchmark
benchmark2 name fn a b =
    benchmarkInternal name (LowLevel.operation2 fn a b)


{-| Benchmark a function with three arguments.

    benchmark3 "dict insert" Dict.insert "b" 2 (Dict.singleton "a" 1)

See also the docs for [`benchmark`](#benchmark).
-}
benchmark3 : String -> (a -> b -> c -> d) -> a -> b -> c -> Benchmark
benchmark3 name fn a b c =
    benchmarkInternal name (LowLevel.operation3 fn a b c)


{-| Benchmark a function with four arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark4 : String -> (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Benchmark
benchmark4 name fn a b c d =
    benchmarkInternal name (LowLevel.operation4 fn a b c d)


{-| Benchmark a function with five arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark5 : String -> (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Benchmark
benchmark5 name fn a b c d e =
    benchmarkInternal name (LowLevel.operation5 fn a b c d e)


{-| Benchmark a function with six arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark6 : String -> (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Benchmark
benchmark6 name fn a b c d e f =
    benchmarkInternal name (LowLevel.operation6 fn a b c d e f)


{-| Benchmark a function with seven arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark7 : String -> (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Benchmark
benchmark7 name fn a b c d e f g =
    benchmarkInternal name (LowLevel.operation7 fn a b c d e f g)


{-| Benchmark a function with eight arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark8 : String -> (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Benchmark
benchmark8 name fn a b c d e f g h =
    benchmarkInternal name (LowLevel.operation8 fn a b c d e f g h)



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


nextTask : Benchmark -> Maybe (Task Never Benchmark)
nextTask benchmark =
    case benchmark of
        Benchmark name sample status ->
            case status of
                ToSize (Timebox time) ->
                    timebox time sample
                        |> Task.map (Pending >> Benchmark name sample)
                        |> Task.onError (Failure >> Benchmark name sample >> Task.succeed)
                        |> Just

                Pending n ->
                    LowLevel.sample n sample
                        |> Task.map (stats n >> Success >> Benchmark name sample)
                        |> Task.onError (Failure >> Benchmark name sample >> Task.succeed)
                        |> Just

                _ ->
                    Nothing

        Group name benchmarks ->
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
                            |> Task.map (Maybe.map (Group name))
                            |> Task.map (Maybe.withDefault benchmark)
                    )


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
