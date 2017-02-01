var _BrianHicks$elm_benchmark$Native_Benchmark = function() {
    var getTimestamp = typeof performance !== 'undefined' ?
    performance.now.bind(performance) :
    Date.now;

    // TODO: docs for determineError
    function determineError(error) {
        var elmError;

        if (error instanceof RangeError) {
            elmError = { ctor : 'StackOverflow' };
        } else {
            elmError = { ctor : 'UnknownError', _0: error.message };
        }

        return _elm_lang$core$Native_Scheduler.fail(elmError);
    }

    // TODO: docs for timingToTask
    function timingToTask(start, end)  {
        return _elm_lang$core$Native_Scheduler.succeed(end - start);
    }

    // TODO: docs for runAndHandleErrors
    function runAndHandleErrors(toRun) {
        return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
            try {
                callback(toRun());
            } catch (error) {
                callback(determineError(error))
            }
        });
    }

    // measure : (() -> a) -> Task Error Time
    function measure(thunk) {
        return runAndHandleErrors(function() {
            var start = getTimestamp();
            thunk();
            return timingToTask(start, getTimestamp());
        });
    }

    // measure1 : (a -> b) -> a -> Task Error Time
    function measure1(fn, a) {
        return runAndHandleErrors(function() {
            var start = getTimestamp();
            fn(a);
            return timingToTask(start, getTimestamp());
        });
    }

    // measure2 : (a -> b -> c) -> a -> b -> Task Error Time
    function measure2(fn, a, b) {
        return runAndHandleErrors(function() {
            var start = getTimestamp();
            A2(fn, a, b);
            return timingToTask(start, getTimestamp());
        });
    }

    // measure3 : (a -> b -> c -> d) -> a -> b -> c -> Task Error Time
    function measure3(fn, a, b, c) {
        return runAndHandleErrors(function() {
            var start = getTimestamp();
            A3(fn, a, b, c);
            return timingToTask(start, getTimestamp());
        });
    }

    // measure4 : (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Task Error Time
    function measure4(fn, a, b, c, d) {
        return runAndHandleErrors(function() {
            var start = getTimestamp();
            A4(fn, a, b, c, d);
            return timingToTask(start, getTimestamp());
        });
    }

    // measure5 : (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Task Error Time
    function measure5(fn, a, b, c, d, e) {
        return runAndHandleErrors(function() {
            var start = getTimestamp();
            A5(fn, a, b, c, d, e);
            return timingToTask(start, getTimestamp());
        });
    }

    // measure6 : (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Task Error Time
    function measure6(fn, a, b, c, d, e, f) {
        return runAndHandleErrors(function() {
            var start = getTimestamp();
            A6(fn, a, b, c, d, e, f);
            return timingToTask(start, getTimestamp());
        });
    }

    // measure7 : (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Task Error Time
    function measure7(fn, a, b, c, d, e, f, g) {
        return runAndHandleErrors(function() {
            var start = getTimestamp();
            A7(fn, a, b, c, d, e, f, g);
            return timingToTask(start, getTimestamp());
        });
    }

    // measure8 : (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Task Error Time
    function measure8(fn, a, b, c, d, e, f, g, h) {
        return runAndHandleErrors(function() {
            var start = getTimestamp();
            A8(fn, a, b, c, d, e, f, g, h);
            return timingToTask(start, getTimestamp());
        });
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
        measure8: F9(measure8)
    };
}();
