//! MIRA - Zig 0.15.1 库构建脚本
//! My Intelligent Romantic Assistant - 系统性能优化模块构建配置
//! 
//! 本文件遵循Zig官方库项目构建最佳实践，使用Zig 0.15.1最新特性：
//! - 模块化构建系统
//! - 条件编译和优化选项
//! - 多阶段测试配置
//! - 性能分析和基准测试
//! - 跨平台兼容性支持

const std = @import("std");

/// 主构建函数 - Zig构建系统的入口点
/// 
/// 这个函数定义了整个项目的构建配置，包括：
/// - 库的创建和配置
/// - 测试的设置和运行
/// - 基准测试的配置
/// - 性能分析工具的设置
/// - 安装和部署选项
pub fn build(b: *std.Build) void {
    // ============================================================================
    // 构建目标和优化选项配置
    // ============================================================================
    
    // 获取目标平台配置 - 支持交叉编译
    // 用户可以通过命令行参数指定目标平台，如：zig build -Dtarget=x86_64-linux
    const target = b.standardTargetOptions(.{});
    
    // 获取优化级别配置 - 影响编译速度和运行时性能
    // 可选值：Debug, ReleaseFast, ReleaseSafe, ReleaseSmall
    const optimize = b.standardOptimizeOption(.{});
    
    // ============================================================================
    // Zig 0.15.1 增强的构建选项 - 支持条件编译和性能调优
    // ============================================================================
    
    // SIMD优化选项 - 启用SIMD指令集优化（默认启用）
    // 在支持的平台上可以显著提升向量运算性能
    const enable_simd = b.option(bool, "enable-simd", "Enable SIMD optimizations") orelse true;
    
    // 性能分析选项 - 启用性能分析功能（默认禁用）
    // 仅在开发时使用，会添加性能监控代码
    const enable_profiling = b.option(bool, "enable-profiling", "Enable performance profiling") orelse false;
    
    // 链接时优化选项 - 启用LTO优化（在非Debug模式下默认启用）
    // 可以显著提升最终二进制文件的性能，但会增加编译时间
    const enable_lto = b.option(bool, "enable-lto", "Enable Link Time Optimization") orelse (optimize != .Debug);
    
    // 增量编译选项 - 保留供未来使用
    // 可以加速重复编译过程
    _ = b.option(bool, "enable-incremental", "Enable incremental compilation") orelse true;
    
    // ============================================================================
    // 构建选项配置 - 将选项传递给编译的代码
    // ============================================================================
    
    // 创建构建选项模块，用于在编译时传递配置信息
    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_simd", enable_simd);
    build_options.addOption(bool, "enable_profiling", enable_profiling);
    build_options.addOption(bool, "enable_lto", enable_lto);
    build_options.addOption(std.builtin.OptimizeMode, "optimize_mode", optimize);
    
    // ============================================================================
    // 主库模块配置 - 核心库的创建和设置
    // ============================================================================
    
    // 创建主库模块 - 按照官方约定使用root.zig作为入口点
    // 这个模块包含了所有公开的API和功能
    const lib_module = b.addModule("zig_system", .{
        .root_source_file = b.path("src/root.zig"),  // 指定入口文件
        .target = target,                             // 设置目标平台
    });
    
    // 将构建选项添加到库模块中，使代码可以访问这些配置
    lib_module.addOptions("build_options", build_options);
    
    // ============================================================================
    // 库工件创建 - 用于安装和分发
    // ============================================================================
    
    // Zig 0.15.1: 创建库工件用于安装和分发
    // 这个工件可以被其他项目链接使用
    const lib = b.addLibrary(.{
        .name = "zig_system",  // 库的名称
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    
    // 将构建选项添加到库工件中
    lib.root_module.addOptions("build_options", build_options);
    
    // ============================================================================
    // 平台特定优化配置
    // ============================================================================
    
    // 根据优化级别和平台设置库属性
    if (enable_lto and optimize != .Debug) {
        // LLD支持检查 - 在Linux和某些其他平台上启用
        // LLD是LLVM的链接器，通常比系统默认链接器更快
        if (target.result.os.tag == .linux or target.result.os.tag == .windows) {
            lib.use_lld = true;
        }
    }
    
    // ============================================================================
    // 安装配置 - 使库可以被系统使用
    // ============================================================================
    
    // 安装库到系统目录，使其可以被其他项目使用
    b.installArtifact(lib);
    
    // ============================================================================
    // 单元测试配置 - 测试库的核心功能
    // ============================================================================
    
    // 创建单元测试 - 测试源代码中的功能
    // 这些测试直接测试库的各个模块
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_module,  // 使用相同的模块配置
    });
    
    // 创建运行单元测试的步骤
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    
    // 创建测试步骤，用户可以通过 "zig build test" 运行
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    
    // ============================================================================
    // 集成测试配置 - 测试整个系统的协作
    // ============================================================================
    
    // 集成测试（如果存在）- 测试整个系统的协作
    const integration_test_path = "tests/integration_test.zig";
    
    // 检查集成测试文件是否存在
    if (b.build_root.handle.access(integration_test_path, .{})) |_| {
        // 创建集成测试模块 - 需要导入主库模块
        const integration_test_module = b.createModule(.{
            .root_source_file = b.path(integration_test_path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                // 导入主库模块，使测试可以访问库的功能
                .{ .name = "zig_system", .module = lib_module },
            },
        });
        
        // 创建集成测试
        const integration_tests = b.addTest(.{
            .root_module = integration_test_module,
        });
        
        // 创建运行集成测试的步骤
        const run_integration_tests = b.addRunArtifact(integration_tests);
        
        // 创建单独的集成测试步骤
        const integration_test_step = b.step("test-integration", "Run integration tests");
        integration_test_step.dependOn(&run_integration_tests.step);
        
        // 将集成测试添加到主测试步骤中
        test_step.dependOn(&run_integration_tests.step);
    } else |_| {
        // 集成测试文件不存在，跳过
        // 这允许项目在没有集成测试的情况下也能正常构建
    }
    
    // ============================================================================
    // 基准测试和性能分析配置
    // ============================================================================
    
    // Zig 0.15.1: 改进的基准测试设置
    setupBenchmarks(b, target, optimize, lib_module, build_options);
    
    // Zig 0.15.1: 添加性能分析步骤（仅在启用时）
    if (enable_profiling) {
        setupProfiling(b, target, optimize, lib_module, build_options);
    }
}

/// Zig 0.15.1 增强的基准测试设置
/// 
/// 这个函数配置性能基准测试，用于测量和优化关键功能的性能。
/// 基准测试通常使用ReleaseFast优化级别以获得最佳性能。
fn setupBenchmarks(
    b: *std.Build,                    // 构建系统实例
    target: std.Build.ResolvedTarget, // 目标平台
    _: std.builtin.OptimizeMode,      // 优化级别（未使用但保留用于一致性）
    lib_module: *std.Build.Module,    // 主库模块
    build_options: *std.Build.Step.Options, // 构建选项
) void {
    // 内存基准测试配置
    const memory_bench_path = "bench/memory_bench.zig";
    
    // 检查基准测试文件是否存在
    if (b.build_root.handle.access(memory_bench_path, .{})) |_| {
        // Zig 0.15.1: 优化的基准测试模块
        const memory_bench_module = b.createModule(.{
            .root_source_file = b.path(memory_bench_path),
            .target = target,
            .optimize = .ReleaseFast, // 基准测试总是使用最快优化
            .imports = &.{
                // 导入主库模块以测试其功能
                .{ .name = "zig_system", .module = lib_module },
            },
        });
        
        // 将构建选项添加到基准测试模块
        memory_bench_module.addOptions("build_options", build_options);
        
        // 创建基准测试可执行文件
        const memory_bench = b.addExecutable(.{
            .name = "memory_bench",
            .root_module = memory_bench_module,
        });
        
        // Zig 0.15.1: 基准测试优化设置 (仅在支持的平台)
        // 使用LLD链接器可以提升性能
        if (target.result.os.tag == .linux or target.result.os.tag == .windows) {
            memory_bench.use_lld = true;
        }
        
        // 创建运行基准测试的步骤
        const run_memory_bench = b.addRunArtifact(memory_bench);
        
        // 创建内存基准测试步骤
        const memory_bench_step = b.step("bench-memory", "Run memory benchmarks");
        memory_bench_step.dependOn(&run_memory_bench.step);
        
        // 创建通用基准测试步骤
        const bench_step = b.step("bench", "Run all benchmarks");
        bench_step.dependOn(&run_memory_bench.step);
    } else |_| {
        // 基准测试文件不存在，跳过
        // 这允许项目在没有基准测试的情况下也能正常构建
    }
}

/// Zig 0.15.1 性能分析设置
/// 
/// 这个函数配置性能分析工具，用于深入分析代码性能。
/// 性能分析功能使用基准测试和集成测试来实现。
fn setupProfiling(
    b: *std.Build,                    // 构建系统实例
    _: std.Build.ResolvedTarget,      // 目标平台（未使用）
    _: std.builtin.OptimizeMode,      // 优化级别（未使用但保留用于一致性）
    lib_module: *std.Build.Module,    // 主库模块
    build_options: *std.Build.Step.Options, // 构建选项
) void {
    // 使用基准测试和集成测试进行性能分析
    const profiling_test = b.addTest(.{
        .root_module = lib_module,
    });
    
    // Zig 0.15.1: 为性能分析启用详细信息
    profiling_test.root_module.addOptions("build_options", build_options);
    
    // 创建运行性能分析测试的步骤
    const run_profiling_test = b.addRunArtifact(profiling_test);
    
    // 创建性能分析步骤
    const profiling_step = b.step("profile", "Run performance profiling tests");
    profiling_step.dependOn(&run_profiling_test.step);
    
    // 添加内存分析步骤
    const memory_profile_step = b.step("profile-memory", "Profile memory usage");
    memory_profile_step.dependOn(&run_profiling_test.step);
}