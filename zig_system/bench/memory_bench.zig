//! 内存池性能基准测试
//! 使用Zig官方推荐的基准测试结构

const std = @import("std");
const mira = @import("zig_system");

const ITERATIONS = 100_000;
const POOL_SIZE = 1024 * 1024; // 1MB

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("=== MIRA 内存池性能基准测试 ===\n", .{});
    std.debug.print("测试迭代次数: {}\n", .{ITERATIONS});
    std.debug.print("内存池大小: {}KB\n\n", .{POOL_SIZE / 1024});
    
    try benchmarkMemoryPool(allocator);
    try benchmarkStandardAllocator(allocator);
    try benchmarkSimpleOperations(allocator);
    try benchmarkOptimizedFree(allocator);
}

fn benchmarkMemoryPool(allocator: std.mem.Allocator) !void {
    std.debug.print("📦 内存池基准测试:\n", .{});
    
    var pool = try mira.memory.MemoryPool.init(allocator, POOL_SIZE);
    defer pool.deinit();
    
    const sizes = [_]usize{ 64, 128, 256, 512, 1024 };
    
    for (sizes) |size| {
        const start_time = std.time.nanoTimestamp();
        
        // 分配测试
        var ptrs = std.ArrayList(?*anyopaque).initCapacity(allocator, ITERATIONS) catch unreachable;
        defer ptrs.deinit(allocator);
        
        for (0..ITERATIONS) |_| {
            if (pool.alloc(size)) |ptr| {
                try ptrs.append(allocator, ptr);
            } else |_| {
                break;
            }
        }
        
        const alloc_end = std.time.nanoTimestamp();
        
        // 释放测试
        for (ptrs.items) |ptr| {
            if (ptr) |p| {
                pool.free(p);
            }
        }
        
        const free_end = std.time.nanoTimestamp();
        
        const alloc_time = alloc_end - start_time;
        const free_time = free_end - alloc_end;
        const alloc_ns_per_op = @as(f64, @floatFromInt(alloc_time)) / @as(f64, @floatFromInt(ptrs.items.len));
        const free_ns_per_op = @as(f64, @floatFromInt(free_time)) / @as(f64, @floatFromInt(ptrs.items.len));
        
        const stats = pool.get_stats();
        const fragmentation = (@as(f64, @floatFromInt(stats.total - stats.used - stats.free)) / @as(f64, @floatFromInt(stats.total))) * 100.0;
        
        std.debug.print("  大小 {}B: 分配 {d:.2}ns/op, 释放 {d:.2}ns/op, 碎片率 {d:.1}%\n", 
            .{ size, alloc_ns_per_op, free_ns_per_op, fragmentation });
    }
    std.debug.print("\n", .{});
}

fn benchmarkStandardAllocator(allocator: std.mem.Allocator) !void {
    std.debug.print("🔧 标准分配器基准测试:\n", .{});
    
    const sizes = [_]usize{ 64, 128, 256, 512, 1024 };
    
    for (sizes) |size| {
        const start_time = std.time.nanoTimestamp();
        
        // 分配测试
        var ptrs = std.ArrayList([]u8).initCapacity(allocator, ITERATIONS) catch unreachable;
        defer {
            for (ptrs.items) |ptr| {
                allocator.free(ptr);
            }
            ptrs.deinit(allocator);
        }
        
        for (0..ITERATIONS) |_| {
            const ptr = allocator.alloc(u8, size) catch break;
            try ptrs.append(allocator, ptr);
        }
        
        const alloc_end = std.time.nanoTimestamp();
        
        // 释放在defer中处理
        const free_end = std.time.nanoTimestamp();
        
        const alloc_time = alloc_end - start_time;
        const total_time = free_end - start_time;
        const alloc_ns_per_op = @as(f64, @floatFromInt(alloc_time)) / @as(f64, @floatFromInt(ptrs.items.len));
        const total_ns_per_op = @as(f64, @floatFromInt(total_time)) / @as(f64, @floatFromInt(ptrs.items.len));
        
        std.debug.print("  大小 {}B: 分配 {d:.2}ns/op, 总计 {d:.2}ns/op\n", 
            .{ size, alloc_ns_per_op, total_ns_per_op });
    }
    std.debug.print("\n", .{});
}

fn benchmarkSimpleOperations(allocator: std.mem.Allocator) !void {
    std.debug.print("🔄 简单操作基准测试:\n", .{});
    
    var pool = try mira.memory.MemoryPool.init(allocator, POOL_SIZE);
    defer pool.deinit();
    
    const start_time = std.time.nanoTimestamp();
    
    // 简单的分配和释放循环
    for (0..ITERATIONS) |i| {
        const size = 32 + (i % 480); // 32-512字节
        if (pool.alloc(size)) |ptr| {
            pool.free(ptr);
        } else |_| {
            // 如果分配失败，重置池
            pool.reset();
        }
    }
    
    const end_time = std.time.nanoTimestamp();
    const total_time = end_time - start_time;
    const ns_per_op = @as(f64, @floatFromInt(total_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    const stats = pool.get_stats();
    const efficiency = (@as(f64, @floatFromInt(stats.used + stats.free)) / @as(f64, @floatFromInt(stats.total))) * 100.0;
    
    std.debug.print("  简单操作: {d:.2}ns/op\n", .{ns_per_op});
    std.debug.print("  内存效率: {d:.1}%\n", .{efficiency});
    std.debug.print("  最终统计: 总计={}B, 已用={}B, 空闲={}B\n", 
        .{ stats.total, stats.used, stats.free });
}

fn benchmarkOptimizedFree(allocator: std.mem.Allocator) !void {
    std.debug.print("⚡ 优化释放基准测试:\n", .{});
    
    var pool = try mira.memory.MemoryPool.init(allocator, POOL_SIZE);
    defer pool.deinit();
    
    const sizes = [_]usize{ 64, 128, 256, 512, 1024 };
    
    for (sizes) |size| {
        const start_time = std.time.nanoTimestamp();
        
        // 分配测试
        var ptrs = std.ArrayList(?*anyopaque).initCapacity(allocator, ITERATIONS) catch unreachable;
        defer ptrs.deinit(allocator);
        
        for (0..ITERATIONS) |_| {
            if (pool.alloc(size)) |ptr| {
                try ptrs.append(allocator, ptr);
            } else |_| {
                break;
            }
        }
        
        const alloc_end = std.time.nanoTimestamp();
        
        // 批量释放（利用延迟合并）
        for (ptrs.items) |ptr| {
            if (ptr) |p| {
                pool.free(p);
            }
        }
        
        const free_end = std.time.nanoTimestamp();
        
        // 手动触发最终合并
        pool.force_coalesce();
        const coalesce_end = std.time.nanoTimestamp();
        
        const alloc_time = alloc_end - start_time;
        const free_time = free_end - alloc_end;
        const coalesce_time = coalesce_end - free_end;
        const total_free_time = free_time + coalesce_time;
        
        const alloc_ns_per_op = @as(f64, @floatFromInt(alloc_time)) / @as(f64, @floatFromInt(ptrs.items.len));
        const free_ns_per_op = @as(f64, @floatFromInt(total_free_time)) / @as(f64, @floatFromInt(ptrs.items.len));
        
        std.debug.print("  大小 {}B: 分配 {d:.2}ns/op, 释放 {d:.2}ns/op (合并: {d:.2}ns)\n", 
            .{ size, alloc_ns_per_op, free_ns_per_op, @as(f64, @floatFromInt(coalesce_time)) / @as(f64, @floatFromInt(ptrs.items.len)) });
    }
    std.debug.print("\n", .{});
}
