var _BrianHicks$elm_benchmark$Native_Benchmark = function() {
    var getTimestamp = typeof performance !== 'undefined' ?
        performance.now.bind(performance) :
        Date.now;

    function measurement(fn) {
        return { function: fn };
    }

    function getFunction(measurement) {
        return measurement.function;
    }

    // runTimes : Int -> Measurement -> Task Error Time
    function runTimes(n, measurement) {
        return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
            try {
                var fn = getFunction(measurement),
                    start = getTimestamp();

                for (var i = 0; i < n; i++) {
                    fn();
                }

                callback(_elm_lang$core$Native_Scheduler.succeed(getTimestamp() - start));
            } catch (error) {
                var elmError;

                if (error instanceof RangeError) {
                    elmError = { ctor : 'StackOverflow' };
                } else {
                    elmError = { ctor : 'UnknownError', _0: error.message };
                }

                callback(_elm_lang$core$Native_Scheduler.fail(elmError));
            }
        })
    }

    // measure : (() -> a) -> Measurement
    function measure(thunk) {
        return measurement(fn);
    }

    // measure1 : (a -> b) -> a -> Measurement
    function measure1(fn, a) {
        return measurement(function() { fn(a); });
    }

    // measure2 : (a -> b -> c) -> a -> b -> Measurement
    function measure2(fn, a, b) {
        return measurement(function() { A2(fn, a, b); });
    }

    // measure3 : (a -> b -> c -> d) -> a -> b -> c -> Measurement
    function measure3(fn, a, b, c) {
        return measurement(function() { A3(fn, a, b, c); });
    }

    // measure4 : (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Measurement
    function measure4(fn, a, b, c, d) {
        return measurement(function() { A4(fn, a, b, c, d); });
    }

    // measure5 : (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Measurement
    function measure5(fn, a, b, c, d, e) {
        return measurement(function() { A5(fn, a, b, c, d, e); });
    }

    // measure6 : (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Measurement
    function measure6(fn, a, b, c, d, e, f) {
        return measurement(function() { A6(fn, a, b, c, d, e, f); });
    }

    // measure7 : (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Measurement
    function measure7(fn, a, b, c, d, e, f, g) {
        return measurement(function() { A7(fn, a, b, c, d, e, f, g); });
    }

    // measure8 : (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Measurement
    function measure8(fn, a, b, c, d, e, f, g, h) {
        return measurement(function() { A8(fn, a, b, c, d, e, f, g, h); });
    }

    return {
        measure: measure,
        measure1: F2(measure1),
        measure2: F3(measure2),
        measure3: F4(measure3),
        measure4: F5(measure4),
        measure5: F6(measure5),
        measure6: F7(measure6),
        measure7: F8(measure7),
        measure8: F9(measure8),
        runTimes: F2(runTimes),
    };
}();
