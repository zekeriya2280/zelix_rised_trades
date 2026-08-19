-module(exception).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([rescue/1, defer/2, on_crash/2]).
-export_type([exception/0]).

-type exception() :: {errored, gleam@dynamic:dynamic_()} | {thrown, gleam@dynamic:dynamic_()} | {exited, gleam@dynamic:dynamic_()}.

-file("src\\exception.gleam", 29).
-spec rescue(fun(() -> DKT)) -> {ok, DKT} | {error, exception()}.
-doc(~" This function will catch any crash and convert it into a result rather than
 crashing the process.

 You should ideally never use this function! Exceptions are not flow control
 in Gleam, a result type should be used instead. This function is only if you
 need to perform some cleanup when a crash occurs, and then you should favour
 `defer` if possible.
").
rescue(Body) ->
    exception_ffi:rescue(Body).

-file("src\\exception.gleam", 51).
-spec defer(fun(() -> any()), fun(() -> DKX)) -> DKX.
-doc(~" This function will run a cleanup function after the given body function, even
 if the body function crashes.

 You should ideally never use this function! Exceptions are not flow control
 in Gleam, a result type should be used instead. This function is only if you
 need to perform some cleanup when a crash occurs.

 # Examples
 
 ```gleam
 pub fn run_with_lock(f: fn() -> a) -> a {
   let lock = acquire()
   use <- defer(fn() { release(lock) })
   f()
 }
 ```
 
").
defer(Cleanup, Body) ->
    exception_ffi:defer(Cleanup, Body).

-file("src\\exception.gleam", 62).
-spec on_crash(fun(() -> any()), fun(() -> DKZ)) -> DKZ.
-doc(~" This function will run a cleanup function after the given body function,
 but only if the body function crashes.

 You should ideally never use this function! Exceptions are not flow control
 in Gleam, a result type should be used instead. This function is only if you
 need to perform some cleanup when a crash occurs.
").
on_crash(Cleanup, Body) ->
    exception_ffi:on_crash(Cleanup, Body).

