%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2007-2023 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(clustering_management_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("eunit/include/eunit.hrl").

-compile(export_all).

-define(LOOP_RECURSION_DELAY, 100).

all() ->
    [
     {group, mnesia_store},
     {group, khepri_store}
    ].

groups() ->
    [{mnesia_store, [], [
                         {unclustered_2_nodes, [], 
                          [
                           {cluster_size_2, [], [
                                                 classic_config_discovery_node_list
                                                ]}
                          ]},
                         {unclustered_3_nodes, [],
                          [
                           {cluster_size_3, [], [
                                                 join_and_part_cluster,
                                                 join_cluster_bad_operations,
                                                 join_to_start_interval,
                                                 forget_cluster_node,
                                                 change_cluster_node_type,
                                                 change_cluster_when_node_offline,
                                                 update_cluster_nodes,
                                                 force_reset_node
                                                ]}
                          ]},
                         {clustered_2_nodes, [],
                          [
                           {cluster_size_2, [], [
                                                 forget_removes_things,
                                                 reset_removes_things,
                                                 forget_offline_removes_things,
                                                 forget_unavailable_node_in_mnesia,
                                                 force_boot,
                                                 status_with_alarm,
                                                 pid_file_and_await_node_startup,
                                                 await_running_count,
                                                 start_with_invalid_schema_in_path,
                                                 persistent_cluster_id,
                                                 reset_last_disc_node
                                                ]}
                          ]},
                         {clustered_4_nodes, [],
                          [
                           {cluster_size_4, [], [
                                                 forget_promotes_offline_follower
                                                ]}
                          ]}
                        ]},
     {khepri_store, [], [
                         {clustered_2_nodes, [],
                          [
                           {cluster_size_2, [], [
                                                 change_cluster_node_type_in_khepri,
                                                 forget_node_in_khepri,
                                                 forget_removes_things_in_khepri,
                                                 forget_unavailable_node_in_khepri,
                                                 reset_in_khepri,
                                                 reset_removes_things_in_khepri,
                                                 reset_in_minority,
                                                 force_boot_in_khepri,
                                                 status_with_alarm,
                                                 pid_file_and_await_node_startup_in_khepri,
                                                 await_running_count_in_khepri,
                                                 start_with_invalid_schema_in_path,
                                                 persistent_cluster_id,
                                                 stop_start_cluster_node,
                                                 restart_cluster_node,
                                                 unsupported_forget_cluster_node_offline,
                                                 unsupported_update_cluster_nodes
                                                ]}
                          ]},
                         {unclustered_3_nodes, [],
                          [
                           {cluster_size_3, [], [
                                                 join_and_part_cluster_in_khepri,
                                                 join_cluster_bad_operations_in_khepri,
                                                 force_reset_node_in_khepri,
                                                 join_to_start_interval,
                                                 forget_cluster_node_in_khepri,
                                                 start_nodes_in_reverse_order,
                                                 start_nodes_in_stop_order,
                                                 start_nodes_in_stop_order_with_force_boot
                                                ]}
                          ]}
                        ]}
    ].

suite() ->
    [
      %% If a testcase hangs, no need to wait for 30 minutes.
      {timetrap, {minutes, 5}}
    ].

%% -------------------------------------------------------------------
%% Testsuite setup/teardown.
%% -------------------------------------------------------------------

init_per_suite(Config) ->
    rabbit_ct_helpers:log_environment(),
    Config1 = rabbit_ct_helpers:merge_app_env(
                Config, {rabbit, [
                          {mnesia_table_loading_retry_limit, 2},
                          {mnesia_table_loading_retry_timeout,1000}
                         ]}),
    rabbit_ct_helpers:run_setup_steps(Config1).

end_per_suite(Config) ->
    rabbit_ct_helpers:run_teardown_steps(Config).

init_per_group(mnesia_store, Config) ->
    rabbit_ct_helpers:set_config(Config, [{metadata_store, mnesia}]);
init_per_group(khepri_store, Config) ->
    rabbit_ct_helpers:set_config(Config, [{metadata_store, khepri}]);
init_per_group(unclustered_2_nodes, Config) ->
    rabbit_ct_helpers:set_config(Config, [{rmq_nodes_clustered, false}]);
init_per_group(unclustered_3_nodes, Config) ->
    rabbit_ct_helpers:set_config(Config, [{rmq_nodes_clustered, false}]);
init_per_group(clustered_2_nodes, Config) ->
    rabbit_ct_helpers:set_config(Config, [{rmq_nodes_clustered, true}]);
init_per_group(clustered_3_nodes, Config) ->
    rabbit_ct_helpers:set_config(Config, [{rmq_nodes_clustered, true}]);
init_per_group(clustered_4_nodes, Config) ->
    rabbit_ct_helpers:set_config(Config, [{rmq_nodes_clustered, true}]);
init_per_group(cluster_size_2, Config) ->
    rabbit_ct_helpers:set_config(Config, [{rmq_nodes_count, 2}]);
init_per_group(cluster_size_3, Config) ->
    rabbit_ct_helpers:set_config(Config, [{rmq_nodes_count, 3}]);
init_per_group(cluster_size_4, Config) ->
    rabbit_ct_helpers:set_config(Config, [{rmq_nodes_count, 4}]).

end_per_group(_, Config) ->
    Config.

init_per_testcase(create_bad_schema = Testcase, Config) ->
    case rabbit_ct_broker_helpers:configured_metadata_store(Config) of
        mnesia ->
            init_per_testcase0(Testcase, Config);
        _ ->
            {skip, "Mnesia operations not supported by Khepri"}
    end;
init_per_testcase(Testcase, Config) ->
    init_per_testcase0(Testcase, Config).

init_per_testcase0(Testcase, Config) ->
    rabbit_ct_helpers:testcase_started(Config, Testcase),
    ClusterSize = ?config(rmq_nodes_count, Config),
    TestNumber = rabbit_ct_helpers:testcase_number(Config, ?MODULE, Testcase),
    Config1 = rabbit_ct_helpers:set_config(Config, [
        {rmq_nodename_suffix, Testcase},
        {tcp_ports_base, {skip_n_nodes, TestNumber * ClusterSize}},
        {keep_pid_file_on_exit, true}
      ]),
    rabbit_ct_helpers:run_steps(Config1,
      rabbit_ct_broker_helpers:setup_steps() ++
      rabbit_ct_client_helpers:setup_steps()).

end_per_testcase(Testcase, Config) ->
    Config1 = rabbit_ct_helpers:run_steps(Config,
      rabbit_ct_client_helpers:teardown_steps() ++
      rabbit_ct_broker_helpers:teardown_steps()),
    rabbit_ct_helpers:testcase_finished(Config1, Testcase).

%% -------------------------------------------------------------------
%% Test cases
%% -------------------------------------------------------------------

start_with_invalid_schema_in_path(Config) ->
    [Rabbit, Hare] = cluster_members(Config),
    stop_app(Rabbit),
    stop_app(Hare),

    create_bad_schema(Rabbit, Hare, Config),

    spawn(fun() -> start_app(Hare) end),
    case start_app(Rabbit) of
        ok  -> ok;
        ErrRabbit -> error({unable_to_start_with_bad_schema_in_work_dir, ErrRabbit})
    end.

persistent_cluster_id(Config) ->
    case rabbit_ct_helpers:is_mixed_versions() of
      false ->
        [Rabbit, Hare] = cluster_members(Config),
        ClusterIDA1 = rpc:call(Rabbit, rabbit_nodes, persistent_cluster_id, []),
        ClusterIDB1 = rpc:call(Hare, rabbit_nodes, persistent_cluster_id, []),
        ?assertEqual(ClusterIDA1, ClusterIDB1),

        rabbit_ct_broker_helpers:restart_node(Config, Rabbit),
        ClusterIDA2 = rpc:call(Rabbit, rabbit_nodes, persistent_cluster_id, []),
        rabbit_ct_broker_helpers:restart_node(Config, Hare),
        ClusterIDB2 = rpc:call(Hare, rabbit_nodes, persistent_cluster_id, []),
        ?assertEqual(ClusterIDA1, ClusterIDA2),
        ?assertEqual(ClusterIDA2, ClusterIDB2);
      _ ->
        %% skip the test in mixed version mode
        {skip, "Should not run in mixed version environments"}
    end.

create_bad_schema(Rabbit, Hare, Config) ->
    {ok, RabbitMnesiaDir} = rpc:call(Rabbit, application, get_env, [mnesia, dir]),
    {ok, HareMnesiaDir} = rpc:call(Hare, application, get_env, [mnesia, dir]),
    %% Make sure we don't use the current dir:
    PrivDir = ?config(priv_dir, Config),
    ct:pal("Priv dir ~tp~n", [PrivDir]),
    ok = filelib:ensure_dir(filename:join(PrivDir, "file")),

    ok = rpc:call(Rabbit, file, set_cwd, [PrivDir]),
    ok = rpc:call(Hare, file, set_cwd, [PrivDir]),

    ok = rpc:call(Rabbit, application, unset_env, [mnesia, dir]),
    ok = rpc:call(Hare, application, unset_env, [mnesia, dir]),
    ok = rpc:call(Rabbit, mnesia, create_schema, [[Rabbit, Hare]]),
    ok = rpc:call(Rabbit, mnesia, start, []),
    {atomic,ok} = rpc:call(Rabbit, mnesia, create_table,
                                   [rabbit_queue, [{ram_copies, [Rabbit, Hare]}]]),
    stopped = rpc:call(Rabbit, mnesia, stop, []),
    ok = rpc:call(Rabbit, application, set_env, [mnesia, dir, RabbitMnesiaDir]),
    ok = rpc:call(Hare, application, set_env, [mnesia, dir, HareMnesiaDir]).

join_and_part_cluster(Config) ->
    [Rabbit, Hare, Bunny] = cluster_members(Config),
    assert_not_clustered(Rabbit),
    assert_not_clustered(Hare),
    assert_not_clustered(Bunny),

    stop_join_start(Rabbit, Bunny),
    assert_clustered([Rabbit, Bunny]),

    stop_join_start(Hare, Bunny, true),
    assert_cluster_status(
      {[Bunny, Hare, Rabbit], [Bunny, Rabbit], [Bunny, Hare, Rabbit]},
      [Rabbit, Hare, Bunny]),

    %% Allow clustering with already clustered node
    ok = stop_app(Rabbit),
    {ok, <<"The node is already a member of this cluster">>} =
        join_cluster(Rabbit, Hare),
    ok = start_app(Rabbit),

    stop_reset_start(Rabbit),
    assert_not_clustered(Rabbit),
    assert_cluster_status({[Bunny, Hare], [Bunny], [Bunny, Hare]},
                          [Hare, Bunny]),

    stop_reset_start(Hare),
    assert_not_clustered(Hare),
    assert_not_clustered(Bunny).

stop_start_cluster_node(Config) ->
    [Rabbit, Hare] = cluster_members(Config),

    assert_clustered([Rabbit, Hare]),

    ok = stop_app(Rabbit),
    ok = start_app(Rabbit),

    assert_clustered([Rabbit, Hare]),

    ok = stop_app(Hare),
    ok = start_app(Hare),

    assert_clustered([Rabbit, Hare]).

restart_cluster_node(Config) ->
    [Rabbit, Hare] = cluster_members(Config),

    assert_clustered([Rabbit, Hare]),
    
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    ok = rabbit_ct_broker_helpers:start_node(Config, Hare),

    assert_clustered([Rabbit, Hare]),

    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    ok = rabbit_ct_broker_helpers:start_node(Config, Rabbit),

    assert_clustered([Rabbit, Hare]).

join_and_part_cluster_in_khepri(Config) ->
    [Rabbit, Hare, Bunny] = cluster_members(Config),
    assert_not_clustered(Rabbit),
    assert_not_clustered(Hare),
    assert_not_clustered(Bunny),

    stop_join_start(Rabbit, Bunny),
    assert_clustered([Rabbit, Bunny]),

    stop_join_start(Hare, Bunny),
    assert_clustered([Rabbit, Bunny, Hare]),

    %% Allow clustering with already clustered node
    ok = stop_app(Rabbit),
    {ok, <<"The node is already a member of this cluster">>} =
        join_cluster(Rabbit, Hare),
    ok = start_app(Rabbit),

    assert_clustered([Rabbit, Bunny, Hare]),

    stop_reset_start(Bunny),
    assert_not_clustered(Bunny),
    assert_clustered([Hare, Rabbit]),

    stop_reset_start(Rabbit),
    assert_not_clustered(Rabbit),
    assert_not_clustered(Hare).

join_cluster_bad_operations(Config) ->
    [Rabbit, Hare, Bunny] = cluster_members(Config),

    UsePrelaunch = rabbit_ct_broker_helpers:rpc(
                     Config, Hare,
                     erlang, function_exported,
                     [rabbit_prelaunch, get_context, 0]),

    %% Nonexistent node
    ok = stop_app(Rabbit),
    assert_failure(fun () -> join_cluster(Rabbit, non@existent) end),
    ok = start_app(Rabbit),
    assert_not_clustered(Rabbit),

    %% Trying to cluster with mnesia running
    assert_failure(fun () -> join_cluster(Rabbit, Bunny) end),
    assert_not_clustered(Rabbit),

    %% Trying to cluster the node with itself
    ok = stop_app(Rabbit),
    assert_failure(fun () -> join_cluster(Rabbit, Rabbit) end),
    ok = start_app(Rabbit),
    assert_not_clustered(Rabbit),

    %% Do not let the node leave the cluster or reset if it's the only
    %% ram node
    stop_join_start(Hare, Rabbit, true),
    assert_cluster_status({[Rabbit, Hare], [Rabbit], [Rabbit, Hare]},
                          [Rabbit, Hare]),
    ok = stop_app(Hare),
    assert_failure(fun () -> join_cluster(Rabbit, Bunny) end),
    assert_failure(fun () -> reset(Rabbit) end),
    ok = start_app(Hare),
    assert_cluster_status({[Rabbit, Hare], [Rabbit], [Rabbit, Hare]},
                          [Rabbit, Hare]),

    %% Cannot start RAM-only node first
    ok = stop_app(Rabbit),
    ok = stop_app(Hare),
    assert_failure(fun () -> start_app(Hare) end),
    ok = start_app(Rabbit),
    case UsePrelaunch of
        true ->
            ok = start_app(Hare);
        false ->
            %% The Erlang VM has stopped after previous rabbit app failure
            ok = rabbit_ct_broker_helpers:start_node(Config, Hare)
    end,
    ok.

join_cluster_bad_operations_in_khepri(Config) ->
    [Rabbit, _Hare, Bunny] = cluster_members(Config),

    %% Nonexistent node
    ok = stop_app(Rabbit),
    assert_failure(fun () -> join_cluster(Rabbit, non@existent) end),
    ok = start_app(Rabbit),
    assert_not_clustered(Rabbit),

    %% Trying to cluster with mnesia running
    assert_failure(fun () -> join_cluster(Rabbit, Bunny) end),
    assert_not_clustered(Rabbit),

    %% Trying to cluster the node with itself
    ok = stop_app(Rabbit),
    assert_failure(fun () -> join_cluster(Rabbit, Rabbit) end),
    ok = start_app(Rabbit),
    assert_not_clustered(Rabbit),

    ok.

%% This tests that the nodes in the cluster are notified immediately of a node
%% join, and not just after the app is started.
join_to_start_interval(Config) ->
    [Rabbit, Hare, _Bunny] = cluster_members(Config),

    ok = stop_app(Rabbit),
    ok = join_cluster(Rabbit, Hare),
    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Hare]},
                          [Rabbit, Hare]),
    ok = start_app(Rabbit),
    assert_clustered([Rabbit, Hare]).

forget_cluster_node(Config) ->
    [Rabbit, Hare, Bunny] = cluster_members(Config),

    %% Trying to remove a node not in the cluster should fail
    assert_failure(fun () -> forget_cluster_node(Hare, Rabbit) end),

    stop_join_start(Rabbit, Hare),
    assert_clustered([Rabbit, Hare]),

    %% Trying to remove an online node should fail
    assert_failure(fun () -> forget_cluster_node(Hare, Rabbit) end),

    ok = stop_app(Rabbit),
    %% We're passing the --offline flag, but Hare is online
    assert_failure(fun () -> forget_cluster_node(Hare, Rabbit, true) end),
    %% Removing some nonexistent node will fail
    assert_failure(fun () -> forget_cluster_node(Hare, non@existent) end),
    ok = forget_cluster_node(Hare, Rabbit),
    assert_not_clustered(Hare),
    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Hare]},
                          [Rabbit]),

    %% Now we can't start Rabbit since it thinks that it's still in the cluster
    %% with Hare, while Hare disagrees.
    assert_failure(fun () -> start_app(Rabbit) end),

    ok = reset(Rabbit),
    ok = start_app(Rabbit),
    assert_not_clustered(Rabbit),

    %% Now we remove Rabbit from an offline node.
    stop_join_start(Bunny, Hare),
    stop_join_start(Rabbit, Hare),
    assert_clustered([Rabbit, Hare, Bunny]),
    ok = stop_app(Hare),
    ok = stop_app(Rabbit),
    ok = stop_app(Bunny),
    %% This is fine but we need the flag
    assert_failure(fun () -> forget_cluster_node(Hare, Bunny) end),
    %% Also fails because hare node is still running
    assert_failure(fun () -> forget_cluster_node(Hare, Bunny, true) end),
    %% But this works
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Hare,
      ["forget_cluster_node", "--offline", Bunny]),
    ok = rabbit_ct_broker_helpers:start_node(Config, Hare),
    ok = start_app(Rabbit),
    %% Bunny still thinks its clustered with Rabbit and Hare
    assert_failure(fun () -> start_app(Bunny) end),
    ok = reset(Bunny),
    ok = start_app(Bunny),
    assert_not_clustered(Bunny),
    assert_clustered([Rabbit, Hare]).

forget_cluster_node_in_khepri(Config) ->
    [Rabbit, Hare, _Bunny] = cluster_members(Config),

    %% Trying to remove a node not in the cluster should fail
    assert_failure(fun () -> forget_cluster_node(Hare, Rabbit) end),

    stop_join_start(Rabbit, Hare),
    assert_clustered([Rabbit, Hare]),

    %% Trying to remove an online node should fail
    assert_failure(fun () -> forget_cluster_node(Hare, Rabbit) end),

    ok = stop_app(Rabbit),
    %% Removing some nonexistent node will fail
    assert_failure(fun () -> forget_cluster_node(Hare, non@existent) end),
    ok = forget_cluster_node(Hare, Rabbit),
    assert_not_clustered(Hare),
    assert_status({[], [], [Rabbit, Hare], [Rabbit, Hare], [Hare]}, [Rabbit]),

    %% Now we can't start Rabbit since it thinks that it's still in the cluster
    %% with Hare, while Hare disagrees.
    assert_failure(fun () -> start_app(Rabbit) end),

    ok = reset(Rabbit),
    ok = start_app(Rabbit),
    assert_not_clustered(Rabbit),
    assert_not_clustered(Hare).

unsupported_forget_cluster_node_offline(Config) ->
    [Rabbit, Hare] = cluster_members(Config),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    ok = stop_app(Rabbit),
    Ret0 = rabbit_ct_broker_helpers:rabbitmqctl(Config, Hare,
                                                ["forget_cluster_node", "--offline", Rabbit]),
    is_not_supported(Ret0).

forget_removes_things(Config) ->
    test_removes_things(Config, fun (R, H) -> ok = forget_cluster_node(H, R) end).

reset_removes_things(Config) ->
    test_removes_things(Config, fun (R, _H) -> ok = reset(R) end).

test_removes_things(Config, LoseRabbit) ->
    Unmirrored = <<"unmirrored-queue">>,
    [Rabbit, Hare | _] = cluster_members(Config),
    RCh = rabbit_ct_client_helpers:open_channel(Config, Rabbit),
    declare(RCh, Unmirrored),
    ok = stop_app(Rabbit),

    HCh = rabbit_ct_client_helpers:open_channel(Config, Hare),
    {'EXIT',{{shutdown,{server_initiated_close,404,_}}, _}} =
        (catch declare(HCh, Unmirrored)),

    ok = LoseRabbit(Rabbit, Hare),
    HCh2 = rabbit_ct_client_helpers:open_channel(Config, Hare),
    declare(HCh2, Unmirrored),
    ok.

forget_node_in_khepri(Config) ->
    [Rabbit, Hare] = cluster_members(Config),
    
    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Rabbit, Hare]},
                          [Rabbit, Hare]),
    
    ok = stop_app(Rabbit),
    ok = forget_cluster_node(Hare, Rabbit),
    
    assert_cluster_status({[Hare], [Hare]}, [Hare]),

    ok.

forget_removes_things_in_khepri(Config) ->
    ClassicQueue = <<"classic-queue">>,
    [Rabbit, Hare | _] = cluster_members(Config),

    RCh = rabbit_ct_client_helpers:open_channel(Config, Rabbit),
    ?assertMatch(#'queue.declare_ok'{}, declare(RCh, ClassicQueue)),

    ok = stop_app(Rabbit),
    ok = forget_cluster_node(Hare, Rabbit),

    HCh = rabbit_ct_client_helpers:open_channel(Config, Hare),
    ?assertExit(
       {{shutdown, {server_initiated_close, 404, _}}, _},
       declare_passive(HCh, ClassicQueue)),

    ok.

forget_unavailable_node_in_khepri(Config) ->
    [Rabbit, Hare] = cluster_members(Config),

    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    Ret = forget_cluster_node(Hare, Rabbit),

    ?assertMatch({error, 69, _}, Ret),
    {error, _, Msg} = Ret,
    ?assertMatch(match, re:run(Msg, ".*must be running.*", [{capture, none}])).

forget_unavailable_node_in_mnesia(Config) ->
    [Rabbit, Hare] = cluster_members(Config),

    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    ?assertMatch(ok, forget_cluster_node(Hare, Rabbit)).

reset_in_khepri(Config) ->
    ClassicQueue = <<"classic-queue">>,
    [Rabbit, Hare | _] = cluster_members(Config),

    RCh = rabbit_ct_client_helpers:open_channel(Config, Rabbit),
    ?assertMatch(#'queue.declare_ok'{}, declare(RCh, ClassicQueue)),
    
    stop_app(Hare),
    ok = reset(Hare),

    %% Rabbit is a 1-node cluster. The classic queue is still there.
    assert_cluster_status({[Rabbit], [Rabbit]}, [Rabbit]),
    ?assertMatch(#'queue.declare_ok'{}, declare_passive(RCh, ClassicQueue)),

    %% Can't reset a running node
    ?assertMatch({error, 64, _}, reset(Rabbit)),

    %% Start Hare, it should work as standalone node.
    start_app(Hare),

    assert_cluster_status({[Hare], [Hare]}, [Hare]),

    ok.

reset_removes_things_in_khepri(Config) ->
    ClassicQueue = <<"classic-queue">>,
    [Rabbit, Hare | _] = cluster_members(Config),

    RCh = rabbit_ct_client_helpers:open_channel(Config, Rabbit),
    ?assertMatch(#'queue.declare_ok'{}, declare(RCh, ClassicQueue)),

    stop_app(Rabbit),
    ok = reset(Rabbit),

    assert_cluster_status({[Hare], [Hare]}, [Hare]),

    start_app(Rabbit),
    assert_cluster_status({[Rabbit], [Rabbit]}, [Rabbit]),

    %% The classic queue was declared in Rabbit, once that node is reset
    %% the queue needs to be removed from the rest of the cluster
    HCh = rabbit_ct_client_helpers:open_channel(Config, Hare),
    ?assertExit(
       {{shutdown, {server_initiated_close, 404, _}}, _},
       declare_passive(HCh, ClassicQueue)),

    ok.

reset_in_minority(Config) ->
    [Rabbit, Hare | _] = cluster_members(Config),

    rabbit_ct_broker_helpers:stop_node(Config, Hare),

    stop_app(Rabbit),
    ?assertMatch({error, 75, _}, reset(Rabbit)),

    ok.

reset_last_disc_node(Config) ->
    Servers = [Rabbit, Hare | _] = cluster_members(Config),

    stop_app(Hare),
    ?assertEqual(ok, change_cluster_node_type(Hare, ram)),
    start_app(Hare),

    ok = rabbit_ct_broker_helpers:enable_feature_flag(Config, Servers, raft_based_metadata_store_phase1),

    stop_app(Rabbit),
    ?assertMatch({error, 69, _}, reset(Rabbit)),

    ok.

forget_offline_removes_things(Config) ->
    [Rabbit, Hare] = rabbit_ct_broker_helpers:get_node_configs(Config,
      nodename),
    Unmirrored = <<"unmirrored-queue">>,
    X = <<"X">>,
    RCh = rabbit_ct_client_helpers:open_channel(Config, Rabbit),
    declare(RCh, Unmirrored),

    amqp_channel:call(RCh, #'exchange.declare'{durable     = true,
                                               exchange    = X,
                                               auto_delete = true}),
    amqp_channel:call(RCh, #'queue.bind'{queue    = Unmirrored,
                                         exchange = X}),
    ok = rabbit_ct_broker_helpers:stop_broker(Config, Rabbit),

    HCh = rabbit_ct_client_helpers:open_channel(Config, Hare),
    {'EXIT',{{shutdown,{server_initiated_close,404,_}}, _}} =
        (catch declare(HCh, Unmirrored)),

    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Hare,
      ["forget_cluster_node", "--offline", Rabbit]),
    ok = rabbit_ct_broker_helpers:start_node(Config, Hare),

    HCh2 = rabbit_ct_client_helpers:open_channel(Config, Hare),
    declare(HCh2, Unmirrored),
    {'EXIT',{{shutdown,{server_initiated_close,404,_}}, _}} =
        (catch amqp_channel:call(HCh2,#'exchange.declare'{durable     = true,
                                                          exchange    = X,
                                                          auto_delete = true,
                                                          passive     = true})),
    ok.

forget_promotes_offline_follower(Config) ->
    [A, B, C, D] = rabbit_ct_broker_helpers:get_node_configs(Config, nodename),
    ACh = rabbit_ct_client_helpers:open_channel(Config, A),
    QName = <<"mirrored-queue">>,
    declare(ACh, QName),
    set_ha_policy(Config, QName, A, [B, C]),
    set_ha_policy(Config, QName, A, [C, D]), %% Test add and remove from recoverable_mirrors

    %% Publish and confirm
    amqp_channel:call(ACh, #'confirm.select'{}),
    amqp_channel:cast(ACh, #'basic.publish'{routing_key = QName},
                      #amqp_msg{props = #'P_basic'{delivery_mode = 2}}),
    amqp_channel:wait_for_confirms(ACh),

    %% We kill nodes rather than stop them in order to make sure
    %% that we aren't dependent on anything that happens as they shut
    %% down (see bug 26467).
    ok = rabbit_ct_broker_helpers:kill_node(Config, D),
    ok = rabbit_ct_broker_helpers:kill_node(Config, C),
    ok = rabbit_ct_broker_helpers:kill_node(Config, B),
    ok = rabbit_ct_broker_helpers:kill_node(Config, A),

    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, C,
      ["force_boot"]),

    ok = rabbit_ct_broker_helpers:start_node(Config, C),

    %% We should now have the following dramatis personae:
    %% A - down, master
    %% B - down, used to be mirror, no longer is, never had the message
    %% C - running, should be mirror, but has wiped the message on restart
    %% D - down, recoverable mirror, contains message
    %%
    %% So forgetting A should offline-promote the queue to D, keeping
    %% the message.
    
    %% TODO doesn't work with Khepri running if the other node is down!!
    %% However, Khepri is not enabled. Should we skip leaving the Khepri cluster
    %% on that case?
    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, C,
      ["forget_cluster_node", A]),

    ok = rabbit_ct_broker_helpers:start_node(Config, D),
    DCh2 = rabbit_ct_client_helpers:open_channel(Config, D),
    #'queue.declare_ok'{message_count = 1} = declare(DCh2, QName),
    ok.

set_ha_policy(Config, QName, Master, Slaves) ->
    Nodes = [list_to_binary(atom_to_list(N)) || N <- [Master | Slaves]],
    HaPolicy = {<<"nodes">>, Nodes},
    rabbit_ct_broker_helpers:set_ha_policy(Config, Master, QName, HaPolicy),
    await_followers(QName, Master, Slaves).

await_followers(QName, Master, Slaves) ->
    await_followers_0(QName, Master, Slaves, 10).

await_followers_0(QName, Master, Slaves0, Tries) ->
    {ok, Queue} = await_followers_lookup_queue(QName, Master),
    SPids = amqqueue:get_slave_pids(Queue),
    ActMaster = amqqueue:qnode(Queue),
    ActSlaves = lists:usort([node(P) || P <- SPids]),
    Slaves1 = lists:usort(Slaves0),
    await_followers_1(QName, ActMaster, ActSlaves, Master, Slaves1, Tries).

await_followers_1(QName, _ActMaster, _ActSlaves, _Master, _Slaves, 0) ->
    error({timeout_waiting_for_followers, QName});
await_followers_1(QName, ActMaster, ActSlaves, Master, Slaves, Tries) ->
    case {Master, Slaves} of
        {ActMaster, ActSlaves} ->
            ok;
        _                      ->
            timer:sleep(250),
            await_followers_0(QName, Master, Slaves, Tries - 1)
    end.

await_followers_lookup_queue(QName, Master) ->
    await_followers_lookup_queue(QName, Master, 10).

await_followers_lookup_queue(QName, _Master, 0) ->
    error({timeout_looking_up_queue, QName});
await_followers_lookup_queue(QName, Master, Tries) ->
    RpcArgs = [rabbit_misc:r(<<"/">>, queue, QName)],
    case rpc:call(Master, rabbit_amqqueue, lookup, RpcArgs) of
        {error, not_found} ->
            timer:sleep(250),
            await_followers_lookup_queue(QName, Master, Tries - 1);
        {ok, Q} ->
            {ok, Q}
    end.

force_boot(Config) ->
    [Rabbit, Hare] = rabbit_ct_broker_helpers:get_node_configs(Config,
      nodename),
    {error, _, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
      ["force_boot"]),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    {error, _} = rabbit_ct_broker_helpers:start_node(Config, Rabbit),
    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
      ["force_boot"]),
    ok = rabbit_ct_broker_helpers:start_node(Config, Rabbit),
    ok.

force_boot_in_khepri(Config) ->
    [Rabbit, _Hare] = rabbit_ct_broker_helpers:get_node_configs(Config,
      nodename),
    stop_app(Rabbit),
    %% It executes force boot for mnesia, currently Khepri does nothing
    ?assertMatch({ok, []}, rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit, ["force_boot"])),
    ok.

change_cluster_node_type(Config) ->
    [Rabbit, Hare, _Bunny] = cluster_members(Config),

    %% Trying to change the node to the ram type when not clustered should always fail
    ok = stop_app(Rabbit),
    assert_failure(fun () -> change_cluster_node_type(Rabbit, ram) end),
    ok = start_app(Rabbit),

    ok = stop_app(Rabbit),
    join_cluster(Rabbit, Hare),
    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Hare]},
                          [Rabbit, Hare]),
    change_cluster_node_type(Rabbit, ram),
    assert_cluster_status({[Rabbit, Hare], [Hare], [Rabbit, Hare], [Hare], [Hare]},
                          [Rabbit, Hare]),
    change_cluster_node_type(Rabbit, disc),

    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Hare]},
                          [Rabbit, Hare]),
    change_cluster_node_type(Rabbit, ram),
    ok = start_app(Rabbit),
    assert_cluster_status({[Rabbit, Hare], [Hare], [Hare, Rabbit]},
                          [Rabbit, Hare]),

    %% Changing to ram when you're the only ram node should fail
    ok = stop_app(Hare),
    assert_failure(fun () -> change_cluster_node_type(Hare, ram) end),
    ok = start_app(Hare).

change_cluster_node_type_in_khepri(Config) ->
    [Rabbit, Hare] = cluster_members(Config),

    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Rabbit, Hare]},
                          [Rabbit, Hare]),
    change_cluster_node_type(Rabbit, ram),
    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Rabbit, Hare]},
                          [Rabbit, Hare]),
    change_cluster_node_type(Rabbit, disc),
    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Rabbit, Hare]},
                          [Rabbit, Hare]).

change_cluster_when_node_offline(Config) ->
    [Rabbit, Hare, Bunny] = cluster_members(Config),

    %% Cluster the three notes
    stop_join_start(Rabbit, Hare),
    assert_clustered([Rabbit, Hare]),

    stop_join_start(Bunny, Hare),
    assert_clustered([Rabbit, Hare, Bunny]),

    %% Bring down Rabbit, and remove Bunny from the cluster while
    %% Rabbit is offline
    ok = stop_app(Rabbit),
    ok = stop_app(Bunny),
    ok = reset(Bunny),
    assert_cluster_status({[Bunny], [Bunny], []}, [Bunny]),
    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Hare]}, [Hare]),
    assert_cluster_status(
      {[Rabbit, Hare, Bunny], [Hare], [Rabbit, Hare, Bunny], [Rabbit, Hare, Bunny], [Hare, Bunny]}, [Rabbit]),

    %% Bring Rabbit back up
    ok = start_app(Rabbit),
    assert_clustered([Rabbit, Hare]),
    ok = start_app(Bunny),
    assert_not_clustered(Bunny),

    %% Now the same, but Rabbit is a RAM node, and we bring up Bunny
    %% before
    ok = stop_app(Rabbit),
    ok = change_cluster_node_type(Rabbit, ram),
    ok = start_app(Rabbit),
    stop_join_start(Bunny, Hare),
    assert_cluster_status(
      {[Rabbit, Hare, Bunny], [Hare, Bunny], [Rabbit, Hare, Bunny]},
      [Rabbit, Hare, Bunny]),
    ok = stop_app(Rabbit),
    ok = stop_app(Bunny),
    ok = reset(Bunny),
    ok = start_app(Bunny),
    assert_not_clustered(Bunny),
    assert_cluster_status({[Rabbit, Hare], [Hare], [Hare]}, [Hare]),
    assert_cluster_status(
      {[Rabbit, Hare, Bunny], [Hare, Bunny], [Hare, Bunny]},
      [Rabbit]),
    ok = start_app(Rabbit),
    assert_cluster_status({[Rabbit, Hare], [Hare], [Rabbit, Hare]},
                          [Rabbit, Hare]),
    assert_not_clustered(Bunny).

update_cluster_nodes(Config) ->
    [Rabbit, Hare, Bunny] = cluster_members(Config),

    %% Mnesia is running...
    assert_failure(fun () -> update_cluster_nodes(Rabbit, Hare) end),

    ok = stop_app(Rabbit),
    ok = join_cluster(Rabbit, Hare),
    ok = stop_app(Bunny),
    ok = join_cluster(Bunny, Hare),
    ok = start_app(Bunny),
    stop_reset_start(Hare),
    assert_failure(fun () -> start_app(Rabbit) end),
    %% Bogus node
    assert_failure(fun () -> update_cluster_nodes(Rabbit, non@existent) end),
    %% Inconsistent node
    assert_failure(fun () -> update_cluster_nodes(Rabbit, Hare) end),
    ok = update_cluster_nodes(Rabbit, Bunny),
    ok = start_app(Rabbit),
    assert_not_clustered(Hare),
    assert_clustered([Rabbit, Bunny]).

unsupported_update_cluster_nodes(Config) ->
    [Rabbit, Hare] = cluster_members(Config),

    %% Mnesia is running...
    assert_failure(fun () -> update_cluster_nodes(Rabbit, Hare) end),

    ok = stop_app(Rabbit),
    Ret = update_cluster_nodes(Rabbit, Hare),
    is_not_supported(Ret).

is_not_supported(Ret) ->
    ?assertMatch({error, _, _}, Ret),
    {error, _, Msg} = Ret,
    ?assertMatch(match, re:run(Msg, ".*not_supported.*", [{capture, none}])).

classic_config_discovery_node_list(Config) ->
    [Rabbit, Hare] = cluster_members(Config),

    ok = stop_app(Hare),
    ok = reset(Hare),
    ok = rpc:call(Hare, application, set_env,
                  [rabbit, cluster_nodes, {[Rabbit], disc}]),
    ok = start_app(Hare),
    assert_clustered([Rabbit, Hare]),

    ok = stop_app(Hare),
    ok = reset(Hare),
    ok = rpc:call(Hare, application, set_env,
                  [rabbit, cluster_nodes, {[Rabbit], ram}]),
    ok = start_app(Hare),
    assert_cluster_status({[Rabbit, Hare], [Rabbit], [Rabbit, Hare]},
                          [Rabbit, Hare]),

    %% List of nodes [node()] is equivalent to {[node()], disk}
    ok = stop_app(Hare),
    ok = reset(Hare),
    ok = rpc:call(Hare, application, set_env,
                  [rabbit, cluster_nodes, [Rabbit]]),
    ok = start_app(Hare),
    assert_clustered([Rabbit, Hare]),

    ok = stop_app(Hare),
    ok = reset(Hare),
    %% If we use an invalid cluster_nodes conf, the node fails to start.
    ok = rpc:call(Hare, application, set_env,
                  [rabbit, cluster_nodes, "Yes, please"]),
    assert_failure(fun () -> start_app(Hare) end),
    assert_not_clustered(Rabbit).

force_reset_node(Config) ->
    [Rabbit, Hare, _Bunny] = cluster_members(Config),

    stop_join_start(Rabbit, Hare),
    stop_app(Rabbit),
    force_reset(Rabbit),
    %% Hare thinks that Rabbit is still clustered
    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Hare]},
                          [Hare]),
    %% %% ...but it isn't
    assert_cluster_status({[Rabbit], [Rabbit], []}, [Rabbit]),
    %% We can rejoin Rabbit and Hare
    update_cluster_nodes(Rabbit, Hare),
    start_app(Rabbit),
    assert_clustered([Rabbit, Hare]).

force_reset_node_in_khepri(Config) ->
    [Rabbit, Hare, _Bunny] = cluster_members(Config),

    stop_join_start(Rabbit, Hare),
    stop_app(Rabbit),
    ok = force_reset(Rabbit),
    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Hare]}, [Hare]),
    %% Khepri is stopped, so it won't report anything.
    assert_status({[], [], [Rabbit], [Rabbit], []}, [Rabbit]),
    %% Hare thinks that Rabbit is still clustered
    assert_cluster_status({[Rabbit, Hare], [Rabbit, Hare], [Hare]},
                          [Hare]),
    start_app(Rabbit),
    assert_not_clustered(Rabbit),
    %% We can't rejoin Rabbit and Hare
    ok = stop_app(Rabbit),
    ?assertMatch({error, _, _}, join_cluster(Rabbit, Hare, false)).

status_with_alarm(Config) ->
    [Rabbit, Hare] = rabbit_ct_broker_helpers:get_node_configs(Config,
      nodename),

    %% Given: an alarm is raised each node.
    rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
      ["set_vm_memory_high_watermark", "0.000000001"]),
    rabbit_ct_broker_helpers:rabbitmqctl(Config, Hare,
      ["set_disk_free_limit", "2048G"]),

    %% When: we ask for alarm status
    S = rabbit_ct_broker_helpers:rpc(Config, Rabbit,
                                          rabbit_alarm, get_alarms, []),
    R = rabbit_ct_broker_helpers:rpc(Config, Hare,
                                          rabbit_alarm, get_alarms, []),

    %% Then: both nodes have printed alarm information for eachother.
    ok = alarm_information_on_each_node(S, Rabbit, Hare),
    ok = alarm_information_on_each_node(R, Rabbit, Hare).

alarm_information_on_each_node(Result, Rabbit, Hare) ->
    %% Example result:
    %% [{{resource_limit,disk,'rmq-ct-status_with_alarm-2-24240@localhost'},
    %%           []},
    %% {{resource_limit,memory,'rmq-ct-status_with_alarm-1-24120@localhost'},
    %%           []}]
    Alarms = [A || {A, _} <- Result],
    ?assert(lists:member({resource_limit, memory, Rabbit}, Alarms)),
    ?assert(lists:member({resource_limit, disk, Hare}, Alarms)),

    ok.

pid_file_and_await_node_startup(Config) ->
    [Rabbit, Hare] = rabbit_ct_broker_helpers:get_node_configs(Config,
      nodename),
    RabbitConfig = rabbit_ct_broker_helpers:get_node_config(Config,Rabbit),
    RabbitPidFile = ?config(pid_file, RabbitConfig),
    %% ensure pid file is readable
    {ok, _} = file:read_file(RabbitPidFile),
    %% ensure wait works on running node
    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
      ["wait", RabbitPidFile]),
    %% stop both nodes
    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    %% starting first node fails - it was not the last node to stop
    {error, _} = rabbit_ct_broker_helpers:start_node(Config, Rabbit),
    PreviousPid = pid_from_file(RabbitPidFile),
    %% start first node in the background
    spawn_link(fun() ->
        rabbit_ct_broker_helpers:start_node(Config, Rabbit)
    end),
    Attempts = 200,
    Timeout = 50,
    wait_for_pid_file_to_change(RabbitPidFile, PreviousPid, Attempts, Timeout),
    {error, _, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
      ["wait", RabbitPidFile]).

pid_file_and_await_node_startup_in_khepri(Config) ->
    [Rabbit, Hare] = rabbit_ct_broker_helpers:get_node_configs(Config,
      nodename),
    RabbitConfig = rabbit_ct_broker_helpers:get_node_config(Config,Rabbit),
    RabbitPidFile = ?config(pid_file, RabbitConfig),
    %% ensure pid file is readable
    {ok, _} = file:read_file(RabbitPidFile),
    %% ensure wait works on running node
    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
      ["wait", RabbitPidFile]),
    %% stop both nodes
    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    %% start first node in the background. It will wait for Khepri
    %% and then Mnesia tables (which will already be available)
    spawn_link(fun() ->
        rabbit_ct_broker_helpers:start_node(Config, Rabbit)
    end),
    PreviousPid = pid_from_file(RabbitPidFile),
    Attempts = 200,
    Timeout = 50,
    wait_for_pid_file_to_change(RabbitPidFile, PreviousPid, Attempts, Timeout),
    %% The node is blocked waiting for Khepri, so this will timeout. Mnesia
    %% alone would fail here as it wasn't the last node to stop
    %% Let's make it a short wait.
    {error, timeout, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
                                                               ["wait", RabbitPidFile], 10000).

await_running_count(Config) ->
    [Rabbit, Hare] = rabbit_ct_broker_helpers:get_node_configs(Config,
      nodename),
    RabbitConfig = rabbit_ct_broker_helpers:get_node_config(Config,Rabbit),
    RabbitPidFile = ?config(pid_file, RabbitConfig),
    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
      ["wait", RabbitPidFile]),
    %% stop both nodes
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    %% start one node in the background
    rabbit_ct_broker_helpers:start_node(Config, Rabbit),
    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
                                                   ["wait", RabbitPidFile]),
    ?assertEqual(ok, rabbit_ct_broker_helpers:rpc(Config, Rabbit,
                                                  rabbit_nodes,
                                                  await_running_count, [1, 30000])),
    ?assertEqual({error, timeout},
                 rabbit_ct_broker_helpers:rpc(Config, Rabbit,
                                              rabbit_nodes,
                                              await_running_count, [2, 1000])),
    ?assertEqual({error, timeout},
                 rabbit_ct_broker_helpers:rpc(Config, Rabbit,
                                              rabbit_nodes,
                                              await_running_count, [5, 1000])),
    rabbit_ct_broker_helpers:start_node(Config, Hare),
    %% this now succeeds
    ?assertEqual(ok, rabbit_ct_broker_helpers:rpc(Config, Rabbit,
                                                  rabbit_nodes,
                                                  await_running_count, [2, 30000])),
    %% this still succeeds
    ?assertEqual(ok, rabbit_ct_broker_helpers:rpc(Config, Rabbit,
                                                  rabbit_nodes,
                                                  await_running_count, [1, 30000])),
    %% this still fails
    ?assertEqual({error, timeout},
                 rabbit_ct_broker_helpers:rpc(Config, Rabbit,
                                              rabbit_nodes,
                                              await_running_count, [5, 1000])).

await_running_count_in_khepri(Config) ->
    [Rabbit, Hare] = rabbit_ct_broker_helpers:get_node_configs(Config,
      nodename),
    RabbitConfig = rabbit_ct_broker_helpers:get_node_config(Config,Rabbit),
    RabbitPidFile = ?config(pid_file, RabbitConfig),
    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
      ["wait", RabbitPidFile]),
    %% stop both nodes
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    %% start one node in the background
    %% One khepri node in minority won't finish starting up, but will wait a reasonable
    %% amount of time for a new leader to be elected. Hopefully on that time
    %% a second (or more) node is brought up so they can reach consensus
    %% Kind of similar to the wait for tables that we had on mnesia
    rabbit_ct_broker_helpers:async_start_node(Config, Rabbit),
    rabbit_ct_broker_helpers:start_node(Config, Hare),
    {ok, _} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
                                                   ["wait", RabbitPidFile]),
    %% this now succeeds
    ?assertEqual(ok, rabbit_ct_broker_helpers:rpc(Config, Rabbit,
                                                  rabbit_nodes,
                                                  await_running_count, [2, 30000])),
    %% this still succeeds
    ?assertEqual(ok, rabbit_ct_broker_helpers:rpc(Config, Rabbit,
                                                  rabbit_nodes,
                                                  await_running_count, [1, 30000])),
    %% this still fails
    ?assertEqual({error, timeout},
                 rabbit_ct_broker_helpers:rpc(Config, Rabbit,
                                              rabbit_nodes,
                                              await_running_count, [5, 1000])).

start_nodes_in_reverse_order(Config) ->
    [Rabbit, Hare, Bunny] = cluster_members(Config),
    assert_not_clustered(Rabbit),
    assert_not_clustered(Hare),
    assert_not_clustered(Bunny),

    stop_join_start(Rabbit, Bunny),
    stop_join_start(Hare, Bunny),
    assert_clustered([Rabbit, Hare, Bunny]),

    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Bunny),

    spawn(fun() -> ok = rabbit_ct_broker_helpers:start_node(Config, Bunny) end),
    ok = rabbit_ct_broker_helpers:start_node(Config, Hare),
    assert_cluster_status({[Bunny, Hare, Rabbit], [Bunny, Hare, Rabbit], [Bunny, Hare]},
                          [Bunny, Hare]),

    ok = rabbit_ct_broker_helpers:start_node(Config, Rabbit),
    assert_clustered([Rabbit, Hare, Bunny]).

%% Test booting nodes in the wrong order for Mnesia. Interesting...
start_nodes_in_stop_order(Config) ->
    [Rabbit, Hare, Bunny] = cluster_members(Config),
    assert_not_clustered(Rabbit),
    assert_not_clustered(Hare),
    assert_not_clustered(Bunny),

    stop_join_start(Rabbit, Bunny),
    stop_join_start(Hare, Bunny),
    assert_clustered([Rabbit, Hare, Bunny]),

    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Bunny),

    Self = self(),
    spawn(fun() ->
                  Reply = rabbit_ct_broker_helpers:start_node(Config, Rabbit),
                  Self ! {start_node_reply, Reply}
          end),
    ?assertMatch({error, {skip, _}}, rabbit_ct_broker_helpers:start_node(Config, Hare)),
    receive
        {start_node_reply, Reply} ->
            ?assertMatch({error, {skip, _}}, Reply)
    end.

%% TODO test force_boot with Khepri involved
start_nodes_in_stop_order_with_force_boot(Config) ->
    [Rabbit, Hare, Bunny] = cluster_members(Config),
    assert_not_clustered(Rabbit),
    assert_not_clustered(Hare),
    assert_not_clustered(Bunny),

    stop_join_start(Rabbit, Bunny),
    stop_join_start(Hare, Bunny),
    assert_clustered([Rabbit, Hare, Bunny]),

    ok = rabbit_ct_broker_helpers:stop_node(Config, Rabbit),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Hare),
    ok = rabbit_ct_broker_helpers:stop_node(Config, Bunny),

    {ok, []} = rabbit_ct_broker_helpers:rabbitmqctl(Config, Rabbit,
                                                    ["force_boot"]),

    spawn(fun() -> rabbit_ct_broker_helpers:start_node(Config, Rabbit) end),
    ok = rabbit_ct_broker_helpers:start_node(Config, Hare),
    assert_cluster_status({[Bunny, Hare, Rabbit], [Bunny, Hare, Rabbit], [Rabbit, Hare]},
                          [Rabbit, Hare]),

    ok = rabbit_ct_broker_helpers:start_node(Config, Bunny),
    assert_clustered([Rabbit, Hare, Bunny]).

%% ----------------------------------------------------------------------------
%% Internal utils
%% ----------------------------------------------------------------------------

wait_for_pid_file_to_change(_, 0, _, _) ->
    error(timeout_waiting_for_pid_file_to_have_running_pid);
wait_for_pid_file_to_change(PidFile, PreviousPid, Attempts, Timeout) ->
    Pid = pid_from_file(PidFile),
    case Pid =/= undefined andalso Pid =/= PreviousPid of
        true  -> ok;
        false ->
            ct:sleep(Timeout),
            wait_for_pid_file_to_change(PidFile,
                                        PreviousPid,
                                        Attempts - 1,
                                        Timeout)
    end.

pid_from_file(PidFile) ->
    case file:read_file(PidFile) of
        {ok, Content} ->
            string:strip(binary_to_list(Content), both, $\n);
        {error, enoent} ->
            undefined
    end.

cluster_members(Config) ->
    rabbit_ct_broker_helpers:get_node_configs(Config, nodename).

assert_status(Tuple, Nodes) ->
    assert_cluster_status(Tuple, Nodes, fun verify_status_equal/3).

assert_cluster_status(Tuple, Nodes) ->
    assert_cluster_status(Tuple, Nodes, fun verify_cluster_status_equal/3).

assert_cluster_status({All, Running}, Nodes, VerifyFun) ->
    assert_cluster_status({All, Running, All, All, Running}, Nodes, VerifyFun);
assert_cluster_status({All, Disc, Running}, Nodes, VerifyFun) ->
    assert_cluster_status({All, Running, All, Disc, Running}, Nodes, VerifyFun);
assert_cluster_status(Status0, Nodes, VerifyFun) ->
    Status = sort_cluster_status(Status0),
    AllNodes = case Status of
                   {undef, undef, All, _, _} ->
                       %% Support mixed-version clusters
                       All;
                   {All, _, _, _, _} ->
                       All
               end,
    wait_for_cluster_status(Status, AllNodes, Nodes, VerifyFun).

wait_for_cluster_status(Status, AllNodes, Nodes, VerifyFun) ->
    Max = 10000 / ?LOOP_RECURSION_DELAY,
    wait_for_cluster_status(0, Max, Status, AllNodes, Nodes, VerifyFun).

wait_for_cluster_status(N, Max, Status, _AllNodes, Nodes, _VerifyFun) when N >= Max ->
    erlang:error({cluster_status_max_tries_failed,
                  [{nodes, Nodes},
                   {expected_status, Status},
                   {max_tried, Max},
                   {status, sort_cluster_status(cluster_status(hd(Nodes)))}]});
wait_for_cluster_status(N, Max, Status, AllNodes, Nodes, VerifyFun) ->
    case lists:all(fun (Node) ->
                           VerifyFun(Node, Status, AllNodes)
                   end, Nodes) of
        true  -> ok;
        false -> timer:sleep(?LOOP_RECURSION_DELAY),
                 wait_for_cluster_status(N + 1, Max, Status, AllNodes, Nodes, VerifyFun)
    end.

verify_status_equal(Node, Status, _AllNodes) ->
    NodeStatus = sort_cluster_status(cluster_status(Node)),
    equal(Status, NodeStatus).

verify_cluster_status_equal(Node, Status, AllNodes) ->
    NodeStatus = sort_cluster_status(cluster_status(Node)),
    IsClustered = rpc:call(Node, rabbit_db_cluster, is_clustered, []),
    ((AllNodes =/= [Node]) =:= IsClustered andalso equal(Status, NodeStatus)).

equal({_, _, A, B, C}, {undef, undef, A, B, C}) ->
    true;
equal({_, _, _, _, _}, {undef, undef, _, _, _}) ->
    false;
equal(Status0, Status1) ->
    Status0 == Status1.

cluster_status(Node) ->
    {rpc:call(Node, rabbit_nodes, list_members, []),
     rpc:call(Node, rabbit_nodes, list_running, []),
     rpc:call(Node, rabbit_mnesia, cluster_nodes, [all]),
     rpc:call(Node, rabbit_mnesia, cluster_nodes, [disc]),
     rpc:call(Node, rabbit_mnesia, cluster_nodes, [running])}.

sort_cluster_status({{badrpc, {'EXIT', {undef, _}}}, {badrpc, {'EXIT', {undef, _}}}, AllM, DiscM, RunningM}) ->
    {undef, undef, lists:sort(AllM), lists:sort(DiscM), lists:sort(RunningM)};
sort_cluster_status({All, Running, AllM, DiscM, RunningM}) ->
    {lists:sort(All), lists:sort(Running), lists:sort(AllM), lists:sort(DiscM), lists:sort(RunningM)}.

assert_clustered(Nodes) ->
    assert_cluster_status({Nodes, Nodes, Nodes, Nodes, Nodes}, Nodes).

assert_not_clustered(Node) ->
    assert_cluster_status({[Node], [Node], [Node], [Node], [Node]}, [Node]).

assert_failure(Fun) ->
    case catch Fun() of
        {error, _Code, Reason}         -> Reason;
        {error, Reason}                -> Reason;
        {error_string, Reason}         -> Reason;
        {badrpc, {'EXIT', Reason}}     -> Reason;
        %% Failure to start an app result in node shutdown
        {badrpc, nodedown}             -> nodedown;
        {badrpc_multi, Reason, _Nodes} -> Reason;
        Other                          -> error({expected_failure, Other})
    end.

stop_app(Node) ->
    rabbit_control_helper:command(stop_app, Node).

start_app(Node) ->
    rabbit_control_helper:command(start_app, Node).

join_cluster(Node, To) ->
    join_cluster(Node, To, false).

join_cluster(Node, To, Ram) ->
    rabbit_control_helper:command_with_output(join_cluster, Node, [atom_to_list(To)], [{"--ram", Ram}]).

reset(Node) ->
    rabbit_control_helper:command(reset, Node).

force_reset(Node) ->
    rabbit_control_helper:command(force_reset, Node).

forget_cluster_node(Node, Removee, RemoveWhenOffline) ->
    rabbit_control_helper:command(forget_cluster_node, Node, [atom_to_list(Removee)],
                   [{"--offline", RemoveWhenOffline}]).

forget_cluster_node(Node, Removee) ->
    forget_cluster_node(Node, Removee, false).

change_cluster_node_type(Node, Type) ->
    rabbit_control_helper:command(change_cluster_node_type, Node, [atom_to_list(Type)]).

update_cluster_nodes(Node, DiscoveryNode) ->
    rabbit_control_helper:command(update_cluster_nodes, Node, [atom_to_list(DiscoveryNode)]).

stop_join_start(Node, ClusterTo, Ram) ->
    ok = stop_app(Node),
    ok = join_cluster(Node, ClusterTo, Ram),
    ok = start_app(Node).

stop_join_start(Node, ClusterTo) ->
    stop_join_start(Node, ClusterTo, false).

stop_reset_start(Node) ->
    ok = stop_app(Node),
    ok = reset(Node),
    ok = start_app(Node).

declare(Ch, Name) ->
    Res = amqp_channel:call(Ch, #'queue.declare'{durable = true,
                                                 queue   = Name}),
    amqp_channel:call(Ch, #'queue.bind'{queue    = Name,
                                        exchange = <<"amq.fanout">>}),
    Res.

declare_passive(Ch, Name) ->
    amqp_channel:call(Ch, #'queue.declare'{durable = true,
                                           passive = true,
                                           queue   = Name}).
