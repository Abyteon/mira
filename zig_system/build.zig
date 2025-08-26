//! MIRA - Zig 0.15.1 库构建脚本
//! 遵循Zig官方库项目构建最佳实践，使用Zig 0.15.1新特性

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Zig 0.15.1 增强的构建选项
    const enable_simd = b.option(bool, "enable-simd", "Enable SIMD optimizations") orelse true;
    const enable_profiling = b.option(bool, "enable-profiling", "Enable performance profiling") orelse false;
    const enable_lto = b.option(bool, "enable-lto", "Enable Link Time Optimization") orelse (optimize != .Debug);
    _ = b.option(bool, "enable-incremental", "Enable incremental compilation") orelse true; // 保留选项供未来使用
    
    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_simd", enable_simd);
    build_options.addOption(bool, "enable_profiling", enable_profiling);
    build_options.addOption(bool, "enable_lto", enable_lto);
    build_options.addOption(std.builtin.OptimizeMode, "optimize_mode", optimize);
    
    // 主库模块 - 按照官方约定使用root.zig，应用构建选项
    const lib_module = b.addModule("zig_system", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    lib_module.addOptions("build_options", build_options);
    
    // Zig 0.15.1: 创建库工件用于安装
    const lib = b.addLibrary(.{
        .name = "zig_system",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib.root_module.addOptions("build_options", build_options);
    
    // 根据优化级别和平台设置库属性
    if (enable_lto and optimize != .Debug) {
        // LLD支持检查 - 在Linux和某些其他平台上启用
        if (target.result.os.tag == .linux or target.result.os.tag == .windows) {
            lib.use_lld = true;
        }
    }
    
    // 安装库
    b.installArtifact(lib);
    
    // 单元测试 - 使用增强的测试配置
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_module,
    });
    
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    
    // 集成测试（如果存在）
    const integration_test_path = "tests/integration_test.zig";
    if (b.build_root.handle.access(integration_test_path, .{})) |_| {
        const integration_test_module = b.createModule(.{
            .root_source_file = b.path(integration_test_path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zig_system", .module = lib_module },
            },
        });
        
        const integration_tests = b.addTest(.{
            .root_module = integration_test_module,
        });
        
        const run_integration_tests = b.addRunArtifact(integration_tests);
        const integration_test_step = b.step("test-integration", "Run integration tests");
        integration_test_step.dependOn(&run_integration_tests.step);
        
        // 主测试步骤包含集成测试
        test_step.dependOn(&run_integration_tests.step);
    } else |_| {
        // 集成测试文件不存在，跳过
    }
    
    // Zig 0.15.1: 改进的基准测试设置
    setupBenchmarks(b, target, optimize, lib_module, build_options);
    
    // Zig 0.15.1: 添加性能分析步骤
    if (enable_profiling) {
        setupProfiling(b, target, optimize, lib_module, build_options);
    }
}

/// Zig 0.15.1 增强的基准测试设置
fn setupBenchmarks(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    _: std.builtin.OptimizeMode, // 标记未使用但保留用于一致性
    lib_module: *std.Build.Module,
    build_options: *std.Build.Step.Options,
) void {
    // 内存基准测试
    const memory_bench_path = "bench/memory_bench.zig";
    if (b.build_root.handle.access(memory_bench_path, .{})) |_| {
        // Zig 0.15.1: 优化的基准测试模块
        const memory_bench_module = b.createModule(.{
            .root_source_file = b.path(memory_bench_path),
            .target = target,
            .optimize = .ReleaseFast, // 基准测试总是使用最快优化
            .imports = &.{
                .{ .name = "zig_system", .module = lib_module },
            },
        });
        memory_bench_module.addOptions("build_options", build_options);
        
        const memory_bench = b.addExecutable(.{
            .name = "memory_bench",
            .root_module = memory_bench_module,
        });
        
        // Zig 0.15.1: 基准测试优化设置 (仅在支持的平台)
        if (target.result.os.tag == .linux or target.result.os.tag == .windows) {
            memory_bench.use_lld = true; // 使用LLD链接器提升性能
        }
        
        const run_memory_bench = b.addRunArtifact(memory_bench);
        const memory_bench_step = b.step("bench-memory", "Run memory benchmarks");
        memory_bench_step.dependOn(&run_memory_bench.step);
        
        // 通用基准测试步骤
        const bench_step = b.step("bench", "Run all benchmarks");
        bench_step.dependOn(&run_memory_bench.step);
    } else |_| {
        // 基准测试文件不存在，跳过
    }
}

/// Zig 0.15.1 性能分析设置
fn setupProfiling(
    b: *std.Build,
    _: std.Build.ResolvedTarget, // 标记未使用但保留用于一致性
    _: std.builtin.OptimizeMode, // 标记未使用但保留用于一致性
    lib_module: *std.Build.Module,
    build_options: *std.Build.Step.Options,
) void {
    // 创建性能分析测试
    const profiling_test = b.addTest(.{
        .root_module = lib_module,
    });
    
    // Zig 0.15.1: 为性能分析启用详细信息
    profiling_test.root_module.addOptions("build_options", build_options);
    
    const run_profiling_test = b.addRunArtifact(profiling_test);
    const profiling_step = b.step("profile", "Run performance profiling tests");
    profiling_step.dependOn(&run_profiling_test.step);
    
    // 添加内存分析
    const memory_profile_step = b.step("profile-memory", "Profile memory usage");
    memory_profile_step.dependOn(&run_profiling_test.step);
}