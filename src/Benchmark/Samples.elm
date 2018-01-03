module Benchmark.Samples
    exposing
        ( Point
        , Samples
        , count
        , empty
        , groups
        , points
        , record
        , trend
        )

{-| Collect benchmarking runs with their sample size.


# Sampling

@docs Samples, empty, record, count


## Evaluation

@docs Lines, Line, all, fitLines

-}

import Dict exposing (Dict)
import Time exposing (Time)
import Trend.Linear exposing (Quick, Trend, quick)
import Trend.Math as Math exposing (Error)


{-| Samples keeps track of the sample size at which samples have been
gathered.
-}
type Samples
    = Samples (Dict Int (List Time))


{-| an empty samples for initializing things
-}
empty : Samples
empty =
    Samples Dict.empty


{-| How many samples have we collected in total?
-}
count : Samples -> Int
count (Samples samples) =
    Dict.foldl (\_ times acc -> List.length times + acc) 0 samples


{-| Record a new sample
-}
record : Int -> Time -> Samples -> Samples
record sampleSize sample (Samples samples) =
    Samples <|
        Dict.update
            sampleSize
            (\value ->
                case value of
                    Nothing ->
                        Just [ sample ]

                    Just samples ->
                        Just (sample :: samples)
            )
            samples


{-| A point representing `(sampleSize, runtime)`.
-}
type alias Point =
    ( Float, Float )


{-| The `(sampleSize, runtime)` coordinates for plotting or
calculation. The first item in the tuple is the points to be used for
consideration in a trend. The second item contains the outliers.

For our purposes, an outlier is a value that is one standard deviation
from the mean of its bucket.

-}
points : Samples -> ( List Point, List Point )
points (Samples samples) =
    samples
        |> Dict.map (\_ values -> partitionOutliers values)
        |> Dict.foldr
            (\sampleSize ( good, outliers ) ( accGood, accOutliers ) ->
                ( List.map ((,) (toFloat sampleSize)) good ++ accGood
                , List.map ((,) (toFloat sampleSize)) outliers ++ accOutliers
                )
            )
            ( [], [] )


partitionOutliers : List Time -> ( List Time, List Time )
partitionOutliers samples =
    Result.map2
        (\mean stddev ->
            let
                upper =
                    mean + stddev

                lower =
                    mean - stddev
            in
            List.partition (\item -> lower < item && item < upper) samples
        )
        (Math.mean samples)
        (Math.stddev samples)
        |> Result.withDefault ( samples, [] )


{-| A dictionary of samples grouped by sample size.
-}
groups : Samples -> Dict Int (List Time)
groups (Samples samples) =
    -- TODO: this should separate into outliers, then `points` should use it instead.
    samples


{-| Get a trend for these samples, ignoring outliers.
-}
trend : Samples -> Result Error (Trend Quick)
trend samples =
    samples
        |> points
        |> Tuple.first
        |> quick
