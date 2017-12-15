module Benchmark.ReportingTest exposing (..)

import Benchmark.LowLevel as LowLevel
import Benchmark.Reporting as Reporting
import Benchmark.Samples as Samples exposing (Samples)
import Benchmark.Status as Status exposing (Status)
import Dict
import Expect
import Fuzz exposing (Fuzzer)
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (..)
import Time


lazy : (() -> Fuzzer a) -> Fuzzer a
lazy fuzzer =
    Fuzz.andThen fuzzer Fuzz.unit


error : Fuzzer Status.Error
error =
    Fuzz.oneOf
        [ Fuzz.constant <| Status.MeasurementError LowLevel.StackOverflow
        , Fuzz.map (Status.MeasurementError << LowLevel.UnknownError) Fuzz.string

        -- TODO: this doesn't matter for the 2.0.0 release, but come
        -- back and add all the other cases. For serialization /
        -- deserialization tests.
        ]


samples : Fuzzer Samples
samples =
    Fuzz.map2
        (\size samples ->
            List.foldl (Samples.record size) Samples.empty samples
        )
        Fuzz.int
        (Fuzz.list Fuzz.float)


status : Fuzzer Status
status =
    Fuzz.oneOf
        [ Fuzz.constant Status.Cold
        , Fuzz.constant Status.Unsized
        , Fuzz.map2 Status.Pending Fuzz.int samples
        , Fuzz.map Status.Failure error

        -- there's not a nice way to construct a trend, so we won't
        -- for now. But I really should when I get back around to
        -- serializing / deserializing reports.
        -- , Fuzz.map Status.Success samples
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
-- TODO: We're definitely going to want these decoders tested, when they get rewritten.


dummy : Test
dummy =
    test "always success so elm-test doesn't complain for now" (\_ -> Expect.pass)



-- serialization : Test
-- serialization =
--     describe "serialization"
--         [ fuzz report "round trip" <|
--             \r ->
--                 r
--                     |> Reporting.encoder
--                     |> Encode.encode 0
--                     |> Decode.decodeString Reporting.decoder
--                     |> Expect.equal (Ok r)
--         ]
