-module(gleam@httpc).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([dispatch_bits/2, configure/0, send_bits/1, verify_tls/2, follow_redirects/2, timeout/2, dispatch/2, send/1]).
-export_type([http_error/0, connect_error/0, erl_http_option/0, body_format/0, erl_option/0, socket_opt/0, inet6fb4/0, erl_ssl_option/0, erl_verify_option/0, configuration/0]).

-type http_error() :: invalid_utf8_response | {failed_to_connect, connect_error(), connect_error()} | response_timeout.

-type connect_error() :: {posix, binary()} | {tls_alert, binary(), binary()}.

-type erl_http_option() :: {ssl, list(erl_ssl_option())} | {autoredirect, boolean()} | {timeout, integer()}.

-type body_format() :: binary.

-type erl_option() :: {body_format, body_format()} | {socket_opts, list(socket_opt())}.

-type socket_opt() :: {ipfamily, inet6fb4()}.

-type inet6fb4() :: inet6fb4.

-type erl_ssl_option() :: {verify, erl_verify_option()}.

-type erl_verify_option() :: verify_none.

-opaque configuration() :: {builder, boolean(), boolean(), integer()}.

-file("src\\gleam\\httpc.gleam", 84).
-spec string_header({gleam@erlang@charlist:charlist(), gleam@erlang@charlist:charlist()}) -> {binary(), binary()}.
string_header(Header) ->
    {K, V} = Header,
    {unicode:characters_to_binary(K), unicode:characters_to_binary(V)}.

-file("src\\gleam\\httpc.gleam", 243).
-spec prepare_headers_loop(list({binary(), binary()}), list({gleam@erlang@charlist:charlist(), gleam@erlang@charlist:charlist()}), boolean()) -> list({gleam@erlang@charlist:charlist(), gleam@erlang@charlist:charlist()}).
prepare_headers_loop(In, Out, User_agent_set) ->
    case In of
        [] when User_agent_set ->
            Out;

        [] ->
            [gleam_httpc_ffi:default_user_agent() | Out];

        [{K, V} | In@1] ->
            User_agent_set@1 = User_agent_set orelse (K =:= ~"user-agent"),
            Out@1 = [{unicode:characters_to_list(K), unicode:characters_to_list(V)} | Out],
            prepare_headers_loop(In@1, Out@1, User_agent_set@1)
    end.

-file("src\\gleam\\httpc.gleam", 237).
-spec prepare_headers(list({binary(), binary()})) -> list({gleam@erlang@charlist:charlist(), gleam@erlang@charlist:charlist()}).
prepare_headers(Headers) ->
    prepare_headers_loop(Headers, [], false).

-file("src\\gleam\\httpc.gleam", 104).
-spec dispatch_bits(configuration(), gleam@http@request:request(bitstring())) -> {ok, gleam@http@response:response(bitstring())} | {error, http_error()}.
-doc(~" Send a HTTP request of binary data.
").
dispatch_bits(Config, Req) ->
    Erl_url = begin
        _pipe = Req,
        _pipe@1 = gleam@http@request:to_uri(_pipe),
        _pipe@2 = gleam@uri:to_string(_pipe@1),
        unicode:characters_to_list(_pipe@2)
    end,
    Erl_headers = prepare_headers(erlang:element(3, Req)),
    Erl_http_options = [{autoredirect, erlang:element(3, Config)}, {timeout, erlang:element(4, Config)}],
    Erl_http_options@1 = case erlang:element(2, Config) of
        true ->
            Erl_http_options;

        false ->
            [{ssl, [{verify, verify_none}]} | Erl_http_options]
    end,
    Erl_options = [{body_format, binary}, {socket_opts, [{ipfamily, inet6fb4}]}],
    gleam@result:'try'(begin
        _pipe@3 = case erlang:element(2, Req) of
            options ->
                Erl_req = {Erl_url, Erl_headers},
                httpc:request(erlang:element(2, Req), Erl_req, Erl_http_options@1, Erl_options);

            head ->
                Erl_req = {Erl_url, Erl_headers},
                httpc:request(erlang:element(2, Req), Erl_req, Erl_http_options@1, Erl_options);

            get ->
                Erl_req = {Erl_url, Erl_headers},
                httpc:request(erlang:element(2, Req), Erl_req, Erl_http_options@1, Erl_options);

            _ ->
                Erl_content_type = begin
                    _pipe@4 = Req,
                    _pipe@5 = gleam@http@request:get_header(_pipe@4, ~"content-type"),
                    _pipe@6 = gleam@result:unwrap(_pipe@5, ~"application/octet-stream"),
                    unicode:characters_to_list(_pipe@6)
                end,
                Erl_req@1 = {Erl_url, Erl_headers, Erl_content_type, erlang:element(4, Req)},
                httpc:request(erlang:element(2, Req), Erl_req@1, Erl_http_options@1, Erl_options)
        end,
        gleam@result:map_error(_pipe@3, fun gleam_httpc_ffi:normalise_error/1)
    end, fun(Response) ->
        {{_, Status, _}, Headers, Resp_body} = Response,
        {ok, {response, Status, gleam@list:map(Headers, fun string_header/1), Resp_body}}
    end).

-file("src\\gleam\\httpc.gleam", 181).
-spec configure() -> configuration().
-doc(~" Create a new configuration with the default settings.

 # Defaults

 - TLS is verified.
 - Redirects are not followed.
 - The timeout for the response to be received is 30 seconds from when the
   request is sent.
").
configure() ->
    {builder, true, false, 30000}.

-file("src\\gleam\\httpc.gleam", 94).
-spec send_bits(gleam@http@request:request(bitstring())) -> {ok, gleam@http@response:response(bitstring())} | {error, http_error()}.
-doc(~" Send a HTTP request of binary data using the default configuration.

 If you wish to use some other configuration use `dispatch_bits` instead.
").
send_bits(Req) ->
    _pipe = configure(),
    dispatch_bits(_pipe, Req).

-file("src\\gleam\\httpc.gleam", 194).
-spec verify_tls(configuration(), boolean()) -> configuration().
-doc(~" Set whether to verify the TLS certificate of the server.

 This defaults to `True`, meaning that the TLS certificate will be verified
 unless you call this function with `False`.

 Setting this to `False` can make your application vulnerable to
 man-in-the-middle attacks and other security risks. Do not do this unless
 you are sure and you understand the risks.
").
verify_tls(Config, Which) ->
    {builder, Which, erlang:element(3, Config), erlang:element(4, Config)}.

-file("src\\gleam\\httpc.gleam", 199).
-spec follow_redirects(configuration(), boolean()) -> configuration().
-doc(~" Set whether redirects should be followed automatically.").
follow_redirects(Config, Which) ->
    {builder, erlang:element(2, Config), Which, erlang:element(4, Config)}.

-file("src\\gleam\\httpc.gleam", 208).
-spec timeout(configuration(), integer()) -> configuration().
-doc(~" Set the timeout in milliseconds, the default being 30 seconds.

 If the response is not recieved within this amount of time then the
 client disconnects and an error is returned.
").
timeout(Config, Timeout) ->
    {builder, erlang:element(2, Config), erlang:element(3, Config), Timeout}.

-file("src\\gleam\\httpc.gleam", 214).
-spec dispatch(configuration(), gleam@http@request:request(binary())) -> {ok, gleam@http@response:response(binary())} | {error, http_error()}.
-doc(~" Send a HTTP request of unicode data.
").
dispatch(Config, Request) ->
    Request@1 = gleam@http@request:map(Request, fun gleam_stdlib:identity/1),
    gleam@result:'try'(dispatch_bits(Config, Request@1), fun(Resp) ->
        case gleam@bit_array:to_string(erlang:element(4, Resp)) of
            {ok, Body} ->
                {ok, gleam@http@response:set_body(Resp, Body)};

            {error, _} ->
                {error, invalid_utf8_response}
        end
    end).

-file("src\\gleam\\httpc.gleam", 232).
-spec send(gleam@http@request:request(binary())) -> {ok, gleam@http@response:response(binary())} | {error, http_error()}.
-doc(~" Send a HTTP request of unicode data using the default configuration.

 If you wish to use some other configuration use `dispatch` instead.
").
send(Req) ->
    _pipe = configure(),
    dispatch(_pipe, Req).

