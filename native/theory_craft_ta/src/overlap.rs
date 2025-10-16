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

    #[link(name = "ta-lib", kind = "static")]
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

    // Empty data → return empty (like Python)
    if data.is_empty() {
        let success = (atoms::ok(), Vec::<Option<f64>>::new());
        return Ok(success.encode(env));
    }

    let data_len = data.len() as i32;

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

    if ret_code != TARetCode::Success as i32 {
        let error_msg = match ret_code {
            x if x == TARetCode::BadParam as i32 => "Invalid period: must be >= 2 for SMA",
            x if x == TARetCode::AllocErr as i32 => "Memory allocation failed",
            x if x == TARetCode::OutOfRangeStartIndex as i32 => "Start index out of range",
            x if x == TARetCode::OutOfRangeEndIndex as i32 => "End index out of range",
            _ => "TA-Lib internal error",
        };

        let err = (atoms::error(), error_msg);
        return Ok(err.encode(env));
    }

    // Build result with nil padding for lookback period
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Lookback is period - 1, but can't exceed data length
    let num_nils = std::cmp::min(lookback, data_len);

    // Add nil values for lookback period
    for _ in 0..num_nils {
        result.push(None);
    }

    // Add calculated SMA values
    for i in 0..out_nb_element {
        result.push(Some(out_real[i as usize]));
    }

    let success = (atoms::ok(), result);
    Ok(success.encode(env))
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sma_next(
    env: Env,
    data: Vec<f64>,
    period: i32,
    prev: Vec<Option<f64>>,
) -> NifResult<Term> {
    use talib_ffi::{TARetCode, TA_SMA};

    let data_len = data.len();
    let prev_len = prev.len();

    if data_len == 0 {
        let success = (atoms::ok(), Vec::<Option<f64>>::new());
        return Ok(success.encode(env));
    }

    let should_update = data_len == prev_len;
    let should_append = data_len == prev_len + 1;

    if !should_update && !should_append {
        let err = (
            atoms::error(),
            "Input size must be equal to or one more than prev size",
        );
        return Ok(err.encode(env));
    }

    let end_idx = (data_len - 1) as i32;
    let start_idx = end_idx;

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; 1];

    let ret_code = unsafe {
        TA_SMA(
            start_idx,
            end_idx,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    if ret_code != TARetCode::Success as i32 {
        let error_msg = match ret_code {
            x if x == TARetCode::BadParam as i32 => "Invalid period: must be >= 2 for SMA",
            x if x == TARetCode::AllocErr as i32 => "Memory allocation failed",
            x if x == TARetCode::OutOfRangeStartIndex as i32 => "Start index out of range",
            x if x == TARetCode::OutOfRangeEndIndex as i32 => "End index out of range",
            _ => "TA-Lib internal error",
        };

        let err = (atoms::error(), error_msg);
        return Ok(err.encode(env));
    }

    let new_sma = if out_nb_element > 0 {
        Some(out_real[0])
    } else {
        None
    };

    let result = if should_update {
        let mut updated = prev.clone();
        if let Some(last) = updated.last_mut() {
            *last = new_sma;
        }
        updated
    } else {
        let mut appended = prev.clone();
        appended.push(new_sma);
        appended
    };

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

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_sma_next(
    env: Env,
    _data: Vec<f64>,
    _period: i32,
    _prev: Vec<Option<f64>>,
) -> NifResult<Term> {
    let err = (
        atoms::error(),
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend.",
    );
    Ok(err.encode(env))
}
