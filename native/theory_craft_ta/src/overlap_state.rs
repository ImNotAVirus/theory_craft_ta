use rustler::{Encoder, Env, NifResult, ResourceArc, Term};

/// State for EMA calculation
#[derive(Clone)]
pub struct EMAState {
    period: i32,
    k: f64,
    current_ema: Option<f64>, // EMA of current bar (can change in UPDATE mode)
    prev_ema: Option<f64>,    // EMA of previous bar (persisted in APPEND mode)
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

/// State for TEMA calculation
pub struct TEMAState {
    period: i32,
    lookback_count: i32,
    ema1_state: Box<EMAState>,
    ema2_state: Box<EMAState>,
    ema3_state: Box<EMAState>,
}

/// State for TRIMA calculation
pub struct TRIMAState {
    period: i32,
    first_period: i32,
    second_period: i32,
    lookback_count: i32,
    first_sma_buffer: Vec<f64>,
    second_sma_buffer: Vec<f64>,
}

/// State for MIDPOINT calculation
pub struct MIDPOINTState {
    period: i32,
    buffer: Vec<f64>,
    lookback_count: i32,
}

/// State for T3 calculation
pub struct T3State {
    period: i32,
    vfactor: f64,
    lookback_count: i32,
    ema1_state: Box<EMAState>,
    ema2_state: Box<EMAState>,
    ema3_state: Box<EMAState>,
    ema4_state: Box<EMAState>,
    ema5_state: Box<EMAState>,
    ema6_state: Box<EMAState>,
}

/// State for SAR calculation
#[derive(Clone)]
pub struct SARState {
    acceleration: f64,
    maximum: f64,
    is_long: Option<bool>,
    sar: Option<f64>,
    ep: Option<f64>,
    af: f64,
    prev_high: Option<f64>,
    prev_low: Option<f64>,
    bar_count: i32,
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
        prev_ema: None,
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
            prev_ema: state.prev_ema,
            lookback_count: new_lookback,
            buffer: new_buffer,
        };
        let new_resource = ResourceArc::new(new_state);
        let result = (rustler::types::atom::nil(), new_resource);
        return ok!(env, result);
    }

    // Calculate new EMA
    let (new_ema, new_prev_ema) = if is_new_bar {
        // APPEND mode: calculate new EMA and persist previous one
        let ema = match state.current_ema {
            None => {
                // First EMA: use SMA as seed (average of all values in buffer)
                let sum: f64 = new_buffer.iter().sum();
                sum / (state.period as f64)
            }
            Some(current) => (value - current) * state.k + current,
        };
        // In APPEND: current_ema becomes prev_ema for next iteration
        (ema, state.current_ema)
    } else {
        // UPDATE mode: only recalculate last value using prev_ema
        let ema = match state.prev_ema {
            None => {
                // First bar being updated: use SMA
                let sum: f64 = new_buffer.iter().sum();
                sum / (state.period as f64)
            }
            Some(prev) => (value - prev) * state.k + prev,
        };
        // In UPDATE: prev_ema stays the same
        (ema, state.prev_ema)
    };

    let new_state = EMAState {
        period: state.period,
        k: state.k,
        current_ema: Some(new_ema),
        prev_ema: new_prev_ema,
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
        prev_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let ema2_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        prev_ema: None,
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
    let (ema1_value, new_ema1_current, new_ema1_prev) = if new_lookback_ema1 < ema1_state.period {
        (None, ema1_state.current_ema, ema1_state.prev_ema)
    } else {
        let (ema, prev) = if is_new_bar {
            // APPEND mode: calculate new EMA and persist previous one
            let e = match ema1_state.current_ema {
                None => {
                    let sum: f64 = new_buffer_ema1.iter().sum();
                    sum / (ema1_state.period as f64)
                }
                Some(current) => (value - current) * ema1_state.k + current,
            };
            (e, ema1_state.current_ema)
        } else {
            // UPDATE mode: only recalculate last value using prev_ema
            let e = match ema1_state.prev_ema {
                None => {
                    let sum: f64 = new_buffer_ema1.iter().sum();
                    sum / (ema1_state.period as f64)
                }
                Some(prev) => (value - prev) * ema1_state.k + prev,
            };
            (e, ema1_state.prev_ema)
        };
        (Some(ema), Some(ema), prev)
    };

    let new_ema1_state = Box::new(EMAState {
        period: ema1_state.period,
        k: ema1_state.k,
        current_ema: new_ema1_current,
        prev_ema: new_ema1_prev,
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
        let (ema2_val, new_ema2_current, new_ema2_prev) = if new_lookback_ema2 < ema2_state.period {
            (None, ema2_state.current_ema, ema2_state.prev_ema)
        } else {
            let (ema, prev) = if is_new_bar {
                // APPEND mode: calculate new EMA and persist previous one
                let e = match ema2_state.current_ema {
                    None => {
                        let sum: f64 = new_buffer_ema2.iter().sum();
                        sum / (ema2_state.period as f64)
                    }
                    Some(current) => (ema1_val - current) * ema2_state.k + current,
                };
                (e, ema2_state.current_ema)
            } else {
                // UPDATE mode: only recalculate last value using prev_ema
                let e = match ema2_state.prev_ema {
                    None => {
                        let sum: f64 = new_buffer_ema2.iter().sum();
                        sum / (ema2_state.period as f64)
                    }
                    Some(prev) => (ema1_val - prev) * ema2_state.k + prev,
                };
                (e, ema2_state.prev_ema)
            };
            (Some(ema), Some(ema), prev)
        };

        let new_state = Box::new(EMAState {
            period: ema2_state.period,
            k: ema2_state.k,
            current_ema: new_ema2_current,
            prev_ema: new_ema2_prev,
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

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_tema_state_init(env: Env, period: i32) -> NifResult<Term> {
    if period < 2 {
        return error!(env, "Invalid period: must be >= 2 for TEMA");
    }

    let k = 2.0 / (period as f64 + 1.0);
    let ema1_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        prev_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let ema2_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        prev_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let ema3_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        prev_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let state = TEMAState {
        period,
        lookback_count: 0,
        ema1_state,
        ema2_state,
        ema3_state,
    };

    let resource = ResourceArc::new(state);
    ok!(env, resource)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_tema_state_next(
    env: Env,
    state_arc: ResourceArc<TEMAState>,
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
    let (ema1_value, new_ema1_current, new_ema1_prev) = if new_lookback_ema1 < ema1_state.period {
        (None, ema1_state.current_ema, ema1_state.prev_ema)
    } else {
        let (ema, prev) = if is_new_bar {
            // APPEND mode: calculate new EMA and persist previous one
            let e = match ema1_state.current_ema {
                None => {
                    let sum: f64 = new_buffer_ema1.iter().sum();
                    sum / (ema1_state.period as f64)
                }
                Some(current) => (value - current) * ema1_state.k + current,
            };
            (e, ema1_state.current_ema)
        } else {
            // UPDATE mode: only recalculate last value using prev_ema
            let e = match ema1_state.prev_ema {
                None => {
                    let sum: f64 = new_buffer_ema1.iter().sum();
                    sum / (ema1_state.period as f64)
                }
                Some(prev) => (value - prev) * ema1_state.k + prev,
            };
            (e, ema1_state.prev_ema)
        };
        (Some(ema), Some(ema), prev)
    };

    let new_ema1_state = Box::new(EMAState {
        period: ema1_state.period,
        k: ema1_state.k,
        current_ema: new_ema1_current,
        prev_ema: new_ema1_prev,
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
        let (ema2_val, new_ema2_current, new_ema2_prev) = if new_lookback_ema2 < ema2_state.period {
            (None, ema2_state.current_ema, ema2_state.prev_ema)
        } else {
            let (ema, prev) = if is_new_bar {
                // APPEND mode: calculate new EMA and persist previous one
                let e = match ema2_state.current_ema {
                    None => {
                        let sum: f64 = new_buffer_ema2.iter().sum();
                        sum / (ema2_state.period as f64)
                    }
                    Some(current) => (ema1_val - current) * ema2_state.k + current,
                };
                (e, ema2_state.current_ema)
            } else {
                // UPDATE mode: only recalculate last value using prev_ema
                let e = match ema2_state.prev_ema {
                    None => {
                        let sum: f64 = new_buffer_ema2.iter().sum();
                        sum / (ema2_state.period as f64)
                    }
                    Some(prev) => (ema1_val - prev) * ema2_state.k + prev,
                };
                (e, ema2_state.prev_ema)
            };
            (Some(ema), Some(ema), prev)
        };

        let new_state = Box::new(EMAState {
            period: ema2_state.period,
            k: ema2_state.k,
            current_ema: new_ema2_current,
            prev_ema: new_ema2_prev,
            lookback_count: new_lookback_ema2,
            buffer: new_buffer_ema2,
        });

        (ema2_val, new_state)
    } else {
        // During warmup of first EMA, don't update second EMA
        (None, state.ema2_state.clone())
    };

    // Calculate third EMA (EMA of EMA2)
    let (ema3_value, new_ema3_state) = if let Some(ema2_val) = ema2_value {
        let ema3_state = &*state.ema3_state;
        let new_lookback_ema3 = if is_new_bar {
            ema3_state.lookback_count + 1
        } else {
            ema3_state.lookback_count
        };

        // Update buffer for EMA3
        let mut new_buffer_ema3 = ema3_state.buffer.clone();
        if is_new_bar || new_buffer_ema3.is_empty() {
            new_buffer_ema3.push(ema2_val);
        } else {
            let last_idx = new_buffer_ema3.len() - 1;
            new_buffer_ema3[last_idx] = ema2_val;
        }

        // Calculate EMA3 value
        let (ema3_val, new_ema3_current, new_ema3_prev) = if new_lookback_ema3 < ema3_state.period {
            (None, ema3_state.current_ema, ema3_state.prev_ema)
        } else {
            let (ema, prev) = if is_new_bar {
                // APPEND mode: calculate new EMA and persist previous one
                let e = match ema3_state.current_ema {
                    None => {
                        let sum: f64 = new_buffer_ema3.iter().sum();
                        sum / (ema3_state.period as f64)
                    }
                    Some(current) => (ema2_val - current) * ema3_state.k + current,
                };
                (e, ema3_state.current_ema)
            } else {
                // UPDATE mode: only recalculate last value using prev_ema
                let e = match ema3_state.prev_ema {
                    None => {
                        let sum: f64 = new_buffer_ema3.iter().sum();
                        sum / (ema3_state.period as f64)
                    }
                    Some(prev) => (ema2_val - prev) * ema3_state.k + prev,
                };
                (e, ema3_state.prev_ema)
            };
            (Some(ema), Some(ema), prev)
        };

        let new_state = Box::new(EMAState {
            period: ema3_state.period,
            k: ema3_state.k,
            current_ema: new_ema3_current,
            prev_ema: new_ema3_prev,
            lookback_count: new_lookback_ema3,
            buffer: new_buffer_ema3,
        });

        (ema3_val, new_state)
    } else {
        // During warmup of second EMA, don't update third EMA
        (None, state.ema3_state.clone())
    };

    let new_state = TEMAState {
        period: state.period,
        lookback_count: new_lookback,
        ema1_state: new_ema1_state,
        ema2_state: new_ema2_state,
        ema3_state: new_ema3_state,
    };

    let new_resource = ResourceArc::new(new_state);

    // Calculate TEMA = 3 * EMA1 - 3 * EMA2 + EMA3
    match (ema1_value, ema2_value, ema3_value) {
        (Some(e1), Some(e2), Some(e3)) => {
            let tema = 3.0 * e1 - 3.0 * e2 + e3;
            let result = (tema, new_resource);
            ok!(env, result)
        }
        _ => {
            let result = (rustler::types::atom::nil(), new_resource);
            ok!(env, result)
        }
    }
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_trima_state_init(env: Env, period: i32) -> NifResult<Term> {
    if period < 2 {
        return error!(env, "Invalid period: must be >= 2 for TRIMA");
    }

    // Calculate periods for double smoothing
    let (first_period, second_period) = if period < 3 {
        // For period < 3, TRIMA = SMA
        (period, period)
    } else if period % 2 == 1 {
        // Odd period
        let half = (period + 1) / 2;
        (half, half)
    } else {
        // Even period
        let half = period / 2;
        (half, half + 1)
    };

    let state = TRIMAState {
        period,
        first_period,
        second_period,
        lookback_count: 0,
        first_sma_buffer: Vec::new(),
        second_sma_buffer: Vec::new(),
    };

    let resource = ResourceArc::new(state);
    ok!(env, resource)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_trima_state_next(
    env: Env,
    state_arc: ResourceArc<TRIMAState>,
    value: f64,
    is_new_bar: bool,
) -> NifResult<Term> {
    let state = &*state_arc;

    let new_lookback = if is_new_bar {
        state.lookback_count + 1
    } else {
        state.lookback_count
    };

    // Update first SMA buffer
    let mut new_first_buffer = state.first_sma_buffer.clone();
    if is_new_bar {
        new_first_buffer.push(value);
        if new_first_buffer.len() > state.first_period as usize {
            new_first_buffer.remove(0);
        }
    } else if !new_first_buffer.is_empty() {
        let last_idx = new_first_buffer.len() - 1;
        new_first_buffer[last_idx] = value;
    } else {
        new_first_buffer.push(value);
    }

    // Calculate first SMA if we have enough data
    let first_sma = if new_first_buffer.len() >= state.first_period as usize {
        let sum: f64 = new_first_buffer.iter().sum();
        Some(sum / (state.first_period as f64))
    } else {
        None
    };

    // Update second SMA buffer with first SMA value
    let mut new_second_buffer = state.second_sma_buffer.clone();
    if let Some(sma1) = first_sma {
        if is_new_bar {
            new_second_buffer.push(sma1);
            if new_second_buffer.len() > state.second_period as usize {
                new_second_buffer.remove(0);
            }
        } else if !new_second_buffer.is_empty() {
            let last_idx = new_second_buffer.len() - 1;
            new_second_buffer[last_idx] = sma1;
        } else {
            new_second_buffer.push(sma1);
        }
    }

    // Calculate TRIMA (second SMA)
    let trima = if state.period < 3 {
        // For period < 3, TRIMA = first SMA
        first_sma
    } else if new_second_buffer.len() >= state.second_period as usize {
        let sum: f64 = new_second_buffer.iter().sum();
        Some(sum / (state.second_period as f64))
    } else {
        None
    };

    let new_state = TRIMAState {
        period: state.period,
        first_period: state.first_period,
        second_period: state.second_period,
        lookback_count: new_lookback,
        first_sma_buffer: new_first_buffer,
        second_sma_buffer: new_second_buffer,
    };

    let new_resource = ResourceArc::new(new_state);

    match trima {
        Some(value) => {
            let result = (value, new_resource);
            ok!(env, result)
        }
        None => {
            let result = (rustler::types::atom::nil(), new_resource);
            ok!(env, result)
        }
    }
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_midpoint_state_init(env: Env, period: i32) -> NifResult<Term> {
    if period < 2 {
        return error!(env, "Invalid period: must be >= 2 for MIDPOINT");
    }

    let state = MIDPOINTState {
        period,
        buffer: Vec::new(),
        lookback_count: 0,
    };

    let resource = ResourceArc::new(state);
    ok!(env, resource)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_midpoint_state_next(
    env: Env,
    state_arc: ResourceArc<MIDPOINTState>,
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
        let new_state = MIDPOINTState {
            period: state.period,
            buffer: new_buffer,
            lookback_count: new_lookback,
        };
        let new_resource = ResourceArc::new(new_state);
        let result = (rustler::types::atom::nil(), new_resource);
        return ok!(env, result);
    }

    // Calculate MIDPOINT = (MAX + MIN) / 2
    let max_val = new_buffer.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let min_val = new_buffer.iter().cloned().fold(f64::INFINITY, f64::min);
    let midpoint = (max_val + min_val) / 2.0;

    let new_state = MIDPOINTState {
        period: state.period,
        buffer: new_buffer,
        lookback_count: new_lookback,
    };

    let new_resource = ResourceArc::new(new_state);
    let result = (midpoint, new_resource);
    ok!(env, result)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_t3_state_init(env: Env, period: i32, vfactor: f64) -> NifResult<Term> {
    if period < 2 {
        return error!(env, "Invalid period: must be >= 2 for T3");
    }

    let k = 2.0 / (period as f64 + 1.0);

    let ema1_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        prev_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let ema2_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        prev_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let ema3_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        prev_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let ema4_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        prev_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let ema5_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        prev_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let ema6_state = Box::new(EMAState {
        period,
        k,
        current_ema: None,
        prev_ema: None,
        lookback_count: 0,
        buffer: Vec::new(),
    });

    let state = T3State {
        period,
        vfactor,
        lookback_count: 0,
        ema1_state,
        ema2_state,
        ema3_state,
        ema4_state,
        ema5_state,
        ema6_state,
    };

    let resource = ResourceArc::new(state);
    ok!(env, resource)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_t3_state_next(
    env: Env,
    state_arc: ResourceArc<T3State>,
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

    // Helper function to process EMA state
    let process_ema_state =
        |ema_state: &EMAState, input_value: f64, is_new: bool| -> (Option<f64>, Box<EMAState>) {
            let new_lb = if is_new {
                ema_state.lookback_count + 1
            } else {
                ema_state.lookback_count
            };

            let mut new_buf = ema_state.buffer.clone();
            if is_new || new_buf.is_empty() {
                new_buf.push(input_value);
            } else {
                let last_idx = new_buf.len() - 1;
                new_buf[last_idx] = input_value;
            }

            let (ema_val, new_current, new_prev) = if new_lb < ema_state.period {
                (None, ema_state.current_ema, ema_state.prev_ema)
            } else {
                let (ema, prev) = if is_new {
                    // APPEND mode: calculate new EMA and persist previous one
                    let e = match ema_state.current_ema {
                        None => {
                            let sum: f64 = new_buf.iter().sum();
                            sum / (ema_state.period as f64)
                        }
                        Some(current) => (input_value - current) * ema_state.k + current,
                    };
                    (e, ema_state.current_ema)
                } else {
                    // UPDATE mode: only recalculate last value using prev_ema
                    let e = match ema_state.prev_ema {
                        None => {
                            let sum: f64 = new_buf.iter().sum();
                            sum / (ema_state.period as f64)
                        }
                        Some(prev) => (input_value - prev) * ema_state.k + prev,
                    };
                    (e, ema_state.prev_ema)
                };
                (Some(ema), Some(ema), prev)
            };

            let new_state = Box::new(EMAState {
                period: ema_state.period,
                k: ema_state.k,
                current_ema: new_current,
                prev_ema: new_prev,
                lookback_count: new_lb,
                buffer: new_buf,
            });

            (ema_val, new_state)
        };

    // Process EMA1
    let (ema1_value, new_ema1_state) = process_ema_state(&state.ema1_state, value, is_new_bar);

    // Process EMA2 (EMA of EMA1)
    let (ema2_value, new_ema2_state) = if let Some(ema1_val) = ema1_value {
        process_ema_state(&state.ema2_state, ema1_val, is_new_bar)
    } else {
        (None, state.ema2_state.clone())
    };

    // Process EMA3 (EMA of EMA2)
    let (ema3_value, new_ema3_state) = if let Some(ema2_val) = ema2_value {
        process_ema_state(&state.ema3_state, ema2_val, is_new_bar)
    } else {
        (None, state.ema3_state.clone())
    };

    // Process EMA4 (EMA of EMA3)
    let (ema4_value, new_ema4_state) = if let Some(ema3_val) = ema3_value {
        process_ema_state(&state.ema4_state, ema3_val, is_new_bar)
    } else {
        (None, state.ema4_state.clone())
    };

    // Process EMA5 (EMA of EMA4)
    let (ema5_value, new_ema5_state) = if let Some(ema4_val) = ema4_value {
        process_ema_state(&state.ema5_state, ema4_val, is_new_bar)
    } else {
        (None, state.ema5_state.clone())
    };

    // Process EMA6 (EMA of EMA5)
    let (ema6_value, new_ema6_state) = if let Some(ema5_val) = ema5_value {
        process_ema_state(&state.ema6_state, ema5_val, is_new_bar)
    } else {
        (None, state.ema6_state.clone())
    };

    let new_state = T3State {
        period: state.period,
        vfactor: state.vfactor,
        lookback_count: new_lookback,
        ema1_state: new_ema1_state,
        ema2_state: new_ema2_state,
        ema3_state: new_ema3_state,
        ema4_state: new_ema4_state,
        ema5_state: new_ema5_state,
        ema6_state: new_ema6_state,
    };

    let new_resource = ResourceArc::new(new_state);

    // Calculate T3 = c1*e6 + c2*e5 + c3*e4 + c4*e3
    // where coefficients are based on vfactor
    match (ema3_value, ema4_value, ema5_value, ema6_value) {
        (Some(e3), Some(e4), Some(e5), Some(e6)) => {
            let c1 = -state.vfactor * state.vfactor * state.vfactor;
            let c2 = 3.0 * state.vfactor * state.vfactor
                + 3.0 * state.vfactor * state.vfactor * state.vfactor;
            let c3 = -6.0 * state.vfactor * state.vfactor
                - 3.0 * state.vfactor
                - 3.0 * state.vfactor * state.vfactor * state.vfactor;
            let c4 = 1.0
                + 3.0 * state.vfactor
                + state.vfactor * state.vfactor * state.vfactor
                + 3.0 * state.vfactor * state.vfactor;

            let t3 = c1 * e6 + c2 * e5 + c3 * e4 + c4 * e3;
            let result = (t3, new_resource);
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

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_tema_state_init(env: Env, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_tema_state_next(
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
pub fn overlap_midpoint_state_init(env: Env, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_midpoint_state_next(
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
pub fn overlap_trima_state_init(env: Env, _period: i32) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_trima_state_next(
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
pub fn overlap_t3_state_init(env: Env, _period: i32, _vfactor: f64) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_t3_state_next(
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

// SAR State implementation
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sar_state_init(env: Env, acceleration: f64, maximum: f64) -> NifResult<Term> {
    if acceleration <= 0.0 {
        return error!(env, "acceleration must be positive");
    }

    if maximum <= 0.0 {
        return error!(env, "maximum must be positive");
    }

    if acceleration > maximum {
        return error!(env, "acceleration must be less than or equal to maximum");
    }

    let state = SARState {
        acceleration,
        maximum,
        is_long: None,
        sar: None,
        ep: None,
        af: acceleration,
        prev_high: None,
        prev_low: None,
        bar_count: 0,
    };

    let resource = ResourceArc::new(state);
    ok!(env, resource)
}

#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sar_state_next(
    env: Env,
    state_arc: ResourceArc<SARState>,
    high: f64,
    low: f64,
    is_new_bar: bool,
) -> NifResult<Term> {
    let mut state = (*state_arc).clone();

    if is_new_bar {
        // APPEND mode
        if state.bar_count == 0 {
            // First bar - just store values
            state.prev_high = Some(high);
            state.prev_low = Some(low);
            state.bar_count = 1;
            let new_state_arc = ResourceArc::new(state);
            return ok!(env, (None::<f64>, new_state_arc));
        } else if state.bar_count == 1 {
            // Second bar - initialize position
            let prev_high = state.prev_high.unwrap();
            let prev_low = state.prev_low.unwrap();

            let (is_long, initial_sar, initial_ep) = if high - prev_high > prev_low - low {
                // Uptrend
                (true, prev_low, high)
            } else {
                // Downtrend
                (false, prev_high, low)
            };

            state.is_long = Some(is_long);
            state.sar = Some(initial_sar);
            state.ep = Some(initial_ep);
            state.af = state.acceleration;
            state.prev_high = Some(high);
            state.prev_low = Some(low);
            state.bar_count = 2;

            let new_state_arc = ResourceArc::new(state);
            return ok!(env, (Some(initial_sar), new_state_arc));
        } else {
            // Subsequent bars - normal SAR calculation
            let is_long = state.is_long.unwrap();
            let sar = state.sar.unwrap();
            let ep = state.ep.unwrap();
            let af = state.af;

            // Calculate new SAR
            let new_sar = sar + af * (ep - sar);

            // Check for reversal
            let (final_sar, new_ep, new_af, new_is_long) = if is_long {
                // Long position
                if low <= new_sar {
                    // Reversal to short
                    (ep, low, state.acceleration, false)
                } else {
                    // Continue long
                    let (updated_ep, updated_af) = if high > ep {
                        (high, f64::min(af + state.acceleration, state.maximum))
                    } else {
                        (ep, af)
                    };
                    (new_sar, updated_ep, updated_af, true)
                }
            } else {
                // Short position
                if high >= new_sar {
                    // Reversal to long
                    (ep, high, state.acceleration, true)
                } else {
                    // Continue short
                    let (updated_ep, updated_af) = if low < ep {
                        (low, f64::min(af + state.acceleration, state.maximum))
                    } else {
                        (ep, af)
                    };
                    (new_sar, updated_ep, updated_af, false)
                }
            };

            state.is_long = Some(new_is_long);
            state.sar = Some(final_sar);
            state.ep = Some(new_ep);
            state.af = new_af;
            state.prev_high = Some(high);
            state.prev_low = Some(low);
            state.bar_count += 1;

            let new_state_arc = ResourceArc::new(state);
            return ok!(env, (Some(final_sar), new_state_arc));
        }
    } else {
        // UPDATE mode - recalculate current bar
        if state.bar_count < 2 {
            // During warmup, just update stored values
            if state.bar_count == 0 {
                state.prev_high = Some(high);
                state.prev_low = Some(low);
            } else {
                state.prev_high = Some(high);
                state.prev_low = Some(low);
            }
            let new_state_arc = ResourceArc::new(state);
            return ok!(env, (None::<f64>, new_state_arc));
        } else {
            // Temporarily reduce bar count and recalculate
            state.bar_count -= 1;
            let temp_state_arc = ResourceArc::new(state);
            return overlap_sar_state_next(env, temp_state_arc, high, low, true);
        }
    }
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_sar_state_init(env: Env, _acceleration: f64, _maximum: f64) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}

#[cfg(not(has_talib))]
#[rustler::nif]
pub fn overlap_sar_state_next(
    env: Env,
    _state: Term,
    _high: f64,
    _low: f64,
    _is_new_bar: bool,
) -> NifResult<Term> {
    error!(
        env,
        "TA-Lib not available. Please build ta-lib using tools/build_talib.cmd or use the Elixir backend."
    )
}
