module Benchmark.Runner exposing (BenchmarkProgram, program)

{-| Browser Benchmark Runner

@docs program, BenchmarkProgram

-}

import Benchmark exposing (Benchmark)
import Benchmark.Reporting as Reporting exposing (Report, Stats)
import Benchmark.Status as Status exposing (Status)
import Html exposing (Html)
import Html.Attributes as A
import Process
import Task exposing (Task)
import Time exposing (Time)


type alias Model =
    Benchmark


breakForRender : Task x a -> Task x a
breakForRender task =
    Task.andThen (\_ -> task) (Process.sleep 0)


next : Benchmark -> Cmd Msg
next benchmark =
    if Benchmark.done benchmark then
        Cmd.none
    else
        Benchmark.step benchmark
            |> breakForRender
            |> Task.perform Update


init : Benchmark -> ( Model, Cmd Msg )
init benchmark =
    ( benchmark
    , if Benchmark.done benchmark then
        Cmd.none
      else
        next benchmark
    )


type Msg
    = Update Benchmark


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Update benchmark ->
            if Benchmark.done benchmark then
                ( benchmark, Cmd.none )
            else
                ( benchmark, next benchmark )


percent : Float -> String
percent pct =
    pct
        |> (*) 10000
        |> round
        |> toFloat
        |> flip (/) 100
        |> toString


percentChange : Float -> String
percentChange pct =
    pct
        |> (*) 10000
        |> round
        |> toFloat
        |> flip (/) 100
        |> (\i ->
                case compare i 0 of
                    GT ->
                        "+" ++ toString i ++ "%"

                    _ ->
                        toString i ++ "%"
           )


humanizeTime : Time -> String
humanizeTime =
    let
        chopToThousandth : Float -> Float
        chopToThousandth =
            (*) 1000 >> round >> toFloat >> flip (/) 1000

        helper : List String -> Float -> String
        helper units time =
            case units of
                unit :: [] ->
                    toString (chopToThousandth time) ++ unit

                unit :: rest ->
                    if time > 1 then
                        toString (chopToThousandth time) ++ unit
                    else
                        helper rest (time * 1000)

                _ ->
                    toString time ++ " of unknown unit"
    in
    Time.inSeconds >> helper [ "s", "ms", "µs", "ns" ]


chopDecimal : Int -> Float -> Float
chopDecimal places number =
    let
        magnitude =
            10 ^ places |> toFloat
    in
    number
        * magnitude
        |> round
        |> toFloat
        |> flip (/) magnitude


groupsOfThree : List a -> List (List a)
groupsOfThree items =
    case List.take 3 items of
        [] ->
            []

        xs ->
            xs :: groupsOfThree (List.drop 3 items)


humanizeNumber : number -> String
humanizeNumber number =
    let
        humanizeIntegralPart =
            String.reverse
                >> String.toList
                >> groupsOfThree
                >> List.map String.fromList
                >> String.join ","
                >> String.reverse

        humanizeDecimalPart part =
            if part == "" then
                ""
            else if String.endsWith "0" part then
                humanizeDecimalPart (String.dropRight 1 part)
            else
                "." ++ part
    in
    case number |> toString |> String.split "." of
        [ l ] ->
            humanizeIntegralPart l

        [ l, r ] ->
            humanizeIntegralPart l ++ humanizeDecimalPart r

        _ ->
            toString number


humanizeSamplingMethodology : Stats -> String
humanizeSamplingMethodology stats =
    (humanizeNumber <| List.length stats.samples)
        ++ " runs of "
        ++ humanizeNumber stats.sampleSize
        ++ " calls"


humanizeMeanRuntime : Stats -> String
humanizeMeanRuntime stats =
    let
        ( mean, stddev ) =
            Reporting.meanRuntime stats

        pctDiff =
            (stddev + mean) / mean - 1
    in
    humanizeTime mean
        ++ " (stddev: "
        ++ humanizeTime stddev
        ++ ", "
        ++ percent pctDiff
        ++ "%)"


humanizeOpsPerSec : Stats -> String
humanizeOpsPerSec stats =
    let
        ( ops, stddev ) =
            Reporting.operationsPerSecond stats

        pctDiff =
            (stddev + ops) / ops - 1
    in
    (humanizeNumber <| chopDecimal 2 <| ops)
        ++ " (stddev: "
        ++ (humanizeNumber <| chopDecimal 2 <| stddev)
        ++ ", "
        ++ percent pctDiff
        ++ "%)"


attrs : List ( String, Html msg ) -> Html msg
attrs list =
    let
        row : ( String, Html msg ) -> Html msg
        row ( caption, value ) =
            Html.tr
                []
                [ Html.th [ A.style [ ( "text-align", "right" ) ] ] [ Html.text caption ]
                , Html.td [] [ value ]
                ]
    in
    Html.table
        []
        (List.map row list)


name : Report -> String
name benchmark =
    case benchmark of
        Reporting.Single name _ ->
            name

        Reporting.Series name _ ->
            name

        Reporting.Group name _ ->
            name


benchmarkView : Report -> Html Msg
benchmarkView benchmark =
    let
        humanizeStatus : Status -> Html a
        humanizeStatus status =
            case status of
                Status.Unsized _ ->
                    Html.text "Needs Sizing"

                Status.Pending sampleSize time samples ->
                    Html.div
                        []
                        [ Html.progress
                            [ A.max <| toString time
                            , A.value <| toString <| List.sum samples
                            , A.style [ ( "display", "block" ) ]
                            ]
                            []
                        , Html.text <| "Collected " ++ humanizeTime (List.sum samples) ++ " of " ++ humanizeTime time
                        ]

                Status.Failure error ->
                    Html.text <| "Error: " ++ toString error

                Status.Success _ _ ->
                    Html.text "Complete"
    in
    case benchmark of
        Reporting.Single name status ->
            Html.section
                []
                [ Html.h1 [] [ Html.text <| "Benchmark: " ++ name ]
                , case status of
                    Status.Success sampleSize samples ->
                        let
                            stats =
                                Reporting.stats sampleSize samples
                        in
                        attrs
                            [ ( "mean ops/sec", Html.text <| humanizeOpsPerSec stats )
                            , ( "mean runtime", Html.text <| humanizeMeanRuntime stats )
                            , ( "total runtime", Html.text <| humanizeTime <| Reporting.totalRuntime stats )
                            , ( "sampling", Html.text <| humanizeSamplingMethodology stats )
                            ]

                    _ ->
                        attrs [ ( "status", humanizeStatus status ) ]
                ]

        Reporting.Series _ benchmarks ->
            Html.section
                []
                [ Html.h1 [] [ Html.text <| "Comparing " ++ name benchmark ]
                , benchmarks
                    |> List.map (uncurry Reporting.Single)
                    |> List.map benchmarkView
                    |> Html.ol []
                ]

        Reporting.Group name benchmarks ->
            Html.section
                []
                [ Html.h1 [] [ Html.text <| "Group: " ++ name ]
                , Html.ol [] (List.map benchmarkView benchmarks)
                ]


view : Model -> Html Msg
view model =
    Html.div
        []
        [ Html.p
            []
            [ if Benchmark.done model then
                Html.text "Benchmark Finished"
              else
                Html.text "Benchmark Running"
            ]
        , model
            |> Reporting.fromBenchmark
            |> benchmarkView
        ]


{-| Create a runner program from a benchmark. For example:

    main : BenchmarkProgram
    main =
        Runner.program <|
            Benchmark.group "your benchmarks"
                [-- your benchmarks here
                ]

Compile this and visit the result in your browser to run the benchmarks.

-}
program : Benchmark -> BenchmarkProgram
program benchmark =
    Html.program
        { init = init benchmark
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }


{-| A handy type alias for values produced by [`program`](#program)
-}
type alias BenchmarkProgram =
    Program Never Model Msg
