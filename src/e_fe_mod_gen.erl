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

%%
%% @author Michal Ptaszek <michal.ptaszek@erlang-consulting.com>
%% @doc Generic module for all e_fe_mod_* servers.
%%
-module(e_fe_mod_gen).

-export([handle_request/2]).
-export([view/1]).

%%
%% @spec handle_request(Url :: string()) -> Response :: term()
%% @doc Handles the incoming request.
%% The docroot content and the static routes are always handled
%% by the frontend server. The dynamic ones are passed to the 
%% backend node. 
%%
-spec(handle_request/1 :: (string()) -> term()).	     
handle_request("/app/" ++ URL) ->
    case parse_url(URL) of
	{M, F, A} -> dynamic_request(M, F, A);
	{view, View} -> static_request(URL, View);
	{error, Error} -> error_request(501, Error)
    end;
handle_request(URL) ->
    case e_dispatcher:dispatch(URL) of
	{M, F, A} -> dynamic_request(M, F, A);
	{view, View} -> static_request(URL, View);
	{error, Code, Path} -> error_request(Code, Path);
	invalid_url -> enoent  
    end.

-spec(static_request/2 :: (string(), string()) -> term()).	     
static_request(URL, View) ->
    BURL = list_to_binary(URL),
    case e_fe_cache:request(BURL) of
	not_found ->
	    Response = e_fe_cache:ask_front_end(BURL, View),
	    e_fe_cache:save_cache(persistent, BURL, term_to_binary(Response)),
	    Response;
	{cache, Cached} ->
	    Cached
    end.

dynamic_request(M, F, A) ->
    BURL = list_to_binary(URL),
    case e_fe_cache:request(BURL) of
	not_found ->
	    Response = controller_exec(e_fe_cache:ask_back_end(BURL, M, F, A)),
%% process the response, expand the template, etc.
	    e_fe_cache:save_cache(URL, Response),
	    Reponse;
	{cache, Cached} ->
	    Cached
    end.

error_request(Code, Path) ->
    ok.

-spec(view/1 :: (string()) -> term()).	     
view(View) ->
    template(template_file(View)).

-spec(template_file/1 :: (string()) -> string()).	     
template_file(View) ->
    filename:join([
		   e_conf:template_root(),
		   sanitize_file_name(View)
		  ]).

-spec(template/1 :: (string()) -> term()).
template(File) ->
    case e_cache:read_file(File) of
	{error, Error} ->
	    error_page(404, File, {e_cache_error, Error});
	E ->
	    {html, wpart_xs:process_xml(E)}
    end.

controller_exec({ret_view, Ret, View}) ->
    ok;
controller_exec({html, HTML}) ->
    ok;
controller_exec([Status, HTML]) ->
    ok;
controller_exec(Else) ->
    ok.

-spec(sanitize_file_name/1 :: (string()) -> string()).	     
sanitize_file_name([$.,$.|T]) ->
    sanitize_file_name([$.|T]);
sanitize_file_name([H|T]) ->
    case lists:member(H, " &;'`{}!\\?<>\"()$") of
        true ->
            sanitize_file_name(T);
        false ->
            [H|sanitize_file_name(T)]
    end;
sanitize_file_name([]) ->
    [].
