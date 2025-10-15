import Config

# Use Elixir backend for tests to avoid needing Rust compilation
config :theory_craft_ta,
  default_backend: TheoryCraftTA.Elixir
