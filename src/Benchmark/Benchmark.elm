module Benchmark.Benchmark exposing (..)

{-| hey, don't publish me please!
-}

import Benchmark.LowLevel as LowLevel
import Benchmark.Status exposing (Status)


type Benchmark
    = Single LowLevel.Benchmark Status
    | Series String (List ( LowLevel.Benchmark, Status ))
    | Group String (List Benchmark)
