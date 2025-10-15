use rustler::{Encoder, Env, NifResult, Term};

// Define atoms module for return tuples
mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

// Only include FFI declarations when ta-lib is available
#[cfg(has_talib)]
mod talib_ffi {
    // FFI declarations for ta-lib C functions
    #[repr(C)]
    #[derive(Debug, PartialEq)]
    #[allow(dead_code)]
    pub enum TARetCode {
        Success = 0,
        LibNotInitialize = 1,
        BadParam = 2,
        AllocErr = 3,
        GroupNotFound = 4,
        FuncNotFound = 5,
        InvalidHandle = 6,
        InvalidParamHolder = 7,
        InvalidParamFunction = 8,
        InputNotAllInitialize = 9,
        OutputNotAllInitialize = 10,
        OutOfRangeStartIndex = 11,
        OutOfRangeEndIndex = 12,
        InvalidListType = 13,
        BadObject = 14,
        NotSupported = 15,
        InternalError = 5000,
        UnknownErr = 0xFFFF,
    }

    #[link(name = "ta_lib", kind = "static")]
    extern "C" {
        pub fn TA_SMA(
            start_idx: i32,
            end_idx: i32,
            in_real: *const f64,
            opt_in_time_period: i32,
            out_beg_idx: *mut i32,
            out_nb_element: *mut i32,
            out_real: *mut f64,
        ) -> i32;

        pub fn TA_SMA_Lookback(opt_in_time_period: i32) -> i32;
    }
}

// Implementation when ta-lib is available
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sma(env: Env, data: Vec<f64>, period: i32) -> NifResult<Term> {
    use talib_ffi::{TARetCode, TA_SMA_Lookback, TA_SMA};

    // Validate period
    if period < 2 {
        let err = (atoms::error(), "Period must be >= 2");
        return Ok(err.encode(env));
    }

    let data_len = data.len() as i32;

    // Check if we have enough data
    if data_len < period {
        let err = (
            atoms::error(),
            "Not enough data points for the given period",
        );
        return Ok(err.encode(env));
    }

    // Calculate lookback period
    let lookback = unsafe { TA_SMA_Lookback(period) };

    // Prepare output buffers
    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; data_len as usize];

    // Call TA_SMA
    let ret_code = unsafe {
        TA_SMA(
            0,
            data_len - 1,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    // Check return code
    if ret_code != TARetCode::Success as i32 {
        let err = (atoms::error(), format!("TA-Lib error code: {}", ret_code));
        return Ok(err.encode(env));
    }

    // Build result with nil padding for lookback period
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Add nil values for lookback period
    for _ in 0..lookback {
        result.push(None);
    }

    // Add calculated SMA values
    for i in 0..out_nb_element {
        result.push(Some(out_real[i as usize]));
    }

    let success = (atoms::ok(), result);
    Ok(success.encode(env))
}

// Stub implementation when ta-lib is not available
#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_sma(env: Env, _data: Vec<f64>, _period: i32) -> NifResult<Term> {
    let err = (
        atoms::error(),
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend.",
    );
    Ok(err.encode(env))
}
