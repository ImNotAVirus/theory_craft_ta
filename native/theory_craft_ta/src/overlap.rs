// Implementation when ta-lib is available
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sma(data: Vec<Option<f64>>, period: i32) -> Result<Vec<Option<f64>>, String> {
    use crate::helpers::{build_result, check_begidx, options_to_nan};
    use crate::overlap_ffi::{TA_SMA_Lookback, TA_SMA};

    if data.is_empty() {
        return Ok(Vec::new());
    }

    let clean_data = options_to_nan(&data);
    let length = clean_data.len();

    // Python ta-lib pattern: skip leading NaN values
    let begidx = check_begidx(&clean_data);
    let endidx = (length - begidx - 1) as i32;

    // Calculate lookback from the beginning of valid data
    let lookback = unsafe { TA_SMA_Lookback(period) };
    let total_lookback = begidx as i32 + lookback;

    // If not enough valid data, return all None
    if total_lookback >= length as i32 {
        return Ok(vec![None; length]);
    }

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let valid_data_len = length - begidx;
    let mut out_real: Vec<f64> = vec![0.0; valid_data_len];

    // Call ta-lib with data starting from begidx
    let ret_code = unsafe {
        TA_SMA(
            0,
            endidx,
            clean_data[begidx..].as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(ret_code, "SMA");

    let result = build_result(total_lookback, out_nb_element, &out_real);

    Ok(result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_ema(data: Vec<Option<f64>>, period: i32) -> Result<Vec<Option<f64>>, String> {
    use crate::helpers::{build_result, check_begidx, options_to_nan};
    use crate::overlap_ffi::{TA_EMA_Lookback, TA_EMA};

    if data.is_empty() {
        return Ok(Vec::new());
    }

    let clean_data = options_to_nan(&data);
    let length = clean_data.len();

    let begidx = check_begidx(&clean_data);
    let endidx = (length - begidx - 1) as i32;

    let lookback = unsafe { TA_EMA_Lookback(period) };
    let total_lookback = begidx as i32 + lookback;

    if total_lookback >= length as i32 {
        return Ok(vec![None; length]);
    }

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let valid_data_len = length - begidx;
    let mut out_real: Vec<f64> = vec![0.0; valid_data_len];

    let ret_code = unsafe {
        TA_EMA(
            0,
            endidx,
            clean_data[begidx..].as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(ret_code, "EMA");

    let result = build_result(total_lookback, out_nb_element, &out_real);

    Ok(result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_wma(data: Vec<Option<f64>>, period: i32) -> Result<Vec<Option<f64>>, String> {
    use crate::helpers::{build_result, check_begidx, options_to_nan};
    use crate::overlap_ffi::{TA_WMA_Lookback, TA_WMA};

    if data.is_empty() {
        return Ok(Vec::new());
    }

    let clean_data = options_to_nan(&data);
    let length = clean_data.len();

    let begidx = check_begidx(&clean_data);
    let endidx = (length - begidx - 1) as i32;

    let lookback = unsafe { TA_WMA_Lookback(period) };
    let total_lookback = begidx as i32 + lookback;

    if total_lookback >= length as i32 {
        return Ok(vec![None; length]);
    }

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let valid_data_len = length - begidx;
    let mut out_real: Vec<f64> = vec![0.0; valid_data_len];

    let ret_code = unsafe {
        TA_WMA(
            0,
            endidx,
            clean_data[begidx..].as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(ret_code, "WMA");

    let result = build_result(total_lookback, out_nb_element, &out_real);

    Ok(result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_dema(data: Vec<Option<f64>>, period: i32) -> Result<Vec<Option<f64>>, String> {
    use crate::helpers::{build_result, check_begidx, options_to_nan};
    use crate::overlap_ffi::{TA_DEMA_Lookback, TA_DEMA};

    if data.is_empty() {
        return Ok(Vec::new());
    }

    let clean_data = options_to_nan(&data);
    let length = clean_data.len();

    let begidx = check_begidx(&clean_data);
    let endidx = (length - begidx - 1) as i32;

    let lookback = unsafe { TA_DEMA_Lookback(period) };
    let total_lookback = begidx as i32 + lookback;

    if total_lookback >= length as i32 {
        return Ok(vec![None; length]);
    }

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let valid_data_len = length - begidx;
    let mut out_real: Vec<f64> = vec![0.0; valid_data_len];

    let ret_code = unsafe {
        TA_DEMA(
            0,
            endidx,
            clean_data[begidx..].as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(ret_code, "DEMA");

    let result = build_result(total_lookback, out_nb_element, &out_real);

    Ok(result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_tema(data: Vec<Option<f64>>, period: i32) -> Result<Vec<Option<f64>>, String> {
    use crate::helpers::{build_result, check_begidx, options_to_nan};
    use crate::overlap_ffi::{TA_TEMA_Lookback, TA_TEMA};

    if data.is_empty() {
        return Ok(Vec::new());
    }

    let clean_data = options_to_nan(&data);
    let length = clean_data.len();

    let begidx = check_begidx(&clean_data);
    let endidx = (length - begidx - 1) as i32;

    let lookback = unsafe { TA_TEMA_Lookback(period) };
    let total_lookback = begidx as i32 + lookback;

    if total_lookback >= length as i32 {
        return Ok(vec![None; length]);
    }

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let valid_data_len = length - begidx;
    let mut out_real: Vec<f64> = vec![0.0; valid_data_len];

    let ret_code = unsafe {
        TA_TEMA(
            0,
            endidx,
            clean_data[begidx..].as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(ret_code, "TEMA");

    let result = build_result(total_lookback, out_nb_element, &out_real);

    Ok(result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_trima(data: Vec<Option<f64>>, period: i32) -> Result<Vec<Option<f64>>, String> {
    use crate::helpers::{build_result, check_begidx, options_to_nan};
    use crate::overlap_ffi::{TA_TRIMA_Lookback, TA_TRIMA};

    if data.is_empty() {
        return Ok(Vec::new());
    }

    let clean_data = options_to_nan(&data);
    let length = clean_data.len();

    let begidx = check_begidx(&clean_data);
    let endidx = (length - begidx - 1) as i32;

    let lookback = unsafe { TA_TRIMA_Lookback(period) };
    let total_lookback = begidx as i32 + lookback;

    if total_lookback >= length as i32 {
        return Ok(vec![None; length]);
    }

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let valid_data_len = length - begidx;
    let mut out_real: Vec<f64> = vec![0.0; valid_data_len];

    let ret_code = unsafe {
        TA_TRIMA(
            0,
            endidx,
            clean_data[begidx..].as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(ret_code, "TRIMA");

    let result = build_result(total_lookback, out_nb_element, &out_real);

    Ok(result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_midpoint(data: Vec<Option<f64>>, period: i32) -> Result<Vec<Option<f64>>, String> {
    use crate::helpers::{build_result, check_begidx, options_to_nan};
    use crate::overlap_ffi::{TA_MIDPOINT_Lookback, TA_MIDPOINT};

    if data.is_empty() {
        return Ok(Vec::new());
    }

    let clean_data = options_to_nan(&data);
    let length = clean_data.len();

    let begidx = check_begidx(&clean_data);
    let endidx = (length - begidx - 1) as i32;

    let lookback = unsafe { TA_MIDPOINT_Lookback(period) };
    let total_lookback = begidx as i32 + lookback;

    if total_lookback >= length as i32 {
        return Ok(vec![None; length]);
    }

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let valid_data_len = length - begidx;
    let mut out_real: Vec<f64> = vec![0.0; valid_data_len];

    let ret_code = unsafe {
        TA_MIDPOINT(
            0,
            endidx,
            clean_data[begidx..].as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(ret_code, "MIDPOINT");

    let result = build_result(total_lookback, out_nb_element, &out_real);

    Ok(result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_t3(
    data: Vec<Option<f64>>,
    period: i32,
    vfactor: f64,
) -> Result<Vec<Option<f64>>, String> {
    use crate::helpers::{build_result, check_begidx, options_to_nan};
    use crate::overlap_ffi::{TA_T3_Lookback, TA_T3};

    if data.is_empty() {
        return Ok(Vec::new());
    }

    let clean_data = options_to_nan(&data);
    let length = clean_data.len();

    let begidx = check_begidx(&clean_data);
    let endidx = (length - begidx - 1) as i32;

    let lookback = unsafe { TA_T3_Lookback(period, vfactor) };
    let total_lookback = begidx as i32 + lookback;

    if total_lookback >= length as i32 {
        return Ok(vec![None; length]);
    }

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let valid_data_len = length - begidx;
    let mut out_real: Vec<f64> = vec![0.0; valid_data_len];

    let ret_code = unsafe {
        TA_T3(
            0,
            endidx,
            clean_data[begidx..].as_ptr(),
            period,
            vfactor,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    check_ret_code!(ret_code, "T3");

    let result = build_result(total_lookback, out_nb_element, &out_real);

    Ok(result)
}

// Stub implementations when ta-lib is not available
#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_sma(_data: Vec<Option<f64>>, _period: i32) -> Result<Vec<Option<f64>>, String> {
    Err("SMA: TA-Lib not available. Please use the Elixir backend.".to_string())
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_ema(_data: Vec<Option<f64>>, _period: i32) -> Result<Vec<Option<f64>>, String> {
    Err("EMA: TA-Lib not available. Please use the Elixir backend.".to_string())
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_wma(_data: Vec<Option<f64>>, _period: i32) -> Result<Vec<Option<f64>>, String> {
    Err("WMA: TA-Lib not available. Please use the Elixir backend.".to_string())
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_dema(_data: Vec<Option<f64>>, _period: i32) -> Result<Vec<Option<f64>>, String> {
    Err("DEMA: TA-Lib not available. Please use the Elixir backend.".to_string())
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_tema(_data: Vec<Option<f64>>, _period: i32) -> Result<Vec<Option<f64>>, String> {
    Err("TEMA: TA-Lib not available. Please use the Elixir backend.".to_string())
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_trima(_data: Vec<Option<f64>>, _period: i32) -> Result<Vec<Option<f64>>, String> {
    Err("TRIMA: TA-Lib not available. Please use the Elixir backend.".to_string())
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_midpoint(_data: Vec<Option<f64>>, _period: i32) -> Result<Vec<Option<f64>>, String> {
    Err("MIDPOINT: TA-Lib not available. Please use the Elixir backend.".to_string())
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_t3(
    _data: Vec<Option<f64>>,
    _period: i32,
    _vfactor: f64,
) -> Result<Vec<Option<f64>>, String> {
    Err("T3: TA-Lib not available. Please use the Elixir backend.".to_string())
}
