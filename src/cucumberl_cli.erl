-module(cucumberl_cli).
-include("cucumberl.hrl").
-export([main/1]).

%% TODO: introduce command line arguments to control things like
%%      (a) features directory
%%      (b) extra sources/directories to add to code:path
%%      (c) choice of feature(s) to be run
%%      (d) support for code coverage....

main(_) ->
    code:add_pathz("ebin"),
    code:add_pathz("../ebin"),
              
    Features = find_files("features", ".*\\.feature\$"),
    Outcomes = [ run_feature(F) || F <- Features ],
    case lists:all(fun(X) -> X =:= ok end, Outcomes) of
        true    -> ok;
        false   -> halt(1)
    end.

run_feature(FeatureFile) ->
    %% is there a mod *named* for this feature?
    StepModName = step_mod_name(FeatureFile),
    StepMod = (catch ensure_loaded(StepModName)),
    case StepMod of
        {error, nofile} -> 
            io:format("no module ~p found for feature ~p~n", [StepModName, FeatureFile]),
            {failed, []};
        
        _Other          -> 
            {ok, #cucumberl_stats{failures=Failed}} =
                cucumberl:run(FeatureFile, StepMod),
            case Failed of
                [] ->
                    ok;
                _ ->
                    io:format("~p failed steps.~n", [length(Failed)]),
                    {failed, Failed}
            end
    end.

ensure_loaded(Mod) when is_atom(Mod) ->
    case code:ensure_loaded(Mod) of
        {error, _}=E ->
            throw(E);
        _ ->
            Mod
    end.

find_files(Dir, Regex) ->
    filelib:fold_files(Dir, Regex, true, fun(F, Acc) -> [F | Acc] end, []).

-define(STEPMOD_PREFIX, "sm").

%% step_mod_name/1
%%
%% @doc generate unique and valid name for step module from path and name of feature file.
%%
-spec step_mod_name(FeatureFile :: file:filename()) -> atom().
step_mod_name(FeatureFile) ->
    %% should work, as the main will only run in the presence of a directory called 'features'
    ["features"| DirElems] = filename:split(filename:dirname(FeatureFile)),
    
    Elems = [?STEPMOD_PREFIX] ++ DirElems ++ [filename:basename(FeatureFile, ".feature")],
    
    list_to_atom(string:to_lower(string:join(Elems, "_"))).

