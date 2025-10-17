// Helper macros for NIF error handling and return values

/// Creates an error tuple and encodes it
///
/// # Examples
///
/// ```
/// error!(env, "Invalid parameter")
/// ```
#[macro_export]
macro_rules! error {
    ($env:expr, $msg:expr) => {{
        let err = ($crate::atoms::error(), $msg);
        Ok(err.encode($env))
    }};
}

/// Creates an ok tuple and encodes it
///
/// # Examples
///
/// ```
/// ok!(env, result_value)
/// ```
#[macro_export]
macro_rules! ok {
    ($env:expr, $term:expr) => {{
        let success = ($crate::atoms::ok(), $term);
        Ok(success.encode($env))
    }};
}

/// Checks TA-Lib return code and returns error if not Success
///
/// Handles all TARetCode enum values and returns appropriate error messages.
/// If the return code is Success, execution continues.
///
/// # Examples
///
/// ```
/// let ret_code = unsafe { TA_SMA(...) };
/// check_ret_code!(env, ret_code, "SMA");
/// // Execution continues only if ret_code was Success
/// ```
#[cfg(has_talib)]
#[macro_export]
macro_rules! check_ret_code {
    ($env:expr, $ret_code:expr, $func_name:expr) => {{
        use $crate::overlap_ffi::TARetCode;

        if $ret_code != TARetCode::Success as i32 {
            let error_msg = match $ret_code {
                x if x == TARetCode::LibNotInitialize as i32 => {
                    format!("{}: TA-Lib not initialized", $func_name)
                }
                x if x == TARetCode::BadParam as i32 => {
                    format!("{}: Invalid parameters", $func_name)
                }
                x if x == TARetCode::AllocErr as i32 => {
                    format!("{}: Memory allocation failed", $func_name)
                }
                x if x == TARetCode::GroupNotFound as i32 => {
                    format!("{}: Function group not found", $func_name)
                }
                x if x == TARetCode::FuncNotFound as i32 => {
                    format!("{}: Function not found", $func_name)
                }
                x if x == TARetCode::InvalidHandle as i32 => {
                    format!("{}: Invalid handle", $func_name)
                }
                x if x == TARetCode::InvalidParamHolder as i32 => {
                    format!("{}: Invalid parameter holder", $func_name)
                }
                x if x == TARetCode::InvalidParamFunction as i32 => {
                    format!("{}: Invalid parameter function", $func_name)
                }
                x if x == TARetCode::InputNotAllInitialize as i32 => {
                    format!("{}: Not all inputs initialized", $func_name)
                }
                x if x == TARetCode::OutputNotAllInitialize as i32 => {
                    format!("{}: Not all outputs initialized", $func_name)
                }
                x if x == TARetCode::OutOfRangeStartIndex as i32 => {
                    format!("{}: Start index out of range", $func_name)
                }
                x if x == TARetCode::OutOfRangeEndIndex as i32 => {
                    format!("{}: End index out of range", $func_name)
                }
                x if x == TARetCode::InvalidListType as i32 => {
                    format!("{}: Invalid list type", $func_name)
                }
                x if x == TARetCode::BadObject as i32 => {
                    format!("{}: Bad object", $func_name)
                }
                x if x == TARetCode::NotSupported as i32 => {
                    format!("{}: Operation not supported", $func_name)
                }
                x if x == TARetCode::InternalError as i32 => {
                    format!(
                        "{}: TA-Lib internal error (code: {})",
                        $func_name, $ret_code
                    )
                }
                x if x == TARetCode::UnknownErr as i32 => {
                    format!("{}: Unknown error (code: {})", $func_name, $ret_code)
                }
                _ => format!(
                    "{}: TA-Lib internal error (code: {})",
                    $func_name, $ret_code
                ),
            };

            return error!($env, error_msg);
        }
    }};
}
