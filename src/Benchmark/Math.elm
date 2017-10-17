module Benchmark.Math exposing (..)


mean : List Float -> Maybe Float
mean numbers =
    case numbers of
        [] ->
            Nothing

        _ ->
            Just <| List.sum numbers / toFloat (List.length numbers)


stddev : List Float -> Maybe Float
stddev numbers =
    let
        helper : Float -> Maybe Float
        helper seriesMean =
            numbers
                |> List.map (\n -> (n - seriesMean) ^ 2)
                |> mean
                |> Maybe.map sqrt
    in
    mean numbers |> Maybe.andThen helper


correlation : List ( Float, Float ) -> Maybe Float
correlation values =
    case values of
        -- you can't get a correlation out of no data points
        [] ->
            Nothing

        -- you can't get a correlation out of a single data point
        _ :: [] ->
            Nothing

        -- two or more? That's more like it.
        _ ->
            let
                -- utilities
                deltasFromMean : List Float -> Maybe Float -> Maybe (List Float)
                deltasFromMean series =
                    Maybe.map
                        (\localMean ->
                            List.map (\n -> n - localMean) series
                        )

                squared : Maybe (List Float) -> Maybe (List Float)
                squared =
                    Maybe.map (List.map (\n -> n ^ 2))

                -- calculate stuff now!
                -- ( [ 0.0001 ], [ 0.0001 ] )
                ( xs, ys ) =
                    List.unzip values

                -- 0.0001
                meanX =
                    mean xs

                -- [ 0 ]
                deltaX =
                    deltasFromMean xs meanX

                -- [ 0 ]
                squaredX =
                    squared deltaX

                -- [ 0.0001 ]
                meanY =
                    mean ys

                -- [ 0 ]
                deltaY =
                    deltasFromMean ys meanY

                -- [ 0 ]
                squaredY =
                    squared deltaY

                -- [ 0 ]
                xy =
                    Maybe.map2 (List.map2 (*)) deltaX deltaY

                dividend =
                    Maybe.map List.sum xy

                divisor =
                    Maybe.map2 (+)
                        (Maybe.map List.sum squaredX)
                        (Maybe.map List.sum squaredY)
                        |> Maybe.map sqrt
            in
            Maybe.map2 (/) dividend divisor
                |> Maybe.andThen
                    (\res ->
                        if isNaN res then
                            Nothing
                        else
                            Just res
                    )



-- fitLine : List ( Float, Float ) -> { slope : Float, intercept : Float }
-- fitLine values =
--     let
--         ( xs, ys ) =
--             List.unzip values
--         slope =
--             correlation values * stddev ys / stddev xs
--     in
--     { slope = slope
--     , intercept = mean ys - slope * mean xs
--     }
