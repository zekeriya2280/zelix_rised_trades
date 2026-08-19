-module(server@router).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([handle/2]).
-export_type([ws_state/0]).

-type ws_state() :: {ws_state, gleam@erlang@process:subject(game_server:message()), gleam@option:option(integer())}.

-file("src\\server\\router.gleam", 179).
-spec text(integer(), binary()) -> gleam@http@response:response(mist:response_data()).
text(Status, Body) ->
    _pipe = gleam@http@response:new(Status),
    _pipe@1 = gleam@http@response:set_header(_pipe, ~"content-type", ~"text/plain; charset=utf-8"),
    gleam@http@response:set_body(_pipe@1, {bytes, gleam_stdlib:wrap_list(Body)}).

-file("src\\server\\router.gleam", 185).
-spec auth_response(gleam@http@request:request(mist@internal@http:connection()), binary()) -> gleam@http@response:response(mist:response_data()).
auth_response(Request, Action) ->
    case erlang:element(2, Request) of
        post ->
            case mist:read_body(Request, 64 * 1024) of
                {ok, Body_request} ->
                    Result = server@auth:handle(Action, erlang:element(4, Body_request)),
                    Body = begin
                        _pipe = gleam@json:object([{~"ok", gleam@json:bool(erlang:element(2, Result))}, {~"message", gleam@json:string(erlang:element(3, Result))}, {~"nickname", gleam@json:string(erlang:element(4, Result))}, {~"token", gleam@json:string(erlang:element(5, Result))}]),
                        gleam@json:to_string(_pipe)
                    end,
                    Status = case erlang:element(2, Result) of
                        true ->
                            200;

                        false ->
                            401
                    end,
                    _pipe@1 = gleam@http@response:new(Status),
                    _pipe@2 = gleam@http@response:set_header(_pipe@1, ~"content-type", ~"application/json"),
                    gleam@http@response:set_body(_pipe@2, {bytes, gleam_stdlib:wrap_list(Body)});

                {error, _} ->
                    text(400, ~"invalid request body")
            end;

        _ ->
            text(405, ~"method not allowed")
    end.

-file("src\\server\\router.gleam", 172).
-spec disconnect_player(ws_state()) -> nil.
disconnect_player(State) ->
    case erlang:element(3, State) of
        {some, Player_id} ->
            gleam@erlang@process:send(erlang:element(2, State), {leave_player, Player_id});

        none ->
            nil
    end.

-file("src\\server\\router.gleam", 168).
-spec ignore_send(mist@internal@websocket:websocket_connection(), server@messages:server_message()) -> {ok, nil} | {error, glisten@socket:socket_reason()}.
ignore_send(Connection, Message) ->
    _ = mist:send_text_frame(Connection, server@messages:encode_server(Message)).

-file("src\\server\\router.gleam", 163).
-spec send_and_continue(ws_state(), mist@internal@websocket:websocket_connection(), server@messages:server_message()) -> mist:next(ws_state(), nil).
send_and_continue(State, Connection, Message) ->
    _ = ignore_send(Connection, Message),
    mist:continue(State).

-file("src\\server\\router.gleam", 143).
-spec send_snapshot_for(ws_state(), mist@internal@websocket:websocket_connection()) -> {ok, nil} | {error, binary()}.
send_snapshot_for(State, Connection) ->
    case erlang:element(3, State) of
        none ->
            {error, ~"Authentication required."};

        {some, Player_id} ->
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(erlang:element(2, State), {get_snapshot, Player_id, Reply}),
            case gleam@erlang@process:'receive'(Reply, 1000) of
                {ok, {ok, Snapshot}} ->
                    case mist:send_text_frame(Connection, Snapshot) of
                        {ok, nil} ->
                            {ok, nil};

                        {error, _} ->
                            {error, ~"Failed to send snapshot."}
                    end;

                {ok, {error, Message}} ->
                    {error, Message};

                {error, nil} ->
                    {error, ~"World timeout."}
            end
    end.

-file("src\\server\\router.gleam", 81).
-spec handle_snapshot(ws_state(), mist@internal@websocket:websocket_connection()) -> mist:next(ws_state(), nil).
handle_snapshot(State, Connection) ->
    case erlang:element(3, State) of
        none ->
            send_and_continue(State, Connection, {server_error, ~"Authentication required."});

        {some, _} ->
            case send_snapshot_for(State, Connection) of
                {ok, _} ->
                    mist:continue(State);

                {error, Message} ->
                    send_and_continue(State, Connection, {server_error, Message})
            end
    end.

-file("src\\server\\router.gleam", 135).
-spec send_command_result(ws_state(), mist@internal@websocket:websocket_connection(), gleam@erlang@process:subject({ok, nil} | {error, binary()})) -> mist:next(ws_state(), nil).
send_command_result(State, Connection, Reply) ->
    case gleam@erlang@process:'receive'(Reply, 1000) of
        {ok, {ok, nil}} ->
            handle_snapshot(State, Connection);

        {ok, {error, Message}} ->
            send_and_continue(State, Connection, {command_rejected, Message});

        {error, nil} ->
            send_and_continue(State, Connection, {server_error, ~"World timeout."})
    end.

-file("src\\server\\router.gleam", 124).
-spec handle_set_factory_product(ws_state(), mist@internal@websocket:websocket_connection(), integer(), server@messages:product_type()) -> mist:next(ws_state(), nil).
handle_set_factory_product(State, Connection, Id, Product) ->
    case erlang:element(3, State) of
        none ->
            send_and_continue(State, Connection, {server_error, ~"Authentication required."});

        {some, Player_id} ->
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(erlang:element(2, State), {set_factory_product, Player_id, Id, Product, Reply}),
            send_command_result(State, Connection, Reply)
    end.

-file("src\\server\\router.gleam", 113).
-spec handle_spawn_vehicle(ws_state(), mist@internal@websocket:websocket_connection(), float(), float(), float(), float(), float()) -> mist:next(ws_state(), nil).
handle_spawn_vehicle(State, Connection, X, Y, Tx, Ty, Speed) ->
    case erlang:element(3, State) of
        none ->
            send_and_continue(State, Connection, {server_error, ~"Authentication required."});

        {some, Player_id} ->
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(erlang:element(2, State), {spawn_vehicle, Player_id, X, Y, Tx, Ty, Speed, Reply}),
            send_command_result(State, Connection, Reply)
    end.

-file("src\\server\\router.gleam", 102).
-spec handle_build_structure(ws_state(), mist@internal@websocket:websocket_connection(), server@messages:building_type(), float(), float()) -> mist:next(ws_state(), nil).
handle_build_structure(State, Connection, Building, X, Y) ->
    case erlang:element(3, State) of
        none ->
            send_and_continue(State, Connection, {server_error, ~"Authentication required."});

        {some, Player_id} ->
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(erlang:element(2, State), {build_structure, Player_id, Building, X, Y, Reply}),
            send_command_result(State, Connection, Reply)
    end.

-file("src\\server\\router.gleam", 91).
-spec handle_build_bank(ws_state(), mist@internal@websocket:websocket_connection(), float(), float()) -> mist:next(ws_state(), nil).
handle_build_bank(State, Connection, X, Y) ->
    case erlang:element(3, State) of
        none ->
            send_and_continue(State, Connection, {server_error, ~"Authentication required."});

        {some, Player_id} ->
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(erlang:element(2, State), {build_bank, Player_id, X, Y, Reply}),
            send_command_result(State, Connection, Reply)
    end.

-file("src\\server\\router.gleam", 51).
-spec handle_join(ws_state(), mist@internal@websocket:websocket_connection(), binary(), binary()) -> mist:next(ws_state(), nil).
handle_join(State, Connection, Name, Token) ->
    case erlang:element(3, State) of
        {some, _} ->
            send_and_continue(State, Connection, {server_error, ~"Already authenticated."});

        none ->
            case Token =:= ~"" of
                true ->
                    send_and_continue(State, Connection, {server_error, ~"Authentication required."});

                false ->
                    case server@auth:verify_token(Token) of
                        {error, _} ->
                            send_and_continue(State, Connection, {server_error, ~"Invalid authentication token."});

                        {ok, Uid} ->
                            Reply = gleam@erlang@process:new_subject(),
                            gleam@erlang@process:send(erlang:element(2, State), {join_player, Uid, Name, Reply}),
                            case gleam@erlang@process:'receive'(Reply, 1000) of
                                {ok, {ok, Player_id}} ->
                                    New_state = {ws_state, erlang:element(2, State), {some, Player_id}},
                                    case send_snapshot_for(New_state, Connection) of
                                        {ok, _} ->
                                            _ = ignore_send(Connection, {welcome, Player_id}),
                                            mist:continue(New_state);

                                        {error, Message} ->
                                            send_and_continue(New_state, Connection, {server_error, Message})
                                    end;

                                {ok, {error, Message@1}} ->
                                    send_and_continue(State, Connection, {server_error, Message@1});

                                {error, nil} ->
                                    send_and_continue(State, Connection, {server_error, ~"World timeout."})
                            end
                    end
            end
    end.

-file("src\\server\\router.gleam", 32).
-spec handle_ws(ws_state(), mist:websocket_message(nil), mist@internal@websocket:websocket_connection()) -> mist:next(ws_state(), nil).
handle_ws(State, Message, Connection) ->
    case Message of
        {text, Text} ->
            case server@messages:decode_client(Text) of
                {ok, {join, Name, Token}} ->
                    handle_join(State, Connection, Name, Token);

                {ok, ping} ->
                    send_and_continue(State, Connection, pong);

                {ok, request_snapshot} ->
                    handle_snapshot(State, Connection);

                {ok, {build_bank, X, Y}} ->
                    handle_build_bank(State, Connection, X, Y);

                {ok, {build_structure, Building, X@1, Y@1}} ->
                    handle_build_structure(State, Connection, Building, X@1, Y@1);

                {ok, {spawn_vehicle, X@2, Y@2, Tx, Ty, Speed}} ->
                    handle_spawn_vehicle(State, Connection, X@2, Y@2, Tx, Ty, Speed);

                {ok, {set_factory_product, Id, Product}} ->
                    handle_set_factory_product(State, Connection, Id, Product);

                {error, Message@1} ->
                    send_and_continue(State, Connection, {server_error, Message@1})
            end;

        closed ->
            mist:stop();

        shutdown ->
            mist:stop();

        _ ->
            mist:continue(State)
    end.

-file("src\\server\\router.gleam", 17).
-spec handle(gleam@http@request:request(mist@internal@http:connection()), gleam@erlang@process:subject(game_server:message())) -> gleam@http@response:response(mist:response_data()).
handle(Request, World) ->
    case erlang:element(8, Request) of
        ~"/ws" ->
            mist:websocket(Request, fun handle_ws/3, fun(_) ->
                {{ws_state, World, none}, none}
            end, fun(State) ->
                disconnect_player(State)
            end);

        ~"/health" ->
            text(200, ~"ok");

        ~"/auth/login" ->
            auth_response(Request, ~"login");

        ~"/auth/register" ->
            auth_response(Request, ~"register");

        _ ->
            text(404, ~"not found")
    end.

