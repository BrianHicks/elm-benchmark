# Benchmark

Benchmarking for Elm.

**Status**: Pre 1.0.0.
[`Benchmark.LowLevel`](src/Benchmark/LowLevel.elm) is more-or-less done, depending on the [higher-level API](src/Benchmark.elm)'s needs changing.
We have the first draft of a [browser runner](src/Benchmark/Runner.elm) and an [example of it's use](src/Example.elm).

## Overview

`Benchmark.LowLevel` provides tasks to get high-resolution run time for functions.

The higher-level API has named constructor functions that mirror the lower-level constructors.
So where `Benchmark.LowLevel` has `measure` through `measure8`, `Benchmark` has `benchmark` through `benchmark8`.
It can also construct suites of benchmarks.

## Prior Art

-   [Thread on elm-dev](https://groups.google.com/forum/#!topic/elm-dev/6YyRsZ0vtDg), the source of the LowLevel API
-   [Luke Westby's Gist](https://gist.github.com/lukewestby/9d8e2b0816d417eae926ed86c01de0b8), the source of the initial LowLevel implementation
-   [Rust Benchmarks](https://doc.rust-lang.org/1.1.0/src/test/lib.rs.html#1090-1161)
-   [Go Benchmarks](https://golang.org/src/testing/benchmark.go#L250)

## License

Benchmark is licensed under a 3-Clause BSD License, located at [LICENSE](LICENSE).
