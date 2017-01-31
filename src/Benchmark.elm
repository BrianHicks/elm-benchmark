module Benchmark exposing (..)

{-| Benchmark Elm Programs

# Benchmarks and Suites
@docs Benchmark, Stats

# Creation
@docs suite, benchmark, benchmark1, benchmark2, benchmark3, benchmark4, benchmark5, benchmark6, benchmark7, benchmark8

# Runners
@docs run, timebox
-}

import Benchmark.LowLevel as LowLevel exposing (Error(..), runTimes)
import Task exposing (Task)
import Time exposing (Time)


{-| Benchmarks in various states of completion and grouping
-}
type Benchmark
    = Pending String (Task Error Time)
    | Complete String (Result Error Stats)
    | Suite String (List Benchmark)


{-| Stats returned from a successful benchmarking run
-}
type alias Stats =
    ( Int, Time )


{-| -}
run : Benchmark -> (Result Error Benchmark -> msg) -> Cmd msg
run benchmark msg =
    toTask (timebox Time.second) benchmark |> Task.attempt msg


toTask : (Task Error Time -> Task Error Stats) -> Benchmark -> Task Error Benchmark
toTask runner benchmark =
    case benchmark of
        Pending name task ->
            runner task |> Task.andThen (\res -> Complete name (Ok res) |> Task.succeed)

        Complete _ _ ->
            Task.succeed benchmark

        Suite name benchmarks ->
            benchmarks
                |> List.map (toTask runner)
                |> Task.sequence
                |> Task.map (Suite name)


{-| -}
timebox : Time -> Task Error Time -> Task Error Stats
timebox box task =
    let
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
                runTimes times task
                    |> Task.map mean
                    |> Task.map ((,) times)
    in
        runTimes 10 task
            |> Task.andThen fit


{-| Create a Suite from a list of Benchmarks
-}
suite : String -> List Benchmark -> Benchmark
suite =
    Suite


{-| Benchmark a function. This uses Thunks to measure, so you can use any number
of arguments. That said, it won't be as accurate as using `benchmark1` through
`benchmark8` because of the overhead involved in resolving the Thunk.

The first argument to the benchmark* functions is the name of the thing you're
measuring.
-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    Pending name <| LowLevel.measure fn


{-| Benchmark a function with a single argument.

    benchmark1 "list head" List.head [1]

See also the docs for [`benchmark`](#benchmark).
-}
benchmark1 : String -> (a -> b) -> a -> Benchmark
benchmark1 name fn a =
    Pending name <| LowLevel.measure1 fn a


{-| Benchmark a function with two arguments.

    benchmark2 "dict get" Dict.get "a" (Dict.singleton "a" 1)

See also the docs for [`benchmark`](#benchmark).
-}
benchmark2 : String -> (a -> b -> c) -> a -> b -> Benchmark
benchmark2 name fn a b =
    Pending name <| LowLevel.measure2 fn a b


{-| Benchmark a function with three arguments.

    benchmark3 "dict insert" Dict.insert "b" 2 (Dict.singleton "a" 1)

See also the docs for [`benchmark`](#benchmark).
-}
benchmark3 : String -> (a -> b -> c -> d) -> a -> b -> c -> Benchmark
benchmark3 name fn a b c =
    Pending name <| LowLevel.measure3 fn a b c


{-| Benchmark a function with four arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark4 : String -> (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Benchmark
benchmark4 name fn a b c d =
    Pending name <| LowLevel.measure4 fn a b c d


{-| Benchmark a function with five arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark5 : String -> (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Benchmark
benchmark5 name fn a b c d e =
    Pending name <| LowLevel.measure5 fn a b c d e


{-| Benchmark a function with six arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark6 : String -> (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Benchmark
benchmark6 name fn a b c d e f =
    Pending name <| LowLevel.measure6 fn a b c d e f


{-| Benchmark a function with seven arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark7 : String -> (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Benchmark
benchmark7 name fn a b c d e f g =
    Pending name <| LowLevel.measure7 fn a b c d e f g


{-| Benchmark a function with eight arguments.

See also the docs for [`benchmark`](#benchmark).
-}
benchmark8 : String -> (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Benchmark
benchmark8 name fn a b c d e f g h =
    Pending name <| LowLevel.measure8 fn a b c d e f g h
