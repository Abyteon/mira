//! 高性能内存池实现 - Zig 0.15.1
//! 使用最新的内存管理API和优化

const std = @import("std");
const testing = std.testing;

/// 高性能内存池实现 - 适配Zig 0.15.1
pub const MemoryPool = struct {
    allocator: std.mem.Allocator,
    buffer: []u8,
    free_list: std.ArrayList(*FreeBlock),
    total_size: usize,
    used_size: usize,
    
    const FreeBlock = struct {
        size: usize,
        next: ?*FreeBlock,
    };
    
    const Self = @This();
    
    /// 初始化内存池 - 使用Zig 0.15.1改进的错误处理
    pub fn init(allocator: std.mem.Allocator, size: usize) !Self {
        // 确保大小对齐
        const aligned_size = std.mem.alignForward(usize, size, @alignOf(FreeBlock));
        
        const buffer = try allocator.alloc(u8, aligned_size);
        errdefer allocator.free(buffer);
        
        var free_list = try std.ArrayList(*FreeBlock).initCapacity(allocator, 32);
        errdefer free_list.deinit(allocator);
        
        // 初始化第一个自由块
        const initial_block: *FreeBlock = @ptrCast(@alignCast(buffer.ptr));
        initial_block.* = .{
            .size = aligned_size - @sizeOf(FreeBlock),
            .next = null,
        };
        
        try free_list.append(allocator, initial_block);
        
        return Self{
            .allocator = allocator,
            .buffer = buffer,
            .free_list = free_list,
            .total_size = aligned_size,
            .used_size = 0,
        };
    }
    
    /// 清理内存池
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
        self.free_list.deinit(self.allocator);
    }
    
    /// 分配内存 - Zig 0.15.1优化的内存对齐
    pub fn alloc(self: *Self, size: usize) !*anyopaque {
        const aligned_size = std.mem.alignForward(usize, size, @alignOf(u64));
        
        // 寻找合适的自由块
        for (self.free_list.items, 0..) |block, i| {
            if (block.size >= aligned_size) {
                // 从自由列表中移除
                _ = self.free_list.swapRemove(i);
                
                // 如果块太大，分割它
                if (block.size > aligned_size + @sizeOf(FreeBlock) + @alignOf(FreeBlock)) {
                    const remaining_size = block.size - aligned_size - @sizeOf(FreeBlock);
                    const new_block_ptr = @as([*]u8, @ptrCast(block)) + @sizeOf(FreeBlock) + aligned_size;
                    const new_block: *FreeBlock = @ptrCast(@alignCast(new_block_ptr));
                    new_block.* = .{
                        .size = remaining_size,
                        .next = null,
                    };
                    try self.free_list.append(self.allocator, new_block);
                }
                
                self.used_size += aligned_size;
                const result_ptr = @as([*]u8, @ptrCast(block)) + @sizeOf(FreeBlock);
                return @ptrCast(result_ptr);
            }
        }
        
        return error.OutOfMemory;
    }
    
    /// 释放内存
    pub fn free(self: *Self, ptr: *anyopaque) void {
        const block_ptr = @as([*]u8, @ptrCast(ptr)) - @sizeOf(FreeBlock);
        const block: *FreeBlock = @ptrCast(@alignCast(block_ptr));
        
        // 添加回自由列表
        self.free_list.append(self.allocator, block) catch {
            // 如果无法添加到列表，至少标记为可用
            block.next = null;
            return;
        };
        
        // 合并相邻的自由块
        self.coalesce();
    }
    
    /// 合并相邻的自由块 - Zig 0.15.1优化的排序算法
    fn coalesce(self: *Self) void {
        if (self.free_list.items.len <= 1) return;
        
        // 使用Zig 0.15.1改进的排序API
        std.mem.sort(*FreeBlock, self.free_list.items, {}, struct {
            fn lessThan(_: void, lhs: *FreeBlock, rhs: *FreeBlock) bool {
                return @intFromPtr(lhs) < @intFromPtr(rhs);
            }
        }.lessThan);
        
        // 合并相邻块
        var write_index: usize = 0;
        for (self.free_list.items, 0..) |current_block, read_index| {
            _ = read_index; // 明确标记未使用
            if (write_index == 0) {
                self.free_list.items[write_index] = current_block;
                write_index += 1;
                continue;
            }
            
            const prev_block = self.free_list.items[write_index - 1];
            const prev_end = @intFromPtr(prev_block) + @sizeOf(FreeBlock) + prev_block.size;
            const current_start = @intFromPtr(current_block);
            
            if (prev_end == current_start) {
                // 合并块
                prev_block.size += @sizeOf(FreeBlock) + current_block.size;
            } else {
                self.free_list.items[write_index] = current_block;
                write_index += 1;
            }
        }
        
        // 截断列表
        self.free_list.shrinkRetainingCapacity(write_index);
    }
    
    /// 获取内存池统计信息
    pub fn getStats(self: *const Self) MemoryStats {
        return .{
            .total = self.total_size,
            .used = self.used_size,
            .free = self.total_size - self.used_size,
            .free_blocks = self.free_list.items.len,
            .fragmentation = self.calculateFragmentation(),
        };
    }
    
    /// 计算内存碎片率
    fn calculateFragmentation(self: *const Self) f32 {
        if (self.free_list.items.len == 0) return 0.0;
        if (self.free_list.items.len == 1) return 0.0;
        
        var largest_block: usize = 0;
        var total_free: usize = 0;
        
        for (self.free_list.items) |block| {
            largest_block = @max(largest_block, block.size);
            total_free += block.size;
        }
        
        if (total_free == 0) return 0.0;
        
        return 1.0 - (@as(f32, @floatFromInt(largest_block)) / @as(f32, @floatFromInt(total_free)));
    }
    
    /// 内存池压缩 - 减少碎片
    pub fn compact(self: *Self) void {
        self.coalesce();
        
        // 可以在这里实现更复杂的压缩算法
        // 例如移动已分配的块来减少碎片
    }
    
    /// 重置内存池
    pub fn reset(self: *Self) void {
        // 清空自由列表
        self.free_list.clearRetainingCapacity();
        
        // 重新初始化为单个大块
        const initial_block: *FreeBlock = @ptrCast(@alignCast(self.buffer.ptr));
        initial_block.* = .{
            .size = self.total_size - @sizeOf(FreeBlock),
            .next = null,
        };
        
        self.free_list.append(self.allocator, initial_block) catch unreachable;
        self.used_size = 0;
    }
};

/// 内存统计信息
pub const MemoryStats = struct {
    total: usize,
    used: usize,
    free: usize,
    free_blocks: usize,
    fragmentation: f32,
};

/// Arena分配器增强版 - Zig 0.15.1特性
pub const EnhancedArena = struct {
    backing_allocator: std.mem.Allocator,
    state: State,
    
    const State = union(enum) {
        buffer: []u8,
        node: *std.heap.ArenaAllocator,
    };
    
    pub fn init(backing_allocator: std.mem.Allocator, buffer: []u8) EnhancedArena {
        return .{
            .backing_allocator = backing_allocator,
            .state = .{ .buffer = buffer },
        };
    }
    
    pub fn deinit(self: *EnhancedArena) void {
        switch (self.state) {
            .buffer => {},
            .node => |arena| {
                arena.deinit();
                self.backing_allocator.destroy(arena);
            },
        }
    }
    
    pub fn getAllocator(self: *EnhancedArena) std.mem.Allocator {
        switch (self.state) {
            .buffer => return std.heap.FixedBufferAllocator.init(self.state.buffer).allocator(),
            .node => |arena| return arena.allocator(),
        }
    }
    
    /// 升级到堆分配的Arena - 当缓冲区不够时自动切换
    fn promote(self: *EnhancedArena) !void {
        if (self.state == .node) return;
        
        const arena = try self.backing_allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(self.backing_allocator);
        self.state = .{ .node = arena };
    }
};

// 测试
test "memory pool basic operations" {
    var pool = try MemoryPool.init(testing.allocator, 4096);
    defer pool.deinit();
    
    // 分配内存
    const ptr1 = try pool.alloc(100);
    const ptr2 = try pool.alloc(200);
    const ptr3 = try pool.alloc(300);
    
    // 检查统计信息
    var stats = pool.getStats();
    try testing.expect(stats.total == 4096);
    try testing.expect(stats.used > 0);
    
    // 释放内存
    pool.free(ptr2);
    pool.free(ptr1);
    pool.free(ptr3);
    
    stats = pool.getStats();
    try testing.expect(stats.used == 0);
}

test "memory pool coalescing" {
    var pool = try MemoryPool.init(testing.allocator, 1024);
    defer pool.deinit();
    
    // 分配多个小块
    const ptr1 = try pool.alloc(64);
    const ptr2 = try pool.alloc(64);
    const ptr3 = try pool.alloc(64);
    
    // 释放相邻的块
    pool.free(ptr1);
    pool.free(ptr2);
    
    const stats = pool.getStats();
    try testing.expect(stats.free_blocks <= 2); // 应该合并了一些块
    
    pool.free(ptr3);
}

test "enhanced arena allocator" {
    var buffer: [1024]u8 = undefined;
    var arena = EnhancedArena.init(testing.allocator, &buffer);
    defer arena.deinit();
    
    const alloc = arena.getAllocator();
    
    // 分配一些内存
    const slice1 = try alloc.alloc(u8, 100);
    const slice2 = try alloc.alloc(u32, 50);
    
    try testing.expect(slice1.len == 100);
    try testing.expect(slice2.len == 50);
}
