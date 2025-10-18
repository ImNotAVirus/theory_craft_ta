import Config

if Mix.env() == :dev do
  config :pre_commit,
    commands: ["ci.check"],
    verbose: true
end
