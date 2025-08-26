//! 系统监控模块 - Zig 0.15.1
//! 高性能系统资源监控和性能分析

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

/// 系统监控器 - 适配Zig 0.15.1
pub const SystemMonitor = struct {
    var last_cpu_time: u64 = 0;
    var last_idle_time: u64 = 0;
    var monitoring_interval_ns: u64 = 1000000000; // 1秒
    
    /// 系统性能指标
    pub const PerformanceMetrics = struct {
        memory_usage_bytes: usize,
        cpu_usage_percent: f32,
        process_memory_rss: usize,
        process_memory_vms: usize,
        load_average: [3]f32,
        uptime_seconds: u64,
        thread_count: u32,
        file_descriptor_count: u32,
        
        pub fn format(
            self: PerformanceMetrics,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            
            try writer.print("PerformanceMetrics{{\n");
            try writer.print("  内存使用: {:.2} MB\n", .{@as(f64, @floatFromInt(self.memory_usage_bytes)) / 1024.0 / 1024.0});
            try writer.print("  CPU使用率: {:.1}%\n", .{self.cpu_usage_percent});
            try writer.print("  进程RSS: {:.2} MB\n", .{@as(f64, @floatFromInt(self.process_memory_rss)) / 1024.0 / 1024.0});
            try writer.print("  进程VMS: {:.2} MB\n", .{@as(f64, @floatFromInt(self.process_memory_vms)) / 1024.0 / 1024.0});
            try writer.print("  负载平均: [{:.2}, {:.2}, {:.2}]\n", .{self.load_average[0], self.load_average[1], self.load_average[2]});
            try writer.print("  运行时间: {}s\n", .{self.uptime_seconds});
            try writer.print("  线程数: {}\n", .{self.thread_count});
            try writer.print("  文件描述符: {}\n", .{self.file_descriptor_count});
            try writer.print("}}");
        }
    };
    
    /// 获取综合性能指标
    pub fn get_performance_metrics() PerformanceMetrics {
        return PerformanceMetrics{
            .memory_usage_bytes = get_memory_usage(),
            .cpu_usage_percent = get_cpu_usage(),
            .process_memory_rss = get_process_memory_rss(),
            .process_memory_vms = get_process_memory_vms(),
            .load_average = get_load_average(),
            .uptime_seconds = get_system_uptime(),
            .thread_count = get_thread_count(),
            .file_descriptor_count = get_file_descriptor_count(),
        };
    }
    
    /// 获取系统总内存使用情况
    pub fn get_memory_usage() usize {
        switch (builtin.os.tag) {
            .linux => return getLinuxMemoryUsage(),
            .macos => return getMacOSMemoryUsage(),
            .windows => return getWindowsMemoryUsage(),
            else => return 0,
        }
    }
    
    /// 获取CPU使用率
    pub fn get_cpu_usage() f32 {
        switch (builtin.os.tag) {
            .linux => return getLinuxCpuUsage(),
            .macos => return getMacOSCpuUsage(),
            .windows => return getWindowsCpuUsage(),
            else => return 0.0,
        }
    }
    
    /// 获取进程RSS内存使用
    pub fn get_process_memory_rss() usize {
        switch (builtin.os.tag) {
            .linux => return getLinuxProcessMemoryRSS(),
            .macos => return getMacOSProcessMemoryRSS(),
            .windows => return getWindowsProcessMemoryRSS(),
            else => return 0,
        }
    }
    
    /// 获取进程VMS内存使用
    pub fn get_process_memory_vms() usize {
        switch (builtin.os.tag) {
            .linux => return getLinuxProcessMemoryVMS(),
            .macos => return getMacOSProcessMemoryVMS(),
            .windows => return getWindowsProcessMemoryVMS(),
            else => return 0,
        }
    }
    
    /// 获取系统负载平均值
    pub fn get_load_average() [3]f32 {
        switch (builtin.os.tag) {
            .linux, .macos => return getUnixLoadAverage(),
            .windows => return .{ 0.0, 0.0, 0.0 },
            else => return .{ 0.0, 0.0, 0.0 },
        }
    }
    
    /// 获取系统运行时间
    pub fn get_system_uptime() u64 {
        switch (builtin.os.tag) {
            .linux => return getLinuxUptime(),
            .macos => return getMacOSUptime(),
            .windows => return getWindowsUptime(),
            else => return 0,
        }
    }
    
    /// 获取进程线程数
    pub fn get_thread_count() u32 {
        switch (builtin.os.tag) {
            .linux => return getLinuxThreadCount(),
            .macos => return getMacOSThreadCount(),
            .windows => return getWindowsThreadCount(),
            else => return 0,
        }
    }
    
    /// 获取文件描述符数量
    pub fn get_file_descriptor_count() u32 {
        switch (builtin.os.tag) {
            .linux => return getLinuxFileDescriptorCount(),
            .macos => return getMacOSFileDescriptorCount(),
            .windows => return getWindowsFileDescriptorCount(),
            else => return 0,
        }
    }
    
    /// 设置监控间隔
    pub fn set_monitoring_interval(interval_ms: u64) void {
        monitoring_interval_ns = interval_ms * 1000000;
    }
    
    // Linux实现
    fn getLinuxMemoryUsage() usize {
        const file = std.fs.openFileAbsolute("/proc/meminfo", .{}) catch return 0;
        defer file.close();
        
        var buffer: [4096]u8 = undefined;
        const bytes_read = file.readAll(&buffer) catch return 0;
        
        var total_kb: usize = 0;
        var available_kb: usize = 0;
        
        var lines = std.mem.split(u8, buffer[0..bytes_read], "\n");
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "MemTotal:")) {
                var tokens = std.mem.tokenizeAny(u8, line, " \t");
                _ = tokens.next(); // 跳过标签
                if (tokens.next()) |value_str| {
                    total_kb = std.fmt.parseInt(usize, value_str, 10) catch 0;
                }
            } else if (std.mem.startsWith(u8, line, "MemAvailable:")) {
                var tokens = std.mem.tokenizeAny(u8, line, " \t");
                _ = tokens.next(); // 跳过标签
                if (tokens.next()) |value_str| {
                    available_kb = std.fmt.parseInt(usize, value_str, 10) catch 0;
                }
            }
        }
        
        return (total_kb - available_kb) * 1024; // 转换为字节
    }
    
    fn getLinuxCpuUsage() f32 {
        const file = std.fs.openFileAbsolute("/proc/stat", .{}) catch return 0.0;
        defer file.close();
        
        var buffer: [1024]u8 = undefined;
        const bytes_read = file.readAll(&buffer) catch return 0.0;
        
        var lines = std.mem.split(u8, buffer[0..bytes_read], "\n");
        const cpu_line = lines.next() orelse return 0.0;
        
                    var tokens = std.mem.tokenizeAny(u8, cpu_line, " ");
        _ = tokens.next(); // 跳过"cpu"
        
        var user: u64 = 0;
        var nice: u64 = 0;
        var system: u64 = 0;
        var idle: u64 = 0;
        var iowait: u64 = 0;
        var irq: u64 = 0;
        var softirq: u64 = 0;
        
        if (tokens.next()) |t| user = std.fmt.parseInt(u64, t, 10) catch 0;
        if (tokens.next()) |t| nice = std.fmt.parseInt(u64, t, 10) catch 0;
        if (tokens.next()) |t| system = std.fmt.parseInt(u64, t, 10) catch 0;
        if (tokens.next()) |t| idle = std.fmt.parseInt(u64, t, 10) catch 0;
        if (tokens.next()) |t| iowait = std.fmt.parseInt(u64, t, 10) catch 0;
        if (tokens.next()) |t| irq = std.fmt.parseInt(u64, t, 10) catch 0;
        if (tokens.next()) |t| softirq = std.fmt.parseInt(u64, t, 10) catch 0;
        
        const total_time = user + nice + system + idle + iowait + irq + softirq;
        const active_time = total_time - idle - iowait;
        
        // 计算使用率
        if (last_cpu_time > 0) {
            const total_delta = total_time - last_cpu_time;
            const active_delta = active_time - (last_cpu_time - last_idle_time);
            
            if (total_delta > 0) {
                const usage = @as(f32, @floatFromInt(active_delta)) / @as(f32, @floatFromInt(total_delta));
                last_cpu_time = total_time;
                last_idle_time = idle + iowait;
                return usage * 100.0;
            }
        }
        
        last_cpu_time = total_time;
        last_idle_time = idle + iowait;
        return 0.0;
    }
    
    fn getLinuxProcessMemoryRSS() usize {
        const file = std.fs.openFileAbsolute("/proc/self/status", .{}) catch return 0;
        defer file.close();
        
        var buffer: [4096]u8 = undefined;
        const bytes_read = file.readAll(&buffer) catch return 0;
        
        var lines = std.mem.split(u8, buffer[0..bytes_read], "\n");
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "VmRSS:")) {
                var tokens = std.mem.tokenizeAny(u8, line, " \t");
                _ = tokens.next(); // 跳过标签
                if (tokens.next()) |value_str| {
                    const kb = std.fmt.parseInt(usize, value_str, 10) catch 0;
                    return kb * 1024; // 转换为字节
                }
            }
        }
        return 0;
    }
    
    fn getLinuxProcessMemoryVMS() usize {
        const file = std.fs.openFileAbsolute("/proc/self/status", .{}) catch return 0;
        defer file.close();
        
        var buffer: [4096]u8 = undefined;
        const bytes_read = file.readAll(&buffer) catch return 0;
        
        var lines = std.mem.split(u8, buffer[0..bytes_read], "\n");
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "VmSize:")) {
                var tokens = std.mem.tokenizeAny(u8, line, " \t");
                _ = tokens.next(); // 跳过标签
                if (tokens.next()) |value_str| {
                    const kb = std.fmt.parseInt(usize, value_str, 10) catch 0;
                    return kb * 1024; // 转换为字节
                }
            }
        }
        return 0;
    }
    
    fn getUnixLoadAverage() [3]f32 {
        const file = std.fs.openFileAbsolute("/proc/loadavg", .{}) catch {
            // macOS fallback - 可以使用sysctl
            return .{ 0.0, 0.0, 0.0 };
        };
        defer file.close();
        
        var buffer: [256]u8 = undefined;
        const bytes_read = file.readAll(&buffer) catch return .{ 0.0, 0.0, 0.0 };
        
        var tokens = std.mem.tokenizeAny(u8, buffer[0..bytes_read], " ");
        var load: [3]f32 = .{ 0.0, 0.0, 0.0 };
        
        for (0..3) |i| {
            if (tokens.next()) |token| {
                load[i] = std.fmt.parseFloat(f32, token) catch 0.0;
            }
        }
        
        return load;
    }
    
    fn getLinuxUptime() u64 {
        const file = std.fs.openFileAbsolute("/proc/uptime", .{}) catch return 0;
        defer file.close();
        
        var buffer: [256]u8 = undefined;
        const bytes_read = file.readAll(&buffer) catch return 0;
        
        var tokens = std.mem.tokenizeAny(u8, buffer[0..bytes_read], " ");
        if (tokens.next()) |uptime_str| {
            const uptime_float = std.fmt.parseFloat(f64, uptime_str) catch 0.0;
            return @intFromFloat(uptime_float);
        }
        
        return 0;
    }
    
    fn getLinuxThreadCount() u32 {
        const file = std.fs.openFileAbsolute("/proc/self/status", .{}) catch return 0;
        defer file.close();
        
        var buffer: [4096]u8 = undefined;
        const bytes_read = file.readAll(&buffer) catch return 0;
        
        var lines = std.mem.split(u8, buffer[0..bytes_read], "\n");
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "Threads:")) {
                var tokens = std.mem.tokenizeAny(u8, line, " \t");
                _ = tokens.next(); // 跳过标签
                if (tokens.next()) |value_str| {
                    return std.fmt.parseInt(u32, value_str, 10) catch 0;
                }
            }
        }
        return 0;
    }
    
    fn getLinuxFileDescriptorCount() u32 {
        var fd_dir = std.fs.openDirAbsolute("/proc/self/fd", .{ .iterate = true }) catch return 0;
        defer fd_dir.close();
        
        var count: u32 = 0;
        var iterator = fd_dir.iterate();
        while (iterator.next() catch null) |entry| {
            if (entry.kind == .file or entry.kind == .sym_link) {
                count += 1;
            }
        }
        
        return count;
    }
    
    // macOS实现 (简化版)
    fn getMacOSMemoryUsage() usize {
        // 需要使用mach系统调用，这里返回默认值
        return 0;
    }
    
    fn getMacOSCpuUsage() f32 {
        // 需要使用host_processor_info等系统调用
        return 0.0;
    }
    
    fn getMacOSProcessMemoryRSS() usize {
        // 需要使用task_info系统调用
        return 0;
    }
    
    fn getMacOSProcessMemoryVMS() usize {
        return 0;
    }
    
    fn getMacOSUptime() u64 {
        return 0;
    }
    
    fn getMacOSThreadCount() u32 {
        return 0;
    }
    
    fn getMacOSFileDescriptorCount() u32 {
        return 0;
    }
    
    // Windows实现 (占位符)
    fn getWindowsMemoryUsage() usize {
        return 0;
    }
    
    fn getWindowsCpuUsage() f32 {
        return 0.0;
    }
    
    fn getWindowsProcessMemoryRSS() usize {
        return 0;
    }
    
    fn getWindowsProcessMemoryVMS() usize {
        return 0;
    }
    
    fn getWindowsUptime() u64 {
        return 0;
    }
    
    fn getWindowsThreadCount() u32 {
        return 0;
    }
    
    fn getWindowsFileDescriptorCount() u32 {
        return 0;
    }
};

/// 性能分析器 - Zig 0.15.1新特性
pub const Profiler = struct {
    start_time: std.time.Instant,
    checkpoints: std.ArrayList(Checkpoint),
    allocator: std.mem.Allocator,
    
    const Checkpoint = struct {
        name: []const u8,
        timestamp: std.time.Instant,
        memory_usage: usize,
    };
    
    pub fn init(allocator: std.mem.Allocator) !Profiler {
        return Profiler{
            .start_time = try std.time.Instant.now(),
            .checkpoints = std.ArrayList(Checkpoint){},
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Profiler) void {
        self.checkpoints.deinit(self.allocator);
    }
    
    pub fn checkpoint(self: *Profiler, name: []const u8) !void {
        const now = try std.time.Instant.now();
        const memory = SystemMonitor.get_process_memory_rss();
        
        try self.checkpoints.append(self.allocator, .{
            .name = name,
            .timestamp = now,
            .memory_usage = memory,
        });
    }
    
    /// 生成性能报告 - 准备兼容Zig 0.15.1新的Writer接口
    pub fn report(self: *const Profiler, writer: anytype) !void {
        try writer.print("性能分析报告:\n", .{});
        try writer.print("================\n", .{});
        
        var prev_time = self.start_time;
        var prev_memory: usize = 0;
        
        for (self.checkpoints.items) |cp| {
            const elapsed = cp.timestamp.since(prev_time);
            const memory_delta = if (cp.memory_usage > prev_memory) 
                cp.memory_usage - prev_memory 
            else 
                0;
            
            try writer.print("{s}: {d:.2}ms (+{:.2}MB)\n", .{
                cp.name,
                @as(f64, @floatFromInt(elapsed)) / 1000000.0,
                @as(f64, @floatFromInt(memory_delta)) / 1024.0 / 1024.0,
            });
            
            prev_time = cp.timestamp;
            prev_memory = cp.memory_usage;
        }
        
        const total_elapsed = prev_time.since(self.start_time);
        try writer.print("总用时: {d:.2}ms\n", .{
            @as(f64, @floatFromInt(total_elapsed)) / 1000000.0
        });
    }
};

// 测试
test "system monitor basic functionality" {
    const metrics = SystemMonitor.get_performance_metrics();
    
    // 基本检查
    try testing.expect(metrics.memory_usage_bytes > 0 or builtin.os.tag != .linux);
    try testing.expect(metrics.cpu_usage_percent >= 0.0);
    try testing.expect(metrics.process_memory_rss > 0 or builtin.os.tag != .linux);
}

test "profiler functionality" {
    var profiler = try Profiler.init(testing.allocator);
    defer profiler.deinit();
    
    try profiler.checkpoint("开始");
    
    // 模拟一些工作
    var sum: u64 = 0;
    for (0..1000) |i| {
        sum += i;
    }
    
    try profiler.checkpoint("计算完成");
    
    // 输出报告到stdout进行验证
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try profiler.report(fbs.writer());
    
    try testing.expect(fbs.getWritten().len > 0);
}
