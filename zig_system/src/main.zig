//! MIRA系统层 - Zig 0.15.1
//! My Intelligent Romantic Assistant
//! 高性能内存管理、向量运算和系统监控
//! 使用最新的Zig 0.15.1特性和优化的标准库

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

// 导入模块化组件 - Zig 0.15.1模块系统
const memory = @import("memory");
const vector = @import("vector");
const monitor = @import("monitor");

// 导出C接口给Rust使用 - 使用新的模块化API
pub export fn zig_memory_pool_init(pool_size: usize) ?*anyopaque {
    const allocator = std.heap.page_allocator;
    const pool = memory.MemoryPool.init(allocator, pool_size) catch return null;
    const pool_ptr = allocator.create(memory.MemoryPool) catch return null;
    pool_ptr.* = pool;
    return @ptrCast(pool_ptr);
}

pub export fn zig_memory_pool_alloc(pool_ptr: ?*anyopaque, size: usize) ?*anyopaque {
    if (pool_ptr == null) return null;
    const pool: *memory.MemoryPool = @ptrCast(@alignCast(pool_ptr));
    return pool.alloc(size) catch null;
}

pub export fn zig_memory_pool_free(pool_ptr: ?*anyopaque, ptr: ?*anyopaque) void {
    if (pool_ptr == null or ptr == null) return;
    const pool: *memory.MemoryPool = @ptrCast(@alignCast(pool_ptr));
    pool.free(@ptrCast(ptr));
}

pub export fn zig_memory_pool_destroy(pool_ptr: ?*anyopaque) void {
    if (pool_ptr == null) return;
    const pool: *memory.MemoryPool = @ptrCast(@alignCast(pool_ptr));
    pool.deinit();
    std.heap.page_allocator.destroy(pool);
}

pub export fn zig_fast_string_hash(text: [*c]const u8, len: usize) u64 {
    const slice = text[0..len];
    return vector.FastHash.hash(slice);
}

pub export fn zig_vector_dot_product(a: [*c]const f32, b: [*c]const f32, len: usize) f32 {
    const slice_a = a[0..len];
    const slice_b = b[0..len];
    return vector.VectorOps.dotProduct(slice_a, slice_b);
}

pub export fn zig_get_memory_usage() usize {
    return monitor.SystemMonitor.getMemoryUsage();
}

pub export fn zig_get_cpu_usage() f32 {
    return monitor.SystemMonitor.getCpuUsage();
}

// 新增的C接口 - Zig 0.15.1特性 (返回简化的数据)
pub export fn zig_get_memory_usage_bytes() usize {
    return monitor.SystemMonitor.getMemoryUsage();
}

pub export fn zig_get_cpu_usage_percent() f32 {
    return monitor.SystemMonitor.getCpuUsage();
}

pub export fn zig_memory_pool_get_total(pool_ptr: ?*anyopaque) usize {
    if (pool_ptr == null) return 0;
    const pool: *memory.MemoryPool = @ptrCast(@alignCast(pool_ptr));
    return pool.getStats().total;
}

pub export fn zig_memory_pool_get_used(pool_ptr: ?*anyopaque) usize {
    if (pool_ptr == null) return 0;
    const pool: *memory.MemoryPool = @ptrCast(@alignCast(pool_ptr));
    return pool.getStats().used;
}

pub export fn zig_vector_cosine_similarity(a: [*c]const f32, b: [*c]const f32, len: usize) f32 {
    const slice_a = a[0..len];
    const slice_b = b[0..len];
    return vector.VectorOps.cosineSimilarity(slice_a, slice_b);
}

pub export fn zig_vector_normalize(vec: [*c]f32, len: usize) void {
    const slice = @as([*]f32, @ptrCast(vec))[0..len];
    vector.VectorOps.normalize(slice);
}

// 重新导出模块中的主要类型，便于外部访问
pub const MemoryPool = memory.MemoryPool;
pub const MemoryStats = memory.MemoryStats;
pub const VectorOps = vector.VectorOps;
pub const FastHash = vector.FastHash;
pub const SystemMonitor = monitor.SystemMonitor;
pub const Profiler = monitor.Profiler;

// 集成测试 - 测试模块间的协作
test "integrated functionality" {
    // 测试内存池和向量运算的集成
    var pool = try MemoryPool.init(testing.allocator, 4096);
    defer pool.deinit();
    
    // 分配向量内存
    const vec_size = 100;
    const vec_ptr = try pool.alloc(vec_size * @sizeOf(f32));
    defer pool.free(vec_ptr);
    
    const vec_slice: []f32 = @as([*]f32, @ptrCast(@alignCast(vec_ptr)))[0..vec_size];
    
    // 初始化向量
    for (vec_slice, 0..) |*elem, i| {
        elem.* = @as(f32, @floatFromInt(i));
    }
    
    // 归一化向量
    VectorOps.normalize(vec_slice);
    
    // 验证归一化结果
    var norm: f32 = 0.0;
    for (vec_slice) |v| {
        norm += v * v;
    }
    
    try testing.expectApproxEqAbs(@sqrt(norm), 1.0, 0.001);
}

test "performance monitoring integration" {
    const initial_metrics = SystemMonitor.getPerformanceMetrics();
    
    // 执行一些计算密集的操作
    var sum: f64 = 0.0;
    for (0..10000) |i| {
        sum += @sqrt(@as(f64, @floatFromInt(i)));
    }
    
    const final_metrics = SystemMonitor.getPerformanceMetrics();
    
    // 验证监控数据的合理性
    try testing.expect(initial_metrics.memory_usage_bytes > 0 or builtin.os.tag != .linux);
    try testing.expect(final_metrics.cpu_usage_percent >= 0.0);
    
    // 确保计算有实际效果
    try testing.expect(sum > 0.0);
}
