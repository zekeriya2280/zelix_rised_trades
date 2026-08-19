-module(gleam@erlang@application).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([priv_directory/1]).
-export_type([start_type/0]).
-moduledoc(~" An Erlang application is a collection of code that can be loaded into the
 Erlang virtual machine and even started and stopped if they define a
 start module and supervision tree. Each Gleam package is an Erlang
 application.").

-type start_type() :: normal | {takeover, gleam@erlang@node:node_()} | {failover, gleam@erlang@node:node_()}.

-file("src\\gleam\\erlang\\application.gleam", 37).
-spec priv_directory(binary()) -> {ok, binary()} | {error, nil}.
-doc(~" Returns the path of an application's `priv` directory, where extra non-Gleam
 or Erlang files are typically kept. Each Gleam package is an Erlang
 application.

 Returns an error if no application was found with the given name.

 # Example

 ```gleam
 application.priv_directory(\"my_app\")
 // -> Ok(\"/some/location/my_app/priv\")
 ```
").
priv_directory(Name) ->
    gleam_erlang_ffi:priv_directory(Name).

