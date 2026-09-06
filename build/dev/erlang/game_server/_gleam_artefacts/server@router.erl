-module(server@router).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([handle/2]).
-export_type([ws_state/0]).

-type ws_state() :: {ws_state, gleam@erlang@process:subject(game_server:message()), gleam@option:option(integer())}.

-file("src\\server\\router.gleam", 21).
-spec allowed_origin() -> binary().
-doc(~" CORS origin for the auth endpoints. Defaults to \"*\" for local/dev use
 (matching the project's previous behavior), but production deployments
 should set the ALLOWED_ORIGIN environment variable to their real Web
 origin (e.g. \"https://play.example.com\") to avoid allowing arbitrary
 third-party sites to call the authenticated endpoints from a browser.").
allowed_origin() ->
    case game_server_os_ffi:get_env(~"ALLOWED_ORIGIN") of
        {ok, Value} ->
            Value;

        {error, _} ->
            ~"*"
    end.

-file("src\\server\\router.gleam", 753).
-spec text(integer(), binary()) -> gleam@http@response:response(mist:response_data()).
text(Status, Body) ->
    _pipe = gleam@http@response:new(Status),
    _pipe@1 = gleam@http@response:set_header(_pipe, ~"content-type", ~"text/plain; charset=utf-8"),
    gleam@http@response:set_body(_pipe@1, {bytes, gleam_stdlib:wrap_list(Body)}).

-file("src\\server\\router.gleam", 769).
-spec cors(gleam@http@response:response(mist:response_data())) -> gleam@http@response:response(mist:response_data()).
cors(Resp) ->
    _pipe = Resp,
    _pipe@1 = gleam@http@response:set_header(_pipe, ~"access-control-allow-origin", allowed_origin()),
    _pipe@2 = gleam@http@response:set_header(_pipe@1, ~"access-control-allow-methods", ~"POST, OPTIONS"),
    gleam@http@response:set_header(_pipe@2, ~"access-control-allow-headers", ~"content-type, authorization").

-file("src\\server\\router.gleam", 787).
-spec auth_response(gleam@http@request:request(mist@internal@http:connection()), binary()) -> gleam@http@response:response(mist:response_data()).
auth_response(Request, Action) ->
    case erlang:element(2, Request) of
        options ->
            cors(text(204, ~""));

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
                    _pipe@3 = gleam@http@response:set_body(_pipe@2, {bytes, gleam_stdlib:wrap_list(Body)}),
                    cors(_pipe@3);

                {error, _} ->
                    cors(text(400, ~"invalid request body"))
            end;

        _ ->
            cors(text(405, ~"method not allowed"))
    end.

-file("src\\server\\router.gleam", 740).
-spec disconnect_player(ws_state()) -> nil.
disconnect_player(State) ->
    case erlang:element(3, State) of
        {some, Player_id} ->
            gleam@erlang@process:send(erlang:element(2, State), {leave_player, Player_id});

        none ->
            nil
    end.

-file("src\\server\\router.gleam", 729).
-spec ignore_send(mist@internal@websocket:websocket_connection(), server@messages:server_message()) -> {ok, nil} | {error, glisten@socket:socket_reason()}.
ignore_send(Connection, Message) ->
    _ = mist:send_text_frame(Connection, server@messages:encode_server(Message)).

-file("src\\server\\router.gleam", 715).
-spec send_and_continue(ws_state(), mist@internal@websocket:websocket_connection(), server@messages:server_message()) -> mist:next(ws_state(), nil).
send_and_continue(State, Connection, Message) ->
    _ = ignore_send(Connection, Message),
    mist:continue(State).

-file("src\\server\\router.gleam", 678).
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

-file("src\\server\\router.gleam", 440).
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

-file("src\\server\\router.gleam", 614).
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

-file("src\\server\\router.gleam", 578).
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

-file("src\\server\\router.gleam", 536).
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

-file("src\\server\\router.gleam", 498).
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

-file("src\\server\\router.gleam", 467).
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

-file("src\\server\\router.gleam", 642).
-spec send_lobby_for(ws_state(), mist@internal@websocket:websocket_connection()) -> {ok, nil} | {error, binary()}.
send_lobby_for(State, Connection) ->
    case erlang:element(3, State) of
        none ->
            {error, ~"Authentication required."};

        {some, Player_id} ->
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(erlang:element(2, State), {get_lobby, Player_id, Reply}),
            case gleam@erlang@process:'receive'(Reply, 1000) of
                {ok, {ok, Data}} ->
                    case mist:send_text_frame(Connection, Data) of
                        {ok, nil} ->
                            {ok, nil};

                        {error, _} ->
                            {error, ~"Failed to send lobby state."}
                    end;

                {ok, {error, Message}} ->
                    {error, Message};

                {error, nil} ->
                    {error, ~"Lobby timeout."}
            end
    end.

-file("src\\server\\router.gleam", 385).
-spec handle_lobby_leave(ws_state(), mist@internal@websocket:websocket_connection()) -> mist:next(ws_state(), nil).
handle_lobby_leave(State, Connection) ->
    case erlang:element(3, State) of
        none ->
            send_and_continue(State, Connection, {server_error, ~"Authentication required."});

        {some, Player_id} ->
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(erlang:element(2, State), {leave_room, Player_id, Reply}),
            case gleam@erlang@process:'receive'(Reply, 1000) of
                {ok, {ok, nil}} ->
                    _ = send_lobby_for(State, Connection),
                    _ = send_snapshot_for(State, Connection),
                    mist:continue(State);

                {ok, {error, Message}} ->
                    send_and_continue(State, Connection, {command_rejected, Message});

                {error, nil} ->
                    send_and_continue(State, Connection, {server_error, ~"Lobby timeout."})
            end
    end.

-file("src\\server\\router.gleam", 330).
-spec handle_lobby_start(ws_state(), mist@internal@websocket:websocket_connection()) -> mist:next(ws_state(), nil).
handle_lobby_start(State, Connection) ->
    case erlang:element(3, State) of
        none ->
            send_and_continue(State, Connection, {server_error, ~"Authentication required."});

        {some, Player_id} ->
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(erlang:element(2, State), {start_room, Player_id, Reply}),
            case gleam@erlang@process:'receive'(Reply, 1000) of
                {ok, {ok, nil}} ->
                    _ = send_lobby_for(State, Connection),
                    _ = send_snapshot_for(State, Connection),
                    mist:continue(State);

                {ok, {error, Message}} ->
                    send_and_continue(State, Connection, {command_rejected, Message});

                {error, nil} ->
                    send_and_continue(State, Connection, {server_error, ~"Lobby timeout."})
            end
    end.

-file("src\\server\\router.gleam", 280).
-spec handle_lobby_join(ws_state(), mist@internal@websocket:websocket_connection(), binary()) -> mist:next(ws_state(), nil).
handle_lobby_join(State, Connection, Code) ->
    case erlang:element(3, State) of
        none ->
            send_and_continue(State, Connection, {server_error, ~"Authentication required."});

        {some, Player_id} ->
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(erlang:element(2, State), {join_room, Player_id, Code, Reply}),
            case gleam@erlang@process:'receive'(Reply, 1000) of
                {ok, {ok, _}} ->
                    _ = send_lobby_for(State, Connection),
                    mist:continue(State);

                {ok, {error, Message}} ->
                    send_and_continue(State, Connection, {command_rejected, Message});

                {error, nil} ->
                    send_and_continue(State, Connection, {server_error, ~"Lobby timeout."})
            end
    end.

-file("src\\server\\router.gleam", 230).
-spec handle_lobby_create(ws_state(), mist@internal@websocket:websocket_connection(), binary()) -> mist:next(ws_state(), nil).
handle_lobby_create(State, Connection, Mode) ->
    case erlang:element(3, State) of
        none ->
            send_and_continue(State, Connection, {server_error, ~"Authentication required."});

        {some, Player_id} ->
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(erlang:element(2, State), {create_room, Player_id, Mode, Reply}),
            case gleam@erlang@process:'receive'(Reply, 1000) of
                {ok, {ok, _}} ->
                    _ = send_lobby_for(State, Connection),
                    mist:continue(State);

                {ok, {error, Message}} ->
                    send_and_continue(State, Connection, {command_rejected, Message});

                {error, nil} ->
                    send_and_continue(State, Connection, {server_error, ~"Lobby timeout."})
            end
    end.

-file("src\\server\\router.gleam", 211).
-spec handle_ping(ws_state(), mist@internal@websocket:websocket_connection()) -> mist:next(ws_state(), nil).
handle_ping(State, Connection) ->
    _ = ignore_send(Connection, pong),
    _ = send_lobby_for(State, Connection),
    mist:continue(State).

-file("src\\server\\router.gleam", 122).
-spec handle_join(ws_state(), mist@internal@websocket:websocket_connection(), binary()) -> mist:next(ws_state(), nil).
handle_join(State, Connection, Token) ->
    case erlang:element(3, State) of
        {some, _} ->
            send_and_continue(State, Connection, {server_error, ~"Already authenticated."});

        none ->
            case Token =:= ~"" of
                true ->
                    send_and_continue(State, Connection, {server_error, ~"Authentication required."});

                false ->
                    case server@auth:verify_identity(Token) of
                        {error, _} ->
                            send_and_continue(State, Connection, {server_error, ~"Invalid authentication token."});

                        {ok, {Uid, Nickname}} ->
                            Reply = gleam@erlang@process:new_subject(),
                            gleam@erlang@process:send(erlang:element(2, State), {join_player, Uid, Nickname, Token, Reply}),
                            case gleam@erlang@process:'receive'(Reply, 1000) of
                                {ok, {ok, Player_id}} ->
                                    New_state = {ws_state, erlang:element(2, State), {some, Player_id}},
                                    _ = ignore_send(Connection, {welcome, Player_id}),
                                    _ = send_lobby_for(New_state, Connection),
                                    case send_snapshot_for(New_state, Connection) of
                                        {ok, _} ->
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

-file("src\\server\\router.gleam", 64).
-spec handle_ws(ws_state(), mist:websocket_message(nil), mist@internal@websocket:websocket_connection()) -> mist:next(ws_state(), nil).
handle_ws(State, Message, Connection) ->
    case Message of
        {text, Text} ->
            case server@messages:decode_client(Text) of
                {ok, {join, Token}} ->
                    handle_join(State, Connection, Token);

                {ok, ping} ->
                    handle_ping(State, Connection);

                {ok, request_snapshot} ->
                    handle_snapshot(State, Connection);

                {ok, {lobby_create, Mode}} ->
                    handle_lobby_create(State, Connection, Mode);

                {ok, {lobby_join, Code}} ->
                    handle_lobby_join(State, Connection, Code);

                {ok, lobby_start} ->
                    handle_lobby_start(State, Connection);

                {ok, lobby_leave} ->
                    handle_lobby_leave(State, Connection);

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

-file("src\\server\\router.gleam", 32).
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
            cors(text(200, ~"ok"));

        ~"/auth/login" ->
            auth_response(Request, ~"login");

        ~"/auth/register" ->
            auth_response(Request, ~"register");

        ~"/auth/guest" ->
            auth_response(Request, ~"guest");

        _ ->
            text(404, ~"not found")
    end.

