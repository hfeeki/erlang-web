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
%% Ltd. Portions created by Erlang Training & Consulting Ltd are Copyright 2009,
%% Erlang Training & Consulting Ltd. All Rights Reserved.

%%%-------------------------------------------------------------------
%%% File	: wpart_cache.erl
%%% @author Michal Ptaszek <michal.ptaszek@erlang-consulting.com>
%%% @doc Cache HTML parts expanding module.
%%% @end
%%%-------------------------------------------------------------------
-module(wpart_cache).

-export([process_xml/1]).

-include_lib("xmerl/include/xmerl.hrl").

-define(DEFAULT_TIMEOUT, 10000000).

process_xml(E) ->
    case application:get_env(eptic, node_type) of
	{ok, frontend} ->
	    cached_content(E);
	_ ->
	    wpart_xs:process_xml(E#xmlElement.content)
    end.

%% @todo add the cache group when saving
cached_content(E) ->
    Id = wpartlib:has_attribute("attribute::id", E),
    Groups = wpartlib:has_attribute("attribute::groups", E),
    
    if 
	Id == false;
	Groups == false ->
	    wpart_xs:process_xml(E#xmlElement.content);
	true ->
	    BId = list_to_binary(Id),
	    case e_fe_cache:check_cache(BId) of
		not_found ->
		    Type = case wpartlib:has_attribute("attribute::type", E) of
			       "persistent" ->
				   persistent;
			       "timeout(" ++ Rest ->
				   case catch list_to_integer(lists:reverse(tl(lists:reverse(Rest)))) of
				       {'EXIT', _} ->
					   normal;
				       T ->
					   {timeout, T}
				   end;
			       "timeout" ->
				   {timeout, ?DEFAULT_TIMEOUT};
			       _ ->
				   normal
			   end,
		    Result = wpart_xs:process_xml(E#xmlElement.content),
		    e_fe_cache:save_cache(Type, BId, term_to_binary(Result)),
		    Result;
		{cached, Cache} ->
		    Cache
	    end
    end.
