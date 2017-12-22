# Elm Benchmark

[![Build Status](https://travis-ci.org/BrianHicks/elm-benchmark.svg?branch=master)](https://travis-ci.org/BrianHicks/elm-benchmark)

Run microbenchmarks in Elm.

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Elm Benchmark](#elm-benchmark)
    - [Quick Start](#quick-start)
        - [Installing](#installing)
        - [Running Benchmarks in the Browser](#running-benchmarks-in-the-browser)
    - [Writing Effective Benchmarks](#writing-effective-benchmarks)
    - [FAQ](#faq)
        - [What Does Goodness of Fit Mean?](#what-does-goodness-of-fit-mean)
        - [Why Are My Benchmarks Run In Parallel?](#why-are-my-benchmarks-run-in-parallel)
        - [How Are My Benchmarks Measured?](#how-are-my-benchmarks-measured)
    - [Inspirations and Thanks](#inspirations-and-thanks)
    - [License](#license)

<!-- markdown-toc end -->


## Quick Start

Here's a sample, benchmarking [`Array.Hamt`](http://package.elm-lang.org/packages/Skinney/elm-array-exploration/latest).

```elm
import Array
import Arry.Hamt as Hamt
import Benchmark exposing (..)


suite : Benchmark
suite =
    let
        sampleArray =
            Hamt.initialize 100 identity
    in
    describe "Array.Hamt"
        [ -- nest as many descriptions as you like
          describe "slice"
            [ benchmark "from the beginning" <|
                \_ -> Hamt.slice 50 100 sampleArray
            , benchmark "from the end" <|
                \_ -> Hamt.slice 0 50 sampleArray
            ]

        -- compare the results of two benchmarks
        , Benchmark.compare "initialize"
            "HAMT"
            (\_ -> Hamt.initialize 100 identity)
            "core"
            (\_ -> Array.initialize 100 identity)
        ]
```

This code uses a few common functions:

- `describe` to organize benchmarks
- `benchmark` to run benchmarks
- `compare` to compare the results of two benchmarks

For a more thorough overview, I've written an [introduction to elm-benchmark](https://www.brianthicks.com/post/2017/02/27/introducing-elm-benchmark/).

### Installing

You should keep your benchmarks separate from your code since you don't want the elm-benchmark code in your production artifacts.
This is necessary because of how `elm-package` works; it may change in the future.
Here are the commands (with explanation) that you should run to get started:

```sh
mkdir benchmarks                             # create a benchmarks directory
cd benchmarks                                # go into that directory
elm package install BrianHicks/elm-benchmark # get this project, including the browser runner
```

You'll also need to add your main source directory (probably `../` or `../src`) to the `source-directories` list in `benchmarks/elm-package.json`.
If you don't do this, you won't be able to import the code you're benchmarking!

### Running Benchmarks in the Browser

`Benchmark.Runner` provides `program`, which takes a `Benchmark` and runs it in the browser.
To run the sample above, you would do:

```elm
import Benchmark.Runner exposing (BenchmarkProgram, program)


main : BenchmarkProgram
main =
    program suite
```

Compile and open in your browser to start the benchmarking run.

## Writing Effective Benchmarks

Some general principles:

- Don't compare raw values from different machines.
- When you're working on speeding up a function, keep the old implementation around and use `compare` to measure your progress.
- "As always, if you see numbers that look wildly out of whack, you shouldn’t rejoice that you have magically achieved fast performance—be skeptical and investigate!" – [Bryan O'Sullivan](http://www.serpentine.com/criterion/tutorial.html)

## FAQ

### What Does Goodness of Fit Mean?

Goodness of fit is a measurement of how well our prediction fits the measurements we have collected.
You want this to be as close to 100% as possible.
In elm-benchmark:

- 99% is great
- 95% is okay
- 90% is not great, consider closing other programs on your computer and re-running
- 80% and below, the result has been highly affected by outliers.
  Please do not trust the results when goodness of fit is this low.
  
elm-benchmark will eventually incorporate this advice into the reporting interface.
See [Issue #13](https://github.com/BrianHicks/elm-benchmark/issues/13).

For more, see [Wikipedia: Goodness of Fit](https://en.wikipedia.org/wiki/Goodness_of_fit).

### Why Are My Benchmarks Running In Parallel?

They're not, but they look like it because we interleave runs and only update the UI after collecting one of each.
Keep reading for more on why we do this!

### How Are My Benchmarks Measured?

When we measure the speed of your code, we take the following steps:

1. We warm up the JIT so that we can get a good measurement.
2. We measure how many runs of the function will fit into a small but measurable timespan.
3. We collect multiples of this amount, until we have enough to create a trend.
   We can do this because running a benchmark twice *should* take twice as long as running it once, so we can create a reliable prediction by splitting sample sizes among a number of buckets.
4. Once we have enough we present our prediction of runs per second *on your computer, in this configuration, now*.
   We try to be as consistent as possible, but be aware that the environment matters a lot!

If the run contains multiple benchmarks, we interleave sampling between them.
This means that given three benchmarks we would take one sample of each and continue in that pattern until they were complete.

We do this because the system might be busy with other work when running the first, but give its full attention to the second and third.
This would make one artificially slower than the others, so we would get misleading data!

By interleaving samples, we spread this offset among all the benchmarks.
It sets a more even playing field for all the benchmarks, and gives us better data.

## Inspirations and Thanks

- [Bryan O'Sullivan's Criterion](http://www.serpentine.com/criterion/), from which we take our prediction technique.
- [Gary Bernhardt's Readygo](https://github.com/garybernhardt/readygo#timing-methodology), from which we take interleaved runs.
- Special thanks to Luke Westby for both the [initial implementation of the measurement code](https://gist.github.com/lukewestby/9d8e2b0816d417eae926ed86c01de0b8) and starting the conversations that lead to this library.

## License

elm-benchmark is licensed under a 3-Clause BSD License.
