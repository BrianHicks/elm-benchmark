module TestBenchmarking exposing (..)

import Benchmark exposing (Benchmark)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Time


arities : Benchmark
arities =
    Benchmark.describe "arities"
        (let
            fn1 a =
                a

            fn2 a b =
                b

            fn3 a b c =
                c

            fn4 a b c d =
                d

            fn5 a b c d e =
                e

            fn6 a b c d e f =
                f

            fn7 a b c d e f g =
                g

            fn8 a b c d e f g h =
                h
         in
            [ Benchmark.compare
                (Benchmark.benchmark "benchmark" fn1)
                (Benchmark.benchmark1 "benchmark1" fn1 ())
            , Benchmark.compare
                (Benchmark.benchmark "benchmark" <| fn2 ())
                (Benchmark.benchmark2 "benchmark2" fn2 () ())
            , Benchmark.compare
                (Benchmark.benchmark "benchmark" <| fn3 () ())
                (Benchmark.benchmark3 "benchmark3" fn3 () () ())
            , Benchmark.compare
                (Benchmark.benchmark "benchmark" <| fn4 () () ())
                (Benchmark.benchmark4 "benchmark4" fn4 () () () ())
            , Benchmark.compare
                (Benchmark.benchmark "benchmark" <| fn5 () () () ())
                (Benchmark.benchmark5 "benchmark5" fn5 () () () () ())
            , Benchmark.compare
                (Benchmark.benchmark "benchmark" <| fn6 () () () () ())
                (Benchmark.benchmark6 "benchmark6" fn6 () () () () () ())
            , Benchmark.compare
                (Benchmark.benchmark "benchmark" <| fn7 () () () () () ())
                (Benchmark.benchmark7 "benchmark7" fn7 () () () () () () ())
            , Benchmark.compare
                (Benchmark.benchmark "benchmark" <| fn8 () () () () () () ())
                (Benchmark.benchmark8 "benchmark8" fn8 () () () () () () () ())
            ]
        )


main : BenchmarkProgram
main =
    program <|
        Benchmark.withSizingMethod (Benchmark.Timebox (5 * Time.second)) <|
            Benchmark.describe "elm-benchmark"
                [ arities ]
