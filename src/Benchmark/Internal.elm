module Benchmark.Internal exposing (..)

import Benchmark.LowLevel exposing (Operation, Error)
import Benchmark.Stats exposing (Stats)
import Time exposing (Time)


type Benchmark
    = Benchmark String Operation Status
    | Group String (List Benchmark)
    | Compare Benchmark Benchmark


{-| The status of a benchmarking run.
-}
type Status
    = ToSize Time
    | Pending Int
    | Complete (Result Error Stats)


benchmark : String -> Operation -> Benchmark
benchmark name operation =
    Benchmark name operation (ToSize Time.second)
