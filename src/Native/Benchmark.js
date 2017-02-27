var _BrianHicks$elm_benchmark$Native_Benchmark = function() {
    var getTimestamp = typeof performance !== 'undefined' ?
        performance.now.bind(performance) :
        Date.now;

    // sample : Int -> Operation -> Task Error Time
    function sample(n, fn) {
        return _elm_lang$core$Native_Scheduler.nativeBinding(function(callback) {
            var start = getTimestamp();

            try {
                for (var i = 0; i < n; i++) {
                    fn();
                }
            } catch (error) {
                if (error instanceof RangeError) {
                    callback(_elm_lang$core$Native_Scheduler.fail({ ctor : 'StackOverflow' }));
                } else {
                    callback(_elm_lang$core$Native_Scheduler.fail({ ctor : 'UnknownError', _0: error.message }));
                }
                return;
            }

            var end = getTimestamp();

            callback(_elm_lang$core$Native_Scheduler.succeed(end - start));
        });
    }

    // operation : (() -> a) -> Operation
    function operation(thunk) {
        return function() { thunk(); };
    }

    // operation1 : (a -> b) -> a -> Operation
    function operation1(fn, a) {
        return function() { fn(a); };
    }

    // operation2 : (a -> b -> c) -> a -> b -> Operation
    function operation2(fn, a, b) {
        return function() { A2(fn, a, b); };
    }

    // operation3 : (a -> b -> c -> d) -> a -> b -> c -> Operation
    function operation3(fn, a, b, c) {
        return function() { A3(fn, a, b, c); };
    }

    // operation4 : (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Operation
    function operation4(fn, a, b, c, d) {
        return function() { A4(fn, a, b, c, d); };
    }

    // operation5 : (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Operation
    function operation5(fn, a, b, c, d, e) {
        return function() { A5(fn, a, b, c, d, e); };
    }

    // operation6 : (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Operation
    function operation6(fn, a, b, c, d, e, f) {
        return function() { A6(fn, a, b, c, d, e, f); };
    }

    // operation7 : (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Operation
    function operation7(fn, a, b, c, d, e, f, g) {
        return function() { A7(fn, a, b, c, d, e, f, g); };
    }

    // operation8 : (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Operation
    function operation8(fn, a, b, c, d, e, f, g, h) {
        return function() { A8(fn, a, b, c, d, e, f, g, h); };
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
