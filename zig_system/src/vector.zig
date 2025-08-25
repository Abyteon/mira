//! 向量运算优化模块 - Zig 0.15.1
//! 使用SIMD指令和最新的向量化技术

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

/// 向量运算优化 - 适配Zig 0.15.1
pub const VectorOps = struct {
    /// 向量点积 - 使用SIMD优化
    pub fn dotProduct(a: []const f32, b: []const f32) f32 {
        if (a.len != b.len) return 0.0;
        if (a.len == 0) return 0.0;
        
        var result: f32 = 0.0;
        
        // 尝试使用SIMD优化 - Zig 0.15.1改进的向量支持
        if (comptime std.simd.suggestVectorLength(f32)) |vector_len| {
            if (a.len >= vector_len) {
                return dotProductSIMD(a, b, vector_len);
            }
        }
        
        // 标量实现，手动展开循环
        const unroll_factor = 4;
        var i: usize = 0;
        
        // 展开的主循环
        while (i + unroll_factor <= a.len) : (i += unroll_factor) {
            result += a[i] * b[i];
            result += a[i + 1] * b[i + 1];
            result += a[i + 2] * b[i + 2];
            result += a[i + 3] * b[i + 3];
        }
        
        // 处理剩余元素
        while (i < a.len) : (i += 1) {
            result += a[i] * b[i];
        }
        
        return result;
    }
    
    /// SIMD优化的点积实现
    fn dotProductSIMD(a: []const f32, b: []const f32, comptime vector_len: u32) f32 {
        const VectorType = @Vector(vector_len, f32);
        var result_vec: VectorType = @splat(0.0);
        
        var i: usize = 0;
        const vectorized_len = (a.len / vector_len) * vector_len;
        
        // SIMD主循环
        while (i < vectorized_len) : (i += vector_len) {
            const vec_a: VectorType = a[i..i + vector_len][0..vector_len].*;
            const vec_b: VectorType = b[i..i + vector_len][0..vector_len].*;
            result_vec += vec_a * vec_b;
        }
        
        // 归约向量结果
        var scalar_result: f32 = @reduce(.Add, result_vec);
        
        // 处理剩余元素
        while (i < a.len) : (i += 1) {
            scalar_result += a[i] * b[i];
        }
        
        return scalar_result;
    }
    
    /// 余弦相似度 - 优化版本
    pub fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
        if (a.len != b.len or a.len == 0) return 0.0;
        
        var dot: f32 = 0.0;
        var norm_a: f32 = 0.0;
        var norm_b: f32 = 0.0;
        
        // 尝试使用SIMD
        if (comptime std.simd.suggestVectorLength(f32)) |vector_len| {
            if (a.len >= vector_len) {
                return cosineSimilaritySIMD(a, b, vector_len);
            }
        }
        
        // 标量实现
        for (a, b) |ai, bi| {
            dot += ai * bi;
            norm_a += ai * ai;
            norm_b += bi * bi;
        }
        
        const magnitude = @sqrt(norm_a * norm_b);
        return if (magnitude > 0.0) dot / magnitude else 0.0;
    }
    
    /// SIMD优化的余弦相似度
    fn cosineSimilaritySIMD(a: []const f32, b: []const f32, comptime vector_len: u32) f32 {
        const VectorType = @Vector(vector_len, f32);
        var dot_vec: VectorType = @splat(0.0);
        var norm_a_vec: VectorType = @splat(0.0);
        var norm_b_vec: VectorType = @splat(0.0);
        
        var i: usize = 0;
        const vectorized_len = (a.len / vector_len) * vector_len;
        
        // SIMD主循环
        while (i < vectorized_len) : (i += vector_len) {
            const vec_a: VectorType = a[i..i + vector_len][0..vector_len].*;
            const vec_b: VectorType = b[i..i + vector_len][0..vector_len].*;
            
            dot_vec += vec_a * vec_b;
            norm_a_vec += vec_a * vec_a;
            norm_b_vec += vec_b * vec_b;
        }
        
        // 归约结果
        var dot: f32 = @reduce(.Add, dot_vec);
        var norm_a: f32 = @reduce(.Add, norm_a_vec);
        var norm_b: f32 = @reduce(.Add, norm_b_vec);
        
        // 处理剩余元素
        while (i < a.len) : (i += 1) {
            dot += a[i] * b[i];
            norm_a += a[i] * a[i];
            norm_b += b[i] * b[i];
        }
        
        const magnitude = @sqrt(norm_a * norm_b);
        return if (magnitude > 0.0) dot / magnitude else 0.0;
    }
    
    /// 向量归一化 - 就地操作
    pub fn normalize(vector: []f32) void {
        if (vector.len == 0) return;
        
        // 计算模长
        var norm: f32 = 0.0;
        for (vector) |v| {
            norm += v * v;
        }
        
        norm = @sqrt(norm);
        if (norm > std.math.floatEps(f32)) {
            const inv_norm = 1.0 / norm;
            for (vector) |*v| {
                v.* *= inv_norm;
            }
        }
    }
    
    /// 向量加法 - SIMD优化
    pub fn vectorAdd(result: []f32, a: []const f32, b: []const f32) void {
        std.debug.assert(result.len == a.len and a.len == b.len);
        
        if (comptime std.simd.suggestVectorLength(f32)) |vector_len| {
            if (a.len >= vector_len) {
                return vectorAddSIMD(result, a, b, vector_len);
            }
        }
        
        // 标量实现
        for (result, a, b) |*r, ai, bi| {
            r.* = ai + bi;
        }
    }
    
    /// SIMD优化的向量加法
    fn vectorAddSIMD(result: []f32, a: []const f32, b: []const f32, comptime vector_len: u32) void {
        const VectorType = @Vector(vector_len, f32);
        
        var i: usize = 0;
        const vectorized_len = (a.len / vector_len) * vector_len;
        
        // SIMD主循环
        while (i < vectorized_len) : (i += vector_len) {
            const vec_a: VectorType = a[i..i + vector_len][0..vector_len].*;
            const vec_b: VectorType = b[i..i + vector_len][0..vector_len].*;
            const vec_result = vec_a + vec_b;
            
            @memcpy(result[i..i + vector_len], &vec_result);
        }
        
        // 处理剩余元素
        while (i < a.len) : (i += 1) {
            result[i] = a[i] + b[i];
        }
    }
    
    /// 向量标量乘法
    pub fn vectorScale(result: []f32, vector: []const f32, scalar: f32) void {
        std.debug.assert(result.len == vector.len);
        
        if (comptime std.simd.suggestVectorLength(f32)) |vector_len| {
            if (vector.len >= vector_len) {
                return vectorScaleSIMD(result, vector, scalar, vector_len);
            }
        }
        
        // 标量实现
        for (result, vector) |*r, v| {
            r.* = v * scalar;
        }
    }
    
    /// SIMD优化的向量标量乘法
    fn vectorScaleSIMD(result: []f32, vector: []const f32, scalar: f32, comptime vector_len: u32) void {
        const VectorType = @Vector(vector_len, f32);
        const scalar_vec: VectorType = @splat(scalar);
        
        var i: usize = 0;
        const vectorized_len = (vector.len / vector_len) * vector_len;
        
        // SIMD主循环
        while (i < vectorized_len) : (i += vector_len) {
            const vec: VectorType = vector[i..i + vector_len][0..vector_len].*;
            const vec_result = vec * scalar_vec;
            
            @memcpy(result[i..i + vector_len], &vec_result);
        }
        
        // 处理剩余元素
        while (i < vector.len) : (i += 1) {
            result[i] = vector[i] * scalar;
        }
    }
    
    /// 欧几里得距离
    pub fn euclideanDistance(a: []const f32, b: []const f32) f32 {
        if (a.len != b.len) return std.math.inf(f32);
        
        var sum: f32 = 0.0;
        for (a, b) |ai, bi| {
            const diff = ai - bi;
            sum += diff * diff;
        }
        
        return @sqrt(sum);
    }
    
    /// 曼哈顿距离
    pub fn manhattanDistance(a: []const f32, b: []const f32) f32 {
        if (a.len != b.len) return std.math.inf(f32);
        
        var sum: f32 = 0.0;
        for (a, b) |ai, bi| {
            sum += @abs(ai - bi);
        }
        
        return sum;
    }
};

/// 快速哈希算法 - Zig 0.15.1优化版本
pub const FastHash = struct {
    /// 使用XXHash64算法的优化实现
    pub fn hash(data: []const u8) u64 {
        if (data.len == 0) return 0;
        
        // XXHash64常量
        const PRIME1: u64 = 0x9E3779B185EBCA87;
        const PRIME2: u64 = 0xC2B2AE3D27D4EB4F;
        const PRIME5: u64 = 0x27D4EB2F165667C5;
        
        var h64: u64 = undefined;
        
        if (data.len >= 32) {
            h64 = hashLarge(data, PRIME1, PRIME2);
        } else {
            h64 = PRIME5 +% data.len;
        }
        
        // 处理剩余数据
        h64 = finalize(h64, data[data.len & ~@as(usize, 31)..]);
        
        return h64;
    }
    
    /// 处理大数据块
    fn hashLarge(data: []const u8, prime1: u64, prime2: u64) u64 {
        var v1 = prime1 +% prime2;
        var v2 = prime2;
        var v3: u64 = 0;
        var v4 = 0 -% prime1;
        
        var i: usize = 0;
        while (i + 32 <= data.len) : (i += 32) {
            const slice1: *const [8]u8 = data[i..i+8][0..8];
            const slice2: *const [8]u8 = data[i+8..i+16][0..8];
            const slice3: *const [8]u8 = data[i+16..i+24][0..8];
            const slice4: *const [8]u8 = data[i+24..i+32][0..8];
            v1 = round(v1, std.mem.readInt(u64, slice1, .little));
            v2 = round(v2, std.mem.readInt(u64, slice2, .little));
            v3 = round(v3, std.mem.readInt(u64, slice3, .little));
            v4 = round(v4, std.mem.readInt(u64, slice4, .little));
        }
        
        return std.math.rotl(u64, v1, 1) +%
               std.math.rotl(u64, v2, 7) +%
               std.math.rotl(u64, v3, 12) +%
               std.math.rotl(u64, v4, 18);
    }
    
    /// 哈希轮次
    fn round(acc: u64, input: u64) u64 {
        const PRIME2: u64 = 0xC2B2AE3D27D4EB4F;
        const PRIME1: u64 = 0x9E3779B185EBCA87;
        
        return std.math.rotl(u64, acc +% (input *% PRIME2), 31) *% PRIME1;
    }
    
    /// 最终化处理
    fn finalize(h64: u64, remaining: []const u8) u64 {
        const PRIME5: u64 = 0x27D4EB2F165667C5;
        
        var h = h64;
        var i: usize = 0;
        
        // 处理8字节块
        while (i + 8 <= remaining.len) : (i += 8) {
            const data_slice: *const [8]u8 = remaining[i..i+8][0..8];
            const k1 = round(0, std.mem.readInt(u64, data_slice, .little));
            h ^= k1;
            const LOCAL_PRIME1: u64 = 0x9E3779B185EBCA87;
            const LOCAL_PRIME4: u64 = 0x85EBCA77C2B2AE63;
            h = std.math.rotl(u64, h, 27) *% LOCAL_PRIME1 +% LOCAL_PRIME4;
        }
        
        // 处理4字节块
        while (i + 4 <= remaining.len) : (i += 4) {
            const data_slice: *const [4]u8 = remaining[i..i+4][0..4];
            const PRIME1: u64 = 0x9E3779B185EBCA87;
            h ^= (@as(u64, std.mem.readInt(u32, data_slice, .little)) *% PRIME1);
            const PRIME2: u64 = 0xC2B2AE3D27D4EB4F;
            const LOCAL_PRIME3: u64 = 0x165667B19E3779F9;
            h = std.math.rotl(u64, h, 23) *% PRIME2 +% LOCAL_PRIME3;
        }
        
        // 处理剩余字节
        while (i < remaining.len) : (i += 1) {
            h ^= @as(u64, remaining[i]) *% PRIME5;
            const PRIME1: u64 = 0x9E3779B185EBCA87;
            h = std.math.rotl(u64, h, 11) *% PRIME1;
        }
        
        // 最终混合
        const PRIME2: u64 = 0xC2B2AE3D27D4EB4F;
        const PRIME3: u64 = 0x165667B19E3779F9;
        h ^= h >> 33;
        h *%= PRIME2;
        h ^= h >> 29;
        h *%= PRIME3;
        h ^= h >> 32;
        
        return h;
    }
};

// 测试
test "vector dot product" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const b = [_]f32{ 2.0, 3.0, 4.0, 5.0 };
    
    const result = VectorOps.dotProduct(&a, &b);
    const expected: f32 = 1.0*2.0 + 2.0*3.0 + 3.0*4.0 + 4.0*5.0;
    
    try testing.expectApproxEqAbs(result, expected, 0.001);
}

test "cosine similarity" {
    const a = [_]f32{ 1.0, 0.0, 0.0 };
    const b = [_]f32{ 0.0, 1.0, 0.0 };
    const c = [_]f32{ 1.0, 0.0, 0.0 };
    
    const sim1 = VectorOps.cosineSimilarity(&a, &b); // 应该是0
    const sim2 = VectorOps.cosineSimilarity(&a, &c); // 应该是1
    
    try testing.expectApproxEqAbs(sim1, 0.0, 0.001);
    try testing.expectApproxEqAbs(sim2, 1.0, 0.001);
}

test "vector normalization" {
    var vec = [_]f32{ 3.0, 4.0, 0.0 };
    VectorOps.normalize(&vec);
    
    const norm = @sqrt(vec[0]*vec[0] + vec[1]*vec[1] + vec[2]*vec[2]);
    try testing.expectApproxEqAbs(norm, 1.0, 0.001);
}

test "fast hash consistency" {
    const test_data = "Hello, Zig 0.15.1!";
    const hash1 = FastHash.hash(test_data);
    const hash2 = FastHash.hash(test_data);
    
    try testing.expect(hash1 == hash2);
    
    const different_data = "Different data";
    const hash3 = FastHash.hash(different_data);
    try testing.expect(hash1 != hash3);
}
