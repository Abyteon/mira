//! MIRA系统层集成测试 - Zig 0.15.1兼容版本
//! 使用官方推荐的测试组织方式

const std = @import("std");
const testing = std.testing;
const mira = @import("zig_system");

// 测试常量
const TEST_POOL_SIZE = 8192;
const FLOAT_TOLERANCE = 0.001;
const TEST_ITERATIONS = 1000;

test "memory pool integration" {
    std.debug.print("🧪 开始内存池集成测试...\n", .{});
    var pool = try mira.memory.MemoryPool.init(testing.allocator, TEST_POOL_SIZE);
    defer pool.deinit();
    
    // 测试基本分配和释放
    const ptr1 = try pool.alloc(100);
    const ptr2 = try pool.alloc(200);
    const ptr3 = try pool.alloc(300);
    
    try testing.expect(ptr1 != @as(?*anyopaque, null));
    try testing.expect(ptr2 != @as(?*anyopaque, null));
    try testing.expect(ptr3 != @as(?*anyopaque, null));
    
    const stats_before = pool.get_stats();
    try testing.expect(stats_before.used >= 600);
    
    pool.free(ptr1);
    pool.free(ptr2);
    pool.free(ptr3);
    
    // 验证内存统计合理性
    const stats_after = pool.get_stats();
    try testing.expect(stats_after.used <= stats_after.total);
    try testing.expect(stats_after.free <= stats_after.total);
    
    std.debug.print("✅ 内存池集成测试通过\n", .{});
}

test "vector operations integration" {
    std.debug.print("🧪 开始向量运算集成测试...\n", .{});
    // 测试点积
    const vec1 = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const vec2 = [_]f32{ 2.0, 3.0, 4.0, 5.0, 6.0 };
    
    const dot_result = mira.vector.VectorOps.dot_product(&vec1, &vec2);
    const expected_dot: f32 = 70.0; // 1*2 + 2*3 + 3*4 + 4*5 + 5*6
    
    try testing.expectApproxEqRel(dot_result, expected_dot, FLOAT_TOLERANCE);
    
    // 测试余弦相似度
    const unit_x = [_]f32{ 1.0, 0.0, 0.0 };
    const unit_y = [_]f32{ 0.0, 1.0, 0.0 };
    const unit_x_copy = [_]f32{ 1.0, 0.0, 0.0 };
    
    const sim_orthogonal = mira.vector.VectorOps.cosine_similarity(&unit_x, &unit_y);
    const sim_identical = mira.vector.VectorOps.cosine_similarity(&unit_x, &unit_x_copy);
    
    try testing.expectApproxEqRel(sim_orthogonal, 0.0, FLOAT_TOLERANCE);
    try testing.expectApproxEqRel(sim_identical, 1.0, FLOAT_TOLERANCE);
    
    // 测试归一化
    var test_vec = [_]f32{ 3.0, 4.0, 0.0 };
    mira.vector.VectorOps.normalize(&test_vec);
    
    const length = @sqrt(test_vec[0]*test_vec[0] + test_vec[1]*test_vec[1] + test_vec[2]*test_vec[2]);
    try testing.expectApproxEqRel(length, 1.0, FLOAT_TOLERANCE);
    
    std.debug.print("✅ 向量运算集成测试通过\n", .{});
}

test "hash function integration" {
    std.debug.print("🧪 开始哈希函数集成测试...\n", .{});
    const test_strings = [_][]const u8{
        "Hello World",
        "MIRA - My Intelligent Romantic Assistant", 
        "Zig is fast and safe!",
        "内存管理与向量计算",
        "",
        "A",
        "🚀⚡💕",
    };
    
    for (test_strings) |str| {
        const hash1 = mira.vector.Hash.hash(str);
        const hash2 = mira.vector.Hash.hash(str);
        
        // 测试一致性
        try testing.expect(hash1 == hash2);
        
        // 测试非空字符串产生非零哈希（除了空字符串）
        if (str.len > 0) {
            try testing.expect(hash1 != 0);
        }
    }
    
    std.debug.print("✅ 哈希函数集成测试通过\n", .{});
}

test "system monitoring integration" {
    std.debug.print("🧪 开始系统监控集成测试...\n", .{});
    const initial_memory = mira.monitor.SystemMonitor.get_memory_usage();
    const initial_cpu = mira.monitor.SystemMonitor.get_cpu_usage();
    
    // 基本的检查 - 这些值可能为0在某些系统上
    try testing.expect(initial_memory >= 0);
    try testing.expect(initial_cpu >= 0.0);
    try testing.expect(initial_cpu <= 100.0);
    
    // 执行一些计算来测试监控
    var sum: f64 = 0.0;
    for (0..TEST_ITERATIONS) |i| {
        sum += @sqrt(@as(f64, @floatFromInt(i + 1)));
    }
    
    // 验证计算结果不为零
    try testing.expect(sum > 0.0);
    
    std.debug.print("✅ 系统监控集成测试通过\n", .{});
    
    const final_memory = mira.monitor.SystemMonitor.get_memory_usage();
    const final_cpu = mira.monitor.SystemMonitor.get_cpu_usage();
    
    // 验证监控值仍在合理范围内
    try testing.expect(final_memory >= 0);
    try testing.expect(final_cpu >= 0.0);
    try testing.expect(final_cpu <= 100.0);
}

test "comprehensive integration test" {
    // 测试多个模块协同工作
    var pool = try mira.memory.MemoryPool.init(testing.allocator, TEST_POOL_SIZE);
    defer pool.deinit();
    
    // 分配内存存储向量
    const vector_size = 1000;
    const vec_ptr = try pool.alloc(vector_size * @sizeOf(f32));
    defer pool.free(vec_ptr);
    
    const vector_data: [*]f32 = @ptrCast(@alignCast(vec_ptr));
    
    // 初始化向量数据
    for (0..vector_size) |i| {
        vector_data[i] = @as(f32, @floatFromInt(i)) * 0.1;
    }
    
    // 测试向量运算
    const vector_slice = vector_data[0..vector_size];
    const normalized_vector = try testing.allocator.dupe(f32, vector_slice);
    defer testing.allocator.free(normalized_vector);
    
    mira.vector.VectorOps.normalize(normalized_vector);
    
    // 验证归一化
    var length_squared: f32 = 0.0;
    for (normalized_vector) |val| {
        length_squared += val * val;
    }
    const length = @sqrt(length_squared);
    try testing.expectApproxEqRel(length, 1.0, FLOAT_TOLERANCE);
    
    // 测试内存统计
    const stats = pool.get_stats();
    try testing.expect(stats.used >= vector_size * @sizeOf(f32));
    try testing.expect(stats.free <= stats.total - stats.used);
    
    // 测试哈希
    const test_string = "Integration test string";
    const hash_value = mira.vector.Hash.hash(test_string);
    try testing.expect(hash_value != 0);
}
