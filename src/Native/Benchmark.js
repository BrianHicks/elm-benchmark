var _user$project$Native_Benchmark = function() {
    var getTimestamp = typeof performance !== 'undefined' ?
        performance.now.bind(performance) :
        Date.now;

    function makeOperation(fn) {
        return { function: fn };
    }

    function getFunction(operation) {
        return operation.function;
    }

    // sample : Int -> Operation -> Task Error Time
    function sample(n, measurement) {
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

    // operation : (() -> a) -> Operation
    function operation(thunk) {
        return makeOperation(function() { thunk(); });
    }

    // operation1 : (a -> b) -> a -> Operation
    function operation1(fn, a) {
        return makeOperation(function() { fn(a); });
    }

    // operation2 : (a -> b -> c) -> a -> b -> Operation
    function operation2(fn, a, b) {
        return makeOperation(function() { A2(fn, a, b); });
    }

    // operation3 : (a -> b -> c -> d) -> a -> b -> c -> Operation
    function operation3(fn, a, b, c) {
        return makeOperation(function() { A3(fn, a, b, c); });
    }

    // operation4 : (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Operation
    function operation4(fn, a, b, c, d) {
        return makeOperation(function() { A4(fn, a, b, c, d); });
    }

    // operation5 : (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Operation
    function operation5(fn, a, b, c, d, e) {
        return makeOperation(function() { A5(fn, a, b, c, d, e); });
    }

    // operation6 : (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Operation
    function operation6(fn, a, b, c, d, e, f) {
        return makeOperation(function() { A6(fn, a, b, c, d, e, f); });
    }

    // operation7 : (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Operation
    function operation7(fn, a, b, c, d, e, f, g) {
        return makeOperation(function() { A7(fn, a, b, c, d, e, f, g); });
    }

    // operation8 : (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Operation
    function operation8(fn, a, b, c, d, e, f, g, h) {
        return makeOperation(function() { A8(fn, a, b, c, d, e, f, g, h); });
    }

    return {
        operation: operation,
        operation1: F2(operation1),
        operation2: F3(operation2),
        operation3: F4(operation3),
        operation4: F5(operation4),
        operation5: F6(operation5),
        operation6: F7(operation6),
        operation7: F8(operation7),
        operation8: F9(operation8),
        sample: F2(sample),
    };
}();
