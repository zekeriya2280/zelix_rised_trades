-module(mist@internal@file).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([error_to_string/1, open/1, stat/1, sendfile/6, close/1]).
-export_type([file_descriptor/0, file_error/0, send_error/0, file/0]).
-moduledoc(false).

-type file_descriptor() :: any().

-type file_error() :: is_dir | no_access | no_entry | unknown_file_error.

-type send_error() :: {file_err, file_error()} | {socket_err, glisten@socket:socket_reason()}.

-type file() :: {file, file_descriptor(), integer()}.

-file("src\\mist\\internal\\file.gleam", 15).
-spec error_to_string(file_error()) -> binary().
-doc(false).
error_to_string(Error) ->
    case Error of
        is_dir ->
            ~"IsDir";

        no_access ->
            ~"NoAccess";

        no_entry ->
            ~"NoEntry";

        unknown_file_error ->
            ~"UnknownFileError"
    end.

-file("src\\mist\\internal\\file.gleam", 84).
-spec open(bitstring()) -> {ok, file_descriptor()} | {error, file_error()}.
-doc(false).
open(File) ->
    mist_ffi:file_open(File).

-file("src\\mist\\internal\\file.gleam", 33).
-spec stat(bitstring()) -> {ok, file()} | {error, file_error()}.
-doc(false).
stat(Filename) ->
    _pipe = Filename,
    _pipe@1 = mist_ffi:file_open(_pipe),
    gleam@result:map(_pipe@1, fun(Fd) ->
        File_size = filelib:file_size(Filename),
        {file, Fd, File_size}
    end).

-file("src\\mist\\internal\\file.gleam", 42).
-spec sendfile(glisten@transport:transport(), file_descriptor(), glisten@socket:socket(), integer(), integer(), list(any())) -> {ok, nil} | {error, send_error()}.
-doc(false).
sendfile(Transport, File_descriptor, Socket, Offset, Bytes, Options) ->
    case Transport of
        tcp ->
            _pipe = file:sendfile(File_descriptor, Socket, Offset, Bytes, Options),
            _pipe@1 = gleam@result:map_error(_pipe, fun(_value) ->
                {socket_err, _value}
            end),
            gleam@result:replace(_pipe@1, nil);

        ssl = Transport@1 ->
            _pipe@2 = file:pread(File_descriptor, Offset, Bytes),
            _pipe@3 = gleam@result:map_error(_pipe@2, fun(_value@1) ->
                {file_err, _value@1}
            end),
            gleam@result:'try'(_pipe@3, fun(Bits) ->
                _pipe@4 = glisten@transport:send(Transport@1, Socket, gleam@bytes_tree:from_bit_array(Bits)),
                gleam@result:map_error(_pipe@4, fun(_value@2) ->
                    {socket_err, _value@2}
                end)
            end)
    end.

-file("src\\mist\\internal\\file.gleam", 90).
-spec close(file_descriptor()) -> {ok, nil} | {error, file_error()}.
-doc(false).
close(File) ->
    mist_ffi:file_close(File).

