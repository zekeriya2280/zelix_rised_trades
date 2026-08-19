-module(gleam@erlang@node).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([self/0, visible/0, connect/1, name/1]).
-export_type([node_/0, connect_error/0]).
-moduledoc(~" Multiple Erlang VM instances can form a cluster to make a distributed
 Erlang system, talking directly to each other using messages rather than
 other communication protocols like HTTP. In a distributed Erlang system
 each virtual machine is called a _node_. This module provides Node related
 types and functions to be used as a foundation by other packages providing
 more specialised functionality.

 For more information on distributed Erlang systems see the Erlang
 documentation: <https://www.erlang.org/doc/system/distributed.html>.").

-type node_() :: any().

-type connect_error() :: failed_to_connect | local_node_is_not_alive.

-file("src\\gleam\\erlang\\node.gleam", 18).
-spec self() -> node_().
-doc(~" Return the current node.
").
self() ->
    erlang:node().

-file("src\\gleam\\erlang\\node.gleam", 31).
-spec visible() -> list(node_()).
-doc(~" Return a list of all visible nodes in the cluster, not including the current
 node.

 The current node can be included by calling `self()` and prepending the
 result.

 ```gleam
 let all_nodes = [node.self(), ..node.visible()]
 ```
").
visible() ->
    erlang:nodes().

-file("src\\gleam\\erlang\\node.gleam", 52).
-spec connect(gleam@erlang@atom:atom_()) -> {ok, node_()} | {error, connect_error()}.
-doc(~" Establish a connection to a node, so the nodes can send messages to each
 other and any other connected nodes.

 Returns `Error(FailedToConnect)` if the node is not reachable.

 Returns `Error(LocalNodeIsNotAlive)` if the local node is not alive, meaning
 it is not running in distributed mode.
").
connect(Node) ->
    gleam_erlang_ffi:connect_node(Node).

-file("src\\gleam\\erlang\\node.gleam", 63).
-spec name(node_()) -> gleam@erlang@atom:atom_().
-doc(~" Get the atom name of a node.

 ## Examples

 ```gleam
 assert name(my_node) == atom.create(\"app1@localhost\")
 ```
").
name(Node) ->
    gleam_erlang_ffi:identity(Node).

