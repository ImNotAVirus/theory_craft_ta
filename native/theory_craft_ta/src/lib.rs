use rustler::{Env, Term};

// Common atoms used across all modules
mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[cfg(has_talib)]
mod overlap_ffi;

#[macro_use]
mod helpers;

mod overlap;
mod overlap_state;

rustler::init!("Elixir.TheoryCraftTA.Native", load = load);

#[allow(non_local_definitions)]
fn load(env: Env, _: Term) -> bool {
    let _ = rustler::resource!(overlap_state::SMAState, env);
    let _ = rustler::resource!(overlap_state::EMAState, env);
    let _ = rustler::resource!(overlap_state::WMAState, env);
    let _ = rustler::resource!(overlap_state::DEMAState, env);
    let _ = rustler::resource!(overlap_state::TEMAState, env);
    let _ = rustler::resource!(overlap_state::TRIMAState, env);
    let _ = rustler::resource!(overlap_state::MIDPOINTState, env);
    let _ = rustler::resource!(overlap_state::T3State, env);
    let _ = rustler::resource!(overlap_state::SARState, env);
    true
}
