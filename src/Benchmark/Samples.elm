module Benchmark.Samples
    exposing
        ( Line
        , Lines
        , Samples
        , all
        , count
        , empty
        , fitLines
        , record
        , total
        )

{-| Collect information about samples.


# Sampling

@docs Samples, empty, record, count, total


## Evaluation

@docs Lines, Line, all, fitLines

-}

import Benchmark.Math as Math exposing (Fit)
import Dict exposing (Dict)
import Time exposing (Time)


{-| Samples keeps track of the sample size at which samples have been gathered.
-}
type alias Samples =
    Dict Int (List Time)


{-| an empty samples for initializing things
-}
empty : Samples
empty =
    Dict.empty


{-| How many samples have we collected in total?
-}
count : Samples -> Int
count =
    Dict.foldl (\_ times acc -> List.length times + acc) 0


{-| What is the sum of our samples?
-}
total : Samples -> Time
total =
    Dict.foldl (\_ times acc -> List.sum times + acc) 0


{-| Record a new sample
-}
record : Int -> Time -> Samples -> Samples
record sampleSize sample =
    Dict.update
        sampleSize
        (\value ->
            case value of
                Nothing ->
                    Just [ sample ]

                Just samples ->
                    Just (sample :: samples)
        )


minimums : Samples -> List ( Float, Float )
minimums =
    Dict.toList
        >> List.map
            (\( sampleSize, values ) ->
                case List.minimum values of
                    Nothing ->
                        []

                    Just val ->
                        [ ( toFloat sampleSize, val ) ]
            )
        >> List.concat


all : Samples -> List ( Float, Float )
all =
    Dict.toList
        >> List.map
            (\( sampleSize, values ) ->
                List.map (\val -> ( toFloat sampleSize, val )) values
            )
        >> List.concat


maximums : Samples -> List ( Float, Float )
maximums =
    Dict.toList
        >> List.map
            (\( sampleSize, values ) ->
                case List.maximum values of
                    Nothing ->
                        []

                    Just val ->
                        [ ( toFloat sampleSize, val ) ]
            )
        >> List.concat


{-| a single line
-}
type alias Line =
    { line : Fit, confidence : Float }


lineFor : List ( Float, Float ) -> Maybe Line
lineFor series =
    let
        fit =
            Math.fitLine series

        goodness =
            Maybe.andThen (\fit -> Math.goodnessOfFit fit series) fit
    in
    Maybe.map2 Line fit goodness


{-| lines for multiple bands in the samples
-}
type alias Lines =
    { minimums : Line
    , all : Line
    , maximums : Line
    }


{-| Fit a line to these samples. The returned tuple is the calculation of best
fit (see `Benchmark.Math`) and the R-squared value.
-}
fitLines : Samples -> Maybe Lines
fitLines series =
    Maybe.map3 Lines
        (lineFor <| minimums series)
        (lineFor <| all series)
        (lineFor <| maximums series)


fitLine : Samples -> Maybe ( Fit, Float )
fitLine samples =
    let
        values =
            samples
                |> Dict.toList
                |> List.map
                    (\( sampleSize, values ) ->
                        case List.minimum values of
                            Nothing ->
                                []

                            Just val ->
                                [ ( toFloat sampleSize, val ) ]
                    )
                |> List.concat

        fit =
            Math.fitLine values

        goodness =
            Maybe.andThen
                (\fit -> Math.goodnessOfFit fit values)
                fit
    in
    Maybe.map2 (,) fit goodness
