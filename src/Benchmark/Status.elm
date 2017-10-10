module Benchmark.Status exposing (Status(..), init, progress)

{-| Report the status of a Benchmark.


# Reporting

@docs Status, progress


# Runners

You're probably only interested in these functions if you're writing a runner.

@docs init

-}

import Benchmark.LowLevel exposing (Error)
import Time exposing (Time)


{-| Indicate the status of a benchmark.

  - `ToSize`: We have not yet determined the best sample size for this
    benchmark. It will eventually fit into the `Time` value (the only argument.)

  - `Pending`: We are in the process of collecting sample data. We should keep
    collecting sample data at the sample size (first argument, `Int`) until we
    meet or exceed the total size (second argument, `Time`.) We also store
    samples while in progress (third argument, `List Time`.)

  - `Failure`: We ran into an exception while collecting sample data. The
    attached `Error` tells us what went wrong.

  - `Success`: We finished collecting all our sample data at the given sample
    size (first argument, `Int`.) The samples at that size are contained in the
    second argument.

-}
type Status
    = ToSize Time
    | Pending Int Time (List Time)
    | Failure Error
    | Success Int (List Time)


{-| The default status for all benchmarks.
-}
init : Status
init =
    ToSize (5 * Time.second)


{-| How far along is this benchmark? This is a percentage, represented as a
`Float` between `0` and `1`.
-}
progress : Status -> Float
progress status =
    case status of
        ToSize _ ->
            0

        Pending _ total samples ->
            List.sum samples / total |> clamp 0 1

        Failure _ ->
            1

        Success _ _ ->
            1
