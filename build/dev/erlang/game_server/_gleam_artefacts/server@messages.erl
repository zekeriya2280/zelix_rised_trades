-module(server@messages).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([building_cost/1, product_value/1, product_json/1, encode_server/1, decode_client/1]).
-export_type([building_type/0, product_type/0, client_message/0, server_message/0]).

-type building_type() :: gatherer | factory | warehouse | farm.

-type product_type() :: wood | stone | iron | gold | grain.

-type client_message() :: {join, binary(), binary()} | ping | request_snapshot | {build_bank, float(), float()} | {build_structure, building_type(), float(), float()} | {spawn_vehicle, float(), float(), float(), float(), float()} | {set_factory_product, integer(), product_type()}.

-type server_message() :: {welcome, integer()} | pong | {world_snapshot, binary()} | {server_error, binary()} | {command_rejected, binary()}.

-file("src\\server\\messages.gleam", 25).
-spec building_cost(building_type()) -> integer().
building_cost(Building) ->
    case Building of
        gatherer ->
            5000;

        factory ->
            20000;

        warehouse ->
            8000;

        farm ->
            12000
    end.

-file("src\\server\\messages.gleam", 29).
-spec product_value(product_type()) -> integer().
product_value(Product) ->
    case Product of
        wood ->
            80;

        stone ->
            90;

        iron ->
            140;

        gold ->
            220;

        grain ->
            70
    end.

-file("src\\server\\messages.gleam", 33).
-spec product_json(product_type()) -> gleam@json:json().
product_json(Product) ->
    case Product of
        wood ->
            gleam@json:string(~"wood");

        stone ->
            gleam@json:string(~"stone");

        iron ->
            gleam@json:string(~"iron");

        gold ->
            gleam@json:string(~"gold");

        grain ->
            gleam@json:string(~"grain")
    end.

-file("src\\server\\messages.gleam", 37).
-spec encode_server(server_message()) -> binary().
encode_server(Message) ->
    case Message of
        {welcome, Player_id} ->
            _pipe = gleam@json:object([{~"type", gleam@json:string(~"welcome")}, {~"player_id", gleam@json:int(Player_id)}]),
            gleam@json:to_string(_pipe);

        pong ->
            _pipe@1 = gleam@json:object([{~"type", gleam@json:string(~"pong")}]),
            gleam@json:to_string(_pipe@1);

        {world_snapshot, Data} ->
            Data;

        {server_error, Message@1} ->
            _pipe@2 = gleam@json:object([{~"type", gleam@json:string(~"error")}, {~"message", gleam@json:string(Message@1)}]),
            gleam@json:to_string(_pipe@2);

        {command_rejected, Message@2} ->
            _pipe@3 = gleam@json:object([{~"type", gleam@json:string(~"command_rejected")}, {~"message", gleam@json:string(Message@2)}]),
            gleam@json:to_string(_pipe@3)
    end.

-file("src\\server\\messages.gleam", 100).
-spec decode_product() -> gleam@dynamic@decode:decoder(product_type()).
decode_product() ->
    gleam@dynamic@decode:then({decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Text) ->
        case Text of
            ~"wood" ->
                gleam@dynamic@decode:success(wood);

            ~"stone" ->
                gleam@dynamic@decode:success(stone);

            ~"iron" ->
                gleam@dynamic@decode:success(iron);

            ~"gold" ->
                gleam@dynamic@decode:success(gold);

            ~"grain" ->
                gleam@dynamic@decode:success(grain);

            _ ->
                gleam@dynamic@decode:failure(wood, ~"product")
        end
    end).

-file("src\\server\\messages.gleam", 88).
-spec decode_building() -> gleam@dynamic@decode:decoder(building_type()).
decode_building() ->
    gleam@dynamic@decode:then({decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Text) ->
        case Text of
            ~"gatherer" ->
                gleam@dynamic@decode:success(gatherer);

            ~"factory" ->
                gleam@dynamic@decode:success(factory);

            ~"warehouse" ->
                gleam@dynamic@decode:success(warehouse);

            ~"farm" ->
                gleam@dynamic@decode:success(farm);

            _ ->
                gleam@dynamic@decode:failure(gatherer, ~"building_type")
        end
    end).

-file("src\\server\\messages.gleam", 47).
-spec decode_client(binary()) -> {ok, client_message()} | {error, binary()}.
decode_client(Text) ->
    Decoder = begin
        gleam@dynamic@decode:field(~"type", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Tag) ->
            case Tag of
                ~"join" ->
                    gleam@dynamic@decode:field(~"name", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Name) ->
                        gleam@dynamic@decode:field(~"token", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Token) ->
                            gleam@dynamic@decode:success({join, Name, Token})
                        end)
                    end);

                ~"ping" ->
                    gleam@dynamic@decode:success(ping);

                ~"request_snapshot" ->
                    gleam@dynamic@decode:success(request_snapshot);

                ~"build_bank" ->
                    gleam@dynamic@decode:field(~"x", {decoder, fun gleam@dynamic@decode:decode_float/1}, fun(X) ->
                        gleam@dynamic@decode:field(~"y", {decoder, fun gleam@dynamic@decode:decode_float/1}, fun(Y) ->
                            gleam@dynamic@decode:success({build_bank, X, Y})
                        end)
                    end);

                ~"build_structure" ->
                    gleam@dynamic@decode:field(~"building_type", decode_building(), fun(Building) ->
                        gleam@dynamic@decode:field(~"x", {decoder, fun gleam@dynamic@decode:decode_float/1}, fun(X) ->
                            gleam@dynamic@decode:field(~"y", {decoder, fun gleam@dynamic@decode:decode_float/1}, fun(Y) ->
                                gleam@dynamic@decode:success({build_structure, Building, X, Y})
                            end)
                        end)
                    end);

                ~"spawn_vehicle" ->
                    gleam@dynamic@decode:field(~"x", {decoder, fun gleam@dynamic@decode:decode_float/1}, fun(X) ->
                        gleam@dynamic@decode:field(~"y", {decoder, fun gleam@dynamic@decode:decode_float/1}, fun(Y) ->
                            gleam@dynamic@decode:field(~"target_x", {decoder, fun gleam@dynamic@decode:decode_float/1}, fun(Tx) ->
                                gleam@dynamic@decode:field(~"target_y", {decoder, fun gleam@dynamic@decode:decode_float/1}, fun(Ty) ->
                                    gleam@dynamic@decode:field(~"speed", {decoder, fun gleam@dynamic@decode:decode_float/1}, fun(Speed) ->
                                        gleam@dynamic@decode:success({spawn_vehicle, X, Y, Tx, Ty, Speed})
                                    end)
                                end)
                            end)
                        end)
                    end);

                ~"set_factory_product" ->
                    gleam@dynamic@decode:field(~"id", {decoder, fun gleam@dynamic@decode:decode_int/1}, fun(Id) ->
                        gleam@dynamic@decode:field(~"product", decode_product(), fun(Product) ->
                            gleam@dynamic@decode:success({set_factory_product, Id, Product})
                        end)
                    end);

                _ ->
                    gleam@dynamic@decode:failure(ping, ~"known client message")
            end
        end)
    end,
    case gleam@json:parse(Text, Decoder) of
        {ok, Message} ->
            {ok, Message};

        {error, _} ->
            {error, ~"Invalid client message"}
    end.

