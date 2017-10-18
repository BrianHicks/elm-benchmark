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
                ( xs, ys ) =
                    List.unzip values

                standardize : Maybe Float -> Maybe Float -> List Float -> Maybe (List Float)
                standardize maybeMean maybeStddev series =
                    Maybe.map2
                        (\mean stddev -> List.map (\point -> (point - mean) / stddev) series)
                        maybeMean
                        maybeStddev

                summedProduct =
                    Maybe.map2
                        (\stdX stdY -> List.map2 (*) stdX stdY)
                        (standardize (mean xs) (stddev xs) xs)
                        (standardize (mean ys) (stddev ys) ys)
                        |> Maybe.map List.sum
            in
            summedProduct
                |> Maybe.map (\sum -> sum / toFloat (List.length values))
                |> Maybe.andThen
                    (\val ->
                        if isNaN val then
                            Nothing
                        else
                            Just val
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
