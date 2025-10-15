defmodule TheoryCraftTA.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @dev? String.ends_with?(@version, "-dev")
  @force_build? System.get_env("THEORY_CRAFT_TA_BUILD") in ["1", "true"]

  def project() do
    [
      app: :theory_craft_ta,
      version: @version,
      elixir: "~> 1.14",
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [
      extra_applications: [:logger],
      env: [default_backend: TheoryCraftTA.Native]
    ]
  end

  def aliases() do
    [
      tidewave:
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4002) end)'"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps() do
    [
      {:theory_craft, path: "../theorycraft"},
      {:rustler_precompiled, "~> 0.8"},

      ## Optional
      {:rustler, "~> 0.37.0", optional: not (@dev? or @force_build?)},

      ## Dev
      {:tidewave, "~> 0.5", only: :dev},
      {:bandit, "~> 1.0", only: :dev},
      {:benchee, "~> 1.4", only: :dev},

      ## Test
      {:stream_data, "~> 1.2", only: :test}
    ]
  end
end
