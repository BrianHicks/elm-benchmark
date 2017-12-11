module ElmArrayExploration exposing (..)

import Array as NArray
import Array.Hamt as Array exposing (Array)
import Benchmark exposing (..)
import Benchmark.Runner exposing (BenchmarkProgram, program)


type alias Input =
    Array Int


largeArraySize : Int
largeArraySize =
    100


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
            "Core"
            (\_ -> NArray.initialize n identity)
            "HAMT"
            (\_ -> Array.initialize n identity)
        , Benchmark.compare "set"
            "Core"
            (\_ -> NArray.set 7 5 cSampleArray)
            "HAMT"
            (\_ -> Array.set 7 5 sampleArray)
        , Benchmark.compare "push"
            "Core"
            (\_ -> NArray.push 5 cSampleArray)
            "HAMT"
            (\_ -> Array.push 5 sampleArray)
        , Benchmark.compare "get"
            "Core"
            (\_ -> NArray.get 5 cSampleArray)
            "HAMT"
            (\_ -> Array.get 5 sampleArray)
        , Benchmark.compare "append"
            "Core"
            (\_ -> NArray.append cSampleArray cSampleArray)
            "HAMT"
            (\_ -> Array.append sampleArray sampleArray)
        ]


main : BenchmarkProgram
main =
    program <| suite largeArraySize
