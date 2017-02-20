module Benchmark.Internal exposing (..)

import Benchmark.LowLevel as LowLevel exposing (Error, Operation)
import Time exposing (Time)


type Benchmark
    = Benchmark String Operation Status
    | Group String (List Benchmark)
    | Compare String Benchmark Benchmark


{-| The status of a benchmarking run.
-}
type Status
    = ToSize Time
    | Pending Time Int (List Time)
    | Failure Error
    | Success ( Int, Time )


benchmark : String -> Operation -> Benchmark
benchmark name operation =
    Benchmark name operation <| ToSize <| 5 * Time.second
