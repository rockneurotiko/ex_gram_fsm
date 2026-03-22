dsl_macros = [defstates: 1, state: 1, state: 2]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:ex_gram],
  plugins: [Quokka],
  line_length: 120,
  locals_without_parens: dsl_macros,
  export: [locals_without_parens: dsl_macros],
  quokka: [
    autosort: [:map, :defstruct, :schema],
    files: %{
      included: ["lib/", "test/"],
      excluded: []
    }
  ]
]
