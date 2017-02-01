module Benchmark
    exposing
        ( Benchmark(..)
        , Status(..)
        , Stats
        , describe
        , benchmark
        , benchmark2
        , benchmark3
        , benchmark4
        , benchmark5
        , benchmark6
        , benchmark7
        , benchmark8
        , compare2
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

import Benchmark.LowLevel as LowLevel exposing (Error(..))
import Task exposing (Task)
import Time exposing (Time)


-- Benchmarks and Suites
-- TODO: Status should have Running, when we can output status


{-| The status of a benchmark run
-}
type Status
    = NoRunner
    | Pending (Task Error Stats)
    | Complete (Result Error Stats)


{-| Benchmarks in various groupings
-}
type Benchmark
    = Benchmark String (Task Error Time) Status
    | Comparison String Benchmark Benchmark
    | Suite String (List Benchmark)


{-| Stats returned from a successful benchmarking run
-}
type alias Stats =
    ( Int, Time )


stats : Int -> Time -> Stats
stats sampleSize meanRuntime =
    ( sampleSize, meanRuntime )



-- Creation


{-| Create a Suite from a list of Benchmarks
-}
describe : String -> List Benchmark -> Benchmark
describe =
    Suite


{-| Benchmark a function. This uses Thunks to measure, so you can use any number
of arguments. That said, it won't be as accurate as using `benchmark1` through
`benchmark8` because of the overhead involved in resolving the Thunk.

The first argument to the benchmark* functions is the name of the thing you're
measuring.
-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    Benchmark name (LowLevel.measure fn) NoRunner |> withRunner defaultRunner


{-| Benchmark a function with a single argument.

    benchmark1 "list head" List.head [1]

See also the docs for [`benchmark`](#benchmark).
-}
benchmark1 : String -> (a -> b) -> a -> Benchmark
benchmark1 name fn a =
    Benchmark name (LowLevel.measure1 fn a) NoRunner |> withRunner defaultRunner


{-| Benchmark a function with two arguments.

    benchmark2 "dict get" Dict.get "a" (Dict.singleton "a" 1)

See also the docs for [`benchmark`](#benchmark).
-}
benchmark2 : String -> (a -> b -> c) -> a -> b -> Benchmark
benchmark2 name fn a b =
    Benchmark name (LowLevel.measure2 fn a b) NoRunner |> withRunner defaultRunner


{-| Benchmark a function with three arguments.

    benchmark3 "dict insert" Dict.insert "b" 2 (Dict.singleton "a" 1)

See also the docs for [`benchmark`](#benchmark).
-}
benchmark3 : String -> (a -> b -> c -> d) -> a -> b -> c -> Benchmark
benchmark3 name fn a b c =
    Benchmark name (LowLevel.measure3 fn a b c) NoRunner |> withRunner defaultRunner


{-| Benchmark a function with four arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark4 : String -> (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Benchmark
benchmark4 name fn a b c d =
    Benchmark name (LowLevel.measure4 fn a b c d) NoRunner |> withRunner defaultRunner


{-| Benchmark a function with five arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark5 : String -> (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Benchmark
benchmark5 name fn a b c d e =
    Benchmark name (LowLevel.measure5 fn a b c d e) NoRunner |> withRunner defaultRunner


{-| Benchmark a function with six arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark6 : String -> (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Benchmark
benchmark6 name fn a b c d e f =
    Benchmark name (LowLevel.measure6 fn a b c d e f) NoRunner |> withRunner defaultRunner


{-| Benchmark a function with seven arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark7 : String -> (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Benchmark
benchmark7 name fn a b c d e f g =
    Benchmark name (LowLevel.measure7 fn a b c d e f g) NoRunner |> withRunner defaultRunner


{-| Benchmark a function with eight arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark8 : String -> (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Benchmark
benchmark8 name fn a b c d e f g h =
    Benchmark name (LowLevel.measure8 fn a b c d e f g h) NoRunner |> withRunner defaultRunner


compare2 : String -> (a -> b -> c) -> String -> (a -> b -> c) -> a -> b -> Benchmark
compare2 name1 fn1 name2 fn2 a b =
    Comparison
        (name1 ++ " vs " ++ name2)
        (benchmark2 name1 fn1 a b)
        (benchmark2 name2 fn2 a b)



-- Runners


{-| Run [`Benchmark`](#Benchmark)
-}
run : Benchmark -> (Result Error Benchmark -> msg) -> Cmd msg
run benchmark msg =
    toTask benchmark |> Task.attempt msg


toTask : Benchmark -> Task Error Benchmark
toTask benchmark =
    case benchmark of
        Benchmark name task status ->
            case status of
                NoRunner ->
                    Task.fail RunnerNotSet

                Pending runner ->
                    runner |> Task.map (Ok >> Complete >> Benchmark name task)

                Complete _ ->
                    Task.succeed benchmark

        Comparison name a b ->
            Task.map2
                (Comparison name)
                (toTask a)
                (toTask b)

        Suite name benchmarks ->
            benchmarks
                |> List.map toTask
                |> Task.sequence
                |> Task.map (Suite name)


{-| Set the runner for a [`Benchmark`](#Benchmark)
-}
withRunner : (Task Error Time -> Task Error Stats) -> Benchmark -> Benchmark
withRunner runner benchmark =
    case benchmark of
        Benchmark name task _ ->
            Benchmark name task <| Pending (runner task)

        Comparison name a b ->
            Comparison name (withRunner runner a) (withRunner runner b)

        Suite name benchmarks ->
            Suite name <| List.map (withRunner runner) benchmarks


{-| The default runner for benchmarks. This is automatically set on Benchmarks
from `benchmark` through `benchmark9`. It is defined as:

     timebox Time.second
-}
defaultRunner : Task Error Time -> Task Error Stats
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
timebox : Time -> Task Error Time -> Task Error Stats
timebox box task =
    let
        fit : List Time -> Task Error ( Int, Time )
        fit initial =
            let
                -- we don't want to include any zero values in our calibration
                noZeros =
                    List.filter ((/=) 0) initial

                top =
                    List.maximum noZeros |> Maybe.withDefault 0

                bottom =
                    List.minimum noZeros |> Maybe.withDefault 0

                -- remove the top and bottom value. If we change the calibration
                -- value to be several orders of magnitude more than 10, this
                -- should be the top and bottom 5-10%.
                middle =
                    List.filter (\n -> n /= top && n /= bottom) noZeros

                initialMean =
                    mean middle

                -- calculate how many times we could fit the mean into the box.
                -- We add 10% or so here because the result will almost always
                -- be slightly too low otherwise.
                times =
                    if initialMean == 0 then
                        100000
                    else
                        box / initialMean * 1.1 |> ceiling
            in
                LowLevel.runTimes times task
                    |> Task.map mean
                    |> Task.map (stats times)
    in
        LowLevel.runTimes 10 task
            |> Task.andThen fit


{-| Benchmark by running a task exactly the given number of times.
-}
times : Int -> Task Error Time -> Task Error Stats
times n task =
    LowLevel.runTimes n task
        |> Task.map mean
        |> Task.map (stats n)
