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
                ( xs, ys ) =
                    List.unzip values

                meanX =
                    mean xs

                deltaX =
                    deltasFromMean xs meanX

                squaredX =
                    squared deltaX

                meanY =
                    mean ys

                deltaY =
                    deltasFromMean ys meanY

                squaredY =
                    squared deltaY

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


type alias Fit =
    { slope : Float, intercept : Float }


fitLine : List ( Float, Float ) -> Maybe Fit
fitLine values =
    case values of
        -- can't draw a line through no values
        [] ->
            Nothing

        -- also can't draw a line through a single value
        _ :: [] ->
            Nothing

        -- we've got two or more, let's go!
        _ ->
            let
                ( xs, ys ) =
                    List.unzip values

                slope =
                    Maybe.map3 (\correl stddevY stddevX -> correl * stddevY / stddevX)
                        (correlation values)
                        (stddev ys)
                        (stddev xs)

                intercept =
                    Maybe.map3 (\meanY slope meanX -> meanY - slope * meanX)
                        (mean ys)
                        slope
                        (mean xs)
            in
            Maybe.map2 Fit slope intercept


predictY : Fit -> Float -> Float
predictY fit x =
    fit.slope * x + fit.intercept


goodnessOfFit : Fit -> List ( Float, Float ) -> Maybe Float
goodnessOfFit fit values =
    case values of
        [] ->
            Nothing

        _ ->
            let
                ( xs, ys ) =
                    List.unzip values

                predictions =
                    List.map (predictY fit) xs

                meanY =
                    mean ys

                sumSquareTotal =
                    meanY
                        |> Maybe.map (\localMean -> List.map (\y -> (y - localMean) ^ 2) ys)
                        |> Maybe.map List.sum

                sumSquareResiduals =
                    List.map2 (\actual prediction -> (actual - prediction) ^ 2) ys predictions
                        |> List.sum
            in
            sumSquareTotal
                |> Maybe.map (\ssT -> 1 - sumSquareResiduals / ssT)
