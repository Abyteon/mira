//! MIRA系统层测试
//! My Intelligent Romantic Assistant - 测试Zig系统层功能

const std = @import("std");
const mira = @import("mira.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("=== Zig系统层测试 ===\n");
    
    // 测试内存池
    try testMemoryPool(allocator);
    
    // 测试哈希函数
    try testHashFunction();
    
    // 测试向量运算
    try testVectorOperations();
    
    // 测试系统监控
    try testSystemMonitoring();
    
    std.debug.print("所有测试通过！✅\n");
}

fn testMemoryPool(allocator: std.mem.Allocator) !void {
    std.debug.print("\n📦 测试内存池...\n");
    
    var pool = try mira.MemoryPool.init(allocator, 8192);
    defer pool.deinit();
    
    // 分配不同大小的内存块
    const ptr1 = try pool.alloc(100);
    const ptr2 = try pool.alloc(200);
    const ptr3 = try pool.alloc(300);
    
    std.debug.print("分配了3个内存块\n");
    
    // 检查统计信息
    var stats = pool.getStats();
    std.debug.print("内存池统计: 总计={}B, 已用={}B, 空闲={}B\n", 
        .{ stats.total, stats.used, stats.free });
    
    // 释放内存
    pool.free(ptr2);
    std.debug.print("释放中间块\n");
    
    stats = pool.getStats();
    std.debug.print("释放后统计: 总计={}B, 已用={}B, 空闲={}B\n", 
        .{ stats.total, stats.used, stats.free });
    
    // 重新分配
    const ptr4 = try pool.alloc(150);
    std.debug.print("重新分配150B\n");
    
    // 清理
    pool.free(ptr1);
    pool.free(ptr3);
    pool.free(ptr4);
    
    std.debug.print("内存池测试完成 ✅\n");
}

fn testHashFunction() !void {
    std.debug.print("\n🔢 测试哈希函数...\n");
    
    const test_strings = [_][]const u8{
        "Hello World",
        "MIRA - My Intelligent Romantic Assistant",
        "Zig is fast!",
        "内存管理",
        "",
        "A",
        "非常长的字符串用来测试哈希函数的性能和准确性",
    };
    
    var hash_map = std.HashMap(u64, bool, std.hash_map.default_hash, std.hash_map.default_eql, 80).init(std.testing.allocator);
    defer hash_map.deinit();
    
    for (test_strings) |str| {
        const hash = mira.FastHash.hash(str);
        std.debug.print("'{s}' -> 0x{X}\n", .{ str, hash });
        
        // 检查哈希冲突
        if (hash_map.contains(hash)) {
            std.debug.print("警告: 发现哈希冲突!\n");
        } else {
            try hash_map.put(hash, true);
        }
        
        // 验证一致性
        const hash2 = mira.FastHash.hash(str);
        if (hash != hash2) {
            std.debug.print("错误: 哈希不一致!\n");
            return error.HashInconsistent;
        }
    }
    
    std.debug.print("哈希函数测试完成 ✅\n");
}

fn testVectorOperations() !void {
    std.debug.print("\n📐 测试向量运算...\n");
    
    // 测试点积
    const vec1 = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const vec2 = [_]f32{ 2.0, 3.0, 4.0, 5.0, 6.0 };
    
    const dot_product = mira.VectorOps.dotProduct(&vec1, &vec2);
    const expected_dot = 1.0*2.0 + 2.0*3.0 + 3.0*4.0 + 4.0*5.0 + 5.0*6.0;
    
    std.debug.print("点积: {} (期望: {})\n", .{ dot_product, expected_dot });
    
    if (@abs(dot_product - expected_dot) > 0.001) {
        return error.DotProductMismatch;
    }
    
    // 测试余弦相似度
    const vec3 = [_]f32{ 1.0, 0.0, 0.0 };
    const vec4 = [_]f32{ 0.0, 1.0, 0.0 };
    const vec5 = [_]f32{ 1.0, 0.0, 0.0 };
    
    const sim1 = mira.VectorOps.cosineSimilarity(&vec3, &vec4); // 应该是0
    const sim2 = mira.VectorOps.cosineSimilarity(&vec3, &vec5); // 应该是1
    
    std.debug.print("余弦相似度: vec3⟷vec4={:.3}, vec3⟷vec5={:.3}\n", .{ sim1, sim2 });
    
    if (@abs(sim1 - 0.0) > 0.001 or @abs(sim2 - 1.0) > 0.001) {
        return error.CosineSimilarityMismatch;
    }
    
    // 测试归一化
    var vec6 = [_]f32{ 3.0, 4.0, 0.0 };
    mira.VectorOps.normalize(&vec6);
    
    const norm = @sqrt(vec6[0]*vec6[0] + vec6[1]*vec6[1] + vec6[2]*vec6[2]);
    std.debug.print("归一化后模长: {:.3} (期望: 1.0)\n", .{norm});
    
    if (@abs(norm - 1.0) > 0.001) {
        return error.NormalizationFailed;
    }
    
    std.debug.print("向量运算测试完成 ✅\n");
}

fn testSystemMonitoring() !void {
    std.debug.print("\n📊 测试系统监控...\n");
    
    const memory_usage = mira.SystemMonitor.getMemoryUsage();
    const cpu_usage = mira.SystemMonitor.getCpuUsage();
    
    std.debug.print("当前内存使用: {}KB\n", .{memory_usage});
    std.debug.print("当前CPU使用: {:.1}%\n", .{cpu_usage * 100});
    
    // 做一些计算密集的操作来测试CPU监控
    var sum: f64 = 0.0;
    var i: usize = 0;
    while (i < 1000000) : (i += 1) {
        sum += @sqrt(@as(f64, @floatFromInt(i)));
    }
    
    // 再次检查CPU使用率
    const cpu_usage_after = mira.SystemMonitor.getCpuUsage();
    std.debug.print("计算后CPU使用: {:.1}% (计算结果: {:.2})\n", 
        .{ cpu_usage_after * 100, sum });
    
    std.debug.print("系统监控测试完成 ✅\n");
}
