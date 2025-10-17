use rustler::{Encoder, Env, NifResult, Term};

// Implementation when ta-lib is available
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sma(env: Env, data: Vec<f64>, period: i32) -> NifResult<Term> {
    use crate::overlap_ffi::{TA_SMA_Lookback, TA_SMA};

    // Empty data → return empty (like Python)
    if data.is_empty() {
        return ok!(env, Vec::<Option<f64>>::new());
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

    check_ret_code!(env, ret_code, "SMA");

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

    ok!(env, result)
}

// Implementation when ta-lib is available
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_ema(env: Env, data: Vec<f64>, period: i32) -> NifResult<Term> {
    use crate::overlap_ffi::{TA_EMA_Lookback, TA_EMA};

    // Empty data → return empty (like Python)
    if data.is_empty() {
        return ok!(env, Vec::<Option<f64>>::new());
    }

    let data_len = data.len() as i32;

    // Calculate lookback period
    let lookback = unsafe { TA_EMA_Lookback(period) };

    // Prepare output buffers
    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; data_len as usize];

    // Call TA_EMA
    let ret_code = unsafe {
        TA_EMA(
            0,
            data_len - 1,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(env, ret_code, "EMA");

    // Build result with nil padding for lookback period
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Lookback is period - 1, but can't exceed data length
    let num_nils = std::cmp::min(lookback, data_len);

    // Add nil values for lookback period
    for _ in 0..num_nils {
        result.push(None);
    }

    // Add calculated EMA values
    for i in 0..out_nb_element {
        result.push(Some(out_real[i as usize]));
    }

    ok!(env, result)
}

// Implementation when ta-lib is available
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_wma(env: Env, data: Vec<f64>, period: i32) -> NifResult<Term> {
    use crate::overlap_ffi::{TA_WMA_Lookback, TA_WMA};

    // Empty data → return empty (like Python)
    if data.is_empty() {
        return ok!(env, Vec::<Option<f64>>::new());
    }

    let data_len = data.len() as i32;

    // Calculate lookback period
    let lookback = unsafe { TA_WMA_Lookback(period) };

    // Prepare output buffers
    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; data_len as usize];

    // Call TA_WMA
    let ret_code = unsafe {
        TA_WMA(
            0,
            data_len - 1,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(env, ret_code, "WMA");

    // Build result with nil padding for lookback period
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Lookback is period - 1, but can't exceed data length
    let num_nils = std::cmp::min(lookback, data_len);

    // Add nil values for lookback period
    for _ in 0..num_nils {
        result.push(None);
    }

    // Add calculated WMA values
    for i in 0..out_nb_element {
        result.push(Some(out_real[i as usize]));
    }

    ok!(env, result)
}

// Stub implementation when ta-lib is not available
#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_sma(env: Env, _data: Vec<f64>, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_ema(env: Env, _data: Vec<f64>, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_wma(env: Env, _data: Vec<f64>, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}
