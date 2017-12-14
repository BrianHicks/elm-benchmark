# Elm Benchmark [![Build Status](https://travis-ci.org/BrianHicks/elm-benchmark.svg?branch=master)](https://travis-ci.org/BrianHicks/elm-benchmark)

Measure the speed of pure functions in Elm, with as little Native code as possible.

## Quick Start

Here's a sample, benchmarking [`Array.Hamt`](http://package.elm-lang.org/packages/Skinney/elm-array-exploration/latest).

```elm
suite : Benchmark
suite =
    let
        sampleArray = Hamt.initialize 1000 identity
    in
        describe "Array.Hamt"
            [ describe "slice" -- nest as many descriptions as you like
                [ benchmark3 "from beginning" Hamt.slice 3 1000 sampleArray
                , benchmark3 "from end minor" Hamt.slice 0 -3 sampleArray
                , benchmark3 "from end major" Hamt.slice 0 500 sampleArray ]
            , Benchmark.compare "initialize" -- compare the results of two benchmarks
                (benchmark2 "HAMT" Hamt.initialize n identity)
                (benchmark2 "core" Array.initialize n identity)
            ]
```

This code uses a few common functions:

-   `describe` to organize benchmarks
-   `benchmark*` to run benchmarks
-   `compare` to compare the results of two benchmarks

For a more thorough overview, I've written an [introduction to elm-benchmark](https://www.brianthicks.com/post/2017/02/27/introducing-elm-benchmark/).

### Installing

You should keep your benchmarks separate from your code since you don't want the elm-benchmark code in your production artifacts.
This is necessary because of how `elm-package` works; it will probably change in the future.
Here are the commands (with explanation) that you should run to get started:

```sh
mkdir benchmarks                             # create a benchmarks directory
cd benchmarks                                # go into that directory
elm package install BrianHicks/elm-benchmark # get this project, including the browser runner
```

You'll also need to add your source directory (probably `../` or `../src`) to the `source-directories` list in `benchmarks/elm-package.json`.
If you don't do this, you won't be able to import the code you're benchmarking.

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

### How Are My Benchmarks Measured?

When we measure the speed of your code, we take the following steps:

1.  We measure how many runs of the function will fit into a tenth of a second.
2.  Next, we round this sample size to the nearest order of magnitude.
    (So if we could fit 23456 runs into a tenth of a second, we would round to 20000.)
    We do this to get a consistent sample size between runs.
3.  At this stage, we start collecting samples until we have the total time specified.
    (The total defaults to 5 seconds.)

If the run contains multiple benchmarks, we interleave sampling between them.
This means that given three benchmarks we would take one sample of each and continue in that pattern until they were complete.

We do this because the system might be busy with other work when running the first, but give its full attention to the second and third.
This would make one artificially slower than the others, so we would get misleading data!

By interleaving samples, we spread this offset among all the benchmarks.
It sets a more even playing field for all the benchmarks, and gives us better data.

## Writing Effective Benchmarks

Some general principles:

-   Don't compare raw values from different machines.
-   When you're working on speeding up a function, keep the old implementation around and use `compare` to measure your progress.
-   "As always, if you see numbers that look wildly out of whack, you shouldn’t rejoice that you have magically achieved fast performance—be skeptical and investigate!" – [Bryan O'Sullivan](http://www.serpentine.com/criterion/tutorial.html)

And advice specific to `elm-benchmark`:

-   Don't compare calls to `benchmark` to `benchmark1` through `benchmark8`.
    `benchmark` uses thunks, while `benchmark1` through `benchmark8` call functions directly.
    Thunks are around 50% slower than direct application (increasing with the number of arguments.)
    Run `examples/Thunks.elm` to replicate this yourself.
    You won't get accurate results if you mix the two styles.
    Just don't do it!

## Prior Art and Inspirations

-   [Thread on elm-dev](https://groups.google.com/forum/#!topic/elm-dev/6YyRsZ0vtDg), the source of the LowLevel API
-   [Luke Westby's Gist](https://gist.github.com/lukewestby/9d8e2b0816d417eae926ed86c01de0b8), the source of the initial LowLevel implementation
-   [Gary Bernhardt's Readygo](https://github.com/garybernhardt/readygo#timing-methodology), the inspiration for our interleaved runs
-   [Rust Benchmarks](https://doc.rust-lang.org/1.1.0/src/test/lib.rs.html#1090-1161)
-   [Go Benchmarks](https://golang.org/src/testing/benchmark.go#L250)

## License

Benchmark is licensed under a 3-Clause BSD License.
