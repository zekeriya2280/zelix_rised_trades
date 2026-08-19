-module(mist@internal@buffer).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([empty/0, new/1, append/2, slice/2, with_capacity/2, size/1]).
-export_type([buffer/0]).
-moduledoc(false).

-type buffer() :: {buffer, integer(), bitstring()}.

-file("src\\mist\\internal\\buffer.gleam", 8).
-spec empty() -> buffer().
-doc(false).
empty() ->
    {buffer, 0, <<>>}.

-file("src\\mist\\internal\\buffer.gleam", 12).
-spec new(bitstring()) -> buffer().
-doc(false).
new(Data) ->
    {buffer, 0, Data}.

-file("src\\mist\\internal\\buffer.gleam", 16).
-spec append(buffer(), bitstring()) -> buffer().
-doc(false).
append(Buffer, Data) ->
    Data_size = erlang:byte_size(Data),
    Remaining = gleam@int:max(erlang:element(2, Buffer) - Data_size, 0),
    {buffer, Remaining, <<(erlang:element(3, Buffer))/bitstring, Data/bitstring>>}.

-file("src\\mist\\internal\\buffer.gleam", 22).
-spec slice(buffer(), integer()) -> {bitstring(), bitstring()}.
-doc(false).
slice(Buffer, Bits) ->
    Bytes = Bits * 8,
    case erlang:element(3, Buffer) of
        <<Value:Bytes/bitstring, Rest/bitstring>> ->
            {Value, Rest};

        _ ->
            {erlang:element(3, Buffer), <<>>}
    end.

-file("src\\mist\\internal\\buffer.gleam", 30).
-spec with_capacity(buffer(), integer()) -> buffer().
-doc(false).
with_capacity(Buffer, Size) ->
    {buffer, Size, erlang:element(3, Buffer)}.

-file("src\\mist\\internal\\buffer.gleam", 34).
-spec size(integer()) -> buffer().
-doc(false).
size(Remaining) ->
    {buffer, Remaining, <<>>}.

