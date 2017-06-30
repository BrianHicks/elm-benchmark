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
        return thunk;
    }

    return {
        operation: operation,
        sample: F2(sample),
    };
}();
