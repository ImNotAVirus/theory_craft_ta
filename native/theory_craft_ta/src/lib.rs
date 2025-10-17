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

rustler::init!("Elixir.TheoryCraftTA.Native");
