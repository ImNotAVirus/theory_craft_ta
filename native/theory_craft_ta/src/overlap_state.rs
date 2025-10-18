use rustler::{Encoder, Env, NifResult, ResourceArc, Term};

/// State for EMA calculation
#[derive(Clone)]
pub struct EMAState {
    period: i32,
    k: f64,
    current_ema: Option<f64>,
    lookback_count: i32,
    buffer: Vec<f64>,
}

/// State for SMA calculation
pub struct SMAState {
    period: i32,
    buffer: Vec<f64>,
    lookback_count: i32,
}

/// State for WMA calculation
pub struct WMAState {
    period: i32,
    buffer: Vec<f64>,
    lookback_count: i32,
}

/// State for DEMA calculation
pub struct DEMAState {
    period: i32,
    lookback_count: i32,
    ema1_state: Box<EMAState>,
    ema2_state: Box<EMAState>,
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_ema_state_init(env: Env, period: i32) -> NifResult<Term> {
    if period < 2 {
        return error!(env, "Invalid period: must be >= 2 for EMA");
    }

    let k = 2.0 / (period as f64 + 1.0);
    let state = EMAState {
        period,
        k,
        current_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    };

    let resource = ResourceArc::new(state);
    ok!(env, resource)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_ema_state_next(
    env: Env,
    state_arc: ResourceArc<EMAState>,
    value: f64,
    is_new_bar: bool,
) -> NifResult<Term> {
    let state = &*state_arc;

    let new_lookback = if is_new_bar {
        state.lookback_count + 1
    } else {
        state.lookback_count
    };

    // Update buffer
    let mut new_buffer = state.buffer.clone();
    if is_new_bar || new_buffer.is_empty() {
        new_buffer.push(value);
    } else {
        let last_idx = new_buffer.len() - 1;
        new_buffer[last_idx] = value;
    }

    // Warmup phase: need 'period' bars before we can calculate EMA
    if new_lookback < state.period {
        let new_state = EMAState {
            period: state.period,
            k: state.k,
            current_ema: state.current_ema,
            lookback_count: new_lookback,
            buffer: new_buffer,
        };
        let new_resource = ResourceArc::new(new_state);
        let result = (rustler::types::atom::nil(), new_resource);
        return ok!(env, result);
    }

    // Calculate new EMA
    let new_ema = match state.current_ema {
        None => {
            // First EMA: use SMA as seed (average of all values in buffer)
            let sum: f64 = new_buffer.iter().sum();
            sum / (state.period as f64)
        }
        Some(prev_ema) => (value - prev_ema) * state.k + prev_ema,
    };

    let new_state = EMAState {
        period: state.period,
        k: state.k,
        current_ema: Some(new_ema),
        lookback_count: new_lookback,
        buffer: new_buffer,
    };

    let new_resource = ResourceArc::new(new_state);
    let result = (new_ema, new_resource);
    ok!(env, result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sma_state_init(env: Env, period: i32) -> NifResult<Term> {
    if period < 2 {
        return error!(env, "Invalid period: must be >= 2 for SMA");
    }

    let state = SMAState {
        period,
        buffer: Vec::new(),
        lookback_count: 0,
    };

    let resource = ResourceArc::new(state);
    ok!(env, resource)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sma_state_next(
    env: Env,
    state_arc: ResourceArc<SMAState>,
    value: f64,
    is_new_bar: bool,
) -> NifResult<Term> {
    let state = &*state_arc;

    let mut new_buffer = state.buffer.clone();
    let new_lookback = if is_new_bar {
        state.lookback_count + 1
    } else {
        state.lookback_count
    };

    // Update buffer
    if is_new_bar {
        new_buffer.push(value);
        if new_buffer.len() > state.period as usize {
            new_buffer.remove(0);
        }
    } else {
        // UPDATE mode: replace last value
        if !new_buffer.is_empty() {
            let last_idx = new_buffer.len() - 1;
            new_buffer[last_idx] = value;
        } else {
            // First value in first bar
            new_buffer.push(value);
        }
    }

    // Warmup phase: need 'period' bars
    if new_lookback < state.period {
        let new_state = SMAState {
            period: state.period,
            buffer: new_buffer,
            lookback_count: new_lookback,
        };
        let new_resource = ResourceArc::new(new_state);
        let result = (rustler::types::atom::nil(), new_resource);
        return ok!(env, result);
    }

    // Calculate SMA
    let sum: f64 = new_buffer.iter().sum();
    let sma = sum / (state.period as f64);

    let new_state = SMAState {
        period: state.period,
        buffer: new_buffer,
        lookback_count: new_lookback,
    };

    let new_resource = ResourceArc::new(new_state);
    let result = (sma, new_resource);
    ok!(env, result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_wma_state_init(env: Env, period: i32) -> NifResult<Term> {
    if period < 2 {
        return error!(env, "Invalid period: must be >= 2 for WMA");
    }

    let state = WMAState {
        period,
        buffer: Vec::new(),
        lookback_count: 0,
    };

    let resource = ResourceArc::new(state);
    ok!(env, resource)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_wma_state_next(
    env: Env,
    state_arc: ResourceArc<WMAState>,
    value: f64,
    is_new_bar: bool,
) -> NifResult<Term> {
    let state = &*state_arc;

    let mut new_buffer = state.buffer.clone();
    let new_lookback = if is_new_bar {
        state.lookback_count + 1
    } else {
        state.lookback_count
    };

    // Update buffer
    if is_new_bar {
        new_buffer.push(value);
        if new_buffer.len() > state.period as usize {
            new_buffer.remove(0);
        }
    } else {
        // UPDATE mode: replace last value
        if !new_buffer.is_empty() {
            let last_idx = new_buffer.len() - 1;
            new_buffer[last_idx] = value;
        } else {
            // First value in first bar
            new_buffer.push(value);
        }
    }

    // Warmup phase: need 'period' bars
    if new_lookback < state.period {
        let new_state = WMAState {
            period: state.period,
            buffer: new_buffer,
            lookback_count: new_lookback,
        };
        let new_resource = ResourceArc::new(new_state);
        let result = (rustler::types::atom::nil(), new_resource);
        return ok!(env, result);
    }

    // Calculate WMA
    // Sum of weights: 1 + 2 + ... + period = period * (period + 1) / 2
    let sum_weights = (state.period * (state.period + 1)) as f64 / 2.0;

    // Weighted sum: buffer[0] * 1 + buffer[1] * 2 + ... + buffer[period-1] * period
    let weighted_sum: f64 = new_buffer
        .iter()
        .enumerate()
        .map(|(i, &val)| val * (i + 1) as f64)
        .sum();

    let wma = weighted_sum / sum_weights;

    let new_state = WMAState {
        period: state.period,
        buffer: new_buffer,
        lookback_count: new_lookback,
    };

    let new_resource = ResourceArc::new(new_state);
    let result = (wma, new_resource);
    ok!(env, result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_dema_state_init(env: Env, period: i32) -> NifResult<Term> {
    if period < 2 {
        return error!(env, "Invalid period: must be >= 2 for DEMA");
    }

    let k = 2.0 / (period as f64 + 1.0);
    let ema1_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let ema2_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let state = DEMAState {
        period,
        lookback_count: 0,
        ema1_state,
        ema2_state,
    };

    let resource = ResourceArc::new(state);
    ok!(env, resource)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_dema_state_next(
    env: Env,
    state_arc: ResourceArc<DEMAState>,
    value: f64,
    is_new_bar: bool,
) -> NifResult<Term> {
    let state = &*state_arc;

    // Update lookback count
    let new_lookback = if is_new_bar {
        state.lookback_count + 1
    } else {
        state.lookback_count
    };

    // Calculate first EMA
    let ema1_state = &*state.ema1_state;
    let new_lookback_ema1 = if is_new_bar {
        ema1_state.lookback_count + 1
    } else {
        ema1_state.lookback_count
    };

    // Update buffer for EMA1
    let mut new_buffer_ema1 = ema1_state.buffer.clone();
    if is_new_bar || new_buffer_ema1.is_empty() {
        new_buffer_ema1.push(value);
    } else {
        let last_idx = new_buffer_ema1.len() - 1;
        new_buffer_ema1[last_idx] = value;
    }

    // Calculate EMA1 value
    let (ema1_value, new_ema1_current) = if new_lookback_ema1 < ema1_state.period {
        (None, ema1_state.current_ema)
    } else {
        let new_ema = match ema1_state.current_ema {
            None => {
                let sum: f64 = new_buffer_ema1.iter().sum();
                sum / (ema1_state.period as f64)
            }
            Some(prev_ema) => (value - prev_ema) * ema1_state.k + prev_ema,
        };
        (Some(new_ema), Some(new_ema))
    };

    let new_ema1_state = Box::new(EMAState {
        period: ema1_state.period,
        k: ema1_state.k,
        current_ema: new_ema1_current,
        lookback_count: new_lookback_ema1,
        buffer: new_buffer_ema1,
    });

    // Calculate second EMA (EMA of EMA1)
    let (ema2_value, new_ema2_state) = if let Some(ema1_val) = ema1_value {
        let ema2_state = &*state.ema2_state;
        let new_lookback_ema2 = if is_new_bar {
            ema2_state.lookback_count + 1
        } else {
            ema2_state.lookback_count
        };

        // Update buffer for EMA2
        let mut new_buffer_ema2 = ema2_state.buffer.clone();
        if is_new_bar || new_buffer_ema2.is_empty() {
            new_buffer_ema2.push(ema1_val);
        } else {
            let last_idx = new_buffer_ema2.len() - 1;
            new_buffer_ema2[last_idx] = ema1_val;
        }

        // Calculate EMA2 value
        let (ema2_val, new_ema2_current) = if new_lookback_ema2 < ema2_state.period {
            (None, ema2_state.current_ema)
        } else {
            let new_ema = match ema2_state.current_ema {
                None => {
                    let sum: f64 = new_buffer_ema2.iter().sum();
                    sum / (ema2_state.period as f64)
                }
                Some(prev_ema) => (ema1_val - prev_ema) * ema2_state.k + prev_ema,
            };
            (Some(new_ema), Some(new_ema))
        };

        let new_state = Box::new(EMAState {
            period: ema2_state.period,
            k: ema2_state.k,
            current_ema: new_ema2_current,
            lookback_count: new_lookback_ema2,
            buffer: new_buffer_ema2,
        });

        (ema2_val, new_state)
    } else {
        // During warmup of first EMA, don't update second EMA
        (None, state.ema2_state.clone())
    };

    let new_state = DEMAState {
        period: state.period,
        lookback_count: new_lookback,
        ema1_state: new_ema1_state,
        ema2_state: new_ema2_state,
    };

    let new_resource = ResourceArc::new(new_state);

    // Calculate DEMA = 2 * EMA1 - EMA2
    match (ema1_value, ema2_value) {
        (Some(e1), Some(e2)) => {
            let dema = 2.0 * e1 - e2;
            let result = (dema, new_resource);
            ok!(env, result)
        }
        _ => {
            let result = (rustler::types::atom::nil(), new_resource);
            ok!(env, result)
        }
    }
}

// Stub implementations when ta-lib is not available
#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_ema_state_init(env: Env, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_ema_state_next(
    env: Env,
    _state: Term,
    _value: f64,
    _is_new_bar: bool,
) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_sma_state_init(env: Env, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_sma_state_next(
    env: Env,
    _state: Term,
    _value: f64,
    _is_new_bar: bool,
) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_wma_state_init(env: Env, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_wma_state_next(
    env: Env,
    _state: Term,
    _value: f64,
    _is_new_bar: bool,
) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_dema_state_init(env: Env, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_dema_state_next(
    env: Env,
    _state: Term,
    _value: f64,
    _is_new_bar: bool,
) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}
