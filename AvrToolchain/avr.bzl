load("@bazel_tools//tools/build_defs/repo:utils.bzl", "workspace_and_buildfile")
load(
    "@bazel_tools//tools/cpp:lib_cc_configure.bzl",
    "auto_configure_fail",
    "auto_configure_warning",
    "escape_string",
    "get_env_var",
    "get_starlark_list",
    "resolve_labels",
    "split_escaped",
    "which",
)
load(
    "//AvrToolchain:cc_toolchain/cc_toolchain.bzl",
    "avr_tools",
    "create_cc_toolchain_package",
)
load(
    "//AvrToolchain:platforms/platforms.bzl",
    "write_constraints",
)
load(
    "//AvrToolchain:platforms/avr_mcu_list.bzl",
    "mcu_list",
)

def _avr_toolchain_impl(repository_ctx):
    prefix = "@EmbeddedSystemsBuildScripts//AvrToolchain:"

    # tools is a dictionary of avr programs i.e. avr-gcc, avr-ar, avr-g++, etc
    tools = avr_tools(repository_ctx)

    # dictionary with the labels as keys and their paths as values.
    # Path in relation to build output directory i.e.
    # /home/mark/.cache/bazel/_bazel_mark/1223e68e6075ca8dee845497e052a6da/external/EmbeddedSystemsBuildScripts/AvrToolchain/platforms/misc/BUILD.tpl,
    paths = resolve_labels(
        repository_ctx,
        [prefix + label for label in [
            "cc_toolchain/cc_toolchain_config.bzl.tpl",
            "platforms/cpu_frequency/cpu_frequency.bzl.tpl",
            "platforms/misc/BUILD.tpl",
            "platforms/BUILD.tpl",
            "helpers.bzl.tpl",
            "host_config/BUILD.tpl",
            "platforms/avr_mcu_list.bzl",
            "platforms/mcu/mcu.bzl",
            "BUILD.tpl",
        ]],
    )

    # Injects constraint_value and config_settings into BUILD files
    write_constraints(repository_ctx, paths)

    # Creates the toolchains for each mcu in platforms list, sets up compiler flags
    create_cc_toolchain_package(repository_ctx, paths)

    # functions to generate hex file and upload binary using avrdude or dfu
    repository_ctx.template(
        "helpers.bzl",
        paths["@EmbeddedSystemsBuildScripts//AvrToolchain:helpers.bzl.tpl"],
        substitutions = {
            "{avr_objcopy}": tools["objcopy"],
            "{avr_size}": tools["size"],
        },
    )

    # removed funcion below as not sure it's necessary
    # repository_ctx.file("BUILD")

    # functions that elp dfu
    repository_ctx.template("host_config/BUILD", paths["@EmbeddedSystemsBuildScripts//AvrToolchain:host_config/BUILD.tpl"])

    # Copies mcu list over to dist folder
    repository_ctx.template(
        "platforms/avr_mcu_list.bzl",
        paths["@EmbeddedSystemsBuildScripts//AvrToolchain:platforms/avr_mcu_list.bzl"],
    )

    # contain get_mcu() which selects on mcu which is defined
    repository_ctx.template(
        "platforms/mcu/mcu.bzl",
        paths["@EmbeddedSystemsBuildScripts//AvrToolchain:platforms/mcu/mcu.bzl"],
    )

    # creates BUILD file that as genrules to create scripts for upload
    repository_ctx.template(
        "BUILD",
        paths["@EmbeddedSystemsBuildScripts//AvrToolchain:BUILD.tpl"],
    )

_get_avr_toolchain_def_attrs = {
    "gcc_tool": attr.string(),
    "size_tool": attr.string(),
    "ar_tool": attr.string(),
    "ld_tool": attr.string(),
    "cpp_tool": attr.string(),
    "gcov_tool": attr.string(),
    "nm_tool": attr.string(),
    "objdump_tool": attr.string(),
    "strip_tool": attr.string(),
    "objcopy_tool": attr.string(),
    "mcu_list": attr.string_list(mandatory = True),
}

create_avr_toolchain = repository_rule(
    implementation = _avr_toolchain_impl,
    attrs = _get_avr_toolchain_def_attrs,
)

def avr_toolchain():
    print("avr_toolchain()")
    create_avr_toolchain(
        name = "AvrToolchain",
        mcu_list = mcu_list,
    )

    # At this point all the building blocks are assembled, and we just need to make the toolchains available to Bazel’s
    # resolution procedure. This is done by registering the toolchain.
    for mcu in mcu_list:
        native.register_toolchains(
            "@AvrToolchain//cc_toolchain:cc-toolchain-avr-" + mcu,
        )
