use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=zig_system/");
    println!("cargo:rerun-if-changed=zig_system/src/");
    println!("cargo:rerun-if-changed=zig_system/build.zig");

    // 构建Zig静态库
    let zig_output = Command::new("zig")
        .args(["build", "-Doptimize=ReleaseFast"])
        .current_dir("zig_system")
        .output()
        .expect("Failed to execute Zig build command");

    if !zig_output.status.success() {
        panic!(
            "Zig build failed: {}",
            String::from_utf8_lossy(&zig_output.stderr)
        );
    }

    // 获取项目根目录
    let out_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let zig_lib_path = PathBuf::from(out_dir).join("zig_system/zig-out/lib");

    // 告诉Cargo在哪里找到静态库
    println!("cargo:rustc-link-search=native={}", zig_lib_path.display());
    
    // 链接Zig生成的静态库
    println!("cargo:rustc-link-lib=static=zig_system");
    
    // 链接系统库（如果Zig需要的话）
    #[cfg(target_os = "macos")]
    {
        println!("cargo:rustc-link-lib=framework=Foundation");
        println!("cargo:rustc-link-lib=c");
    }
    
    #[cfg(target_os = "linux")]
    {
        println!("cargo:rustc-link-lib=c");
        println!("cargo:rustc-link-lib=m");
    }
}
