module Benchmark.Runner exposing (..)

{-| HTML Benchmark Runner

@docs program, BenchmarkProgram
-}

import Benchmark exposing (Benchmark)
import Html exposing (Html)
import List.Extra as List
import Process
import Task exposing (Task)
import Time


type alias Model =
    Benchmark



-- path calculation for updates


type Segment
    = Index Int


type alias Path =
    List Segment


toList : Benchmark -> List ( Path, Benchmark )
toList benchmark =
    case benchmark of
        Benchmark.Benchmark _ _ _ ->
            [ ( [], benchmark ) ]

        Benchmark.Group _ benchmarks ->
            benchmarks
                |> List.map toList
                |> List.indexedMap
                    (\i subs ->
                        List.map
                            (\( path, b ) -> ( Index i :: path, b ))
                            subs
                    )
                |> List.concat


updateAt : Path -> Benchmark -> Benchmark -> Maybe Benchmark
updateAt path updated collection =
    case ( path, collection ) of
        ( (Index i) :: rest, Benchmark.Group name benchmarks ) ->
            benchmarks
                |> List.getAt i
                |> Maybe.andThen (updateAt rest updated)
                |> Maybe.andThen (\new -> List.setAt i new benchmarks)
                |> Maybe.map (Benchmark.Group name)

        ( [], _ ) ->
            Just updated

        _ ->
            Nothing



-- Elm Architecture stuff


breakForRender : Task x a -> Task x a
breakForRender task =
    Task.andThen (\_ -> task) (Process.sleep Time.millisecond)


init : Benchmark -> ( Model, Cmd Msg )
init benchmark =
    ( benchmark
    , benchmark
        |> toList
        |> List.map
            (\( path, benchmark ) ->
                Task.perform (Sized path) (Benchmark.size benchmark |> breakForRender)
            )
        |> Cmd.batch
    )


type Msg
    = Sized Path Benchmark
    | Complete Path Benchmark


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case (msg |> Debug.log "msg") of
        Sized path benchmark ->
            ( updateAt path benchmark model |> Maybe.withDefault model
            , Task.perform (Complete path) (Benchmark.measure benchmark |> breakForRender)
            )

        Complete path benchmark ->
            ( updateAt path benchmark model |> Maybe.withDefault model
            , Cmd.none
            )


benchmarkView : Benchmark -> Html Msg
benchmarkView benchmark =
    let
        statusView : String -> Benchmark.Status -> Html Msg
        statusView name status =
            case status of
                Benchmark.ToSize (Benchmark.Timebox time) ->
                    Html.p [] [ Html.text <| "Needs sizing into " ++ toString (Time.inSeconds time) ++ " second(s)" ]

                Benchmark.Pending n ->
                    Html.p [] [ Html.text <| toString n ++ " iterations pending" ]

                Benchmark.Failure err ->
                    Html.p [] [ Html.text <| "Benchmark \"" ++ name ++ "\" failed: " ++ toString err ]

                Benchmark.Success ( sampleSize, meanTime ) ->
                    Html.dl []
                        [ Html.dt [] [ Html.text "Sample Size" ]
                        , Html.dd [] [ Html.text <| toString sampleSize ++ " runs" ]
                        , Html.dt [] [ Html.text "Mean Run Time" ]
                        , Html.dd [] [ Html.text <| toString meanTime ++ " ms/run" ]
                        ]
    in
        case benchmark of
            Benchmark.Benchmark name _ status ->
                Html.section []
                    [ Html.h1 [] [ Html.text <| "Benchmark: " ++ name ]
                    , statusView name status
                    ]

            Benchmark.Group name benchmarks ->
                Html.section
                    []
                    [ Html.h1 [] [ Html.text <| "Suite: " ++ name ]
                    , benchmarks
                        |> List.map
                            (benchmarkView
                                >> (\x -> Html.li [] [ x ])
                            )
                        |> Html.ul []
                    ]


view : Model -> Html Msg
view =
    benchmarkView


{-| Create a runner program from a benchmark
-}
program : Benchmark -> Program Never Model Msg
program benchmark =
    Html.program
        { init = init benchmark
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }


{-| -}
type alias BenchmarkProgram =
    Program Never Model Msg
