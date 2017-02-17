module Benchmark.ReportingTest exposing (..)

import Benchmark.LowLevel as LowLevel
import Benchmark.Reporting as Reporting
import Expect
import Fuzz exposing (Fuzzer)
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (..)


lazy : (() -> Fuzzer a) -> Fuzzer a
lazy fuzzer =
    Fuzz.andThen fuzzer Fuzz.unit


choice : List (Fuzzer a) -> Fuzzer a
choice choices =
    case choices |> List.map ((,) 1) |> Fuzz.frequency of
        Err err ->
            Debug.crash "error constructing fuzzer" err

        Ok fuzzer ->
            fuzzer


error : Fuzzer LowLevel.Error
error =
    choice
        [ Fuzz.constant LowLevel.StackOverflow
        , Fuzz.map LowLevel.UnknownError Fuzz.string
        ]


status : Fuzzer Reporting.Status
status =
    choice
        [ Fuzz.map Reporting.ToSize Fuzz.float
        , Fuzz.map Reporting.Pending Fuzz.int
        , Fuzz.map Reporting.Failure error
        , Fuzz.map Reporting.Success (Fuzz.map2 Reporting.stats Fuzz.int Fuzz.float)
        ]


report =
    let
        fuzzer =
            Fuzz.frequency
                [ ( 2, Fuzz.map2 Reporting.Benchmark Fuzz.string status )
                , ( 1
                  , lazy
                        (\_ ->
                            Fuzz.map2 Reporting.Group
                                Fuzz.string
                                (Fuzz.map (flip (::) []) report)
                        )
                  )
                , ( 1, lazy (\_ -> Fuzz.map3 Reporting.Compare Fuzz.string report report) )
                ]
    in
        case fuzzer of
            Err err ->
                Debug.crash "error constructing fuzzer" err

            Ok fuzzer ->
                fuzzer



-- now, finally: the tests


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
        [ serialization ]
