module ElmArrayExploration exposing (..)

import Array as NArray
import Array.Hamt as Array exposing (Array)
import Benchmark exposing (..)
import Benchmark.Runner exposing (BenchmarkProgram, program)


type alias Input =
    Array Int


largeArraySize : Int
largeArraySize =
    10000


suite : Int -> Benchmark
suite n =
    let
        sampleArray =
            Array.initialize n identity

        cSampleArray =
            NArray.initialize n identity
    in
    describe
        ("Array (" ++ toString n ++ " elements)")
        [ Benchmark.compare "initialize"
            (benchmark2 "Core" NArray.initialize n identity)
            (benchmark2 "HAMT" Array.initialize n identity)
        , Benchmark.compare "set"
            (benchmark3 "Core" NArray.set 7 5 cSampleArray)
            (benchmark3 "HAMT" Array.set 7 5 sampleArray)
        , Benchmark.compare "push"
            (benchmark2 "Core" NArray.push 5 cSampleArray)
            (benchmark2 "HAMT" Array.push 5 sampleArray)
        , Benchmark.compare "get"
            (benchmark2 "Core" NArray.get 5 cSampleArray)
            (benchmark2 "HAMT" Array.get 5 sampleArray)
        , Benchmark.compare "append"
            (benchmark2 "Core" NArray.append cSampleArray cSampleArray)
            (benchmark2 "HAMT" Array.append sampleArray sampleArray)
        ]


main : BenchmarkProgram
main =
    program <| suite largeArraySize
