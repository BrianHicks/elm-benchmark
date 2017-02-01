module ElmArrayExploration exposing (..)

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

        sampleList =
            List.range 1 n

        equalButDifferentSample =
            Array.initialize n identity
    in
        describe
            ("Array (" ++ toString n ++ " elements)")
            [ benchmark2 "Build by initialize" Array.initialize n identity
            , benchmark3 "Set" Array.set 7 5 sampleArray
            , benchmark2 "Push" Array.push 5 sampleArray
            , benchmark2 "Get" Array.get 5 sampleArray
            , benchmark2 "Append" Array.append sampleArray sampleArray
            , describe "Slice"
                [ benchmark3 "from beginning minor" Array.slice 3 n sampleArray
                , benchmark3 "from end minor" Array.slice 0 -3 sampleArray
                , benchmark3 "from end major" Array.slice 0 (n // 2) sampleArray
                , benchmark3 "from both minor" Array.slice 3 -3 sampleArray
                , benchmark3 "from both major" Array.slice ((n // 2) - 10) (n // 2) sampleArray
                ]
            , benchmark3 "Foldl" Array.foldl (\_ acc -> acc + 1) 0 sampleArray
            , benchmark3 "Foldr" Array.foldr (\_ acc -> acc + 1) 0 sampleArray
            , benchmark2 "Map" Array.map identity sampleArray
            , benchmark2 "Filter" Array.filter (always True) sampleArray
            , benchmark2 "Indexed Map" Array.indexedMap (,) sampleArray
            , benchmark1 "From List" Array.fromList sampleList
            , benchmark1 "To List" Array.toList sampleArray
            , benchmark1 "Indexed List" Array.toIndexedList sampleArray
            , benchmark1 "toString" Array.toString sampleArray
            , describe "Equality"
                [ benchmark2 "success" (==) sampleArray (Array.set 5 5 sampleArray)
                , benchmark2 "failure" (==) sampleArray (Array.set 5 7 sampleArray)
                , benchmark2 "worst case" (==) sampleArray equalButDifferentSample
                ]
            ]


main : BenchmarkProgram
main =
    program <| suite largeArraySize
