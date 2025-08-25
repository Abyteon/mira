// MIRA - Zig 0.15.1 构建脚本  
// My Intelligent Romantic Assistant
// 高性能内存管理和系统操作，使用正确的0.15.1 API

const std = @import("std");

pub fn build(b: *std.Build) void {
    // 目标和优化级别
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 创建主模块
    const main_module = b.addModule("mira_zig", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
    });

    // 创建子模块
    const memory_module = b.addModule("memory", .{
        .root_source_file = b.path("src/memory.zig"),
        .target = target,
    });
    
    const vector_module = b.addModule("vector", .{
        .root_source_file = b.path("src/vector.zig"),
        .target = target,
    });
    
    const monitor_module = b.addModule("monitor", .{
        .root_source_file = b.path("src/monitor.zig"),
        .target = target,
    });

    // 为主模块添加依赖
    main_module.addImport("memory", memory_module);
    main_module.addImport("vector", vector_module);
    main_module.addImport("monitor", monitor_module);

    // 静态库 - 提供给Rust调用
    const lib = b.addExecutable(.{
        .name = "mira_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "memory", .module = memory_module },
                .{ .name = "vector", .module = vector_module },
                .{ .name = "monitor", .module = monitor_module },
            },
        }),
    });

    // 添加C ABI导出
    lib.linkLibC();
    
    // 安装库
    b.installArtifact(lib);

    // 测试可执行文件
    const test_exe = b.addExecutable(.{
        .name = "mira_system_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "main", .module = main_module },
                .{ .name = "memory", .module = memory_module },
                .{ .name = "vector", .module = vector_module },
                .{ .name = "monitor", .module = monitor_module },
            },
        }),
    });
    
    test_exe.linkLibC();
    
    // 运行集成测试步骤
    const run_test = b.addRunArtifact(test_exe);
    const integration_test_step = b.step("integration-test", "运行集成测试");
    integration_test_step.dependOn(&run_test.step);

    // 性能基准测试
    const bench_exe = b.addExecutable(.{
        .name = "mira_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "main", .module = main_module },
                .{ .name = "memory", .module = memory_module },
                .{ .name = "vector", .module = vector_module },
                .{ .name = "monitor", .module = monitor_module },
            },
        }),
    });
    
    bench_exe.linkLibC();
    
    const run_bench = b.addRunArtifact(bench_exe);
    const bench_step = b.step("bench", "运行性能基准测试");
    bench_step.dependOn(&run_bench.step);

    // 单元测试
    const unit_tests = b.addTest(.{
        .root_module = main_module,
    });
    
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "运行单元测试");
    test_step.dependOn(&run_unit_tests.step);

    // 运行步骤
    const run_step = b.step("run", "运行主程序");
    const run_cmd = b.addRunArtifact(lib);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}