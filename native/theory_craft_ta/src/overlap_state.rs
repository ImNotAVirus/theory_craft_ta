use rustler::{Encoder, Env, NifResult, ResourceArc, Term};

/// State for EMA calculation
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
