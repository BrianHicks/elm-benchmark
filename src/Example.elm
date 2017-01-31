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
        Benchmark.suite
            "dictionary"
            [ Benchmark.benchmark2 "get" Dict.get "a" dest
            , Benchmark.benchmark3 "insert" Dict.insert "b" 2 dest
            ]


match : Benchmark
match =
    Benchmark.benchmark2 "regex match" Regex.contains (Regex.regex "^a+") "aaaaaaaaaaaaaaaaaaaaaaaaaa"


main : BenchmarkProgram
main =
    program
        (Benchmark.suite "sample" [ insert, match ])
