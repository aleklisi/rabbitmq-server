load("@rules_erlang//:erlang_bytecode2.bzl", "erlang_bytecode")
load("@rules_erlang//:filegroup.bzl", "filegroup")

def all_beam_files(name = "all_beam_files"):
    filegroup(
        name = "beam_files",
        srcs = [":behaviours", ":other_beam"],
    )
    erlang_bytecode(
        name = "behaviours",
        srcs = [
            "src/gen_server2.erl",
            "src/rabbit_authn_backend.erl",
            "src/rabbit_authz_backend.erl",
            "src/rabbit_password_hashing.erl",
            "src/rabbit_registry_class.erl",
        ],
        hdrs = [":public_and_private_hdrs"],
        app_name = "rabbit_common",
        dest = "ebin",
        erlc_opts = "//:erlc_opts",
    )
    erlang_bytecode(
        name = "other_beam",
        srcs = [
            "src/app_utils.erl",
            "src/code_version.erl",
            "src/credit_flow.erl",
            "src/delegate.erl",
            "src/delegate_sup.erl",
            "src/file_handle_cache.erl",
            "src/file_handle_cache_stats.erl",
            "src/mirrored_supervisor_locks.erl",
            "src/mnesia_sync.erl",
            "src/pmon.erl",
            "src/priority_queue.erl",
            "src/rabbit_amqp_connection.erl",
            "src/rabbit_amqqueue_common.erl",
            "src/rabbit_auth_backend_dummy.erl",
            "src/rabbit_auth_mechanism.erl",
            "src/rabbit_basic_common.erl",
            "src/rabbit_binary_generator.erl",
            "src/rabbit_binary_parser.erl",
            "src/rabbit_cert_info.erl",
            "src/rabbit_channel_common.erl",
            "src/rabbit_command_assembler.erl",
            "src/rabbit_control_misc.erl",
            "src/rabbit_core_metrics.erl",
            "src/rabbit_data_coercion.erl",
            "src/rabbit_date_time.erl",
            "src/rabbit_env.erl",
            "src/rabbit_error_logger_handler.erl",
            "src/rabbit_event.erl",
            "src/rabbit_framing.erl",
            "src/rabbit_framing_amqp_0_8.erl",
            "src/rabbit_framing_amqp_0_9_1.erl",
            "src/rabbit_heartbeat.erl",
            "src/rabbit_http_util.erl",
            "src/rabbit_json.erl",
            "src/rabbit_log.erl",
            "src/rabbit_misc.erl",
            "src/rabbit_msg_store_index.erl",
            "src/rabbit_net.erl",
            "src/rabbit_nodes_common.erl",
            "src/rabbit_numerical.erl",
            "src/rabbit_password.erl",
            "src/rabbit_password_hashing_md5.erl",
            "src/rabbit_password_hashing_sha256.erl",
            "src/rabbit_password_hashing_sha512.erl",
            "src/rabbit_pbe.erl",
            "src/rabbit_peer_discovery_backend.erl",
            "src/rabbit_policy_validator.erl",
            "src/rabbit_queue_collector.erl",
            "src/rabbit_registry.erl",
            "src/rabbit_resource_monitor_misc.erl",
            "src/rabbit_runtime.erl",
            "src/rabbit_runtime_parameter.erl",
            "src/rabbit_semver.erl",
            "src/rabbit_semver_parser.erl",
            "src/rabbit_ssl_options.erl",
            "src/rabbit_types.erl",
            "src/rabbit_writer.erl",
            "src/supervisor2.erl",
            "src/vm_memory_monitor.erl",
            "src/worker_pool.erl",
            "src/worker_pool_sup.erl",
            "src/worker_pool_worker.erl",
        ],
        hdrs = [":public_and_private_hdrs"],
        app_name = "rabbit_common",
        beam = [":behaviours"],
        dest = "ebin",
        erlc_opts = "//:erlc_opts",
    )

def all_test_beam_files(name = "all_test_beam_files"):
    filegroup(
        name = "test_beam_files",
        testonly = True,
        srcs = [":test_behaviours", ":test_other_beam"],
    )
    erlang_bytecode(
        name = "test_behaviours",
        testonly = True,
        srcs = [
            "src/gen_server2.erl",
            "src/rabbit_authn_backend.erl",
            "src/rabbit_authz_backend.erl",
            "src/rabbit_password_hashing.erl",
            "src/rabbit_registry_class.erl",
        ],
        hdrs = [":public_and_private_hdrs"],
        app_name = "rabbit_common",
        dest = "test",
        erlc_opts = "//:test_erlc_opts",
    )
    erlang_bytecode(
        name = "test_other_beam",
        testonly = True,
        srcs = [
            "src/app_utils.erl",
            "src/code_version.erl",
            "src/credit_flow.erl",
            "src/delegate.erl",
            "src/delegate_sup.erl",
            "src/file_handle_cache.erl",
            "src/file_handle_cache_stats.erl",
            "src/mirrored_supervisor_locks.erl",
            "src/mnesia_sync.erl",
            "src/pmon.erl",
            "src/priority_queue.erl",
            "src/rabbit_amqp_connection.erl",
            "src/rabbit_amqqueue_common.erl",
            "src/rabbit_auth_backend_dummy.erl",
            "src/rabbit_auth_mechanism.erl",
            "src/rabbit_basic_common.erl",
            "src/rabbit_binary_generator.erl",
            "src/rabbit_binary_parser.erl",
            "src/rabbit_cert_info.erl",
            "src/rabbit_channel_common.erl",
            "src/rabbit_command_assembler.erl",
            "src/rabbit_control_misc.erl",
            "src/rabbit_core_metrics.erl",
            "src/rabbit_data_coercion.erl",
            "src/rabbit_date_time.erl",
            "src/rabbit_env.erl",
            "src/rabbit_error_logger_handler.erl",
            "src/rabbit_event.erl",
            "src/rabbit_framing.erl",
            "src/rabbit_framing_amqp_0_8.erl",
            "src/rabbit_framing_amqp_0_9_1.erl",
            "src/rabbit_heartbeat.erl",
            "src/rabbit_http_util.erl",
            "src/rabbit_json.erl",
            "src/rabbit_log.erl",
            "src/rabbit_misc.erl",
            "src/rabbit_msg_store_index.erl",
            "src/rabbit_net.erl",
            "src/rabbit_nodes_common.erl",
            "src/rabbit_numerical.erl",
            "src/rabbit_password.erl",
            "src/rabbit_password_hashing_md5.erl",
            "src/rabbit_password_hashing_sha256.erl",
            "src/rabbit_password_hashing_sha512.erl",
            "src/rabbit_pbe.erl",
            "src/rabbit_peer_discovery_backend.erl",
            "src/rabbit_policy_validator.erl",
            "src/rabbit_queue_collector.erl",
            "src/rabbit_registry.erl",
            "src/rabbit_resource_monitor_misc.erl",
            "src/rabbit_runtime.erl",
            "src/rabbit_runtime_parameter.erl",
            "src/rabbit_semver.erl",
            "src/rabbit_semver_parser.erl",
            "src/rabbit_ssl_options.erl",
            "src/rabbit_types.erl",
            "src/rabbit_writer.erl",
            "src/supervisor2.erl",
            "src/vm_memory_monitor.erl",
            "src/worker_pool.erl",
            "src/worker_pool_sup.erl",
            "src/worker_pool_worker.erl",
        ],
        hdrs = [":public_and_private_hdrs"],
        app_name = "rabbit_common",
        beam = [":test_behaviours"],
        dest = "test",
        erlc_opts = "//:test_erlc_opts",
    )

def all_srcs(name = "all_srcs"):
    filegroup(
        name = "all_srcs",
        srcs = [":public_and_private_hdrs", ":srcs"],
    )
    filegroup(
        name = "public_and_private_hdrs",
        srcs = [":private_hdrs", ":public_hdrs"],
    )

    filegroup(
        name = "priv",
    )

    filegroup(
        name = "srcs",
        srcs = [
            "src/app_utils.erl",
            "src/code_version.erl",
            "src/credit_flow.erl",
            "src/delegate.erl",
            "src/delegate_sup.erl",
            "src/file_handle_cache.erl",
            "src/file_handle_cache_stats.erl",
            "src/gen_server2.erl",
            "src/mirrored_supervisor_locks.erl",
            "src/mnesia_sync.erl",
            "src/pmon.erl",
            "src/priority_queue.erl",
            "src/rabbit_amqp_connection.erl",
            "src/rabbit_amqqueue_common.erl",
            "src/rabbit_auth_backend_dummy.erl",
            "src/rabbit_auth_mechanism.erl",
            "src/rabbit_authn_backend.erl",
            "src/rabbit_authz_backend.erl",
            "src/rabbit_basic_common.erl",
            "src/rabbit_binary_generator.erl",
            "src/rabbit_binary_parser.erl",
            "src/rabbit_cert_info.erl",
            "src/rabbit_channel_common.erl",
            "src/rabbit_command_assembler.erl",
            "src/rabbit_control_misc.erl",
            "src/rabbit_core_metrics.erl",
            "src/rabbit_data_coercion.erl",
            "src/rabbit_date_time.erl",
            "src/rabbit_env.erl",
            "src/rabbit_error_logger_handler.erl",
            "src/rabbit_event.erl",
            "src/rabbit_framing.erl",
            "src/rabbit_framing_amqp_0_8.erl",
            "src/rabbit_framing_amqp_0_9_1.erl",
            "src/rabbit_heartbeat.erl",
            "src/rabbit_http_util.erl",
            "src/rabbit_json.erl",
            "src/rabbit_log.erl",
            "src/rabbit_misc.erl",
            "src/rabbit_msg_store_index.erl",
            "src/rabbit_net.erl",
            "src/rabbit_nodes_common.erl",
            "src/rabbit_numerical.erl",
            "src/rabbit_password.erl",
            "src/rabbit_password_hashing.erl",
            "src/rabbit_password_hashing_md5.erl",
            "src/rabbit_password_hashing_sha256.erl",
            "src/rabbit_password_hashing_sha512.erl",
            "src/rabbit_pbe.erl",
            "src/rabbit_peer_discovery_backend.erl",
            "src/rabbit_policy_validator.erl",
            "src/rabbit_queue_collector.erl",
            "src/rabbit_registry.erl",
            "src/rabbit_registry_class.erl",
            "src/rabbit_resource_monitor_misc.erl",
            "src/rabbit_runtime.erl",
            "src/rabbit_runtime_parameter.erl",
            "src/rabbit_semver.erl",
            "src/rabbit_semver_parser.erl",
            "src/rabbit_ssl_options.erl",
            "src/rabbit_types.erl",
            "src/rabbit_writer.erl",
            "src/supervisor2.erl",
            "src/vm_memory_monitor.erl",
            "src/worker_pool.erl",
            "src/worker_pool_sup.erl",
            "src/worker_pool_worker.erl",
        ],
    )
    filegroup(
        name = "public_hdrs",
        srcs = [
            "include/logging.hrl",
            "include/rabbit.hrl",
            "include/rabbit_core_metrics.hrl",
            "include/rabbit_framing.hrl",
            "include/rabbit_memory.hrl",
            "include/rabbit_misc.hrl",
            "include/rabbit_msg_store.hrl",
            "include/resource.hrl",
        ],
    )
    filegroup(
        name = "private_hdrs",
    )
    filegroup(
        name = "license_files",
        srcs = [
            "LICENSE",
            "LICENSE-BSD-recon",
            "LICENSE-MIT-Erlware-Commons",
            "LICENSE-MIT-Mochi",
            "LICENSE-MPL-RabbitMQ",
        ],
    )

def test_suite_beam_files(name = "test_suite_beam_files"):
    erlang_bytecode(
        name = "rabbit_env_SUITE_beam_files",
        testonly = True,
        srcs = ["test/rabbit_env_SUITE.erl"],
        outs = ["test/rabbit_env_SUITE.beam"],
        app_name = "rabbit_common",
        erlc_opts = "//:test_erlc_opts",
    )
    erlang_bytecode(
        name = "supervisor2_SUITE_beam_files",
        testonly = True,
        srcs = ["test/supervisor2_SUITE.erl"],
        outs = ["test/supervisor2_SUITE.beam"],
        hdrs = ["include/rabbit.hrl", "include/resource.hrl"],
        app_name = "rabbit_common",
        beam = ["ebin/supervisor2.beam"],
        erlc_opts = "//:test_erlc_opts",
    )
    erlang_bytecode(
        name = "test_gen_server2_test_server_beam",
        testonly = True,
        srcs = ["test/gen_server2_test_server.erl"],
        outs = ["test/gen_server2_test_server.beam"],
        app_name = "rabbit_common",
        beam = ["ebin/gen_server2.beam"],
        erlc_opts = "//:test_erlc_opts",
    )
    erlang_bytecode(
        name = "test_test_event_handler_beam",
        testonly = True,
        srcs = ["test/test_event_handler.erl"],
        outs = ["test/test_event_handler.beam"],
        hdrs = ["include/rabbit.hrl", "include/resource.hrl"],
        app_name = "rabbit_common",
        erlc_opts = "//:test_erlc_opts",
    )
    erlang_bytecode(
        name = "unit_SUITE_beam_files",
        testonly = True,
        srcs = ["test/unit_SUITE.erl"],
        outs = ["test/unit_SUITE.beam"],
        hdrs = ["include/rabbit.hrl", "include/rabbit_memory.hrl", "include/resource.hrl"],
        app_name = "rabbit_common",
        erlc_opts = "//:test_erlc_opts",
        deps = ["//deps/proper:erlang_app"],
    )
    erlang_bytecode(
        name = "unit_priority_queue_SUITE_beam_files",
        testonly = True,
        srcs = ["test/unit_priority_queue_SUITE.erl"],
        outs = ["test/unit_priority_queue_SUITE.beam"],
        app_name = "rabbit_common",
        erlc_opts = "//:test_erlc_opts",
    )
    erlang_bytecode(
        name = "worker_pool_SUITE_beam_files",
        testonly = True,
        srcs = ["test/worker_pool_SUITE.erl"],
        outs = ["test/worker_pool_SUITE.beam"],
        app_name = "rabbit_common",
        erlc_opts = "//:test_erlc_opts",
    )
    erlang_bytecode(
        name = "unit_password_hashing_SUITE_beam_files",
        testonly = True,
        srcs = ["test/unit_password_hashing_SUITE.erl"],
        outs = ["test/unit_password_hashing_SUITE.beam"],
        app_name = "rabbit_common",
        erlc_opts = "//:test_erlc_opts",
    )
