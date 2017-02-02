var _BrianHicks$elm_benchmark$Native_Benchmark = function() {
    var getTimestamp = typeof performance !== 'undefined' ?
        performance.now.bind(performance) :
        Date.now;

    function makeSample(fn) {
        return { function: fn };
    }

    function getFunction(sample) {
        return sample.function;
    }

    // takeSamples : Int -> Sample -> Task Error Time
    function takeSamples(n, measurement) {
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

    // sample : (() -> a) -> Sample
    function sample(thunk) {
        return makeSample(fn);
    }

    // sample1 : (a -> b) -> a -> Sample
    function sample1(fn, a) {
        return makeSample(function() { fn(a); });
    }

    // sample2 : (a -> b -> c) -> a -> b -> Sample
    function sample2(fn, a, b) {
        return makeSample(function() { A2(fn, a, b); });
    }

    // sample3 : (a -> b -> c -> d) -> a -> b -> c -> Sample
    function sample3(fn, a, b, c) {
        return makeSample(function() { A3(fn, a, b, c); });
    }

    // sample4 : (a -> b -> c -> d -> e) -> a -> b -> c -> d -> Sample
    function sample4(fn, a, b, c, d) {
        return makeSample(function() { A4(fn, a, b, c, d); });
    }

    // sample5 : (a -> b -> c -> d -> e -> f) -> a -> b -> c -> d -> e -> Sample
    function sample5(fn, a, b, c, d, e) {
        return makeSample(function() { A5(fn, a, b, c, d, e); });
    }

    // sample6 : (a -> b -> c -> d -> e -> f -> g) -> a -> b -> c -> d -> e -> f -> Sample
    function sample6(fn, a, b, c, d, e, f) {
        return makeSample(function() { A6(fn, a, b, c, d, e, f); });
    }

    // sample7 : (a -> b -> c -> d -> e -> f -> g -> h) -> a -> b -> c -> d -> e -> f -> g -> Sample
    function sample7(fn, a, b, c, d, e, f, g) {
        return makeSample(function() { A7(fn, a, b, c, d, e, f, g); });
    }

    // sample8 : (a -> b -> c -> d -> e -> f -> g -> h -> i) -> a -> b -> c -> d -> e -> f -> g -> h -> Sample
    function sample8(fn, a, b, c, d, e, f, g, h) {
        return makeSample(function() { A8(fn, a, b, c, d, e, f, g, h); });
    }

    return {
        sample: sample,
        sample1: F2(sample1),
        sample2: F3(sample2),
        sample3: F4(sample3),
        sample4: F5(sample4),
        sample5: F6(sample5),
        sample6: F7(sample6),
        sample7: F8(sample7),
        sample8: F9(sample8),
        takeSamples: F2(takeSamples),
    };
}();
