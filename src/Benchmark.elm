module Benchmark
    exposing
        ( Benchmark
        , benchmark
        , compare
        , describe
        , done
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


# Writing Runners

@docs step, done

-}

import Benchmark.Benchmark as Benchmark exposing (Benchmark(..))
import Benchmark.LowLevel as LowLevel exposing (Error(..))
import Benchmark.Samples as Samples
import Benchmark.Status as Status exposing (Status(..))
import Task exposing (Task)
import Time exposing (Time)


-- Benchmarks and Suites


{-| Benchmarks that contain potential, in-progress, and completed runs.

To make these, try [`benchmark`](#benchmark), [`compare`](#compare), or
[`scale`](#scale), and organize them with [`describe`](#describe).

-}
type alias Benchmark =
    Benchmark.Benchmark


defaultStatus : Status
defaultStatus =
    Cold (5 * Time.second)


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
for all members recursively. Be aware that this will also reset any progress
made on the benchmark (see "The Life of a Benchmark") in the documentation.

-}
withRuntime : Time -> Benchmark -> Benchmark
withRuntime time benchmark =
    case benchmark of
        Single name inner _ ->
            Single name inner (Unsized time)

        Series name inners ->
            Series name <|
                List.map
                    (\( name, inner, _ ) -> ( name, inner, Unsized time ))
                    inners

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

When you get the point where you _know_ you need to measure a bunch of different
sizes, we've got your back: that's what [`scale`](#scale) is for.

-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    Single name (LowLevel.operation fn) defaultStatus


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
        [ ( name1, LowLevel.operation fn1, defaultStatus )
        , ( name2, LowLevel.operation fn2, defaultStatus )
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

                        -- tip: prepare your data structures _outside_ the
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
                ( name
                , LowLevel.operation fn
                , defaultStatus
                )
            )
        |> Series name



-- Runners


{-| find out if a Benchmark is done yet. For progress information for reporting
purposes, see `Benchmark.Status.progress`.

Use this function to find out if you should call `step` any more.

-}
done : Benchmark -> Bool
done benchmark =
    case benchmark of
        Single _ _ status ->
            Status.progress status == 1

        Series _ benchmarks ->
            benchmarks
                |> List.map (\( _, _, status ) -> status)
                |> List.map Status.progress
                |> List.all ((==) 1)

        Group _ benchmarks ->
            List.all done benchmarks


{-| Step a benchmark forward to completion.

`step` is only useful for writing runners. As a consumer of the `elm-benchmark`
library, you'll probably never need it!

...

Still with me? Ok, let's go.

This function "advances" a benchmark through a series of states (described
below.) If the benchmark has no more work to do, this is a no-op. But you
probably want to know about that so you can present results to the user, so use
[`done`](#done) to figure it out before you call this.

At a high level, a runner just needs to receive benchmarks from the user,
iterate over them using this function, and convert them to `Report`s whenever it
makes sense to you to do so. You shouldn't need to care _too much_ about the
nuances of the internal benchmark state, but a little knowledge is useful for
making a really great user experience, so read on.


## The Life of a Benchmark

When you get a [`Benchmark`](#Benchmark) from the user it will contain an
expected total runtime (see [`withRuntime`](#withRuntime)), but it _won't_ have
any idea how big the sample size should be. In fact, we can't know this in
advance because different functions will have different performance
characteristics on different machines and browsers and phases of the moon and so
on and so forth.

This is difficult, but not hopeless! We can determine sample size automatically
by running the benchmark a few times to get a feel for how it behaves in this
particular environment. This becomes our first step. (If you're curious about
how exactly we do this, check the `Benchmark.LowLevel` documentation.)

Once we know both total expected runtime and sample size, we start collecting
samples. We add these together and keep taking them until we pass the total
expected runtime or encounter an error. The final result takes the form of an
error or a list of samples and their sample size.

In terms of a state machine, it looks like this:

         ┌─────────────┐
         │    cold     │
         │  benchmark  │
         └─────────────┘
                │
                │  warm up JIT
                ▼
         ┌─────────────┐
         │   unsized   │
         │  benchmark  │
         └─────────────┘
                │
                │  determine
                │  sample size
                ▼
        ┌──────────────┐
        │              │ ───┐
        │    sized     │    │ collect
        │  benchmark   │    │ another
        │  (running)   │    │ sample
        │              │ ◀──┘
        └──────────────┘
            │      │
         ┌──┘      └──┐
         │            │
         ▼            ▼
    ┌─────────┐  ┌─────────┐
    │         │  │         │
    │ success │  │  error  │
    │         │  │         │
    └─────────┘  └─────────┘

-}
step : Benchmark -> Task Never Benchmark
step benchmark =
    case benchmark of
        Single name inner status ->
            stepLowLevel inner status
                |> Task.map (Single name inner)

        Series name benchmarks ->
            benchmarks
                |> List.map
                    (\( name, inner, status ) ->
                        stepLowLevel inner status
                            |> Task.map (\status -> ( name, inner, status ))
                    )
                |> Task.sequence
                |> Task.map (Series name)

        Group name benchmarks ->
            benchmarks
                |> List.map step
                |> Task.sequence
                |> Task.map (Group name)


stepLowLevel : LowLevel.Operation -> Status -> Task Never Status
stepLowLevel operation status =
    case status of
        Cold eventualTotalRuntime ->
            LowLevel.warmup operation
                |> Task.map (\_ -> Unsized eventualTotalRuntime)
                |> Task.onError (Task.succeed << Failure)

        Unsized eventualTotalRuntime ->
            LowLevel.findSampleSize operation
                |> Task.map
                    (\sampleSize ->
                        Pending
                            eventualTotalRuntime
                            sampleSize
                            Samples.empty
                    )
                |> Task.onError (Task.succeed << Failure)

        Pending total baseSampleSize samples ->
            let
                sampleSize =
                    baseSampleSize * ((Samples.count samples % 50) + 1)
            in
            LowLevel.sample sampleSize operation
                |> Task.map
                    (\newSample ->
                        let
                            newSamples =
                                Samples.record sampleSize newSample samples
                        in
                        if Samples.total newSamples >= total then
                            Success newSamples
                        else
                            Pending total baseSampleSize newSamples
                    )
                |> Task.onError (Task.succeed << Failure)

        _ ->
            Task.succeed status
