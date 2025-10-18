defmodule TheoryCraftTA.Native.Overlap.SARState do
  @moduledoc """
  Native (Rust NIF) wrapper for SAR state-based indicator.
  """

  alias TheoryCraftTA.Native

  @doc """
  Initializes a new SAR state using the native Rust NIF.

  See `TheoryCraftTA.Elixir.Overlap.SARState.init/2` for documentation.
  """
  @spec init(float(), float()) :: {:ok, reference()} | {:error, String.t()}
  def init(acceleration \\ 0.02, maximum \\ 0.20) do
    Native.overlap_sar_state_init(acceleration, maximum)
  end

  @doc """
  Processes the next high/low bar using the native Rust NIF.

  See `TheoryCraftTA.Elixir.Overlap.SARState.next/4` for documentation.
  """
  @spec next(reference(), float(), float(), boolean()) ::
          {:ok, float() | nil, reference()} | {:error, String.t()}
  def next(state, high, low, is_new_bar) do
    case Native.overlap_sar_state_next(state, high, low, is_new_bar) do
      {:ok, {sar_value, new_state}} ->
        {:ok, sar_value, new_state}

      {:error, _reason} = error ->
        error
    end
  end
end
