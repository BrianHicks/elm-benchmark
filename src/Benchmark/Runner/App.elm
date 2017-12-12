module Benchmark.Runner.App exposing (Model, Msg, init, update, view)

import Benchmark exposing (Benchmark)
import Html exposing (Html)
import Process
import Task exposing (Task)


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
