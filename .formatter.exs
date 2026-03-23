# Used by "mix format"
[
  import_deps: [:ecto, :phoenix],
  subdirectories: ["priv/*/migrations"],
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}", "priv/*.{ex,exs}"]
]
