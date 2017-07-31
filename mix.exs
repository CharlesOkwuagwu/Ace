defmodule Ace.Mixfile do
  use Mix.Project

  def project do
    [app: :ace,
    version: "0.10.0",
    elixir: "~> 1.4",
    build_embedded: Mix.env == :prod,
    start_permanent: Mix.env == :prod,
    deps: deps(),
    description: description(),
    docs: [
      main: "getting_started",
      source_url: "https://github.com/crowdhailer/ace",
      extras: [
        "getting_started.md",
        "README.md"
      ],
    ],
    package: package()]
  end

  def application do
    [
      extra_applications: [:logger, :ssl]
    ]
  end

  defp deps do
    [
      {:cowlib, github: "ninenines/cowlib", tag: "2.0.0-rc.1"},
      {:raxx, "~> 0.11.1", optional: true},
      {:dialyxir, "~> 0.5.0", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    HTTP/2 server for elixir
    """
  end

  defp package do
    [
      maintainers: ["Peter Saxton"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/crowdhailer/ace"}
    ]
  end
end
