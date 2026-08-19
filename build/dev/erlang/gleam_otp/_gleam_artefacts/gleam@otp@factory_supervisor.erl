-module(gleam@otp@factory_supervisor).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([get_by_name/1, worker_child/1, supervisor_child/1, named/2, restart_tolerance/3, timeout/2, restart_strategy/2, start/1, supervised/1, start_child/2, init/1, start_child_callback/2]).
-export_type([supervisor/2, message/2, builder/2, erlang_start_flags/0, erlang_supervisor_name/2, strategy/0, erlang_start_flag/1, erlang_child_spec/0, erlang_child_spec_property/2, timeout_/0]).
-moduledoc(~" A supervisor where child processes are started dynamically from a
 pre-specified template, so new processes can be created as needed
 while the program is running.

 When the supervisor is shut down it shuts down all its children
 concurrently and in no specified order.

 For further detail see the Erlang documentation, particularly the parts
 about the `simple_one_for_one` restart strategy, which is the Erlang
 equivilent of the factory supervisor.
 <https://www.erlang.org/doc/apps/stdlib/supervisor.html>.

 ## Usage

 Add the factory supervisor to your supervision tree using the `supervised`
 function and a name created at the start of the program. The `new`
 function takes a \"template function\", which is a function that takes one
 argument and starts a linked child process.

 You most likely want to give the factory supervisor a name, and to pass
 that name to any other processes that will want to cause new child
 processes to be started under the factory supervisor. In this example a
 web server is used.

 ```gleam
 import gleam/erlang/process.{type Name}
 import gleam/otp/actor.{type StartResult}
 import gleam/otp/factory_supervisor as factory
 import gleam/otp/static_supervisor as supervisor
 import my_app
 
 /// This function starts the application's supervision tree.
 ///
 /// It takes a record as an argument that 
 ///
 pub fn start_supervision_tree(reporters_name: Name(_)) -> StartResult(_) {
   // Define a named factory supervisor that can create new child processes
   // using the `my_app.start_reporter_actor` function, which is defined
   // elsewhere in the program.
   let reporter_factory_supervisor =
     factory.worker_child(my_app.start_reporter_actor)
     |> factory.named(reporters_name)
     |> factory.supervised
 
   // This web server process takes the name, so it can contact the factory
   // supervisor to command it to start new processes as needed.
   let web_server = my_app.supervised_web_server(reporters_name)
 
   // Create the top-level static supervisor with the supervisor and web
   // server as its children
   supervisor.new(supervisor.RestForOne)
   |> supervisor.add(reporter_factory_supervisor)
   |> supervisor.add(web_server)
   |> supervisor.start
 }
 ```

 Any process with the name of the factory supervisor can use the
 `get_by_name` function to get a reference to the supervisor, and then use
 the `start_child` function to have it start new child processes.

 Remember! Each process name created with `process.new_name` is unique.
 Two names created by calling the function twice are different names, even
 if the same string is given as an argument. You must create the name value
 at the start of your program and then pass it down into application code
 and library code that uses names.

 ```gleam
 import gleam/http/request.{type Request}
 import gleam/http/response.{type Response}
 import gleam/otp/factory_supervisor
 import my_app
 
 /// In our example this function is called each time a HTTP request is 
 /// received by the web server.
 pub fn handle_request(req: Request(_), reporters: Name(_)) -> Response(_) {
   // Get a reference to the supervisor using the name
   let supervisor = factory_supervisor.get_by_name(reporters)
 
   // Start a new child process under the supervisor, passing the request path 
   // to use as the argument for the child-starting template function.
   let start_result = factory_supervisor.start_child(supervisor, request.path)
 
   // A response is sent to the HTTP client.
   // The child starting template function returns a result, with the error case
   // being used when children fail to start. Because of this the `start_child`
   // function also returns a result, so it must be handled too.
   case start_result {
     Ok(_) -> response.new(200)
     Error(_) -> response.new(500)
   }
 }
 ```").

-opaque supervisor(GDJ, GDK) :: {supervisor, gleam@erlang@process:pid_()} | {named_supervisor, gleam@erlang@process:name(message(GDJ, GDK))}.

-type message(GDL, GDM) :: any() | {gleam_phantom, GDL, GDM}.

-opaque builder(GDN, GDO) :: {builder, gleam@otp@supervision:child_type(), fun((GDN) -> {ok, gleam@otp@actor:started(GDO)} | {error, gleam@otp@actor:start_error()}), gleam@otp@supervision:restart(), integer(), integer(), gleam@option:option(gleam@erlang@process:name(message(GDN, GDO)))}.

-type erlang_start_flags() :: any().

-type erlang_supervisor_name(GDP, GDQ) :: {local, gleam@erlang@process:name(message(GDP, GDQ))}.

-type strategy() :: simple_one_for_one.

-type erlang_start_flag(GDR) :: {strategy, strategy()} | {intensity, integer()} | {period, integer()} | {gleam_phantom, GDR}.

-type erlang_child_spec() :: any().

-type erlang_child_spec_property(GDS, GDT) :: {id, integer()} | {start, {gleam@erlang@atom:atom_(), gleam@erlang@atom:atom_(), list(fun((GDS) -> {ok, gleam@otp@actor:started(GDT)} | {error, gleam@otp@actor:start_error()}))}} | {restart, gleam@otp@supervision:restart()} | {type, gleam@erlang@atom:atom_()} | {shutdown, timeout_()}.

-type timeout_() :: any().

-file("src\\gleam\\otp\\factory_supervisor.gleam", 137).
-spec get_by_name(gleam@erlang@process:name(message(GDU, GDV))) -> supervisor(GDU, GDV).
-doc(~" Get a reference to a supervisor using its registered name.

 If no supervisor has been started using this name then functions
 using this reference will fail.

 # Panics

 Functions using the `Supervisor` reference returned by this function
 will panic if there is no factory supervisor registered with the name
 when they are called. Always make sure your supervisors are themselves
 supervised.
").
get_by_name(Name) ->
    {named_supervisor, Name}.

-file("src\\gleam\\otp\\factory_supervisor.gleam", 164).
-spec worker_child(fun((GEB) -> {ok, gleam@otp@actor:started(GEC)} | {error, gleam@otp@actor:start_error()})) -> builder(GEB, GEC).
-doc(~" Configure a supervisor with a child-starting template function.

 You should use this unless the child processes are also supervisors.

 The default shutdown timeout is 5000ms. This can be changed with the
 `timeout` function.
").
worker_child(Template) ->
    {builder, {worker, 5000}, Template, transient, 2, 5, none}.

-file("src\\gleam\\otp\\factory_supervisor.gleam", 185).
-spec supervisor_child(fun((GEG) -> {ok, gleam@otp@actor:started(GEH)} | {error, gleam@otp@actor:start_error()})) -> builder(GEG, GEH).
-doc(~" Configure a supervisor with a template that will start children that are
 also supervisors.

 You should only use this if the child processes are also supervisors.

 Supervisor children have an unlimited amount of time to shutdown, there is
 no timeout.
").
supervisor_child(Template) ->
    {builder, supervisor, Template, transient, 2, 5, none}.

-file("src\\gleam\\otp\\factory_supervisor.gleam", 206).
-spec named(builder(GEL, GEM), gleam@erlang@process:name(message(GEL, GEM))) -> builder(GEL, GEM).
-doc(~" Provide a name for the supervisor to be registered with when started,
 enabling it be more easily contacted by other processes. This is useful for
 enabling processes that can take over from an older one that has exited due
 to a failure.

 If the name is already registered to another process then the factory
 supervisor will fail to start.
").
named(Builder, Name) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), {some, Name}}.

-file("src\\gleam\\otp\\factory_supervisor.gleam", 224).
-spec restart_tolerance(builder(GEU, GEV), integer(), integer()) -> builder(GEU, GEV).
-doc(~" To prevent a supervisor from getting into an infinite loop of child
 process terminations and restarts, a maximum restart tolerance is
 defined using two integer values specified with keys intensity and
 period in the above map. Assuming the values MaxR for intensity and MaxT
 for period, then, if more than MaxR restarts occur within MaxT seconds,
 the supervisor terminates all child processes and then itself. The
 termination reason for the supervisor itself in that case will be
 shutdown. 

 Intensity defaults to 2 and period defaults to 5.
").
restart_tolerance(Builder, Intensity, Period) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), Intensity, Period, erlang:element(7, Builder)}.

-file("src\\gleam\\otp\\factory_supervisor.gleam", 239).
-spec timeout(builder(GFA, GFB), integer()) -> builder(GFA, GFB).
-doc(~" Configure the amount of milliseconds a child has to shut down before
 being brutal killed by the supervisor.

 If not set the default for a child is 5000ms.

 This will be ignored if the child is a supervisor itself.
").
timeout(Builder, Ms) ->
    case erlang:element(2, Builder) of
        {worker, _} ->
            {builder, {worker, Ms}, erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder)};

        _ ->
            Builder
    end.

-file("src\\gleam\\otp\\factory_supervisor.gleam", 256).
-spec restart_strategy(builder(GFG, GFH), gleam@otp@supervision:restart()) -> builder(GFG, GFH).
-doc(~" Configure the strategy for restarting children when they exit. See the
 documentation for the `supervision.Restart` for details.

 If not set the default strategy is `supervision.Transient`, so children
 will be restarted if they terminate abnormally.
").
restart_strategy(Builder, Restart_strategy) ->
    case erlang:element(2, Builder) of
        {worker, _} ->
            {builder, erlang:element(2, Builder), erlang:element(3, Builder), Restart_strategy, erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder)};

        _ ->
            Builder
    end.

-file("src\\gleam\\otp\\factory_supervisor.gleam", 275).
-spec start(builder(GFM, GFN)) -> {ok, gleam@otp@actor:started(supervisor(GFM, GFN))} | {error, gleam@otp@actor:start_error()}.
-doc(~" Start a new supervisor process with the configuration and child template
 specified within the builder.

 Typically you would use the `supervised` function to add your supervisor to
 a supervision tree instead of using this function directly.

 The supervisor will be linked to the parent process that calls this
 function.
").
start(Builder) ->
    Flags = maps:from_list([{strategy, simple_one_for_one}, {intensity, erlang:element(5, Builder)}, {period, erlang:element(6, Builder)}]),
    Module_atom = erlang:binary_to_atom(~"gleam@otp@factory_supervisor"),
    Function_atom = erlang:binary_to_atom(~"start_child_callback"),
    Mfa = {Module_atom, Function_atom, [erlang:element(3, Builder)]},
    {Type_, Shutdown} = case erlang:element(2, Builder) of
        supervisor ->
            {erlang:binary_to_atom(~"supervisor"), gleam_otp_external:make_timeout(-1)};

        {worker, Ms} ->
            {erlang:binary_to_atom(~"worker"), gleam_otp_external:make_timeout(Ms)}
    end,
    Child = maps:from_list([{id, 0}, {start, Mfa}, {restart, erlang:element(4, Builder)}, {type, Type_}, {shutdown, Shutdown}]),
    Configuration = {Flags, [Child]},
    Start_result = case erlang:element(7, Builder) of
        none ->
            supervisor:start_link(Module_atom, Configuration);

        {some, Name} ->
            supervisor:start_link({local, Name}, Module_atom, Configuration)
    end,
    case Start_result of
        {ok, Pid} ->
            {ok, {started, Pid, {supervisor, Pid}}};

        {error, Error} ->
            {error, gleam_otp_external:convert_erlang_start_error(Error)}
    end.

-file("src\\gleam\\otp\\factory_supervisor.gleam", 388).
-spec supervised(builder(GGL, GGM)) -> gleam@otp@supervision:child_specification(supervisor(GGL, GGM)).
-doc(~" Create a `ChildSpecification` that adds this supervisor as the child of
 another, making it fault tolerant and part of the application's supervision
 tree. You should prefer to starting unsupervised supervisors with the
 `start` function.

 If any child fails to start the supevisor first terminates all already
 started child processes with reason shutdown and then terminate itself and
 returns an error.
").
supervised(Builder) ->
    gleam@otp@supervision:supervisor(fun() ->
        start(Builder)
    end).

-file("src\\gleam\\otp\\factory_supervisor.gleam", 397).
-spec start_child(supervisor(GGS, GGT), GGS) -> {ok, gleam@otp@actor:started(GGT)} | {error, gleam@otp@actor:start_error()}.
-doc(~" Start a new child using the supervisor's child template and the given
 argument. The start result of the child is returned.
").
start_child(Supervisor, Argument) ->
    Start = case Supervisor of
        {named_supervisor, Name} ->
            fun(_capture) ->
                supervisor:start_child(Name, _capture)
            end;

        {supervisor, Pid} ->
            fun(_capture) ->
                supervisor:start_child(Pid, _capture)
            end
    end,
    case Start([Argument]) of
        {ok, Pid@1, Data} ->
            {ok, {started, Pid@1, Data}};

        {error, Reason} ->
            {error, Reason}
    end.

-file("src\\gleam\\otp\\factory_supervisor.gleam", 425).
-spec init(gleam@dynamic:dynamic_()) -> {ok, gleam@dynamic:dynamic_()} | {error, any()}.
-doc(false).
init(Start_data) ->
    {ok, Start_data}.

-file("src\\gleam\\otp\\factory_supervisor.gleam", 431).
-spec start_child_callback(fun((GHQ) -> {ok, gleam@otp@actor:started(GHR)} | {error, gleam@otp@actor:start_error()}), GHQ) -> gleam@otp@internal@result2:result2(gleam@erlang@process:pid_(), GHR, gleam@otp@actor:start_error()).
-doc(false).
start_child_callback(Start, Argument) ->
    case Start(Argument) of
        {ok, Started} ->
            {ok, erlang:element(2, Started), erlang:element(3, Started)};

        {error, Error} ->
            {error, Error}
    end.

