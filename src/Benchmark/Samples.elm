module Benchmark.Samples
    exposing
        ( Samples
        , count
        , empty
        , groups
        , points
        , record
        , total
        , trend
        )

{-| Collect information about samples.


# Sampling

@docs Samples, empty, record, count, total


## Evaluation

@docs Lines, Line, all, fitLines

-}

import Dict exposing (Dict)
import Time exposing (Time)
import Trend.Linear exposing (Robust, Trend, robust)
import Trend.Math exposing (Error)


{-| Samples keeps track of the sample size at which samples have been gathered.
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


{-| What is the sum of our samples?
-}
total : Samples -> Time
total (Samples samples) =
    Dict.foldl (\_ times acc -> List.sum times + acc) 0 samples


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


{-| The `(sampleSize, runtime)` coordinates for plotting or calculation.

Most places you use this expect it to be `( Float, Float )`. We
convert it here for your convenience, but you can trust that the first
item will always be integral.

-}
points : Samples -> List ( Float, Float )
points (Samples samples) =
    samples
        |> Dict.toList
        |> List.map
            (\( sampleSize, runtimes ) ->
                List.map
                    ((,) (toFloat sampleSize))
                    runtimes
            )
        |> List.concat


{-| A dictionary of samples grouped by sample size.
-}
groups : Samples -> Dict Int (List Time)
groups (Samples samples) =
    samples


{-| Get a trend for these samples.
-}
trend : Samples -> Result Error (Trend Robust)
trend =
    points >> robust
