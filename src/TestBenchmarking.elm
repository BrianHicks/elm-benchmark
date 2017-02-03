module TestBenchmarking exposing (..)

import Benchmark exposing (Benchmark)
import Benchmark.Runner exposing (BenchmarkProgram, program)


arities : Benchmark
arities =
    Benchmark.describe "arities"
        [ Benchmark.benchmark "benchmark" always
        , Benchmark.benchmark1 "benchmark1" always 1
        , Benchmark.benchmark2 "benchmark2" (,) 1 2
        , Benchmark.benchmark3 "benchmark3" (,,) 1 2 3
        , Benchmark.benchmark4 "benchmark4" (,,,) 1 2 3 4
        , Benchmark.benchmark5 "benchmark5" (,,,,) 1 2 3 4 5
        , Benchmark.benchmark6 "benchmark6" (,,,,,) 1 2 3 4 5 6
        , Benchmark.benchmark7 "benchmark7" (,,,,,,) 1 2 3 4 5 6 7
        , Benchmark.benchmark8 "benchmark8" (,,,,,,,) 1 2 3 4 5 6 7 8
        ]


main : BenchmarkProgram
main =
    program <|
        Benchmark.describe "elm-benchmark"
            [ arities ]
