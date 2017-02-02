module Benchmark
    exposing
        ( Benchmark(..)
        , Status(..)
        , Stats
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
        , run
        , withRunner
        , defaultRunner
        , timebox
        , times
        )

{-| Benchmark Elm Programs

# Benchmarks and Suites
@docs Benchmark, Status, Stats

# Creation
@docs describe, benchmark, benchmark1, benchmark2, benchmark3, benchmark4, benchmark5, benchmark6, benchmark7, benchmark8

# Runners
@docs run, withRunner, defaultRunner, timebox, times
-}

import Benchmark.LowLevel as LowLevel exposing (Error(..), Measurement)
import Task exposing (Task)
import Time exposing (Time)


-- Benchmarks and Suites
-- TODO: Status should have Running, when we can output status


{-| The status of a benchmark run
-}
type Status
    = NoRunner
    | Pending (Task Error Stats)
    | Success Stats
    | Failure Error


{-| Benchmarks in various groupings
-}
type Benchmark
    = Benchmark String Measurement Status
    | Group String (List Benchmark)


{-| Stats returned from a successful benchmarking run
-}
type alias Stats =
    ( Int, Time )


stats : Int -> Time -> Stats
stats sampleSize meanRuntime =
    ( sampleSize, meanRuntime )



-- Creation


{-| Create a Group from a list of Benchmarks
-}
describe : String -> List Benchmark -> Benchmark
describe =
    Group


benchmarkInternal : String -> Measurement -> Benchmark
benchmarkInternal name measurement =
    Benchmark name measurement NoRunner |> withRunner defaultRunner


{-| Benchmark a function. This uses Thunks to measure, so you can use any number
of arguments. That said, it won't be as accurate as using `benchmark1` through
`benchmark8` because of the overhead involved in resolving the Thunk.

The first argument to the benchmark* functions is the name of the thing you're
measuring.
-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    benchmarkInternal name (LowLevel.measure fn)


{-| Benchmark a function with a single argument.

    benchmark1 "list head" List.head [1]

See also the docs for [`benchmark`](#benchmark).
-}
benchmark1 : String -> (a -> b) -> a -> Benchmark
benchmark1 name fn a =
    benchmarkInternal name (LowLevel.measure1 fn a)


{-| Benchmark a function with two arguments.

    benchmark2 "dict get" Dict.get "a" (Dict.singleton "a" 1)

See also the docs for [`benchmark`](#benchmark).
-}
benchmark2 : String -> (a -> b -> c) -> a -> b -> Benchmark
benchmark2 name fn a b =
    benchmarkInternal name (LowLevel.measure2 fn a b)


{-| Benchmark a function with three arguments.

    benchmark3 "dict insert" Dict.insert "b" 2 (Dict.singleton "a" 1)

See also the docs for [`benchmark`](#benchmark).
-}
benchmark3 : String -> (a -> b -> c -> d) -> a -> b -> c -> Benchmark
benchmark3 name fn a b c =
    benchmarkInternal name (LowLevel.measure3 fn a b c)


{-| Benchmark a function with four arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark4 : String -> (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Benchmark
benchmark4 name fn a b c d =
    benchmarkInternal name (LowLevel.measure4 fn a b c d)


{-| Benchmark a function with five arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark5 : String -> (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Benchmark
benchmark5 name fn a b c d e =
    benchmarkInternal name (LowLevel.measure5 fn a b c d e)


{-| Benchmark a function with six arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark6 : String -> (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Benchmark
benchmark6 name fn a b c d e f =
    benchmarkInternal name (LowLevel.measure6 fn a b c d e f)


{-| Benchmark a function with seven arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark7 : String -> (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Benchmark
benchmark7 name fn a b c d e f g =
    benchmarkInternal name (LowLevel.measure7 fn a b c d e f g)


{-| Benchmark a function with eight arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark8 : String -> (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Benchmark
benchmark8 name fn a b c d e f g h =
    benchmarkInternal name (LowLevel.measure8 fn a b c d e f g h)



-- Runners


{-| Run [`Benchmark`s](#Benchmark)
-}
run : Benchmark -> (Benchmark -> msg) -> Cmd msg
run benchmark msg =
    toTask benchmark |> Task.perform msg


toTask : Benchmark -> Task Never Benchmark
toTask benchmark =
    case benchmark of
        Benchmark name task status ->
            case status of
                Pending runner ->
                    runner
                        |> Task.map (Success >> Benchmark name task)
                        |> Task.onError (Failure >> Benchmark name task >> Task.succeed)

                _ ->
                    Task.succeed benchmark

        Group name benchmarks ->
            benchmarks
                |> List.map toTask
                |> Task.sequence
                |> Task.map (Group name)


{-| Set the runner for a [`Benchmark`](#Benchmark)
-}
withRunner : (Measurement -> Task Error Stats) -> Benchmark -> Benchmark
withRunner runner benchmark =
    case benchmark of
        Benchmark name task _ ->
            Benchmark name task <| Pending (runner task)

        Group name benchmarks ->
            Group name <| List.map (withRunner runner) benchmarks


{-| The default runner for benchmarks. This is automatically set on Benchmarks
from `benchmark` through `benchmark9`. It is defined as:

     timebox Time.second
-}
defaultRunner : Measurement -> Task Error Stats
defaultRunner =
    timebox Time.second


mean : List Float -> Float
mean times =
    let
        sum =
            List.sum times

        count =
            toFloat <| List.length times
    in
        if sum == 0 then
            0
        else
            sum / count


{-| Fit as many runs as possible into a Time.

To do this, we take a small number of samples, then extrapolate to fit. This
means that the actual benchmarking runs will not fit *exactly* within the given
time box, but we should be fairly close.
-}
timebox : Time -> Measurement -> Task Error Stats
timebox box measurement =
    let
        sampleSize =
            100000

        fit : Time -> Task Error Stats
        fit initial =
            let
                single =
                    initial / sampleSize

                times =
                    if initial == 0 then
                        100000
                    else
                        box / single |> ceiling
            in
                LowLevel.runTimes times measurement
                    |> Task.map (\total -> total / toFloat times)
                    |> Task.map (stats times)
    in
        LowLevel.runTimes sampleSize measurement
            |> Task.andThen fit


{-| Benchmark by running a task exactly the given number of times.
-}
times : Int -> Measurement -> Task Error Stats
times n measurement =
    LowLevel.runTimes n measurement
        |> Task.map (\total -> total / toFloat n)
        |> Task.map (stats n)
