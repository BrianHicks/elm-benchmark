module Benchmark.Runner exposing (BenchmarkProgram, program)

{-| Browser Benchmark Runner

@docs program, BenchmarkProgram

-}

import Benchmark exposing (Benchmark)
import Benchmark.Runner.App as App exposing (Model, Msg)
import Html


-- USER-VISIBLE API


{-| A handy type alias for values produced by [`program`](#program)
-}
type alias BenchmarkProgram =
    Program Never Model Msg


{-| Create a runner program from a benchmark. For example:

    main : BenchmarkProgram
    main =
        Runner.program <|
            Benchmark.describe "your benchmarks"
                [-- your benchmarks here
                ]

Compile this and visit the result in your browser to run the benchmarks.

-}
program : Benchmark -> BenchmarkProgram
program benchmark =
    Html.program
        { init = App.init benchmark
        , update = App.update
        , view = App.view
        , subscriptions = always Sub.none
        }
