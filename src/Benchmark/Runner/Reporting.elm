module Benchmark.Runner.Reporting exposing (Path, paths)

{-| View helpers for working with Reporting objects. Not meant for
public consumption.
-}

import Benchmark.Reporting as Reporting exposing (Report(..))
import Benchmark.Status as Status exposing (Status(..))


type alias Path =
    { parents : List String
    , name : String
    , status : Status
    }


paths : Report -> List Path
paths report =
    case report of
        Single name status ->
            [ Path [] name status ]

        Series name reports ->
            List.map (uncurry <| Path [ name ]) reports

        Group name reports ->
            reports
                |> List.map paths
                |> List.concat
                |> List.map
                    (\({ parents } as report) ->
                        { report | parents = name :: parents }
                    )
