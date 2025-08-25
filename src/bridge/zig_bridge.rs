//! MIRA Zig系统层桥接
//! My Intelligent Romantic Assistant - 调用Zig实现的高性能内存管理和系统操作

use crate::{Result, MemoryError};
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};

// Zig函数声明 - Rust 2024要求extern块标记为unsafe
unsafe extern "C" {
    /// 初始化Zig内存池
    fn zig_memory_pool_init(pool_size: usize) -> *mut c_void;
    
    /// 从内存池分配内存
    fn zig_memory_pool_alloc(pool: *mut c_void, size: usize) -> *mut c_void;
    
    /// 释放内存到池中
    fn zig_memory_pool_free(pool: *mut c_void, ptr: *mut c_void);
    
    /// 销毁内存池
    fn zig_memory_pool_destroy(pool: *mut c_void);
    
    /// 高性能字符串处理
    fn zig_fast_string_hash(text: *const c_char, len: usize) -> u64;
    
    /// 向量运算优化
    fn zig_vector_dot_product(a: *const f32, b: *const f32, len: usize) -> f32;
    
    /// 系统性能监控
    fn zig_get_memory_usage() -> usize;
    fn zig_get_cpu_usage() -> f32;
}

/// Zig内存池管理器
#[derive(Debug)]
pub struct ZigMemoryPool {
    pool_ptr: *mut c_void,
    pool_size: usize,
}

unsafe impl Send for ZigMemoryPool {}
unsafe impl Sync for ZigMemoryPool {}

impl ZigMemoryPool {
    /// 创建新的内存池
    pub fn new(pool_size: usize) -> Result<Self> {
        let pool_ptr = unsafe { zig_memory_pool_init(pool_size) };
        
        if pool_ptr.is_null() {
            return Err(MemoryError::DatabaseError(
                "Zig内存池初始化失败".to_string()
            ));
        }
        
        Ok(Self {
            pool_ptr,
            pool_size,
        })
    }

    /// 分配内存
    pub fn allocate(&self, size: usize) -> Result<*mut c_void> {
        let ptr = unsafe { zig_memory_pool_alloc(self.pool_ptr, size) };
        
        if ptr.is_null() {
            Err(MemoryError::DatabaseError(
                "内存分配失败".to_string()
            ))
        } else {
            Ok(ptr)
        }
    }

    /// 释放内存
    pub fn deallocate(&self, ptr: *mut c_void) {
        unsafe {
            zig_memory_pool_free(self.pool_ptr, ptr);
        }
    }

    /// 获取池大小
    pub fn pool_size(&self) -> usize {
        self.pool_size
    }
}

impl Drop for ZigMemoryPool {
    fn drop(&mut self) {
        unsafe {
            zig_memory_pool_destroy(self.pool_ptr);
        }
    }
}

/// Zig高性能工具集
#[derive(Debug)]
pub struct ZigPerformanceUtils;

impl ZigPerformanceUtils {
    /// 快速字符串哈希
    pub fn fast_hash(text: &str) -> u64 {
        let c_str = CString::new(text).unwrap_or_default();
        unsafe {
            zig_fast_string_hash(c_str.as_ptr(), text.len())
        }
    }

    /// 向量点积运算
    pub fn vector_dot_product(a: &[f32], b: &[f32]) -> Result<f32> {
        if a.len() != b.len() {
            return Err(MemoryError::DatabaseError(
                "向量维度不匹配".to_string()
            ));
        }

        let result = unsafe {
            zig_vector_dot_product(a.as_ptr(), b.as_ptr(), a.len())
        };

        Ok(result)
    }

    /// 获取系统内存使用情况
    pub fn get_memory_usage() -> usize {
        unsafe { zig_get_memory_usage() }
    }

    /// 获取CPU使用率
    pub fn get_cpu_usage() -> f32 {
        unsafe { zig_get_cpu_usage() }
    }
}

/// Zig系统监控器
#[derive(Debug)]
pub struct ZigSystemMonitor {
    memory_pool: Option<ZigMemoryPool>,
}

impl ZigSystemMonitor {
    /// 创建新的系统监控器
    pub fn new(enable_memory_pool: bool, pool_size: Option<usize>) -> Result<Self> {
        let memory_pool = if enable_memory_pool {
            Some(ZigMemoryPool::new(pool_size.unwrap_or(1024 * 1024))?)
        } else {
            None
        };

        Ok(Self { memory_pool })
    }

    /// 获取系统性能指标
    pub fn get_performance_metrics(&self) -> PerformanceMetrics {
        PerformanceMetrics {
            memory_usage: ZigPerformanceUtils::get_memory_usage(),
            cpu_usage: ZigPerformanceUtils::get_cpu_usage(),
            pool_size: self.memory_pool.as_ref().map(|p| p.pool_size()),
        }
    }

    /// 获取内存池引用
    pub fn memory_pool(&self) -> Option<&ZigMemoryPool> {
        self.memory_pool.as_ref()
    }
}

/// 性能指标
#[derive(Debug, Clone)]
pub struct PerformanceMetrics {
    pub memory_usage: usize,
    pub cpu_usage: f32,
    pub pool_size: Option<usize>,
}

/// 用于与Zig代码接口的辅助函数
#[unsafe(no_mangle)]
pub extern "C" fn rust_log_callback(level: c_int, message: *const c_char) {
    if message.is_null() {
        return;
    }

    let c_str = unsafe { CStr::from_ptr(message) };
    if let Ok(msg) = c_str.to_str() {
        match level {
            0 => tracing::error!("Zig: {}", msg),
            1 => tracing::warn!("Zig: {}", msg),
            2 => tracing::info!("Zig: {}", msg),
            3 => tracing::debug!("Zig: {}", msg),
            _ => tracing::trace!("Zig: {}", msg),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zig_hash() {
        let hash1 = ZigPerformanceUtils::fast_hash("hello");
        let hash2 = ZigPerformanceUtils::fast_hash("hello");
        let hash3 = ZigPerformanceUtils::fast_hash("world");
        
        assert_eq!(hash1, hash2);
        assert_ne!(hash1, hash3);
    }

    #[test]
    fn test_performance_metrics() {
        let monitor = ZigSystemMonitor::new(false, None).unwrap();
        let metrics = monitor.get_performance_metrics();
        
        assert!(metrics.memory_usage > 0);
        assert!(metrics.cpu_usage >= 0.0);
    }
}
