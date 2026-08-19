-module(mist@internal@clock).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([start/2, stop/1, get_date/0]).
-export_type([clock_message/0, clock_table/0, table_key/0, ets_opts/0]).
-moduledoc(false).

-type clock_message() :: set_time.

-type clock_table() :: mist_clock.

-type table_key() :: date_header.

-type ets_opts() :: set | protected | named_table | {read_concurrency, boolean()}.

-file("src\\mist\\internal\\clock.gleam", 102).
-spec month_to_short_string(integer()) -> binary().
-doc(false).
month_to_short_string(Month) ->
    case Month of
        1 ->
            ~"Jan";

        2 ->
            ~"Feb";

        3 ->
            ~"Mar";

        4 ->
            ~"Apr";

        5 ->
            ~"May";

        6 ->
            ~"Jun";

        7 ->
            ~"Jul";

        8 ->
            ~"Aug";

        9 ->
            ~"Sep";

        10 ->
            ~"Oct";

        11 ->
            ~"Nov";

        12 ->
            ~"Dec";

        _ ->
            erlang:error(#{
                gleam_error => panic,
                message => ~"erlang month outside of 1-12 range",
                file => ~"src\\mist\\internal\\clock.gleam",
                module => ~"mist/internal/clock",
                function => ~"month_to_short_string",
                line => 116
            })
    end.

-file("src\\mist\\internal\\clock.gleam", 89).
-spec weekday_to_short_string(integer()) -> binary().
-doc(false).
weekday_to_short_string(Weekday) ->
    case Weekday of
        1 ->
            ~"Mon";

        2 ->
            ~"Tue";

        3 ->
            ~"Wed";

        4 ->
            ~"Thu";

        5 ->
            ~"Fri";

        6 ->
            ~"Sat";

        7 ->
            ~"Sun";

        _ ->
            erlang:error(#{
                gleam_error => panic,
                message => ~"erlang weekday outside of 1-7 range",
                file => ~"src\\mist\\internal\\clock.gleam",
                module => ~"mist/internal/clock",
                function => ~"weekday_to_short_string",
                line => 98
            })
    end.

-file("src\\mist\\internal\\clock.gleam", 73).
-spec date() -> binary().
-doc(false).
date() ->
    {Weekday, {Year, Month, Day}, {Hour, Minute, Second}} = mist_ffi:now(),
    Weekday@1 = weekday_to_short_string(Weekday),
    Year@1 = begin
        _pipe = erlang:integer_to_binary(Year),
        gleam@string:pad_start(_pipe, 4, ~"0")
    end,
    Month@1 = month_to_short_string(Month),
    Day@1 = begin
        _pipe@1 = erlang:integer_to_binary(Day),
        gleam@string:pad_start(_pipe@1, 2, ~"0")
    end,
    Hour@1 = begin
        _pipe@2 = erlang:integer_to_binary(Hour),
        gleam@string:pad_start(_pipe@2, 2, ~"0")
    end,
    Minute@1 = begin
        _pipe@3 = erlang:integer_to_binary(Minute),
        gleam@string:pad_start(_pipe@3, 2, ~"0")
    end,
    Second@1 = begin
        _pipe@4 = erlang:integer_to_binary(Second),
        gleam@string:pad_start(_pipe@4, 2, ~"0")
    end,
    <<<<<<Weekday@1/binary, ", "/utf8>>/binary, <<<<<<<<<<Day@1/binary, " "/utf8>>/binary, Month@1/binary>>/binary, " "/utf8>>/binary, Year@1/binary>>/binary, " "/utf8>>/binary>>/binary, <<<<<<<<<<Hour@1/binary, ":"/utf8>>/binary, Minute@1/binary>>/binary, ":"/utf8>>/binary, Second@1/binary>>/binary, " GMT"/utf8>>/binary>>.

-file("src\\mist\\internal\\clock.gleam", 28).
-spec start(any(), any()) -> {ok, gleam@erlang@process:pid_()} | {error, gleam@otp@actor:start_error()}.
-doc(false).
start(_, _) ->
    _pipe = gleam@otp@actor:new_with_initialiser(500, fun(Subject) ->
        ets:new(mist_clock, [set, protected, named_table, {read_concurrency, true}]),
        gleam@erlang@process:send(Subject, set_time),
        _pipe@1 = Subject,
        _pipe@2 = gleam@otp@actor:initialised(_pipe@1),
        _pipe@3 = gleam@otp@actor:selecting(_pipe@2, begin
            _pipe@4 = gleam_erlang_ffi:new_selector(),
            gleam@erlang@process:select(_pipe@4, Subject)
        end),
        _pipe@5 = gleam@otp@actor:returning(_pipe@3, Subject),
        {ok, _pipe@5}
    end),
    _pipe@1 = gleam@otp@actor:on_message(_pipe, fun(State, Msg) ->
        case Msg of
            set_time ->
                ets:insert(mist_clock, {date_header, date()}),
                gleam@erlang@process:send_after(State, 1000, set_time),
                gleam@otp@actor:continue(State)
        end
    end),
    _pipe@2 = gleam@otp@actor:start(_pipe@1),
    gleam@result:map(_pipe@2, fun(Started) ->
        case gleam@erlang@process:subject_owner(erlang:element(3, Started)) of
            {ok, Pid} ->
                Pid;

            _value ->
                erlang:error(#{
                    gleam_error => let_assert,
                    message => ~"Pattern match failed, no pattern matched the value.",
                    file => ~"src\\mist\\internal\\clock.gleam",
                    module => ~"mist/internal/clock",
                    function => ~"start",
                    line => 51,
                    value => _value,
                    start => 1098,
                    'end' => 1154,
                    pattern_start => 1109,
                    pattern_end => 1116
                })
        end
    end).

-file("src\\mist\\internal\\clock.gleam", 56).
-spec stop(any()) -> gleam@erlang@atom:atom_().
-doc(false).
stop(_) ->
    erlang:binary_to_atom(~"ok").

-file("src\\mist\\internal\\clock.gleam", 60).
-spec get_date() -> binary().
-doc(false).
get_date() ->
    case mist_ffi:ets_lookup_element(mist_clock, date_header, 2) of
        {ok, Value} ->
            Value;

        _ ->
            logging:log(warning, ~"Failed to lookup date, re-calculating"),
            date()
    end.

