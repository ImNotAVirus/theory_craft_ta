use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    eprintln!("=== BUILD.RS STARTED ===");

    // Declare the custom cfg for conditional compilation
    println!("cargo:rustc-check-cfg=cfg(has_talib)");

    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let manifest_path = PathBuf::from(&manifest_dir);
    let project_root = manifest_path
        .parent()
        .and_then(|p| p.parent())
        .expect("Failed to find project root");

    let ta_lib_install = project_root.join("ta-lib-install");

    eprintln!(
        "=== Checking for ta-lib at: {} ===",
        ta_lib_install.display()
    );
    eprintln!("=== Exists: {} ===", ta_lib_install.exists());

    // Check if ta-lib is already built
    if !ta_lib_install.exists() {
        eprintln!("=== TA-Lib NOT FOUND - ATTEMPTING TO BUILD ===");

        // Build ta-lib automatically - panic if it fails
        build_ta_lib(project_root).expect("Failed to build ta-lib");

        eprintln!("=== TA-LIB BUILD SUCCESSFUL ===");
    }

    eprintln!("=== TA-Lib FOUND - CONTINUING WITH LINKING ===");

    // Enable the has_talib cfg flag for conditional compilation
    println!("cargo:rustc-cfg=has_talib");

    // Configure library search path
    let lib_dir = ta_lib_install.join("lib");
    println!("cargo:rustc-link-search=native={}", lib_dir.display());

    // Link ta-lib statically
    println!("cargo:rustc-link-lib=static=ta-lib");

    // Add include path for bindgen or manual FFI
    let include_dir = ta_lib_install.join("include");
    println!("cargo:include={}", include_dir.display());

    // Rerun if ta-lib changes
    println!("cargo:rerun-if-changed={}", ta_lib_install.display());
}

fn build_ta_lib(project_root: &std::path::Path) -> Result<(), String> {
    let tools_dir = project_root.join("tools");

    let build_script = if cfg!(target_os = "windows") {
        tools_dir.join("build_talib.cmd")
    } else {
        tools_dir.join("build_talib.sh")
    };

    if !build_script.exists() {
        return Err(format!(
            "Build script not found: {}",
            build_script.display()
        ));
    }

    eprintln!(
        "=== Running ta-lib build script: {} ===",
        build_script.display()
    );

    let output = if cfg!(target_os = "windows") {
        Command::new("cmd")
            .arg("/C")
            .arg(&build_script)
            .current_dir(project_root)
            .output()
            .map_err(|e| format!("Failed to execute build script: {}", e))?
    } else {
        Command::new("sh")
            .arg(&build_script)
            .current_dir(project_root)
            .output()
            .map_err(|e| format!("Failed to execute build script: {}", e))?
    };

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        return Err(format!(
            "Build script failed:\nstdout: {}\nstderr: {}",
            stdout, stderr
        ));
    }

    println!("cargo:warning=TA-Lib built successfully");
    Ok(())
}
