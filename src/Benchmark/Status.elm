module Benchmark.Status exposing (Config, Status(..), init, progress)

{-| Report the status of a Benchmark.


# Reporting

@docs Status, init, progress


## Configuration

@docs Config

-}

import Benchmark.LowLevel exposing (Error)
import Benchmark.Samples as Samples exposing (Samples)


{-| Runtime configuration. Manipulate this with the functions in
`Benchmark`.
-}
type alias Config =
    { buckets : Int
    , samplesPerBucket : Int
    , spacingRatio : Int
    }


{-| Indicate the status of a benchmark.

  - `Cold`: We have not warmed up the JIT yet. Benchmark run will eventually fit
    into the `Time` value (the only argument.)

  - `Unsized`: We have not yet determined the best sample size for this
    benchmark. It will eventually fit into the `Time` value (the only argument.)

  - `Pending`: We are in the process of collecting sample data. We should keep
    collecting sample data using the config (first argument, `Config`) until we
    meet or exceed the total size (second argument, `Time`.) We also store
    samples while in progress (third argument, `List Time`.)

  - `Failure`: We ran into an exception while collecting sample data. The
    attached `Error` tells us what went wrong.

  - `Success`: We finished collecting all our sample data at the given sample
    size (first argument, `Int`.) The samples at that size are contained in the
    second argument.

See "The Life of a Benchmark" in the docs for `Benchmark` for an explanation of
how these fit together.

-}
type Status
    = Cold Config
    | Unsized Config
    | Pending Config Int Samples
    | Failure Error
    | Success Samples


{-| Default status. Manipulate this configuration with the functions
in `Benchmark`.
-}
init : Status
init =
    Cold
        { buckets = 25
        , samplesPerBucket = 5
        , spacingRatio = 2
        }


{-| How far along is this benchmark? This is a percentage, represented as a
`Float` between `0` and `1`.
-}
progress : Status -> Float
progress status =
    case status of
        Cold _ ->
            0

        Unsized _ ->
            0

        Pending { buckets, samplesPerBucket } _ samples ->
            toFloat (Samples.count samples) / toFloat (buckets * samplesPerBucket) |> clamp 0 1

        Failure _ ->
            1

        Success _ ->
            1
