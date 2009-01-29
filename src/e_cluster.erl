%% The contents of this file are subject to the Erlang Web Public License,
%% Version 1.0, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Web Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang-consulting.com/.
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%%
%% The Initial Developer of the Original Code is Erlang Training & Consulting
%% Ltd. Portions created by Erlang Training & Consulting Ltd are Copyright 2008,
%% Erlang Training & Consulting Ltd. All Rights Reserved.

%%%-------------------------------------------------------------------
%%% File    : e_cluster.erl
%%% @author Michal Ptaszek <michal.ptaszek@erlang-consulting.com>
%%% @end
%%%-------------------------------------------------------------------
-module(e_cluster).

-export([inform_fe_servers/0, dispatcher_reload/0, invalidate/1]).
-export([be_request/4, synchronize_docroot/1]).

%% 1 MB
-define(MAX_FILE_CHUNK, 1 bsl 20).

-spec(inform_fe_servers/0 :: () -> ok).	     
inform_fe_servers() ->
    Fun = fun(Server) ->
		  rpc:cast(Server, e_fe_proxy, be_register, [node()])
	  end,
    call_servers(Fun).

-spec(dispatcher_reload/0 :: () -> ok).	     
dispatcher_reload() ->
    Conf = ets:tab2list(e_dispatcher),

    Fun = fun(Server) ->
		  rpc:cast(Server, e_fe_cache, dispatcher_reload, [Conf])
	  end,
    call_servers(Fun).

-spec(invalidate/1 :: (list(string())) -> ok).	     
invalidate(List) ->
    Compiled = lists:map(fun(Regexp) ->
				 {ok, R} = re:compile(Regexp), 
				 R 
			 end, List),
    Fun = fun(Server) ->
		  rpc:call(Server, e_fe_cache, invalidate_handler, [Compiled])
	  end,
    call_servers(Fun).

-spec(be_request/4 :: (atom(), atom(), atom(), term()) -> {term(), term()}).	     
be_request(M, F, A, Dict) ->
    e_dict:init_state(Dict),
    {e_mod_gen:controller(M, F, A), e_dict:get_state(), self()}.

-spec(call_servers/1 :: (fun()) -> ok).	     
call_servers(Fun) ->
    FEs = e_conf:fe_servers(),
    lists:foreach(Fun, FEs).

-spec(synchronize_docroot/1 :: (string()) -> ok | {error, term()}).
synchronize_docroot(Filename) ->	     
    case e_file:get_size(Filename) of
	N when N < ?MAX_FILE_CHUNK ->
	    copy_file(Filename);
	Size ->
	    copy_file_chunk(Filename, Size)
    end.

-spec(copy_file/1 :: (string()) -> ok | {error, term()}).	     
copy_file(Filename) ->
    case file:read_file(Filename) of
	{ok, Binary} ->
	    Fun = fun(Server) ->
			  rpc:cast(Server, e_fe_cluster, write_file, [Filename, Binary])
		  end,
	    call_servers(Fun);
	{error, Reason} ->
	    {error, Reason}
    end.
    
-spec(copy_file_chunk/2 :: (string(), integer()) -> ok | {error, term()}).	     
copy_file_chunk(Filename, Size) ->
    ok.
