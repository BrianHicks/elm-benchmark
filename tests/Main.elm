port module Main exposing (..)

import Benchmark.ReportingTest as ReportingTest
import Json.Encode exposing (Value)
import Test.Runner.Node exposing (run, TestProgram)


main : TestProgram
main =
    run emit ReportingTest.all


port emit : ( String, Value ) -> Cmd msg
