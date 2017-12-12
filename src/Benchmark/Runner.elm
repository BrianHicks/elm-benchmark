module Benchmark.Runner exposing (BenchmarkProgram, program)

{-| Browser Benchmark Runner

@docs program, BenchmarkProgram

-}

import Benchmark exposing (Benchmark)
import Benchmark.Reporting as Reporting exposing (Report, Stats)
import Benchmark.Samples as Samples
import Benchmark.Status as Status exposing (Status)
import Dict
import Html exposing (Html)
import Html.Attributes as A


-- USER-VISIBLE API


{-| A handy type alias for values produced by [`program`](#program)
-}
type alias BenchmarkProgram =
    Program Never Model Msg


{-| Create a runner program from a benchmark. For example:

    main : BenchmarkProgram
    main =
        Runner.program <|
            Benchmark.describe "your benchmarks"
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



-- MODEL


type alias Model =
    Benchmark


init : Benchmark -> ( Model, Cmd Msg )
init benchmark =
    ( benchmark, next benchmark )



-- UPDATE


type Msg
    = Update Benchmark


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Update benchmark ->
            ( benchmark, next benchmark )


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



-- VIEW


view : Model -> Html Msg
view model =
    Html.text <| toString model
