use rustler::{Encoder, Env, NifResult, Term};

// Define local atoms specific to overlap module
mod atoms {
    rustler::atoms! {
        create,
        update,
    }
}

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

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sma_next(
    env: Env,
    data: Vec<f64>,
    period: i32,
    prev: Vec<Option<f64>>,
) -> NifResult<Term> {
    use crate::overlap_ffi::TA_SMA;

    let data_len = data.len();
    let prev_len = prev.len();

    if data_len == 0 {
        return ok!(env, Vec::<Option<f64>>::new());
    }

    let should_update = data_len == prev_len;
    let should_append = data_len == prev_len + 1;

    if !should_update && !should_append {
        return error!(
            env,
            "Input size must be equal to or one more than prev size"
        );
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

    check_ret_code!(env, ret_code, "SMA_NEXT");

    let new_sma = if out_nb_element > 0 {
        Some(out_real[0])
    } else {
        None
    };

    let result = if should_update {
        (atoms::update(), new_sma)
    } else {
        (atoms::create(), new_sma)
    };

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
pub fn overlap_sma_next(
    env: Env,
    _data: Vec<f64>,
    _period: i32,
    _prev: Vec<Option<f64>>,
) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}
