# Elm Benchmark [![Build Status](https://travis-ci.org/BrianHicks/elm-benchmark.svg?branch=master)](https://travis-ci.org/BrianHicks/elm-benchmark)

Measure the speed of pure functions in Elm, with as little Native code as possible.

## Quick Start

Here's a sample, benchmarking [`Array.Hamt`](https://github.com/Skinney/elm-array-exploration).

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

### Installing

You probably want to keep your benchmarks separate from your code. This is
because your benchmark dependencies aren't necessarily the same as your runtime
dependencies. Just a fact of life now; it might change in the future! So, here
are the commands (with explanation) that you'll run to get started:

```sh
mkdir benchmarks                             # create a benchmarks directory
cd benchmarks                                # go into that directory
elm package install BrianHicks/elm-benchmark # get this project, including the browser runner
```

And keep reading to run them!

### Running Benchmarks in the Browser

`Benchmark.Runner` provides `program`, which takes a `Benchmark` and runs it in the browser.
To run the sample above, you would do:

```elm
import Benchmark.Runner exposing (BenchmarkProgram, program)


main : BenchmarkProgram
main =
    program suite
```

Compile and open in your browser (or use `elm reactor`) to start the benchmarking run.

### How Are My Benchmarks Measured?

When we measure the speed of your code, we take the following steps:

1.  We measure how many runs of the function will fit into a given size (currently a tenth of a second.)
2.  Next, we round this sample size to the nearest order of magnitude.
    We do this to get a more consistent sample size between benchmarking runs.
3.  Now that we have our sample size, we start collecting samples until their total passes the expected time.
    (This is currently 5 seconds, but you can change it with `Benchmark.withRuntime`)

If the run contains multiple benchmarks, sampling is interleaved between all of them.
This means that given benchmarks named `a`, `b`, and `c`, we would take one sample each then start over.

We do this because computers run many things at once.
If we don't account for that, the system might be really busy when running `a`, but give its full attention to `b` and `c`.
This would make `a` artificially slower, so we would get misleading data!

By interleaving samples, the busyness when `a` would be running is replaced by a little busyness in the first runs of all three benchmarks, followed by faster runs of all three benchmarks.
It sets a more even playing field for all the benchmarks, and gives us better data.

## Writing Effective Benchmarks

Some general principles:

-   Don't compare raw values across multiple machines.
-   When you're working on speeding up a function, keep the old implementation around and use `compare` to measure your progress.
-   "As always, if you see numbers that look wildly out of whack, you shouldn’t rejoice that you have magically achieved fast performance—be skeptical and investigate!" – [Bryan O'Sullivan](http://www.serpentine.com/criterion/tutorial.html)

And advice specific to `elm-benchmark`:

-   Don't compare calls to `benchmark` to `benchmark1` through `benchmark8`.
    `benchmark` uses thunks, while `benchmark1` through `benchmark8` apply functions directly.
    The difference is stark:

    ![difference](docs/benchmarkVsBenchmarkn.png)

    (You can run `examples/Thunks.elm` to replicate this data yourself.)

## Prior Art and Inspirations

-   [Thread on elm-dev](https://groups.google.com/forum/#!topic/elm-dev/6YyRsZ0vtDg), the source of the LowLevel API
-   [Luke Westby's Gist](https://gist.github.com/lukewestby/9d8e2b0816d417eae926ed86c01de0b8), the source of the initial LowLevel implementation
-   [Gary Bernhardt's Readygo](https://github.com/garybernhardt/readygo#timing-methodology), the inspiration for our interleaved runs
-   [Rust Benchmarks](https://doc.rust-lang.org/1.1.0/src/test/lib.rs.html#1090-1161)
-   [Go Benchmarks](https://golang.org/src/testing/benchmark.go#L250)

## License

Benchmark is licensed under a 3-Clause BSD License, located at [LICENSE](LICENSE).
