module Benchmark.Status exposing (Status(..), init, progress)

{-| hey, don't publish me please!
-}

import Benchmark.LowLevel exposing (Error)
import Time exposing (Time)


type Status
    = ToSize Time
    | Pending Time Int (List Time)
    | Failure Error
    | Success Int (List Time)


init : Status
init =
    ToSize (5 * Time.second)


{-| report progress percentage for a status between 0 and 1
-}
progress : Status -> Float
progress status =
    case status of
        ToSize _ ->
            0

        Pending total _ samples ->
            List.sum samples / total |> clamp 0 1

        Failure _ ->
            1

        Success _ _ ->
            1
