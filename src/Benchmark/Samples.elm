module Benchmark.Samples
    exposing
        ( Samples
        , count
        , empty
        , record
        , total
        )

{-| Collect information about samples.


# Sampling

@docs Samples, empty, record, count, total

-}

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
