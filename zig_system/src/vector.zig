//! 向量运算优化模块 - Zig 0.15.1
//! 使用SIMD指令和现代化命名约定

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

/// 向量运算操作
pub const VectorOps = struct {
    /// 向量点积 - 使用SIMD优化
    pub fn dot_product(a: []const f32, b: []const f32) f32 {
        if (a.len != b.len) return 0.0;
        if (a.len == 0) return 0.0;
        
        var result: f32 = 0.0;
        
        // 尝试使用SIMD优化
        if (comptime std.simd.suggestVectorLength(f32)) |vector_len| {
            if (a.len >= vector_len) {
                return dot_product_simd(a, b, vector_len);
            }
        }
        
        // 标量实现，手动展开循环
        const unroll_factor = 4;
        var i: usize = 0;
        
        while (i + unroll_factor <= a.len) : (i += unroll_factor) {
            result += a[i] * b[i];
            result += a[i + 1] * b[i + 1];
            result += a[i + 2] * b[i + 2];
            result += a[i + 3] * b[i + 3];
        }
        
        while (i < a.len) : (i += 1) {
            result += a[i] * b[i];
        }
        
        return result;
    }
    
    /// SIMD优化的点积实现
    fn dot_product_simd(a: []const f32, b: []const f32, comptime vector_len: u32) f32 {
        const VectorType = @Vector(vector_len, f32);
        var result_vec: VectorType = @splat(0.0);
        
        var i: usize = 0;
        while (i + vector_len <= a.len) : (i += vector_len) {
            const a_vec: VectorType = a[i..i+vector_len][0..vector_len].*;
            const b_vec: VectorType = b[i..i+vector_len][0..vector_len].*;
            result_vec += a_vec * b_vec;
        }
        
        var scalar_result: f32 = @reduce(.Add, result_vec);
        
        while (i < a.len) : (i += 1) {
            scalar_result += a[i] * b[i];
        }
        
        return scalar_result;
    }
    
    /// 计算两个向量的余弦相似度
    pub fn cosine_similarity(a: []const f32, b: []const f32) f32 {
        if (a.len != b.len or a.len == 0) return 0.0;
        
        const dot_prod = dot_product(a, b);
        const norm_a = vector_norm(a);
        const norm_b = vector_norm(b);
        
        if (norm_a == 0.0 or norm_b == 0.0) return 0.0;
        
        return dot_prod / (norm_a * norm_b);
    }
    
    /// 计算向量的L2范数
    pub fn vector_norm(vec: []const f32) f32 {
        var sum_squares: f32 = 0.0;
        
        if (comptime std.simd.suggestVectorLength(f32)) |vector_len| {
            if (vec.len >= vector_len) {
                return vector_norm_simd(vec, vector_len);
            }
        }
        
        for (vec) |val| {
            sum_squares += val * val;
        }
        
        return @sqrt(sum_squares);
    }
    
    /// SIMD优化的向量范数计算
    fn vector_norm_simd(vec: []const f32, comptime vector_len: u32) f32 {
        const VectorType = @Vector(vector_len, f32);
        var sum_vec: VectorType = @splat(0.0);
        
        var i: usize = 0;
        while (i + vector_len <= vec.len) : (i += vector_len) {
            const v: VectorType = vec[i..i+vector_len][0..vector_len].*;
            sum_vec += v * v;
        }
        
        var sum_squares: f32 = @reduce(.Add, sum_vec);
        
        while (i < vec.len) : (i += 1) {
            const val = vec[i];
            sum_squares += val * val;
        }
        
        return @sqrt(sum_squares);
    }
    
    /// 向量归一化（就地修改）
    pub fn normalize(vec: []f32) void {
        const norm = vector_norm(vec);
        if (norm == 0.0) return;
        
        if (comptime std.simd.suggestVectorLength(f32)) |vector_len| {
            if (vec.len >= vector_len) {
                normalize_simd(vec, norm, vector_len);
                return;
            }
        }
        
        const inv_norm = 1.0 / norm;
        for (vec) |*val| {
            val.* *= inv_norm;
        }
    }
    
    /// SIMD优化的向量归一化
    fn normalize_simd(vec: []f32, norm: f32, comptime vector_len: u32) void {
        const VectorType = @Vector(vector_len, f32);
        const inv_norm_vec: VectorType = @splat(1.0 / norm);
        
        var i: usize = 0;
        while (i + vector_len <= vec.len) : (i += vector_len) {
            var v: VectorType = vec[i..i+vector_len][0..vector_len].*;
            v *= inv_norm_vec;
            const result_array: [vector_len]f32 = v;
            @memcpy(vec[i..i+vector_len], &result_array);
        }
        
        const inv_norm = 1.0 / norm;
        while (i < vec.len) : (i += 1) {
            vec[i] *= inv_norm;
        }
    }
    
    /// 计算加权欧几里德距离
    /// 使用Zig 0.15.1多对象for循环特性
    pub fn weighted_distance(a: []const f32, b: []const f32, weights: []const f32) f32 {
        if (a.len != b.len or a.len != weights.len or a.len == 0) return std.math.inf(f32);
        
        var sum: f32 = 0.0;
        // Zig 0.15.1的多对象for循环语法
        for (a, b, weights) |av, bv, w| {
            const diff = av - bv;
            sum += w * diff * diff;
        }
        
        return @sqrt(sum);
    }
    
    /// 欧几里得距离
    /// 使用Zig 0.15.1多对象for循环优化
    pub fn euclidean_distance(a: []const f32, b: []const f32) f32 {
        if (a.len != b.len) return std.math.inf(f32);
        
        var sum: f32 = 0.0;
        // Zig 0.15.1多对象for循环
        for (a, b) |ai, bi| {
            const diff = ai - bi;
            sum += diff * diff;
        }
        
        return @sqrt(sum);
    }
    
    /// 曼哈顿距离
    /// 使用Zig 0.15.1多对象for循环优化
    pub fn manhattan_distance(a: []const f32, b: []const f32) f32 {
        if (a.len != b.len) return std.math.inf(f32);
        
        var sum: f32 = 0.0;
        // Zig 0.15.1多对象for循环
        for (a, b) |ai, bi| {
            sum += @abs(ai - bi);
        }
        
        return sum;
    }
    
    /// 向量元素的最小值和最大值 - 使用Zig 0.15.1增强的@min/@max
    pub fn vector_min_max(vec: []const f32) struct { min: f32, max: f32 } {
        if (vec.len == 0) return .{ .min = 0.0, .max = 0.0 };
        
        var min_val = vec[0];
        var max_val = vec[0];
        
        for (vec[1..]) |val| {
            min_val = @min(min_val, val);
            max_val = @max(max_val, val);
        }
        
        return .{ .min = min_val, .max = max_val };
    }
    
    /// 多向量点积 - 使用Zig 0.15.1的多对象for循环
    pub fn multi_dot_product(vectors: [][]const f32) f32 {
        if (vectors.len == 0) return 0.0;
        if (vectors.len == 1) return dot_product(vectors[0], vectors[0]);
        
        var result: f32 = 0.0;
        const len = vectors[0].len;
        
        // 验证所有向量长度一致
        for (vectors) |vec| {
            if (vec.len != len) return 0.0;
        }
        
        for (0..len) |i| {
            var product: f32 = 1.0;
            for (vectors) |vec| {
                product *= vec[i];
            }
            result += product;
        }
        
        return result;
    }
};

/// 快速哈希算法
pub const Hash = struct {
    /// 计算字符串的快速哈希值
    pub fn hash(input: []const u8) u64 {
        if (input.len == 0) return 0;
        return std.hash_map.hashString(input);
    }
    
    /// 计算字节数组的哈希值
    pub fn hash_bytes(input: []const u8) u64 {
        return hash(input);
    }
    
    /// 计算整数数组的哈希值
    pub fn hash_ints(input: []const u32) u64 {
        const bytes = std.mem.sliceAsBytes(input);
        return hash(bytes);
    }
    
    /// 计算浮点数组的哈希值
    pub fn hash_floats(input: []const f32) u64 {
        const bytes = std.mem.sliceAsBytes(input);
        return hash(bytes);
    }
};

// ============================================================================
// 测试
// ============================================================================

test "vector dot product" {
    const vec1 = [_]f32{ 1.0, 2.0, 3.0 };
    const vec2 = [_]f32{ 4.0, 5.0, 6.0 };
    
    const result = VectorOps.dot_product(&vec1, &vec2);
    const expected: f32 = 1.0*4.0 + 2.0*5.0 + 3.0*6.0; // 32.0
    
    try testing.expectApproxEqRel(result, expected, 0.001);
}

test "cosine similarity" {
    const a = [_]f32{ 1.0, 0.0, 0.0 };
    const b = [_]f32{ 0.0, 1.0, 0.0 };
    const c = [_]f32{ 1.0, 0.0, 0.0 };
    
    const sim1 = VectorOps.cosine_similarity(&a, &b);
    const sim2 = VectorOps.cosine_similarity(&a, &c);
    
    try testing.expectApproxEqAbs(sim1, 0.0, 0.001);
    try testing.expectApproxEqAbs(sim2, 1.0, 0.001);
}

test "vector normalization" {
    var vec = [_]f32{ 3.0, 4.0, 0.0 };
    VectorOps.normalize(&vec);
    
    const norm = @sqrt(vec[0]*vec[0] + vec[1]*vec[1] + vec[2]*vec[2]);
    try testing.expectApproxEqAbs(norm, 1.0, 0.001);
}

test "hash consistency" {
    const test_data = "Hello, Zig 0.15.1!";
    const hash1 = Hash.hash(test_data);
    const hash2 = Hash.hash(test_data);
    
    try testing.expect(hash1 == hash2);
    try testing.expect(hash1 != 0);
    
    const different_data = "Different data";
    const hash3 = Hash.hash(different_data);
    try testing.expect(hash1 != hash3);
}

test "empty vectors" {
    const empty: []const f32 = &[_]f32{};
    const vec = [_]f32{ 1.0, 2.0, 3.0 };
    
    try testing.expect(VectorOps.dot_product(empty, empty) == 0.0);
    try testing.expect(VectorOps.dot_product(&vec, empty) == 0.0);
    try testing.expect(VectorOps.cosine_similarity(empty, empty) == 0.0);
    try testing.expect(VectorOps.vector_norm(empty) == 0.0);
}

test "distance functions" {
    const vec1 = [_]f32{ 1.0, 2.0, 3.0 };
    const vec2 = [_]f32{ 4.0, 5.0, 6.0 };
    const weights = [_]f32{ 1.0, 1.0, 1.0 };
    
    const euclidean = VectorOps.euclidean_distance(&vec1, &vec2);
    const manhattan = VectorOps.manhattan_distance(&vec1, &vec2);
    const weighted = VectorOps.weighted_distance(&vec1, &vec2, &weights);
    
    try testing.expectApproxEqRel(euclidean, @sqrt(27.0), 0.001);
    try testing.expectApproxEqRel(manhattan, 9.0, 0.001);
    try testing.expectApproxEqRel(weighted, @sqrt(27.0), 0.001);
}

test "vector min max - Zig 0.15.1 features" {
    const vec = [_]f32{ 3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0 };
    const result = VectorOps.vector_min_max(&vec);
    
    try testing.expectApproxEqRel(result.min, 1.0, 0.001);
    try testing.expectApproxEqRel(result.max, 9.0, 0.001);
}

test "multi dot product - Zig 0.15.1 features" {
    const vec1 = [_]f32{ 1.0, 2.0, 3.0 };
    const vec2 = [_]f32{ 2.0, 3.0, 4.0 };
    const vec3 = [_]f32{ 1.0, 1.0, 1.0 };
    
    var vectors = [_][]const f32{ &vec1, &vec2, &vec3 };
    const result = VectorOps.multi_dot_product(&vectors);
    
    // 1*2*1 + 2*3*1 + 3*4*1 = 2 + 6 + 12 = 20
    try testing.expectApproxEqRel(result, 20.0, 0.001);
}

