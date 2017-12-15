module Benchmark.Runner.Humanize exposing (int, percent)


int : Int -> String
int =
    toString


percent : Float -> String
percent =
    (*) 10000
        >> round
        >> toFloat
        >> flip (/) 100
        >> toString
        >> flip (++) "%"
