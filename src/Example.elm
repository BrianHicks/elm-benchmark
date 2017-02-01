module Example exposing (..)

import Benchmark exposing (Benchmark)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Dict
import Regex


insert : Benchmark
insert =
    let
        dest =
            Dict.singleton "a" 1
    in
        Benchmark.describe
            "dictionary"
            [ Benchmark.benchmark2 "get" Dict.get "a" dest
            , Benchmark.benchmark3 "insert" Dict.insert "b" 2 dest
            ]


match : Benchmark
match =
    Benchmark.benchmark2 "regex match" Regex.contains (Regex.regex "^a+") "aaaaaaaaaaaaaaaaaaaaaaaaaa"


compare : Benchmark
compare =
    let
        recurse n m =
            if m == 0 then
                0
            else
                n + recurse n (m - 1)
    in
        Benchmark.compare2
            "multiply"
            (*)
            "recurse"
            recurse
            1000
            100


main : BenchmarkProgram
main =
    program <|
        Benchmark.describe "sample"
            [ insert
            , match
            , compare
            ]
