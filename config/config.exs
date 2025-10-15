import Config

# Default backend configuration
config :theory_craft_ta,
  default_backend: TheoryCraftTA.Native

# Import environment specific config
import_config "#{config_env()}.exs"
