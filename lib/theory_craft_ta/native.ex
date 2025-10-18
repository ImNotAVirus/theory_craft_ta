defmodule TheoryCraftTA.Native do
  @moduledoc false

  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = "https://github.com/ImNotAVirus/theory_craft_ta"

  # Since Rustler 0.27.0, we need to change manually the mode for each env.
  # We want "debug" in dev and test because it's faster to compile.
  mode = if Mix.env() in [:dev, :test], do: :debug, else: :release

  use RustlerPrecompiled,
    otp_app: :theory_craft_ta,
    version: version,
    base_url: "#{github_url}/releases/download/v#{version}",
    targets: ~w(
      aarch64-apple-darwin
      aarch64-unknown-linux-gnu
      aarch64-unknown-linux-musl
      x86_64-apple-darwin
      x86_64-pc-windows-msvc
      x86_64-pc-windows-gnu
      x86_64-unknown-linux-gnu
      x86_64-unknown-linux-musl
      x86_64-unknown-freebsd
    ),
    # We don't use any features of newer NIF versions, so 2.15 is enough.
    nif_versions: ["2.15"],
    mode: mode,
    force_build: System.get_env("THEORY_CRAFT_TA_BUILD") in ["1", "true"]

  ## NIF stubs

  # Batch functions
  def overlap_sma(_data, _period), do: error()
  def overlap_ema(_data, _period), do: error()
  def overlap_wma(_data, _period), do: error()
  def overlap_dema(_data, _period), do: error()
  def overlap_tema(_data, _period), do: error()
  def overlap_trima(_data, _period), do: error()
  def overlap_t3(_data, _period, _vfactor), do: error()
  def overlap_midpoint(_data, _period), do: error()

  # State-based functions
  def overlap_sma_state_init(_period), do: error()
  def overlap_sma_state_next(_state, _value, _is_new_bar), do: error()
  def overlap_ema_state_init(_period), do: error()
  def overlap_ema_state_next(_state, _value, _is_new_bar), do: error()
  def overlap_wma_state_init(_period), do: error()
  def overlap_wma_state_next(_state, _value, _is_new_bar), do: error()
  def overlap_dema_state_init(_period), do: error()
  def overlap_dema_state_next(_state, _value, _is_new_bar), do: error()
  def overlap_tema_state_init(_period), do: error()
  def overlap_tema_state_next(_state, _value, _is_new_bar), do: error()
  def overlap_trima_state_init(_period), do: error()
  def overlap_trima_state_next(_state, _value, _is_new_bar), do: error()
  def overlap_t3_state_init(_period, _vfactor), do: error()
  def overlap_t3_state_next(_state, _value, _is_new_bar), do: error()
  def overlap_midpoint_state_init(_period), do: error()
  def overlap_midpoint_state_next(_state, _value, _is_new_bar), do: error()
  def overlap_sar(_high, _low, _acceleration, _maximum), do: error()
  def overlap_sar_state_init(_acceleration, _maximum), do: error()
  def overlap_sar_state_next(_state, _high, _low, _is_new_bar), do: error()

  ## Private functions

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
