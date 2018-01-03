module Benchmark
    exposing
        ( Benchmark
        , benchmark
        , compare
        , describe
        , done
        , scale
        , step
        )

{-| Benchmark Elm Programs

@docs Benchmark


# Creating and Organizing Benchmarks

@docs benchmark, compare, scale, describe


# Writing Runners

@docs step, done

-}

import Benchmark.Benchmark as Benchmark exposing (Benchmark(..))
import Benchmark.LowLevel as LowLevel exposing (Error(..))
import Benchmark.Samples as Samples exposing (Samples)
import Benchmark.Status as Status exposing (Status(..))
import Task exposing (Task)


-- Benchmarks and Suites


{-| Benchmarks that contain potential, in-progress, and completed runs.

To make these, try [`benchmark`](#benchmark), [`compare`](#compare),
or [`scale`](#scale), and organize them with [`describe`](#describe).

-}
type alias Benchmark =
    Benchmark.Benchmark



-- Creation and Organization


{-| Group a number of benchmarks together. Grouping benchmarks using
`describe` will never effect measurement, only organization.

You'll typically have at least one call to this in your benchmark
program, at the top level:

    describe "your program"
        [{- your benchmarks here -}]

-}
describe : String -> List Benchmark -> Benchmark
describe =
    Group


{-| Benchmark a single function.

    benchmark "head" (\_ -> List.head [1])

The name here should be short and descriptive. Ideally, it should also
uniquely identify a single benchmark among your whole suite.

Your code is wrapped in an anonymous function, which we will call
repeatedly to measure speed. Note that this is slightly slower than
calling functions directly. This is OK! The point of this library is
to _reliably_ measure execution speed. In this case, we get more
consistent results by calling them inside thunks like this.

Now, a note about benchmark design: when you first write benchmarks,
you usually think something along the lines of "I need to test the
worst possible complexity!" You should test this _eventually_, but
it's a bad _first_ step.

Instead, benchmark the smallest _real_ sample. If your typical use of
a data structure has 20 items, measure with 20 items. You'll get edge
cases eventually, but it's better to get the basics right
first. **Solve the problems you know are real** instead of inventing
situations you may never encounter.

When you get the point where you _know_ you need to measure a bunch of
different sizes, we've got your back: that's what [`scale`](#scale) is
for.

-}
benchmark : String -> (() -> a) -> Benchmark
benchmark name fn =
    Single name (LowLevel.operation fn) Cold


{-| Run two benchmarks head-to-head. This is useful when optimizing
data structures or other situations where you can make
apples-to-apples comparisons between different approaches.

As with [`benchmark`](#benchmark), the first argument is the name for
the comparison. The other string arguments are the names of the
functions that follow them directly.

    compare "initialize"
        "Hamt"
        (\_ -> Array.HAMT.initialize 100 identity)
        "Core"
        (\_ -> Array.initialize 100 identity)

In addition to the general advice in [`benchmark`](#benchmark), try as
hard as possible to make the arguments the same. It wouldn't be a
valid comparison if, in the example above, we told `Array.HAMT` to use
1,000 items instead of 100. In the cases where you can't get _exactly_
the same arguments, at least try to match output.

-}
compare : String -> String -> (() -> a) -> String -> (() -> b) -> Benchmark
compare name name1 fn1 name2 fn2 =
    Series name
        [ ( name1, LowLevel.operation fn1, Cold )
        , ( name2, LowLevel.operation fn2, Cold )
        ]


{-| Specify scale benchmarks for a function. This is especially good
for measuring the performance of your data structures under
differently sized workloads.

Beware that large series can make very heavy benchmarks. Adjust your
expectations and measurements accordingly!

For example, this benchmark will see how long it takes to get a
dictionary size, where the size is powers of 10 between 1 and 100,000:

    dictOfSize : Int -> Dict Int ()
    dictOfSize size =
        List.range 0 size
            |> List.map (flip (,) ())
            |> Dict.fromList

    dictSize : Benchmark
    dictSize =
        List.range 0 5
            -- tip: prepare your data structures _outside_ the
            -- benchmark function. Here, we're measuring `Dict.size`
            -- without interference from `dictOfSize` and the
            -- functions that it uses.
            |> List.map ((^) 10)
            |> List.map (\size -> ( size, dictOfSize size ))
            -- now we have a list of structures, make benchmarks pass
            -- them to `scale`!
            |> List.map (\( size, target ) -> ( toString size, \_ -> Dict.size target ))
            |> scale "Dict.size"

**Note:** The API for this function is newer, and may change in the future than
other functions. If you use it, please [open an
issue](https://github.com/brianhicks/elm-benchmark/issues) with your
use case so we can know the right situations to optimize for in future
releases.

-}
scale : String -> List ( String, () -> a ) -> Benchmark
scale name series =
    series
        |> List.map
            (\( subName, fn ) ->
                ( subName
                , LowLevel.operation fn
                , Cold
                )
            )
        |> Series name



-- Runners


{-| find out if a Benchmark is finished. For progress information for
reporting purposes, see `Benchmark.Status.progress`.

The default runner uses this function to find out if it should call
`step` any more.

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

**Warning:** `step` is only useful for writing runners. As a consumer
of the `elm-benchmark` library, you'll probably never need it!

...

Still with me? OK, let's go.

This function "advances" a benchmark through a series of states
(described below.) If the benchmark has no more work to do, this is a
no-op. But you probably want to know about that so you can present
results to the user, so use [`done`](#done) to figure it out before
you call this.

At a high level, a runner just needs to receive benchmarks from the
user, iterate over them using this function, and convert them to
`Report`s whenever it makes sense to you to do so. You shouldn't need
to care _too much_ about the nuances of the internal benchmark state,
but a little knowledge is useful for making a really great user
experience, so read on.


## The Life of a Benchmark

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
    │ success │  │ failure │
    │         │  │         │
    └─────────┘  └─────────┘

When you get a [`Benchmark`](#Benchmark) from the user it won't have
any idea how big the sample size should be. In fact, we can't know
this in advance because different functions will have different
performance characteristics on different machines and browsers and
phases of the moon and so on and so forth.

This is difficult, but not hopeless! We can determine sample size
automatically by running the benchmark a few times to get a feel for
how it behaves in this particular environment. This becomes our first
step. (If you're curious about how exactly we do this, check the
`Benchmark.LowLevel` documentation.)

Once we have the base sample size, we start collecting samples. We
multiply the base sample size to spread runs into a series of buckets.
We do this because running a benchmark twice _ought to_ take about
twice as long as running it once. Since this relationship is perfectly
linear, we can get a number of sample sizes, then create a trend from
them which will be resilient to outliers.

The final result takes the form of an error or a set of samples, their
sizes, and a trend created from that data.

At this point, we're done! The results are presented to the user, and
they make optimizations and try again for ever higher runs per second.

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
        Cold ->
            LowLevel.warmup operation
                |> Task.map (\_ -> Unsized)
                |> Task.onError (Task.succeed << Failure << Status.MeasurementError)

        Unsized ->
            LowLevel.findSampleSize operation
                |> Task.map
                    (\sampleSize ->
                        Pending
                            sampleSize
                            Samples.empty
                    )
                |> Task.onError (Task.succeed << Failure << Status.MeasurementError)

        Pending baseSampleSize samples ->
            let
                sampleSize =
                    baseSampleSize * (Status.bucketSpacingRatio * (Samples.count samples % Status.numBuckets) + 1)
            in
            LowLevel.sample sampleSize operation
                |> Task.map
                    (\newSample ->
                        let
                            newSamples =
                                Samples.record sampleSize newSample samples
                        in
                        if Samples.count newSamples >= (Status.numBuckets * Status.samplesPerBucket) then
                            finalize newSamples
                        else
                            Pending baseSampleSize newSamples
                    )
                |> Task.onError (Task.succeed << Failure << Status.MeasurementError)

        _ ->
            Task.succeed status


finalize : Samples -> Status
finalize samples =
    case Samples.trend samples of
        Ok trend ->
            Success samples trend

        Err err ->
            Failure (Status.AnalysisError err)
