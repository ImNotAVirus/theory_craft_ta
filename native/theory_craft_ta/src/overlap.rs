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

// Implementation when ta-lib is available
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_dema(env: Env, data: Vec<f64>, period: i32) -> NifResult<Term> {
    use crate::overlap_ffi::{TA_DEMA_Lookback, TA_DEMA};

    // Empty data → return empty (like Python)
    if data.is_empty() {
        return ok!(env, Vec::<Option<f64>>::new());
    }

    let data_len = data.len() as i32;

    // Calculate lookback period
    let lookback = unsafe { TA_DEMA_Lookback(period) };

    // Prepare output buffers
    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; data_len as usize];

    // Call TA_DEMA
    let ret_code = unsafe {
        TA_DEMA(
            0,
            data_len - 1,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(env, ret_code, "DEMA");

    // Build result with nil padding for lookback period
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Lookback is 2*(period - 1), but can't exceed data length
    let num_nils = std::cmp::min(lookback, data_len);

    // Add nil values for lookback period
    for _ in 0..num_nils {
        result.push(None);
    }

    // Add calculated DEMA values
    for i in 0..out_nb_element {
        result.push(Some(out_real[i as usize]));
    }

    ok!(env, result)
}

// Implementation when ta-lib is available
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_tema(env: Env, data: Vec<f64>, period: i32) -> NifResult<Term> {
    use crate::overlap_ffi::{TA_TEMA_Lookback, TA_TEMA};

    // Empty data → return empty (like Python)
    if data.is_empty() {
        return ok!(env, Vec::<Option<f64>>::new());
    }

    let data_len = data.len() as i32;

    // Calculate lookback period
    let lookback = unsafe { TA_TEMA_Lookback(period) };

    // Prepare output buffers
    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; data_len as usize];

    // Call TA_TEMA
    let ret_code = unsafe {
        TA_TEMA(
            0,
            data_len - 1,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(env, ret_code, "TEMA");

    // Build result with nil padding for lookback period
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Lookback is 3*(period - 1), but can't exceed data length
    let num_nils = std::cmp::min(lookback, data_len);

    // Add nil values for lookback period
    for _ in 0..num_nils {
        result.push(None);
    }

    // Add calculated TEMA values
    for i in 0..out_nb_element {
        result.push(Some(out_real[i as usize]));
    }

    ok!(env, result)
}

// Implementation when ta-lib is available
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_trima(env: Env, data: Vec<f64>, period: i32) -> NifResult<Term> {
    use crate::overlap_ffi::{TA_TRIMA_Lookback, TA_TRIMA};

    // Empty data → return empty (like Python)
    if data.is_empty() {
        return ok!(env, Vec::<Option<f64>>::new());
    }

    let data_len = data.len() as i32;

    // Calculate lookback period
    let lookback = unsafe { TA_TRIMA_Lookback(period) };

    // Prepare output buffers
    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; data_len as usize];

    // Call TA_TRIMA
    let ret_code = unsafe {
        TA_TRIMA(
            0,
            data_len - 1,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(env, ret_code, "TRIMA");

    // Build result with nil padding for lookback period
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Lookback can't exceed data length
    let num_nils = std::cmp::min(lookback, data_len);

    // Add nil values for lookback period
    for _ in 0..num_nils {
        result.push(None);
    }

    // Add calculated TRIMA values
    for i in 0..out_nb_element {
        result.push(Some(out_real[i as usize]));
    }

    ok!(env, result)
}

// Implementation when ta-lib is available
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_midpoint(env: Env, data: Vec<f64>, period: i32) -> NifResult<Term> {
    use crate::overlap_ffi::{TA_MIDPOINT_Lookback, TA_MIDPOINT};

    // Empty data → return empty (like Python)
    if data.is_empty() {
        return ok!(env, Vec::<Option<f64>>::new());
    }

    let data_len = data.len() as i32;

    // Calculate lookback period
    let lookback = unsafe { TA_MIDPOINT_Lookback(period) };

    // Prepare output buffers
    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; data_len as usize];

    // Call TA_MIDPOINT
    let ret_code = unsafe {
        TA_MIDPOINT(
            0,
            data_len - 1,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(env, ret_code, "MIDPOINT");

    // Build result with nil padding for lookback period
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Lookback is period - 1, but can't exceed data length
    let num_nils = std::cmp::min(lookback, data_len);

    // Add nil values for lookback period
    for _ in 0..num_nils {
        result.push(None);
    }

    // Add calculated MIDPOINT values
    for i in 0..out_nb_element {
        result.push(Some(out_real[i as usize]));
    }

    ok!(env, result)
}

// Implementation when ta-lib is available
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_t3(env: Env, data: Vec<f64>, period: i32, vfactor: f64) -> NifResult<Term> {
    use crate::overlap_ffi::{TA_T3_Lookback, TA_T3};

    // Empty data → return empty (like Python)
    if data.is_empty() {
        return ok!(env, Vec::<Option<f64>>::new());
    }

    let data_len = data.len() as i32;

    // Calculate lookback period
    let lookback = unsafe { TA_T3_Lookback(period, vfactor) };

    // Prepare output buffers
    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; data_len as usize];

    // Call TA_T3
    let ret_code = unsafe {
        TA_T3(
            0,
            data_len - 1,
            data.as_ptr(),
            period,
            vfactor,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(env, ret_code, "T3");

    // Build result with nil padding for lookback period
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Lookback can't exceed data length
    let num_nils = std::cmp::min(lookback, data_len);

    // Add nil values for lookback period
    for _ in 0..num_nils {
        result.push(None);
    }

    // Add calculated T3 values
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

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_dema(env: Env, _data: Vec<f64>, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_tema(env: Env, _data: Vec<f64>, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_midpoint(env: Env, _data: Vec<f64>, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_trima(env: Env, _data: Vec<f64>, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_t3(env: Env, _data: Vec<f64>, _period: i32, _vfactor: f64) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_kama(env: Env, data: Vec<f64>, period: i32) -> NifResult<Term> {
    use crate::overlap_ffi::*;

    // Empty input check
    if data.is_empty() {
        return ok!(env, Vec::<Option<f64>>::new());
    }

    let data_len = data.len() as i32;
    let start_idx = 0;
    let end_idx = data_len - 1;

    // Get lookback period
    let lookback = unsafe { TA_KAMA_Lookback(period) };

    // Allocate output buffer
    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; data_len as usize];

    // Call TA-Lib
    let ret_code = unsafe {
        TA_KAMA(
            start_idx,
            end_idx,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(env, ret_code, "KAMA");

    // Build result with nil padding for lookback period
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Lookback can't exceed data length
    let num_nils = std::cmp::min(lookback, data_len);

    // Add nil values for lookback period
    for _ in 0..num_nils {
        result.push(None);
    }

    // Add calculated KAMA values
    for i in 0..out_nb_element {
        result.push(Some(out_real[i as usize]));
    }

    ok!(env, result)
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_kama(env: Env, _data: Vec<f64>, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}
