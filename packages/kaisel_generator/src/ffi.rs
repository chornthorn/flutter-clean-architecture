use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::Path;

use crate::config::execute_generation;

#[unsafe(no_mangle)]
pub extern "C" fn kaisel_generate(
    project_root_ptr: *const c_char,
    lib_dir_ptr: *const c_char,
    output_path_ptr: *const c_char,
    force: bool,
) -> *mut c_char {
    let root = if !project_root_ptr.is_null() {
        unsafe { CStr::from_ptr(project_root_ptr) }
            .to_str()
            .ok()
            .map(Path::new)
    } else {
        None
    };

    let lib = if !lib_dir_ptr.is_null() {
        unsafe { CStr::from_ptr(lib_dir_ptr) }
            .to_str()
            .ok()
            .map(Path::new)
    } else {
        None
    };

    let out = if !output_path_ptr.is_null() {
        unsafe { CStr::from_ptr(output_path_ptr) }
            .to_str()
            .ok()
            .map(Path::new)
    } else {
        None
    };

    let result = execute_generation(root, lib, out, force);
    let json = serde_json::to_string(&result).unwrap_or_else(|e| {
        format!(
            r#"{{"success":false,"error":"{}","files_scanned":0,"files_parsed":0,"modules_count":0,"elapsed_us":0,"output_path":null}}"#,
            e
        )
    });

    CString::new(json).unwrap_or_default().into_raw()
}

#[unsafe(no_mangle)]
pub extern "C" fn kaisel_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}
