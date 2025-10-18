// FFI declarations for TA-Lib overlap studies functions
//
// This module contains the raw FFI bindings to the TA-Lib C library.
// Only compiled when ta-lib is available (has_talib cfg flag).

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

    pub fn TA_EMA(
        start_idx: i32,
        end_idx: i32,
        in_real: *const f64,
        opt_in_time_period: i32,
        out_beg_idx: *mut i32,
        out_nb_element: *mut i32,
        out_real: *mut f64,
    ) -> i32;

    pub fn TA_EMA_Lookback(opt_in_time_period: i32) -> i32;

    pub fn TA_WMA(
        start_idx: i32,
        end_idx: i32,
        in_real: *const f64,
        opt_in_time_period: i32,
        out_beg_idx: *mut i32,
        out_nb_element: *mut i32,
        out_real: *mut f64,
    ) -> i32;

    pub fn TA_WMA_Lookback(opt_in_time_period: i32) -> i32;

    pub fn TA_DEMA(
        start_idx: i32,
        end_idx: i32,
        in_real: *const f64,
        opt_in_time_period: i32,
        out_beg_idx: *mut i32,
        out_nb_element: *mut i32,
        out_real: *mut f64,
    ) -> i32;

    pub fn TA_DEMA_Lookback(opt_in_time_period: i32) -> i32;

    pub fn TA_TEMA(
        start_idx: i32,
        end_idx: i32,
        in_real: *const f64,
        opt_in_time_period: i32,
        out_beg_idx: *mut i32,
        out_nb_element: *mut i32,
        out_real: *mut f64,
    ) -> i32;

    pub fn TA_TEMA_Lookback(opt_in_time_period: i32) -> i32;

    pub fn TA_TRIMA(
        start_idx: i32,
        end_idx: i32,
        in_real: *const f64,
        opt_in_time_period: i32,
        out_beg_idx: *mut i32,
        out_nb_element: *mut i32,
        out_real: *mut f64,
    ) -> i32;

    pub fn TA_TRIMA_Lookback(opt_in_time_period: i32) -> i32;

    pub fn TA_MIDPOINT(
        start_idx: i32,
        end_idx: i32,
        in_real: *const f64,
        opt_in_time_period: i32,
        out_beg_idx: *mut i32,
        out_nb_element: *mut i32,
        out_real: *mut f64,
    ) -> i32;

    pub fn TA_MIDPOINT_Lookback(opt_in_time_period: i32) -> i32;

    pub fn TA_MIDPRICE(
        start_idx: i32,
        end_idx: i32,
        in_high: *const f64,
        in_low: *const f64,
        opt_in_time_period: i32,
        out_beg_idx: *mut i32,
        out_nb_element: *mut i32,
        out_real: *mut f64,
    ) -> i32;

    pub fn TA_MIDPRICE_Lookback(opt_in_time_period: i32) -> i32;

    pub fn TA_T3(
        start_idx: i32,
        end_idx: i32,
        in_real: *const f64,
        opt_in_time_period: i32,
        opt_in_vfactor: f64,
        out_beg_idx: *mut i32,
        out_nb_element: *mut i32,
        out_real: *mut f64,
    ) -> i32;

    pub fn TA_T3_Lookback(opt_in_time_period: i32, opt_in_vfactor: f64) -> i32;
}
