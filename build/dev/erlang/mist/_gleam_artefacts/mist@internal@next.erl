-module(mist@internal@next).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export_type([next/2]).
-moduledoc(false).

-type next(LUV, LUW) :: {continue, LUV, gleam@option:option(gleam@erlang@process:selector(LUW))} | normal_stop | {abnormal_stop, binary()}.

