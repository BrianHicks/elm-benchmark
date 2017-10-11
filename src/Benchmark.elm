module Benchmark
    exposing
        ( Benchmark
        , benchmark
        , compare
        , describe
        , done
        , progress
        , scale
        , step
        , withRuntime
        )

{-| Benchmark Elm Programs

@docs Benchmark


# Creating and Organizing Benchmarks

@docs benchmark, compare, scale, describe


## Modifying Benchmarks

@docs withRuntime


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



-- Creation and Organization


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


{-| Benchmark a named function.

    benchmark "head" (\_ -> List.head [1])

The name here should be short and descriptive. Ideally, it should also uniquely
identify a single benchmark among your whole suite.

Your code is wrapped in an anonymous function, which we will call repeatedly to
measure speed. Note that this is slightly slower than calling functions
directly. This is OK! The point of this library is to _reliably_ measure
execution speed. In this case, we get more consistent results between functions
and runs by calling them inside thunks like this.

Now, a note about benchmark design: when you first write benchmarks, you usually
think something along the lines of "I need to test the worst possible case."
This is a fair observation and a useful thing to measure eventually, but it's
not a good _first_ step. Unless you're careful, you'll end up with too small a
sample size to be useful, and a very difficult benchmark to maintain.

Instead, benchmark the smallest _real_ sample. If your typical use of a data
structure has 20 items, measure with 20 items. If your model is in one
particular state 90% of the time, measure that. It's helpful to get edge cases
eventually, but better to get the basics right first. Solve the problems you
know are real instead of fabricating more out of whole cloth.

When you get the point where you _know_ you need to test a bunch of different
sizes, we've got your back: that's what [`series`](#series) is for.

-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    Single (LowLevel.benchmark name fn) Status.init


{-| Specify two benchmarks which are meant to be compared directly. This is most
useful when optimizing data structures and other situations where you can make
apples-to-apples comparisons between different approaches.

As with [`benchmark`](#benchmark), the first argument is the name for the
comparison. The other string arguments are the names of the functions that
follow them directly.

    compare "initialize"
        "HAMT"
        (\_ -> Array.HAMT.initialize 10000 identity)
        "Core"
        (\_ -> Array.initialize 10000 identity)

The same advice as single benchmarks applies to comparison benchmarks. In
addition, try as hard as possible to make the arguments the same. It wouldn't be
a valid comparison if, in the example above, we told `Array.HAMT` to use 5,000
items instead of 10,000. In the cases where you can't get _exactly_ the same
arguments, at least try to match functionality.

-}
compare : String -> String -> (() -> a) -> String -> (() -> b) -> Benchmark
compare name name1 fn1 name2 fn2 =
    Series name
        [ ( LowLevel.benchmark name1 fn1, Status.init )
        , ( LowLevel.benchmark name2 fn2, Status.init )
        ]


{-| Specify scale benchmarks for a function. This is especially good for
measuring the performance of your data structures under various sized workloads.

    dictOfSize : Int -> Dict Int ()
    dictOfSize size =
        List.range 0 size
            |> List.map (flip (,) ())
            |> Dict.fromList

    dictSize : Benchmark
    dictSize =
        List.range 0 5
            |> List.map
                (\n ->
                    let
                        size =
                            10 ^ n

                        -- a tip: prepare your data structures _outside_ the
                        -- benchmark function. Here, we're measuring `Dict.size`
                        -- without interference from `dictOfSize` and the
                        -- functions that it uses.
                        target =
                            dictOfSize size
                    in
                    ( toString size
                    , \_ -> Dict.size target
                    )
                )
            |> scale "Dict.size"

Beware that large series can make very intensive benchmarks, and adjust your
size and expectations accordingly!

The API for this function is newer, and may change in the future than other
functions. If you use it, please [open an
issue](https://github.com/brianhicks/elm-benchmark/issues) with your use case so
we can know the right situations to optimize for in future releases.

-}
scale : String -> List ( String, () -> a ) -> Benchmark
scale name series =
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

TODO: remove me in favor of `done`. It's not super useful for runners since
they'll be looking at reports instead.

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


{-| find out if a Benchmark is done yet. For progress information for reporting
purposes, see `Benchmark.Status.progress`.

Use this function to find out if you should call `step` any more.

-}
done : Benchmark -> Bool
done benchmark =
    progress benchmark == 1


{-| Step a benchmark forward to completion.

`step` is only useful for writing runners. As a consumer of the `elm-benchmark`
library, you'll probably never need it!

If a benchmark has no more work to do, this is a no-op. But you probably want to
know if everything is done so you can present results to the user, so use
[`done`](#done) to find out before you call this.

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
