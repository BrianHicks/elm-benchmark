module Benchmark.Samples
    exposing
        ( Samples
        , count
        , empty
        , points
        , record
        , total
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


{-| Samples keeps track of the sample size at which samples have been gathered.
-}
type Samples
    = Samples
        { samples : Dict Int (List Time)
        , trend : Maybe (Trend Robust)
        }


{-| an empty samples for initializing things
-}
empty : Samples
empty =
    Samples { samples = Dict.empty, trend = Nothing }


{-| How many samples have we collected in total?
-}
count : Samples -> Int
count (Samples { samples }) =
    Dict.foldl (\_ times acc -> List.length times + acc) 0 samples


{-| What is the sum of our samples?
-}
total : Samples -> Time
total (Samples { samples }) =
    Dict.foldl (\_ times acc -> List.sum times + acc) 0 samples


{-| Record a new sample
-}
record : Int -> Time -> Samples -> Samples
record sampleSize sample (Samples { samples }) =
    Samples
        { samples =
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
        , trend = Nothing
        }


{-| The `(sampleSize, runtime)` coordinates for plotting or calculation.

Most places you use this expect it to be `( Float, Float )`. We
convert it here for your convenience, but you can trust that the first
item will always be integral.

-}
points : Samples -> List ( Float, Float )
points (Samples { samples }) =
    samples
        |> Dict.toList
        |> List.map
            (\( sampleSize, runtimes ) ->
                List.map
                    ((,) (toFloat sampleSize))
                    runtimes
            )
        |> List.concat
