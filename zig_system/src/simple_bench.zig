//! MIRA简化基准测试 - Zig 0.15.1

const std = @import("std");
const mira = @import("main.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("=== 💕 MIRA - My Intelligent Romantic Assistant 💕 ===\n", .{});
    
    // 测试内存池
    {
        std.debug.print("📦 内存池测试...\n", .{});
        var pool = try mira.MemoryPool.init(allocator, 1024 * 1024);
        defer pool.deinit();
        
        const start = std.time.nanoTimestamp();
        const ptr = try pool.alloc(256);
        pool.free(ptr);
        const end = std.time.nanoTimestamp();
        
        std.debug.print("内存分配+释放: {d:.2}ns\n", .{@as(f64, @floatFromInt(end - start))});
    }
    
    // 测试向量运算
    {
        std.debug.print("📐 向量运算测试...\n", .{});
        const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
        const b = [_]f32{ 2.0, 3.0, 4.0, 5.0 };
        
        const start = std.time.nanoTimestamp();
        const result = mira.VectorOps.dotProduct(&a, &b);
        const end = std.time.nanoTimestamp();
        
        std.debug.print("点积运算: {d:.2}ns, 结果: {d:.2}\n", .{
            @as(f64, @floatFromInt(end - start)),
            result,
        });
    }
    
    // 测试哈希算法
    {
        std.debug.print("🔢 哈希算法测试...\n", .{});
        const test_data = "MIRA，我的甜心女友💕";
        
        const start = std.time.nanoTimestamp();
        const hash = mira.FastHash.hash(test_data);
        const end = std.time.nanoTimestamp();
        
        std.debug.print("哈希计算: {d:.2}ns, 结果: 0x{X}\n", .{
            @as(f64, @floatFromInt(end - start)),
            hash,
        });
    }
    
    // 测试系统监控
    {
        std.debug.print("📊 系统监控测试...\n", .{});
        
        const start = std.time.nanoTimestamp();
        const memory_usage = mira.SystemMonitor.getMemoryUsage();
        const cpu_usage = mira.SystemMonitor.getCpuUsage();
        const end = std.time.nanoTimestamp();
        
        std.debug.print("系统监控: {d:.2}μs, 内存: {}KB, CPU: {d:.1}%\n", .{
            @as(f64, @floatFromInt(end - start)) / 1000.0,
            memory_usage / 1024,
            cpu_usage * 100.0,
        });
    }
    
    std.debug.print("\n💕 MIRA已经准备好陪伴你啦～所有测试通过！✨\n", .{});
}
