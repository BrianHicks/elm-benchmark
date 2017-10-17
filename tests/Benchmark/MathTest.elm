module Benchmark.MathTest exposing (..)

import Benchmark.Math exposing (..)
import Expect exposing (Expectation)
import Fuzz
import Test exposing (..)


reasonablyCloseTo : Float -> Maybe Float -> Expectation
reasonablyCloseTo target maybeActual =
    case maybeActual of
        Nothing ->
            Expect.fail <| "got a null result (Nothing) instead of " ++ toString target

        Just actual ->
            if target - 0.001 <= actual && actual <= target + 0.001 then
                Expect.pass
            else
                Expect.fail <| toString actual ++ " was not within 0.0001 of " ++ toString target


meanTest : Test
meanTest =
    describe "mean"
        [ test "no values" <|
            \_ -> Expect.equal Nothing (mean [])
        , fuzz Fuzz.float "one value" <|
            \i -> Expect.equal (Just i) (mean [ i ])
        , fuzz Fuzz.float "two identical values" <|
            \i -> Expect.equal (Just i) (mean [ i, i ])
        , test "a small series" <|
            \_ ->
                List.range 0 10
                    |> List.map toFloat
                    |> mean
                    |> Expect.equal (Just 5)
        ]


stddevTest : Test
stddevTest =
    describe "stddev"
        [ test "no values" <|
            \_ -> Expect.equal Nothing (stddev [])
        , fuzz Fuzz.float "one value" <|
            \i -> Expect.equal (Just 0) (stddev [ i ])
        , fuzz Fuzz.float "two identical values" <|
            \i -> Expect.equal (Just 0) (stddev [ i, i ])
        , fuzz Fuzz.float "a small series" <|
            \i -> Expect.equal (Just 0.5) (stddev [ i, i + 1 ])
        ]


correlationTest : Test
correlationTest =
    describe "correlation"
        [ test "no values" <|
            \_ -> Expect.equal Nothing (correlation [])
        , test "single value" <|
            \_ -> Expect.equal Nothing (correlation [ ( 1, 1 ) ])
        , fuzz Fuzz.float "strong positive correlation" <|
            \i ->
                [ ( i, i ), ( i + 1, i + 1 ), ( i + 2, i + 2 ) ]
                    |> correlation
                    |> reasonablyCloseTo 1
        , fuzz Fuzz.float "strong negative correlation" <|
            \i ->
                [ ( i - 1, i + 1 ), ( i, i ), ( i + 1, i - 1 ) ]
                    |> correlation
                    |> reasonablyCloseTo -1
        , fuzz Fuzz.float "no correlation" <|
            \i ->
                [ ( 0, i ), ( i, 0 ), ( 0, -i ), ( -i, 0 ) ]
                    |> correlation
                    |> (if i == 0 then
                            Expect.equal Nothing
                        else
                            reasonablyCloseTo 0
                       )
        ]



-- -- fitLineTest : Test
-- -- fitLineTest =
-- --     describe "fitLine"
-- --         [ test "strong correlation" <|
-- --             \_ ->
-- --                 fitLine [ ( 0, 0 ), ( 1, 1 ), ( 2, 2 ) ]
-- --                     |> Expect.equal
-- --                         { slope = 1
-- --                         , intercept = 0
-- --                         }
-- --         ]
