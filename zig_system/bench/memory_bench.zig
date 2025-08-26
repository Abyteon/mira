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
    
    std.debug.print("=== MIRA 内存池性能基准测试 ===\n");
    std.debug.print("测试迭代次数: {}\n", .{ITERATIONS});
    std.debug.print("内存池大小: {}KB\n\n", .{POOL_SIZE / 1024});
    
    try benchmarkMemoryPool(allocator);
    try benchmarkStandardAllocator(allocator);
    try benchmarkMixedOperations(allocator);
}

fn benchmarkMemoryPool(allocator: std.mem.Allocator) !void {
    std.debug.print("📦 内存池基准测试:\n");
    
    var pool = try mira.memory.MemoryPool.init(allocator, POOL_SIZE);
    defer pool.deinit();
    
    const sizes = [_]usize{ 64, 128, 256, 512, 1024 };
    
    for (sizes) |size| {
        const start_time = std.time.nanoTimestamp();
        
        // 分配测试
        var ptrs = std.ArrayList(?*anyopaque).init(allocator);
        defer ptrs.deinit();
        
        for (0..ITERATIONS) |_| {
            if (pool.alloc(size)) |ptr| {
                try ptrs.append(ptr);
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
    std.debug.print("\n");
}

fn benchmarkStandardAllocator(allocator: std.mem.Allocator) !void {
    std.debug.print("🔧 标准分配器基准测试:\n");
    
    const sizes = [_]usize{ 64, 128, 256, 512, 1024 };
    
    for (sizes) |size| {
        const start_time = std.time.nanoTimestamp();
        
        // 分配测试
        var ptrs = std.ArrayList([]u8).init(allocator);
        defer {
            for (ptrs.items) |ptr| {
                allocator.free(ptr);
            }
            ptrs.deinit();
        }
        
        for (0..ITERATIONS) |_| {
            const ptr = allocator.alloc(u8, size) catch break;
            try ptrs.append(ptr);
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
    std.debug.print("\n");
}

fn benchmarkMixedOperations(allocator: std.mem.Allocator) !void {
    std.debug.print("🔄 混合操作基准测试:\n");
    
    var pool = try mira.memory.MemoryPool.init(allocator, POOL_SIZE);
    defer pool.deinit();
    
    const start_time = std.time.nanoTimestamp();
    
    var active_ptrs = std.ArrayList(?*anyopaque).init(allocator);
    defer active_ptrs.deinit();
    
    var rng = std.rand.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random = rng.random();
    
    for (0..ITERATIONS) |_| {
        const operation = random.intRangeLessThan(u8, 0, 3);
        
        switch (operation) {
            0 => { // 分配
                const size = random.intRangeLessThan(usize, 32, 512);
                if (pool.alloc(size)) |ptr| {
                    try active_ptrs.append(ptr);
                } else |_| {}
            },
            1 => { // 释放
                if (active_ptrs.items.len > 0) {
                    const index = random.intRangeLessThan(usize, 0, active_ptrs.items.len);
                    if (active_ptrs.items[index]) |ptr| {
                        pool.free(ptr);
                        _ = active_ptrs.swapRemove(index);
                    }
                }
            },
            2 => { // 重新分配（释放后立即分配）
                if (active_ptrs.items.len > 0) {
                    const index = random.intRangeLessThan(usize, 0, active_ptrs.items.len);
                    if (active_ptrs.items[index]) |ptr| {
                        pool.free(ptr);
                        active_ptrs.items[index] = null;
                    }
                }
                const size = random.intRangeLessThan(usize, 32, 512);
                if (pool.alloc(size)) |ptr| {
                    try active_ptrs.append(ptr);
                } else |_| {}
            },
            else => unreachable,
        }
    }
    
    // 清理剩余指针
    for (active_ptrs.items) |ptr| {
        if (ptr) |p| {
            pool.free(p);
        }
    }
    
    const end_time = std.time.nanoTimestamp();
    const total_time = end_time - start_time;
    const ns_per_op = @as(f64, @floatFromInt(total_time)) / @as(f64, @floatFromInt(ITERATIONS));
    
    const stats = pool.get_stats();
    const efficiency = (@as(f64, @floatFromInt(stats.used + stats.free)) / @as(f64, @floatFromInt(stats.total))) * 100.0;
    
    std.debug.print("  混合操作: {d:.2}ns/op\n", .{ns_per_op});
    std.debug.print("  内存效率: {d:.1}%\n", .{efficiency});
    std.debug.print("  最终统计: 总计={}B, 已用={}B, 空闲={}B\n", 
        .{ stats.total, stats.used, stats.free });
}
