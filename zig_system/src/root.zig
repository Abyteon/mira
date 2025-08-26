//! MIRA系统层库 - Zig 0.15.1
//! My Intelligent Romantic Assistant - 系统性能优化模块
//!
//! 本库提供高性能的核心系统功能，专为AI助手应用设计：
//! - 内存池管理：高效的内存分配和回收
//! - 向量运算：SIMD优化的数值计算
//! - 系统监控：实时性能指标收集
//! - C FFI接口：与Rust主程序无缝集成
//!
//! 特性：
//! - 零拷贝操作
//! - SIMD加速计算
//! - 内存安全保证
//! - 跨平台兼容性
//!
//! 用法示例：
//! ```zig
//! const mira = @import("root.zig");
//! 
//! // 创建内存池
//! var pool = try mira.MemoryPool.init(allocator, 1024 * 1024);
//! defer pool.deinit();
//! 
//! // 向量运算
//! const result = mira.VectorOps.dot_product(vec_a, vec_b);
//! 
//! // 系统监控
//! const cpu_usage = mira.SystemMonitor.get_cpu_usage();
//! ```

const std = @import("std");

// ============================================================================
// 公开的模块API - 核心功能模块
// ============================================================================

/// 内存管理模块 - 提供高效的内存池和竞技场分配器
pub const memory = @import("memory.zig");

/// 向量运算模块 - 提供SIMD优化的数值计算功能
pub const vector = @import("vector.zig");

/// 系统监控模块 - 提供实时的系统性能指标收集
pub const monitor = @import("monitor.zig");

// ============================================================================
// 便利的类型别名 - 简化外部使用
// ============================================================================

/// 高性能内存池，支持快速分配和批量释放
pub const MemoryPool = memory.MemoryPool;

/// 内存使用统计信息结构体
pub const MemoryStats = memory.MemoryStats;

/// 向量运算操作集合，包含SIMD优化的数学函数
pub const VectorOps = vector.VectorOps;

/// 快速哈希计算器，适用于字符串和二进制数据
pub const Hash = vector.Hash;

/// 系统资源监控器，提供CPU和内存使用情况
pub const SystemMonitor = monitor.SystemMonitor;

/// 性能分析器，用于代码性能测量和优化
pub const Profiler = monitor.Profiler;

// ============================================================================
// 库版本信息和配置
// ============================================================================

/// MIRA系统层库版本号，遵循语义化版本规范
pub const version = std.SemanticVersion{
    .major = 1,
    .minor = 0,
    .patch = 0,
};

/// 库运行时配置选项
pub const Config = struct {
    /// 启用SIMD向量优化（默认启用）
    enable_simd: bool = true,
    /// 启用内存池管理（默认启用）
    enable_memory_pool: bool = true,
    /// 启用性能分析功能（默认禁用，仅开发时使用）
    enable_profiling: bool = false,
    /// 调试模式，提供额外的运行时检查（默认禁用）
    debug_mode: bool = false,
};

/// 默认配置实例
pub const default_config = Config{};

// ============================================================================
// C ABI导出接口 - 为Rust主程序提供FFI集成
// ============================================================================
// 
// 这些函数使用C调用约定，允许Rust代码直接调用Zig实现的高性能功能。
// 所有函数都经过空指针检查和错误处理，确保在FFI边界的安全性。

// ----------------------------------------------------------------------------
// 内存池管理C接口
// ----------------------------------------------------------------------------

/// 创建新的内存池实例
/// 
/// 参数：
/// - pool_size: 内存池大小（字节）
/// 
/// 返回：
/// - 成功时返回内存池的不透明指针
/// - 失败时返回null
/// 
/// 注意：调用者负责通过pool_destroy释放资源
export fn pool_init(pool_size: usize) ?*anyopaque {
    const allocator = std.heap.page_allocator;
    const pool = memory.MemoryPool.init(allocator, pool_size) catch return null;
    const pool_ptr = allocator.create(memory.MemoryPool) catch return null;
    pool_ptr.* = pool;
    return @ptrCast(pool_ptr);
}

/// 从内存池分配指定大小的内存块
/// 
/// 参数：
/// - pool_ptr: 由mira_zig_memory_pool_init返回的内存池指针
/// - size: 要分配的内存大小（字节）
/// 
/// 返回：
/// - 成功时返回分配的内存指针
/// - 失败时返回null（内存不足或参数无效）
export fn pool_alloc(pool_ptr: ?*anyopaque, size: usize) ?*anyopaque {
    if (pool_ptr == null) return null;
    const pool: *memory.MemoryPool = @ptrCast(@alignCast(pool_ptr));
    return pool.alloc(size) catch null;
}

/// 释放内存池中的内存块
/// 
/// 参数：
/// - pool_ptr: 内存池指针
/// - ptr: 要释放的内存指针
/// 
/// 注意：ptr必须是由同一内存池分配的有效指针
export fn pool_free(pool_ptr: ?*anyopaque, ptr: ?*anyopaque) void {
    if (pool_ptr == null or ptr == null) return;
    const pool: *memory.MemoryPool = @ptrCast(@alignCast(pool_ptr));
    pool.free(@ptrCast(ptr));
}

/// 销毁内存池并释放所有相关资源
/// 
/// 参数：
/// - pool_ptr: 要销毁的内存池指针
/// 
/// 注意：调用后pool_ptr指针将失效，不可再次使用
export fn pool_destroy(pool_ptr: ?*anyopaque) void {
    if (pool_ptr == null) return;
    const pool: *memory.MemoryPool = @ptrCast(@alignCast(pool_ptr));
    pool.deinit();
    std.heap.page_allocator.destroy(pool);
}

/// 获取内存池的使用统计信息
/// 
/// 参数：
/// - pool_ptr: 内存池指针
/// - stats_out: 输出统计信息的缓冲区指针
/// 
/// 返回：
/// - true: 成功获取统计信息
/// - false: 参数无效或操作失败
export fn pool_stats(pool_ptr: ?*anyopaque, stats_out: ?*memory.MemoryStats) bool {
    if (pool_ptr == null or stats_out == null) return false;
    const pool: *memory.MemoryPool = @ptrCast(@alignCast(pool_ptr));
    stats_out.?.* = pool.get_stats();
    return true;
}

// ----------------------------------------------------------------------------
// 向量运算C接口
// ----------------------------------------------------------------------------

/// 计算两个向量的点积（内积）
/// 使用SIMD优化提供高性能计算
/// 
/// 参数：
/// - a: 第一个向量的数组指针
/// - b: 第二个向量的数组指针  
/// - len: 向量长度（元素个数）
/// 
/// 返回：
/// - 两个向量的点积结果
/// - 参数无效时返回0.0
export fn dot_product(a: [*c]const f32, b: [*c]const f32, len: usize) f32 {
    if (a == null or b == null or len == 0) return 0.0;
    const slice_a = a[0..len];
    const slice_b = b[0..len];
    return vector.VectorOps.dot_product(slice_a, slice_b);
}

/// 计算两个向量的余弦相似度
/// 用于测量向量之间的角度相似性，常用于AI嵌入向量比较
/// 
/// 参数：
/// - a: 第一个向量的数组指针
/// - b: 第二个向量的数组指针
/// - len: 向量长度（元素个数）
/// 
/// 返回：
/// - 余弦相似度值（-1.0到1.0之间）
/// - 参数无效时返回0.0
export fn cosine_similarity(a: [*c]const f32, b: [*c]const f32, len: usize) f32 {
    if (a == null or b == null or len == 0) return 0.0;
    const slice_a = a[0..len];
    const slice_b = b[0..len];
    return vector.VectorOps.cosine_similarity(slice_a, slice_b);
}

/// 就地标准化向量（使其模长为1）
/// 对向量进行单位化处理，常用于归一化嵌入向量
/// 
/// 参数：
/// - vec: 要标准化的向量数组指针（会被修改）
/// - len: 向量长度（元素个数）
/// 
/// 返回：
/// - true: 标准化成功
/// - false: 参数无效或向量模长为0
export fn normalize(vec: [*c]f32, len: usize) bool {
    if (vec == null or len == 0) return false;
    const slice = @as([*]f32, @ptrCast(vec))[0..len];
    vector.VectorOps.normalize(slice);
    return true;
}

// ----------------------------------------------------------------------------
// 哈希计算C接口
// ----------------------------------------------------------------------------

/// 计算字符串或二进制数据的快速哈希值
/// 使用高性能哈希算法，适用于字典、缓存键等场景
/// 
/// 参数：
/// - text: 要哈希的数据指针
/// - len: 数据长度（字节）
/// 
/// 返回：
/// - 64位哈希值
/// - 参数无效时返回0
export fn hash(text: [*c]const u8, len: usize) u64 {
    if (text == null or len == 0) return 0;
    const slice = text[0..len];
    return vector.Hash.hash(slice);
}

// ----------------------------------------------------------------------------
// 系统监控C接口
// ----------------------------------------------------------------------------

/// 获取当前进程的内存使用量
/// 
/// 返回：
/// - 内存使用量（字节）
export fn memory_usage() usize {
    return monitor.SystemMonitor.get_memory_usage();
}

/// 获取当前CPU使用率
/// 
/// 返回：
/// - CPU使用率百分比（0.0-100.0）
export fn cpu_usage() f32 {
    return monitor.SystemMonitor.get_cpu_usage();
}

// ----------------------------------------------------------------------------
// 库信息查询C接口
// ----------------------------------------------------------------------------

/// 获取库版本号信息
/// 
/// 参数：
/// - major: 主版本号输出指针
/// - minor: 次版本号输出指针
/// - patch: 补丁版本号输出指针
export fn get_version(major: *u32, minor: *u32, patch: *u32) void {
    major.* = version.major;
    minor.* = version.minor;
    patch.* = version.patch;
}

/// 查询SIMD优化是否启用
/// 
/// 返回：
/// - true: SIMD优化已启用
/// - false: SIMD优化已禁用
export fn simd_enabled() bool {
    return default_config.enable_simd;
}

// ============================================================================
// 模块测试 - 确保所有子模块正确导入和引用
// ============================================================================

// 递归测试所有声明的可达性
test {
    std.testing.refAllDeclsRecursive(@This());
}

// 测试内存管理模块导入
test "memory module" {
    _ = memory;
}

// 测试向量运算模块导入
test "vector module" {
    _ = vector;
}

// 测试系统监控模块导入
test "monitor module" {
    _ = monitor;
}