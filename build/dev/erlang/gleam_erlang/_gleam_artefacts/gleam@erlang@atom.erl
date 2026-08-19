-module(gleam@erlang@atom).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([get/1, create/1, to_string/1, to_dynamic/1, cast_from_dynamic/1, decoder/0]).
-export_type([atom_/0]).

-type atom_() :: any().

-file("src\\gleam\\erlang\\atom.gleam", 27).
-spec get(binary()) -> {ok, atom_()} | {error, nil}.
-doc(~" Finds an existing atom for the given string.

 If no atom is found in the virtual machine's atom table for the string then
 an error is returned.
").
get(A) ->
    gleam_erlang_ffi:atom_from_string(A).

-file("src\\gleam\\erlang\\atom.gleam", 39).
-spec create(binary()) -> atom_().
-doc(~" Creates an atom from a string, inserting a new value into the virtual
 machine's atom table if an atom does not already exist for the given
 string.

 We must be careful when using this function as there is a limit to the
 number of atom that can fit in the virtual machine's atom table. Never
 convert user input into atoms as filling the atom table will cause the
 virtual machine to crash!
").
create(A) ->
    erlang:binary_to_atom(A).

-file("src\\gleam\\erlang\\atom.gleam", 52).
-spec to_string(atom_()) -> binary().
-doc(~" Returns a `String` corresponding to the text representation of the given
 `Atom`.

 ## Examples
 ```gleam
 let ok_atom = create(\"ok\")
 to_string(ok_atom)
 // -> \"ok\"
 ```
").
to_string(A) ->
    erlang:atom_to_binary(A).

-file("src\\gleam\\erlang\\atom.gleam", 59).
-spec to_dynamic(atom_()) -> gleam@dynamic:dynamic_().
-doc(~" Convert an atom to a dynamic value, throwing away the type information. 

 This may be useful for testing decoders.
").
to_dynamic(A) ->
    gleam_erlang_ffi:identity(A).

-file("src\\gleam\\erlang\\atom.gleam", 62).
-spec cast_from_dynamic(gleam@dynamic:dynamic_()) -> atom_().
cast_from_dynamic(A) ->
    gleam_erlang_ffi:identity(A).

-file("src\\gleam\\erlang\\atom.gleam", 71).
-spec decoder() -> gleam@dynamic@decode:decoder(atom_()).
-doc(~" A dynamic decoder for atoms.

 You almost certainly should not use this to work with externally defined
 functions. They return known types, so you should define the external
 functions with the correct types, defining wrapper functions in Erlang if
 the external types cannot be mapped directly onto Gleam types.
").
decoder() ->
    gleam@dynamic@decode:new_primitive_decoder(~"Atom", fun(Data) ->
        case erlang:is_atom(Data) of
            true ->
                {ok, gleam_erlang_ffi:identity(Data)};

            false ->
                {error, erlang:binary_to_atom(~"nil")}
        end
    end).

