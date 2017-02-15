# Elm Benchmark

Measure the speed of pure functions in Elm, with as little Native code as possible.

**Status**: 1.0.0-pre1 (tagged).

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

### Running Benchmarks

`Benchmark.Runner` provides `program`, which takes a `Benchmark` and runs it in the browser.
To run the sample above, you would do:

```elm
import Benchmark.Runner exposing (BenchmarkProgram, program)


main : BenchmarkProgram
main =
    program suite
```

Compile and open in your browser (or use `elm reactor`) to start the benchmarking run.

## Effective Benchmarks

Some general principles:

-   Don't compare raw values across multiple machines.
-   When you're working on speeding up a function, keep the old implementation around and use `compare` to measure your progress.
-   > As always, if you see numbers that look wildly out of whack, you shouldn’t rejoice that you have magically achieved fast performance—be skeptical and investigate!
    >
    > — [Bryan O'Sullivan](http://www.serpentine.com/criterion/tutorial.html)

## Prior Art

-   [Thread on elm-dev](https://groups.google.com/forum/#!topic/elm-dev/6YyRsZ0vtDg), the source of the LowLevel API
-   [Luke Westby's Gist](https://gist.github.com/lukewestby/9d8e2b0816d417eae926ed86c01de0b8), the source of the initial LowLevel implementation
-   [Rust Benchmarks](https://doc.rust-lang.org/1.1.0/src/test/lib.rs.html#1090-1161)
-   [Go Benchmarks](https://golang.org/src/testing/benchmark.go#L250)

## License

Benchmark is licensed under a 3-Clause BSD License, located at [LICENSE](LICENSE).
