-module(gleam@erlang@reference).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([new/0]).
-export_type([reference_/0]).

-type reference_() :: any().

-file("src\\gleam\\erlang\\reference.gleam", 15).
-spec new() -> reference_().
-doc(~" Create a new unique reference.
").
new() ->
    erlang:make_ref().

