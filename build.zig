const std = @import("std");
const Path = std.Build.LazyPath;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const tests = b.option(bool, "Tests", "Build tests [default: false]") orelse false;
    const examples = b.option(bool, "Examples", "Build all examples [default: false]") orelse true;

    const lib = b.addStaticLibrary(.{
        .name = "taskflow",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.linkLibCpp();
    lib.addIncludePath(Path.relative(""));
    // bypass zig-pkg
    lib.addCSourceFile(.{ .file = .{ .path = "unittests/dummy.cpp" }, .flags = &.{} });
    lib.installHeadersDirectory("taskflow", "taskflow");

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    if (tests) {
        buildTest(b, .{
            .path = "unittests/test_asyncs.cpp",
            .lib = lib,
        });
        buildTest(b, .{
            .path = "unittests/test_basics.cpp",
            .lib = lib,
        });
        buildTest(b, .{
            .path = "unittests/test_data_pipelines.cpp",
            .lib = lib,
        });
    }
    if (examples) {
        buildTest(b, .{
            .lib = lib,
            .path = "examples/async.cpp",
        });
    }
}

fn buildTest(b: *std.Build, info: BuildInfo) void {
    const test_exe = b.addExecutable(.{
        .name = info.filename(),
        .optimize = info.lib.optimize,
        .target = info.lib.target,
    });
    test_exe.addIncludePath(Path.relative(""));
    test_exe.addIncludePath(Path.relative("3rd-party/doctest/"));
    // test_exe.addIncludePath(.{ .path = "taskflow" });
    // test_exe.addIncludePath(Path.relative("taskflow"));
    // test_exe.addIncludePath(.{ .path = "test/_include" });
    test_exe.addCSourceFile(.{ .file = .{ .path = info.path }, .flags = cxxFlags });
    test_exe.linkLibCpp();
    b.installArtifact(test_exe);

    const run_cmd = b.addRunArtifact(test_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(
        b.fmt("{s}", .{info.filename()}),
        b.fmt("Run the {s} test", .{info.filename()}),
    );
    run_step.dependOn(&run_cmd.step);
}

const cxxFlags: []const []const u8 = &.{
    "-Wall",
    "-Wextra",
};

const BuildInfo = struct {
    lib: *std.Build.Step.Compile,
    path: []const u8,

    fn filename(self: BuildInfo) []const u8 {
        var split = std.mem.split(u8, std.fs.path.basename(self.path), ".");
        return split.first();
    }
};
