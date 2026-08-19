-module(gleam@erlang@process).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([self/0, spawn/1, spawn_unlinked/1, unsafely_create_subject/2, new_name/1, named_subject/1, subject_name/1, new_subject/0, named/1, subject_owner/1, send/2, 'receive'/2, receive_forever/1, new_selector/0, selector_receive/2, selector_receive_forever/1, map_selector/2, merge_selector/2, select_trapped_exits/2, flush_messages/0, select_map/3, select/2, deselect/2, select_record/4, select_other/2, sleep/1, sleep_forever/0, is_alive/1, monitor/1, select_specific_monitor/3, select_monitors/2, demonitor_process/1, deselect_specific_monitor/2, call/3, call_forever/2, link/1, unlink/1, send_after/3, cancel_timer/1, kill/1, send_exit/1, send_abnormal_exit/2, trap_exits/1, register/2, unregister/1]).
-export_type([pid_/0, subject/1, name/1, do_not_leak/0, selector/1, exit_message/0, exit_reason/0, anything_selector_tag/0, process_monitor_flag/0, monitor/0, down/0, timer/0, cancelled/0, kill_flag/0]).

-type pid_() :: any().

-opaque subject(DON) :: {subject, pid_(), gleam@dynamic:dynamic_()} | {named_subject, name(DON)}.

-type name(DOO) :: any() | {gleam_phantom, DOO}.

-type do_not_leak() :: any().

-type selector(DOP) :: any() | {gleam_phantom, DOP}.

-type exit_message() :: {exit_message, pid_(), exit_reason()}.

-type exit_reason() :: normal | killed | {abnormal, gleam@dynamic:dynamic_()}.

-type anything_selector_tag() :: anything.

-type process_monitor_flag() :: process.

-type monitor() :: any().

-type down() :: {process_down, monitor(), pid_(), exit_reason()} | {port_down, monitor(), gleam@erlang@port:port_(), exit_reason()}.

-type timer() :: any().

-type cancelled() :: timer_not_found | {cancelled, integer()}.

-type kill_flag() :: kill.

-file("src\\gleam\\erlang\\process.gleam", 17).
-spec self() -> pid_().
-doc(~" Get the `Pid` for the current process.
").
self() ->
    erlang:self().

-file("src\\gleam\\erlang\\process.gleam", 36).
-spec spawn(fun(() -> any())) -> pid_().
-doc(~" Create a new Erlang process that runs concurrently to the creator. In other
 languages this might be called a fibre, a green thread, or a coroutine.

 The child process is linked to the creator process. When a process
 terminates an exit signal is sent to all other processes that are linked to
 it, causing the process to either terminate or have to handle the signal.
 If you want an unlinked process use the `spawn_unlinked` function.

 More can be read about processes and links in the [Erlang documentation][1].

 [1]: https://www.erlang.org/doc/reference_manual/processes.html

 This function starts processes via the Erlang `proc_lib` module, and as
 such they benefit from the functionality described in the
 [`proc_lib` documentation](https://www.erlang.org/doc/apps/stdlib/proc_lib.html).
").
spawn(Running) ->
    proc_lib:spawn_link(Running).

-file("src\\gleam\\erlang\\process.gleam", 53).
-spec spawn_unlinked(fun(() -> any())) -> pid_().
-doc(~" Create a new Erlang process that runs concurrently to the creator. In other
 languages this might be called a fibre, a green thread, or a coroutine.

 Typically you want to create a linked process using the `spawn` function,
 but creating an unlinked process may be occasionally useful.

 More can be read about processes and links in the [Erlang documentation][1].

 [1]: https://www.erlang.org/doc/reference_manual/processes.html

 This function starts processes via the Erlang `proc_lib` module, and as
 such they benefit from the functionality described in the
 [`proc_lib` documentation](https://www.erlang.org/doc/apps/stdlib/proc_lib.html).
").
spawn_unlinked(A) ->
    proc_lib:spawn(A).

-file("src\\gleam\\erlang\\process.gleam", 90).
-spec unsafely_create_subject(pid_(), gleam@dynamic:dynamic_()) -> subject(any()).
-doc(false).
unsafely_create_subject(Owner, Tag) ->
    {subject, Owner, Tag}.

-file("src\\gleam\\erlang\\process.gleam", 136).
-spec new_name(binary()) -> name(any()).
-doc(~" Generate a new name that a process can register itself with using the
 `register` function, and other processes can send messages to using
 `named_subject`.

 The string argument is a prefix for the Erlang name. A unique suffix is
 added to the prefix to make the name, removing the possibility of name
 collisions.

 ## Safe use

 Use this function to create all the names your program needs when it
 starts. **Never call this function dynamically** such as within a loop or
 within a process within a supervision tree.

 Each time this function is called a new atom will be generated. Generating
 too many atoms will result in the atom table getting filled and causing the
 entire virtual machine to crash.
").
new_name(Prefix) ->
    gleam_erlang_ffi:new_name(Prefix).

-file("src\\gleam\\erlang\\process.gleam", 143).
-spec named_subject(name(DOW)) -> subject(DOW).
-doc(~" Create a subject for a name, which can be used to send and receive messages.

 All subjects created for the same name behave identically and can be used
 interchangably.
").
named_subject(Name) ->
    {named_subject, Name}.

-file("src\\gleam\\erlang\\process.gleam", 149).
-spec subject_name(subject(DOZ)) -> {ok, name(DOZ)} | {error, nil}.
-doc(~" Get the name of a subject, returning an error if it doesn't have one.
").
subject_name(Subject) ->
    case Subject of
        {named_subject, Name} ->
            {ok, Name};

        {subject, _, _} ->
            {error, nil}
    end.

-file("src\\gleam\\erlang\\process.gleam", 158).
-spec new_subject() -> subject(any()).
-doc(~" Create a new `Subject` owned by the current process.
").
new_subject() ->
    {subject, erlang:self(), gleam_erlang_ffi:identity(erlang:make_ref())}.

-file("src\\gleam\\erlang\\process.gleam", 876).
-spec named(name(any())) -> {ok, pid_()} | {error, nil}.
-doc(~" Look up a process by registered name, returning the pid if it exists.
").
named(Name) ->
    gleam_erlang_ffi:process_named(Name).

-file("src\\gleam\\erlang\\process.gleam", 168).
-spec subject_owner(subject(any())) -> {ok, pid_()} | {error, nil}.
-doc(~" Get the owner process for a subject, which is the process that will
 receive any messages sent using the subject.

 If the subject was created from a name and no process is currently
 registered with that name then this function will return an error.
").
subject_owner(Subject) ->
    case Subject of
        {named_subject, Name} ->
            gleam_erlang_ffi:process_named(Name);

        {subject, Pid, _} ->
            {ok, Pid}
    end.

-file("src\\gleam\\erlang\\process.gleam", 214).
-spec send(subject(DPL), DPL) -> nil.
-doc(~" Send a message to a process using a `Subject`. The message must be of the
 type that the `Subject` accepts.

 This function does not wait for the `Subject` owner process to call the
 `receive` function, instead it returns once the message has been placed in
 the process' mailbox.
 
 # Named Subjects
 
 If this function is called on a named subject for which a process has not been 
 registered, it will simply drop the message as there's no mailbox to send it to.

 # Panics

 This function will panic when sending to a named subject if no process is
 currently registed under that name.

 # Ordering

 If process P1 sends two messages to process P2 it is guaranteed that process
 P1 will receive the messages in the order they were sent.

 If you wish to receive the messages in a different order you can send them
 on two different subjects and the receiver function can call the `receive`
 function for each subject in the desired order, or you can write some Erlang
 code to perform a selective receive.

 # Examples

 ```gleam
 let subject = new_subject()
 send(subject, \"Hello, Joe!\")
 ```
").
send(Subject, Message) ->
    case Subject of
        {subject, Pid, Tag} ->
            erlang:send(Pid, {Tag, Message});

        {named_subject, Name} ->
            case gleam_erlang_ffi:process_named(Name) of
                {ok, Pid@1} ->
                    erlang:send(Pid@1, {Name, Message});

                _value ->
                    erlang:error(#{
                        gleam_error => let_assert,
                        message => ~"Sending to unregistered name",
                        file => ~"src\\gleam\\erlang\\process.gleam",
                        module => ~"gleam/erlang/process",
                        function => ~"send",
                        line => 220,
                        value => _value,
                        start => 8194,
                        'end' => 8226,
                        pattern_start => 8205,
                        pattern_end => 8212
                    })
            end
    end,
    nil.

-file("src\\gleam\\erlang\\process.gleam", 247).
-spec 'receive'(subject(DPN), integer()) -> {ok, DPN} | {error, nil}.
-doc(~" Receive a message that has been sent to current process using the `Subject`.

 If there is not an existing message for the `Subject` in the process'
 mailbox or one does not arrive `within` the permitted timeout then the
 `Error(Nil)` is returned.

 Only the process that is owner of the `Subject` can receive a message using
 it. If a process that does not own the `Subject` attempts to receive with it
 then it will not receive a message.

 To wait for messages from multiple `Subject`s at the same time see the
 `Selector` type.

 The `within` parameter specifies the timeout duration in milliseconds.

 ## Panics

 This function will panic if a process tries to receive with a non-named
 subject that it does not own.
").
'receive'(Subject, Timeout) ->
    case Subject of
        {named_subject, _} ->
            gleam_erlang_ffi:'receive'(Subject, Timeout);

        {subject, Owner, _} ->
            case Owner =:= erlang:self() of
                true ->
                    gleam_erlang_ffi:'receive'(Subject, Timeout);

                false ->
                    erlang:error(#{
                        gleam_error => panic,
                        message => ~"Cannot receive with a subject owned by another process",
                        file => ~"src\\gleam\\erlang\\process.gleam",
                        module => ~"gleam/erlang/process",
                        function => ~"receive",
                        line => 257
                    })
            end
    end.

-file("src\\gleam\\erlang\\process.gleam", 272).
-spec receive_forever(subject(DPV)) -> DPV.
-doc(~" Receive a message that has been sent to current process using the `Subject`.

 Same as `receive` but waits forever and returns the message as is.").
receive_forever(Subject) ->
    gleam_erlang_ffi:'receive'(Subject).

-file("src\\gleam\\erlang\\process.gleam", 301).
-spec new_selector() -> selector(any()).
-doc(~" Create a new `Selector` which can be used to receive messages on multiple
 `Subject`s at once.
").
new_selector() ->
    gleam_erlang_ffi:new_selector().

-file("src\\gleam\\erlang\\process.gleam", 321).
-spec selector_receive(selector(DPZ), integer()) -> {ok, DPZ} | {error, nil}.
-doc(~" Receive a message that has been sent to current process using any of the
 `Subject`s that have been added to the `Selector` with the `select*`
 functions.

 If there is not an existing message for the `Selector` in the process'
 mailbox or one does not arrive `within` the permitted timeout then the
 `Error(Nil)` is returned.

 Only the process that is owner of the `Subject`s can receive a message using
 them. If a process that does not own the a `Subject` attempts to receive
 with it then it will not receive a message.

 To wait forever for the next message rather than for a limited amount of
 time see the `selector_receive_forever` function.

 The `within` parameter specifies the timeout duration in milliseconds.
").
selector_receive(From, Within) ->
    gleam_erlang_ffi:select(From, Within).

-file("src\\gleam\\erlang\\process.gleam", 330).
-spec selector_receive_forever(selector(DQD)) -> DQD.
-doc(~" Similar to the `select` function but will wait forever for a message to
 arrive rather than timing out after a specified amount of time.
").
selector_receive_forever(From) ->
    gleam_erlang_ffi:select(From).

-file("src\\gleam\\erlang\\process.gleam", 339).
-spec map_selector(selector(DQF), fun((DQF) -> DQH)) -> selector(DQH).
-doc(~" Add a transformation function to a selector. When a message is received
 using this selector the transformation function is applied to the message.

 This function can be used to change the type of messages received and may
 be useful when combined with the `merge_selector` function.
").
map_selector(A, B) ->
    gleam_erlang_ffi:map_selector(A, B).

-file("src\\gleam\\erlang\\process.gleam", 348).
-spec merge_selector(selector(DQJ), selector(DQJ)) -> selector(DQJ).
-doc(~" Merge one selector into another, producing a selector that contains the
 message handlers of both.

 If a subject is handled by both selectors the handler function of the
 second selector is used.
").
merge_selector(A, B) ->
    gleam_erlang_ffi:merge_selector(A, B).

-file("src\\gleam\\erlang\\process.gleam", 364).
-spec select_trapped_exits(selector(DQN), fun((exit_message()) -> DQN)) -> selector(DQN).
-doc(~" Add a handler for trapped exit messages. In order for these messages to be
 sent to the process when a linked process exits the process must call the
 `trap_exit` beforehand.
").
select_trapped_exits(Selector, Handler) ->
    Tag = erlang:binary_to_atom(~"EXIT"),
    Handler@1 = fun(Message) ->
        Handler({exit_message, erlang:element(2, Message), gleam_erlang_ffi:cast_exit_reason(erlang:element(3, Message))})
    end,
    gleam_erlang_ffi:insert_selector_handler(Selector, {Tag, 3}, Handler@1).

-file("src\\gleam\\erlang\\process.gleam", 384).
-spec flush_messages() -> nil.
-doc(~" Discard all messages in the current process' mailbox.

 Warning: This function may cause other processes to crash if they sent a
 message to the current process and are waiting for a response, so use with
 caution.

 This function may be useful in tests.
").
flush_messages() ->
    gleam_erlang_ffi:flush_messages().

-file("src\\gleam\\erlang\\process.gleam", 411).
-spec select_map(selector(DQU), subject(DQW), fun((DQW) -> DQU)) -> selector(DQU).
-doc(~" Add a new `Subject` to the `Selector` so that its messages can be selected
 from the receiver process inbox.

 The `mapping` function provided with the `Subject` can be used to convert
 the type of messages received using this `Subject`. This is useful for when
 you wish to add multiple `Subject`s to a `Selector` when they have differing
 message types. If you do not wish to transform the incoming messages in any
 way then the `identity` function can be given.

 See `deselect` to remove a subject from a selector.
").
select_map(Selector, Subject, Transform) ->
    Handler = fun(Message) ->
        Transform(erlang:element(2, Message))
    end,
    case Subject of
        {named_subject, Name} ->
            gleam_erlang_ffi:insert_selector_handler(Selector, {Name, 2}, Handler);

        {subject, _, Tag} ->
            gleam_erlang_ffi:insert_selector_handler(Selector, {Tag, 2}, Handler)
    end.

-file("src\\gleam\\erlang\\process.gleam", 393).
-spec select(selector(DQQ), subject(DQQ)) -> selector(DQQ).
-doc(~" Add a new `Subject` to the `Selector` so that its messages can be selected
 from the receiver process inbox.

 See `select_map` to add subjects of a different message type.

 See `deselect` to remove a subject from a selector.
").
select(Selector, Subject) ->
    select_map(Selector, Subject, fun(X) ->
        X
    end).

-file("src\\gleam\\erlang\\process.gleam", 426).
-spec deselect(selector(DQZ), subject(any())) -> selector(DQZ).
-doc(~" Remove a new `Subject` from the `Selector` so that its messages will not be
 selected from the receiver process inbox.
").
deselect(Selector, Subject) ->
    case Subject of
        {named_subject, Name} ->
            gleam_erlang_ffi:remove_selector_handler(Selector, {Name, 2});

        {subject, _, Tag} ->
            gleam_erlang_ffi:remove_selector_handler(Selector, {Tag, 2})
    end.

-file("src\\gleam\\erlang\\process.gleam", 447).
-spec select_record(selector(DRE), any(), integer(), fun((gleam@dynamic:dynamic_()) -> DRE)) -> selector(DRE).
-doc(~" Add a handler to a selector for tuple messages with a given tag in the
 first position followed by a given number of fields.

 Typically you want to use the `select` function with a `Subject` instead,
 but this function may be useful if you need to receive messages sent from
 other BEAM languages that do not use the `Subject` type.

 This will not select messages sent via a subject even if the message has
 the same tag in the first position. This is because when a message is sent
 via a subject a new tag is used that is unique and specific to that subject.
").
select_record(Selector, Tag, Arity, Transform) ->
    gleam_erlang_ffi:insert_selector_handler(Selector, {Tag, Arity + 1}, Transform).

-file("src\\gleam\\erlang\\process.gleam", 467).
-spec select_other(selector(DRI), fun((gleam@dynamic:dynamic_()) -> DRI)) -> selector(DRI).
-doc(~" Add a catch-all handler to a selector that will be used when no other
 handler in a selector is suitable for a given message.

 This may be useful for when you want to ensure that any message in the inbox
 is handled, or when you need to handle messages from other BEAM languages
 which do not use subjects or record format messages.
").
select_other(Selector, Handler) ->
    gleam_erlang_ffi:insert_selector_handler(Selector, anything, Handler).

-file("src\\gleam\\erlang\\process.gleam", 491).
-spec sleep(integer()) -> nil.
-doc(~" Suspends the process calling this function for the specified number of
 milliseconds.
").
sleep(A) ->
    gleam_erlang_ffi:sleep(A).

-file("src\\gleam\\erlang\\process.gleam", 498).
-spec sleep_forever() -> nil.
-doc(~" Suspends the process forever! This may be useful for suspending the main
 process in a Gleam program when it has no more work to do but we want other
 processes to continue to work.
").
sleep_forever() ->
    gleam_erlang_ffi:sleep_forever().

-file("src\\gleam\\erlang\\process.gleam", 507).
-spec is_alive(pid_()) -> boolean().
-doc(~" Check to see whether the process for a given `Pid` is alive.

 See the [Erlang documentation][1] for more information.

 [1]: http://erlang.org/doc/man/erlang.html#is_process_alive-1
").
is_alive(A) ->
    erlang:is_process_alive(A).

-file("src\\gleam\\erlang\\process.gleam", 537).
-spec monitor(pid_()) -> monitor().
-doc(~" Start monitoring a process so that when the monitored process exits a
 message is sent to the monitoring process.

 The message is only sent once, when the target process exits. If the
 process was not alive when this function is called the message will never
 be received.

 The down message can be received with a selector and the
 `select_monitors` function.

 The process can be demonitored with the `demonitor_process` function.
").
monitor(Pid) ->
    erlang:monitor(process, Pid).

-file("src\\gleam\\erlang\\process.gleam", 550).
-spec select_specific_monitor(selector(DRU), monitor(), fun((down()) -> DRU)) -> selector(DRU).
-doc(~" Select for a message sent for a given monitor.

 Each monitor handler added to a selector has a select performance cost,
 so prefer [`select_monitors`](#select_monitors) if you are select
 for multiple monitors.

 The handler can be removed from the selector later using
 [`deselect_specific_monitor`](#deselect_specific_monitor).
").
select_specific_monitor(Selector, Monitor, Mapping) ->
    gleam_erlang_ffi:insert_selector_handler(Selector, Monitor, Mapping).

-file("src\\gleam\\erlang\\process.gleam", 564).
-spec select_monitors(selector(DRX), fun((down()) -> DRX)) -> selector(DRX).
-doc(~" Select for any messages sent for any monitors set up by the select process.

 If you want to select for a specific message then use 
 [`select_specific_monitor`](#select_specific_monitor), but this
 function is preferred if you need to select for multiple monitors.
").
select_monitors(Selector, Mapping) ->
    gleam_erlang_ffi:insert_selector_handler(Selector, {erlang:binary_to_atom(~"DOWN"), 5}, fun(Message) ->
        Mapping(gleam_erlang_ffi:cast_down_message(Message))
    end).

-file("src\\gleam\\erlang\\process.gleam", 585).
-spec demonitor_process(monitor()) -> nil.
-doc(~" Remove the monitor for a process so that when the monitor process exits a
 `Down` message is not sent to the monitoring process.

 If the message has already been sent it is removed from the monitoring
 process' mailbox.
").
demonitor_process(Monitor) ->
    gleam_erlang_ffi:demonitor(Monitor),
    nil.

-file("src\\gleam\\erlang\\process.gleam", 598).
-spec deselect_specific_monitor(selector(DSA), monitor()) -> selector(DSA).
-doc(~" Remove a `Monitor` from a `Selector` prevoiusly added by
 [`select_specific_monitor`](#select_specific_monitor). If
 the `Monitor` is not in the `Selector` it will be returned
 unchanged.
").
deselect_specific_monitor(Selector, Monitor) ->
    gleam_erlang_ffi:remove_selector_handler(Selector, Monitor).

-file("src\\gleam\\erlang\\process.gleam", 605).
-spec perform_call(subject(DSD), fun((subject(DSF)) -> DSD), fun((selector(DSF)) -> {ok, DSF} | {error, nil})) -> DSF.
perform_call(Subject, Make_request, Run_selector) ->
    Reply_subject = new_subject(),
    case subject_owner(Subject) of
        {ok, Callee} ->
            Monitor = monitor(Callee),
            send(Subject, Make_request(Reply_subject)),
            Reply = begin
                _pipe = gleam_erlang_ffi:new_selector(),
                _pipe@1 = select(_pipe, Reply_subject),
                _pipe@2 = select_specific_monitor(_pipe@1, Monitor, fun(Down) ->
                    erlang:error(#{
                        gleam_error => panic,
                        message => <<"callee exited: "/utf8, (gleam@string:inspect(Down))/binary>>,
                        file => ~"src\\gleam\\erlang\\process.gleam",
                        module => ~"gleam/erlang/process",
                        function => ~"perform_call",
                        line => 626
                    })
                end),
                Run_selector(_pipe@2)
            end,
            case Reply of
                {ok, Reply@1} ->
                    demonitor_process(Monitor),
                    Reply@1;

                _value ->
                    erlang:error(#{
                        gleam_error => let_assert,
                        message => ~"callee did not send reply before timeout",
                        file => ~"src\\gleam\\erlang\\process.gleam",
                        module => ~"gleam/erlang/process",
                        function => ~"perform_call",
                        line => 630,
                        value => _value,
                        start => 21766,
                        'end' => 21794,
                        pattern_start => 21777,
                        pattern_end => 21786
                    })
            end;

        _value@1 ->
            erlang:error(#{
                gleam_error => let_assert,
                message => ~"Callee subject had no owner",
                file => ~"src\\gleam\\erlang\\process.gleam",
                module => ~"gleam/erlang/process",
                function => ~"perform_call",
                line => 611,
                value => _value@1,
                start => 21173,
                'end' => 21219,
                pattern_start => 21184,
                pattern_end => 21194
            })
    end.

-file("src\\gleam\\erlang\\process.gleam", 695).
-spec call(subject(DSK), integer(), fun((subject(DSM)) -> DSK)) -> DSM.
-doc(~" Send a message to a process and wait a given number of milliseconds for a
 reply.

 ## Panics

 This function will panic under the following circumstances:
 - The callee process exited prior to sending a reply.
 - The callee process did not send a reply within the permitted amount of
   time.
 - The subject is a named subject but no process is registered with that
   name.

 ## Examples

 ```gleam
 pub type Message {
   // This message variant is to be used with `call`.
   // The `reply` field contains a subject that the reply message will be
   // sent over.
   SayHello(reply_to: Subject(String), name: String)
 }
 
 // Typically we make public functions that hide the details of a process'
 // message-based API.
 pub fn say_hello(subject: Subject(Message), name: String) -> String {
   // The `SayHello` message constructor is given _partially applied_ with
   // all the arguments except the reply subject, which will be supplied by
   // the `call` function itself before sending the message.
   process.call(subject, 100, SayHello(_, name))
 }

 // This is the message handling logic used by the process that owns the
 // subject, and so receives the messages. In a real project it would be
 // within a process or some higher level abstraction like an actor, but for
 // this demonstration that has been omitted.
 pub fn handle_message(message: Message) -> Nil {
   case message {
     SayHello(reply:, name:) -> {
       let data = \"Hello, \" <> name <> \"!\"
       // The reply subject is used to send the response back.
       // If the receiver process does not sent a reply in time then the
       // caller will crash.
       process.send(reply, data)
     }
   }
 }

 // Here is what it looks like using the functional API to call the process.
 pub fn run(subject: Subject(Message)) {
   say_hello(subject, \"Lucy\")
   // -> \"Hello, Lucy!\"
   say_hello(subject, \"Nubi\")
   // -> \"Hello, Nubi!\"
 }
 ```
").
call(Subject, Timeout, Make_request) ->
    perform_call(Subject, Make_request, fun(_capture) ->
        gleam_erlang_ffi:select(_capture, Timeout)
    end).

-file("src\\gleam\\erlang\\process.gleam", 712).
-spec call_forever(subject(DSO), fun((subject(DSQ)) -> DSO)) -> DSQ.
-doc(~" Send a message to a process and wait for a reply.

 # Panics

 This function will panic under the following circumstances:
 - The callee process exited prior to sending a reply.
 - The subject is a named subject but no process is registered with that
   name.
").
call_forever(Subject, Make_request) ->
    perform_call(Subject, Make_request, fun(S) ->
        {ok, gleam_erlang_ffi:select(S)}
    end).

-file("src\\gleam\\erlang\\process.gleam", 729).
-spec link(pid_()) -> boolean().
-doc(~" Creates a link between the calling process and another process.

 When a process crashes any linked processes will also crash. This is useful
 to ensure that groups of processes that depend on each other all either
 succeed or fail together.

 Returns `True` if the link was created successfully, returns `False` if the
 process was not alive and as such could not be linked.
").
link(Pid) ->
    gleam_erlang_ffi:link(Pid).

-file("src\\gleam\\erlang\\process.gleam", 736).
-spec unlink(pid_()) -> nil.
-doc(~" Removes any existing link between the caller process and the target process.
").
unlink(Pid) ->
    erlang:unlink(Pid),
    nil.

-file("src\\gleam\\erlang\\process.gleam", 751).
-spec send_after(subject(DSW), integer(), DSW) -> timer().
-doc(~" Send a message over a channel after a specified number of milliseconds.
").
send_after(Subject, Delay, Message) ->
    case Subject of
        {named_subject, Name} ->
            erlang:send_after(Delay, Name, {Name, Message});

        {subject, Owner, Tag} ->
            erlang:send_after(Delay, Owner, {Tag, Message})
    end.

-file("src\\gleam\\erlang\\process.gleam", 781).
-spec cancel_timer(timer()) -> cancelled().
-doc(~" Cancel a given timer, causing it not to trigger if it has not done already.
").
cancel_timer(Timer) ->
    case gleam@dynamic@decode:run(erlang:cancel_timer(Timer), {decoder, fun gleam@dynamic@decode:decode_int/1}) of
        {ok, I} ->
            {cancelled, I};

        {error, _} ->
            timer_not_found
    end.

-file("src\\gleam\\erlang\\process.gleam", 805).
-spec kill(pid_()) -> nil.
-doc(~" Send an untrappable `kill` exit signal to the target process.

 See the documentation for the Erlang [`erlang:exit`][1] function for more
 information.

 [1]: https://erlang.org/doc/man/erlang.html#exit-1
").
kill(Pid) ->
    erlang:exit(Pid, kill),
    nil.

-file("src\\gleam\\erlang\\process.gleam", 821).
-spec send_exit(pid_()) -> nil.
-doc(~" Sends an exit signal to a process, indicating that the process is to shut
 down.

 See the [Erlang documentation][1] for more information.

 [1]: http://erlang.org/doc/man/erlang.html#exit-2
").
send_exit(Pid) ->
    erlang:exit(Pid, normal),
    nil.

-file("src\\gleam\\erlang\\process.gleam", 833).
-spec send_abnormal_exit(pid_(), any()) -> nil.
-doc(~" Sends an exit signal to a process, indicating that the process is to shut
 down due to an abnormal reason such as a failure.

 See the [Erlang documentation][1] for more information.

 [1]: http://erlang.org/doc/man/erlang.html#exit-2
").
send_abnormal_exit(Pid, Reason) ->
    erlang:exit(Pid, Reason),
    nil.

-file("src\\gleam\\erlang\\process.gleam", 849).
-spec trap_exits(boolean()) -> nil.
-doc(~" Set whether the current process is to trap exit signals or not.

 When not trapping exits if a linked process crashes the exit signal
 propagates to the process which will also crash.
 This is the normal behaviour before this function is called.

 When trapping exits (after this function is called) if a linked process
 crashes an exit message is sent to the process instead. These messages can
 be handled with the `select_trapped_exits` function.
").
trap_exits(A) ->
    gleam_erlang_ffi:trap_exits(A).

-file("src\\gleam\\erlang\\process.gleam", 860).
-spec register(pid_(), name(any())) -> {ok, nil} | {error, nil}.
-doc(~" Register a process under a given name, allowing it to be looked up using
 the `named` function.

 This function will return an error under the following conditions:
 - The process for the pid no longer exists.
 - The name has already been registered.
 - The process already has a name.
").
register(Pid, Name) ->
    gleam_erlang_ffi:register_process(Pid, Name).

-file("src\\gleam\\erlang\\process.gleam", 871).
-spec unregister(name(any())) -> {ok, nil} | {error, nil}.
-doc(~" Un-register a process name, after which the process can no longer be looked
 up by that name, and both the name and the process can be re-used in other
 registrations.

 It is possible to un-register process that are not from your application,
 including those from Erlang/OTP itself. This is not recommended and will
 likely result in undesirable behaviour and crashes.
").
unregister(Name) ->
    gleam_erlang_ffi:unregister_process(Name).

