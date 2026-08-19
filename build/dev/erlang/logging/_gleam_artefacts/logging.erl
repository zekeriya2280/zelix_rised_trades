-module(logging).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([configure/0, log/2, set_level/1]).
-export_type([log_level/0, do_not_leak/0, key/0]).

-type log_level() :: emergency | alert | critical | error | warning | notice | info | debug.

-type do_not_leak() :: any().

-type key() :: level.

-file("src\\logging.gleam", 25).
-spec configure() -> nil.
-doc(~" Configure the default Erlang logger handler with a pretty Gleam output
 format, and sets the logging level to `Info`.

 ## Interaction with Elixir

 Elixir's built-in `logger` application removes Erlang's default logger
 handler and replaces it with its own code, so if you have an Elixir package
 in your project then this code will not be able to configure the logger as
 it could normally.
").
configure() ->
    logging_ffi:configure().

-file("src\\logging.gleam", 29).
-spec log(log_level(), binary()) -> nil.
-doc(~" Log a message to the Erlang logger at the given log level.
").
log(Level, Message) ->
    logger:log(Level, Message),
    nil.

-file("src\\logging.gleam", 42).
-spec set_level(log_level()) -> nil.
-doc(~" Change the log visibility level to be output.
").
set_level(Level) ->
    logger:set_primary_config(level, Level),
    nil.

