// Helper macros for NIF error handling and return values

/// Checks TA-Lib return code and returns Err if not Success (for Result<T, String> functions)
///
/// Handles all TARetCode enum values and returns appropriate error messages.
/// If the return code is Success, execution continues.
///
/// # Examples
///
/// ```
/// let ret_code = unsafe { TA_SMA(...) };
/// check_ret_code!(ret_code, "SMA");
/// // Execution continues only if ret_code was Success
/// ```
#[cfg(has_talib)]
#[macro_export]
macro_rules! check_ret_code {
    ($ret_code:expr, $func_name:expr) => {{
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

            return Err(error_msg);
        }
    }};
}

/// Converts a Vec<Option<f64>> to Vec<f64> by replacing None with NaN
///
/// # Examples
///
/// ```
/// let data = vec![Some(1.0), None, Some(3.0)];
/// let result = options_to_nan(data);
/// assert_eq!(result, vec![1.0, f64::NAN, 3.0]);
/// ```
#[inline]
pub fn options_to_nan(data: &[Option<f64>]) -> Vec<f64> {
    data.iter().map(|x| x.unwrap_or(f64::NAN)).collect()
}

/// Find index of first non-NaN value in data, similar to Python ta-lib's check_begidx1
///
/// This replicates the Python ta-lib behavior of skipping leading NaN values
/// before calling ta-lib C functions.
///
/// # Examples
///
/// ```
/// let data = vec![f64::NAN, f64::NAN, 1.0, 2.0];
/// assert_eq!(check_begidx(&data), 2);
///
/// let data = vec![1.0, 2.0, 3.0];
/// assert_eq!(check_begidx(&data), 0);
/// ```
#[inline]
pub fn check_begidx(data: &[f64]) -> usize {
    for (i, &val) in data.iter().enumerate() {
        if !val.is_nan() {
            return i;
        }
    }

    data.len().saturating_sub(1)
}

/// Build result vector from ta-lib output array
///
/// Creates a result vector with `total_lookback` None values at the beginning,
/// followed by the values from `out_real`, converting NaN to None.
///
/// # Examples
///
/// ```
/// let result = build_result(total_lookback, out_nb_element, &out_real);
/// ```
#[inline]
pub fn build_result(
    total_lookback: i32,
    out_nb_element: i32,
    out_real: &[f64],
) -> Vec<Option<f64>> {
    let mut result = vec![None; total_lookback as usize];

    for i in 0..out_nb_element {
        let value = out_real[i as usize];
        if value.is_nan() {
            result.push(None);
        } else {
            result.push(Some(value));
        }
    }

    result
}
