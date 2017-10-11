module Benchmark
    exposing
        ( Benchmark
        , benchmark
        , compare
        , describe
        , done
        , progress
        , series
        , step
        , withRuntime
        )

{-| Benchmark Elm Programs

@docs Benchmark


# Creating and Organizing Benchmarks

@docs benchmark, compare, series, withRuntime, describe


# Running

@docs done, step, progress

-}

import Benchmark.Benchmark exposing (Benchmark(..))
import Benchmark.LowLevel as LowLevel exposing (Error(..))
import Benchmark.Status as Status exposing (Status(..))
import Task exposing (Task)
import Time exposing (Time)


-- Benchmarks and Suites


{-| Benchmarks that contain potential, in-progress, and completed runs.

To make these, try [`benchmark`](#benchmark), [`compare`](#compare), or
[`series`](#series), and organize them with [`describe`](#describe).

-}
type alias Benchmark =
    Benchmark.Benchmark.Benchmark


{-| Set the expected runtime for a [`Benchmark`](#Benchmark). This is how we
determine when the benchmark is "done". Note that this sets the _expected_
runtime, not _actual_ runtime. In other words, your function will be run for _at
least_ this long. In practice, it will usually be slightly more.

The default runtime is 5 seconds, which is good enough for most applications. If
you are benchmarking a very expensive function, this may not be high enough. You
will know that this is the case when you see a low number of total samples
(rough guide: under 10,000.)

On the other hand, 5 seconds is almost never _too much_ time, and usually hits
the sweet spot between getting enough data to be useful while not keeping you
waiting. While there's nothing preventing you from lowering this value, think
about it for a long time before you do. It's easy way to get bad data.

All that said, to set the expected runtime to 10 seconds, pass your constructed
benchmark into this function:

    benchmark "list head" (\_ -> List.head [1])
        |> withRuntime (10 * Time.second)

This works with all the kinds of benchmarks you can create. If you provide a
composite benchmark (a series or group) the same expected runtime will be set
for all members recursively.

-}
withRuntime : Time -> Benchmark -> Benchmark
withRuntime time benchmark =
    case benchmark of
        Single inner _ ->
            Single inner (ToSize time)

        Series name inners ->
            Series name <| List.map (\( inner, _ ) -> ( inner, ToSize time )) inners

        Group name benchmarks ->
            Group name <| List.map (withRuntime time) benchmarks



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
    Group


{-| Benchmark a function.

The first argument to the benchmark* functions is the name of the thing you're
measuring. The rest of the arguments specify how to take samples.

In the case of `benchmark`, we just need an anonymous function that performs
some calculation.

    benchmark "list head" (\_ -> List.head [1])

`benchmark1` through `benchmark8` have a nicer API which doesn't force you to
define anonymous functions. For example, the benchmark above can be defined as:

    benchmark1 "list head" List.head [1]

-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    Single (LowLevel.benchmark name fn) Status.init


{-| Specify that two benchmarks are meant to be directly compared.

As with [`benchmark`](#benchmark), the first argument is the name for the
comparison.

    compare "initialize"
        (benchmark2 "HAMT" HAMT.initialize 10000 identity)
        (benchmark2 "Core" Array.initialize 10000 identity)

When you're doing comparisons, try as hard as possible to **make the arguments
the same**. The comparison above wouldn't be accurate if we told HAMT to
initialize an array with only 5,000 elements. Likewise, try to **use the same
benchmark function**. For example, use only `benchmark2` instead of mixing
`benchmark` and `benchmark2`. The difference between the different benchmark
functions is small, but not so small that it won't influence your results.
See the chart in the README for more on the runtime cost of different functions.

-}
compare : String -> String -> (() -> a) -> String -> (() -> b) -> Benchmark
compare name name1 fn1 name2 fn2 =
    Series name
        [ ( LowLevel.benchmark name1 fn1, Status.init )
        , ( LowLevel.benchmark name2 fn2, Status.init )
        ]


{-| Create (and compmare) a series of benchmarks.

This is especially good for testing out the performance of your data structures
at various scales.

    -- TODO: example!

Beware that large series can make very intensive benchmarks, and adjust your
size and expectations accordingly!

-}
series : String -> List ( String, () -> a ) -> Benchmark
series name series =
    series
        |> List.map
            (\( subName, fn ) ->
                ( LowLevel.benchmark subName fn
                , Status.init
                )
            )
        |> Series name



-- Runners


{-| find out the progress a benchmark has made through its run. This does not
include sizing information, which should be reported separately.

The returned float is between 0 and 1, and represents percentage of progress.

-}
progress : Benchmark -> Float
progress benchmark =
    let
        progressHelp : Benchmark -> List Float
        progressHelp benchmark =
            case benchmark of
                Single _ status ->
                    [ Status.progress status ]

                Series _ benchmarks ->
                    List.map (Tuple.second >> Status.progress) benchmarks

                -- this is our odd duck case. `Group` is the only case that can
                -- contain benchmarks as defined in this module. This means that
                -- if we have a group with two members, one of which has tons of
                -- benchmarks, and the other of which has very few, an average
                -- of the two averages is inaccurate. Instead, we need to
                -- collect all the numbers and push them up.
                Group _ benchmarks ->
                    List.map progressHelp benchmarks
                        |> List.concat

        allProgress =
            progressHelp benchmark
    in
    List.sum allProgress
        / toFloat (List.length allProgress)
        |> clamp 0 1


{-| is this benchmark done yet?
-}
done : Benchmark -> Bool
done benchmark =
    progress benchmark == 1


{-| Step a benchmark forward to completion.

`step` is only useful for writing runners. You'll probably never need it! If you
do, check if a benchmark is finished with `progress` or `done` before running
this to avoid doing extra work.

-}
step : Benchmark -> Task Never Benchmark
step benchmark =
    case benchmark of
        Single inner status ->
            stepLowLevel inner status
                |> Task.map (Single inner)

        Series name benchmarks ->
            benchmarks
                |> List.map
                    (\( inner, status ) ->
                        stepLowLevel inner status
                            |> Task.map ((,) inner)
                    )
                |> Task.sequence
                |> Task.map (Series name)

        Group name benchmarks ->
            benchmarks
                |> List.map step
                |> Task.sequence
                |> Task.map (Group name)


stepLowLevel : LowLevel.Benchmark -> Status -> Task Never Status
stepLowLevel benchmark status =
    case status of
        ToSize eventualTotalRuntime ->
            LowLevel.findSampleSize benchmark
                |> Task.map
                    (\sampleSize ->
                        Pending
                            sampleSize
                            eventualTotalRuntime
                            []
                    )
                |> Task.onError (Task.succeed << Failure)

        Pending sampleSize total samples ->
            LowLevel.sample sampleSize benchmark
                |> Task.map
                    (\newSample ->
                        let
                            newSamples =
                                newSample :: samples
                        in
                        if List.sum newSamples >= total then
                            Success sampleSize newSamples
                        else
                            Pending sampleSize total newSamples
                    )
                |> Task.onError (Task.succeed << Failure)

        _ ->
            Task.succeed status
