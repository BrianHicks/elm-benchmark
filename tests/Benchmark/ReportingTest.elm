module Benchmark.ReportingTest exposing (..)

import Benchmark.LowLevel as LowLevel
import Benchmark.Reporting as Reporting
import Benchmark.Status as Status exposing (Status)
import Expect
import Fuzz exposing (Fuzzer)
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (..)
import Time


lazy : (() -> Fuzzer a) -> Fuzzer a
lazy fuzzer =
    Fuzz.andThen fuzzer Fuzz.unit


error : Fuzzer LowLevel.Error
error =
    Fuzz.oneOf
        [ Fuzz.constant LowLevel.StackOverflow
        , Fuzz.map LowLevel.UnknownError Fuzz.string
        ]


status : Fuzzer Status
status =
    Fuzz.oneOf
        [ Fuzz.map Status.Unsized Fuzz.float
        , Fuzz.map3 Status.Pending Fuzz.int Fuzz.float (Fuzz.list Fuzz.float)
        , Fuzz.map Status.Failure error
        , Fuzz.map2 Status.Success Fuzz.int (Fuzz.list Fuzz.float)
        ]


single : Fuzzer Reporting.Report
single =
    Fuzz.map2 Reporting.Single Fuzz.string status


report : Fuzzer Reporting.Report
report =
    Fuzz.frequency
        [ ( 2, single )
        , ( 1, lazy (\_ -> Fuzz.map2 Reporting.Series Fuzz.string (Fuzz.map List.singleton (Fuzz.tuple ( Fuzz.string, status )))) )
        , ( 1, lazy (\_ -> Fuzz.map2 Reporting.Group Fuzz.string (Fuzz.map List.singleton report)) )
        ]



-- now, finally: the tests


totalOperations : Test
totalOperations =
    describe "totalOperations"
        [ test "with one sample and sample size one" <|
            \() ->
                Reporting.stats 1 [ 1 ]
                    |> Reporting.totalOperations
                    |> Expect.equal 1
        , fuzz (Fuzz.intRange 1 10000) "with many samples" <|
            \size ->
                size
                    |> List.range 1
                    |> List.map toFloat
                    |> Reporting.stats 1
                    |> Reporting.totalOperations
                    |> Expect.equal size
        , fuzz (Fuzz.intRange 1 (10 ^ 9)) "with many sample sizes" <|
            \size ->
                size
                    |> flip Reporting.stats [ 1 ]
                    |> Reporting.totalOperations
                    |> Expect.equal size
        ]


totalRuntime : Test
totalRuntime =
    describe "totalRuntime"
        [ test "with one sample and sample size one" <|
            \() ->
                Reporting.stats 1 [ 1 ]
                    |> Reporting.totalOperations
                    |> Expect.equal 1
        , fuzz (Fuzz.list Fuzz.float) "with many samples" <|
            \samples ->
                samples
                    |> Reporting.stats 1
                    |> Reporting.totalRuntime
                    |> Expect.equal (List.sum samples)
        ]


meanRuntime : Test
meanRuntime =
    describe "meanRuntime"
        [ test "with one sample and sample size one" <|
            \() ->
                Reporting.stats 1 [ 1 ]
                    |> Reporting.meanRuntime
                    |> Expect.equal ( 1, 0 )
        , test "with one large and one small sample" <|
            \() ->
                Reporting.stats 1 [ 0, 2 ]
                    |> Reporting.meanRuntime
                    |> Expect.equal ( 1, 1 )
        ]


operationsPerSecond : Test
operationsPerSecond =
    describe "operationsPerSecond"
        [ test "with one sample and sample size one" <|
            \() ->
                Reporting.stats 1 [ Time.second ]
                    |> Reporting.operationsPerSecond
                    |> Expect.equal ( 1, 0 )
        , test "when an operation takes longer than a second" <|
            \() ->
                Reporting.stats 1 [ 2 * Time.second ]
                    |> Reporting.operationsPerSecond
                    |> Expect.equal ( 0.5, 0 )
        , fuzz (Fuzz.intRange 1 (1 ^ 6 * 5)) "fit into one second" <|
            \operations ->
                operations
                    |> flip Reporting.stats [ Time.second ]
                    |> Reporting.operationsPerSecond
                    |> Expect.equal ( toFloat operations, 0 )
        , fuzz (Fuzz.intRange 1 40) "one operation per second for n seconds" <|
            \operations ->
                operations
                    |> List.range 1
                    |> List.map (always Time.second)
                    |> Reporting.stats 1
                    |> Reporting.operationsPerSecond
                    |> Expect.equal ( 1, 0 )
        ]


serialization : Test
serialization =
    describe "serialization"
        [ fuzz report "round trip" <|
            \r ->
                r
                    |> Reporting.encoder
                    |> Encode.encode 0
                    |> Decode.decodeString Reporting.decoder
                    |> Expect.equal (Ok r)
        ]


all : Test
all =
    describe "reporting"
        [ totalOperations
        , totalRuntime
        , meanRuntime
        , operationsPerSecond
        , serialization
        ]
