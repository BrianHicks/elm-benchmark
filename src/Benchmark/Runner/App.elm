module Benchmark.Runner.App exposing (Model, Msg, init, update, view)

import Benchmark exposing (Benchmark)
import Benchmark.Reporting as Reporting
import Benchmark.Runner.InProgress as InProgress
import Benchmark.Runner.Report as Report
import Benchmark.Runner.Text as Text
import Color
import Element exposing (..)
import Element.Attributes exposing (..)
import Html exposing (Html)
import Process
import Style exposing (..)
import Style.Color as Color
import Style.Sheet as Sheet
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
    let
        body : Element Class variation Msg
        body =
            if Benchmark.done model then
                model
                    |> Reporting.fromBenchmark
                    |> Report.view
                    |> Element.mapAll identity ReportClass identity
            else
                model
                    |> Reporting.fromBenchmark
                    |> InProgress.view
                    |> Element.mapAll identity InProgressClass identity
    in
    Element.viewport (Style.styleSheet styles) <|
        Element.el Page
            [ width fill
            , height fill
            ]
        <|
            Element.el Wrapper
                [ center
                , verticalCenter
                , maxWidth (px 800)
                , padding 60
                ]
            <|
                body



-- STYLE


type Class
    = Page
    | Wrapper
    | InProgressClass InProgress.Class
    | ReportClass Report.Class


styles : List (Style Class variation)
styles =
    [ style Page (Text.body ++ [ Color.background <| Color.rgb 242 242 242 ])
    , style Wrapper []
    , InProgress.styles
        |> Sheet.map InProgressClass identity
        |> Sheet.merge
    , Report.styles
        |> Sheet.map ReportClass identity
        |> Sheet.merge
    ]
