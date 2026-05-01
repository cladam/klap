/*
 * klap/arg – Argument definition types and builders
 */
module src/arg

// ---------------------------------------------------------------------------
// Arg definition — describes a single CLI argument
// ---------------------------------------------------------------------------

pub type arg-kind
  ArgFlag        // boolean flag, no value (e.g. -a, --all)
  ArgOption      // takes a value (e.g. --sort=name, -I PATTERN)
  ArgPositional  // positional argument (e.g. FILE...)

pub struct arg-def
  arg-name       : string                // canonical name ("all", "sort", "FILE")
  arg-short      : maybe<char> = Nothing // short form: 'a'
  arg-long       : maybe<string> = Nothing // long form: "all" (auto-derived from name for flags/options)
  arg-help       : string = ""           // help text
  arg-kind       : arg-kind = ArgFlag
  arg-value-name : string = ""           // metavar shown in help: "WORD", "FILE", "PATTERN"
  arg-default    : maybe<string> = Nothing    // default value for options
  arg-values     : list<string> = []     // allowed values (empty = any)
  arg-multiple   : bool = False          // can appear multiple times
  arg-required   : bool = False          // required positional
  arg-hidden     : bool = False          // hide from help output
  arg-actions    : list<(string, string)> = [] // for flags that set values (e.g., -S sets sort=size)
  arg-optional-value : maybe<string> = Nothing // default value when option used without =

// ---------------------------------------------------------------------------
// Builders — create arg-def values
// ---------------------------------------------------------------------------

// Create a boolean flag: flag("all", 'a')
pub fun flag( name : string, short : maybe<char> = Nothing ) : arg-def
  Arg-def(
    arg-name = name,
    arg-short = short,
    arg-long = Just(name),
    arg-kind = ArgFlag
  )

// Convenience: flag with a short char directly
pub fun flag-short( name : string, short : char ) : arg-def
  flag(name, Just(short))

// Create an option that takes a value: option("sort", 'S')
pub fun option( name : string, short : maybe<char> = Nothing ) : arg-def
  Arg-def(
    arg-name = name,
    arg-short = short,
    arg-long = Just(name),
    arg-kind = ArgOption,
    arg-value-name = name.to-upper
  )

pub fun option-short( name : string, short : char ) : arg-def
  option(name, Just(short))

// Create a positional argument: positional("FILE")
pub fun positional( name : string ) : arg-def
  Arg-def(
    arg-name = name,
    arg-kind = ArgPositional,
    arg-value-name = name
  )

// ---------------------------------------------------------------------------
// Modifier functions — chainable builders
// ---------------------------------------------------------------------------

pub fun help( a : arg-def, text : string ) : arg-def
  a(arg-help = text)

pub fun value-name( a : arg-def, name : string ) : arg-def
  a(arg-value-name = name)

pub fun default-value( a : arg-def, val_ : string ) : arg-def
  a(arg-default = Just(val_))

pub fun values( a : arg-def, vs : list<string> ) : arg-def
  a(arg-values = vs)

pub fun multiple( a : arg-def ) : arg-def
  a(arg-multiple = True)

pub fun required( a : arg-def ) : arg-def
  a(arg-required = True)

pub fun hidden( a : arg-def ) : arg-def
  a(arg-hidden = True)

pub fun no-long( a : arg-def ) : arg-def
  a(arg-long = Nothing)

pub fun long( a : arg-def, l : string ) : arg-def
  a(arg-long = Just(l))

pub fun action( a : arg-def, target : string, val_ : string ) : arg-def
  a(arg-actions = Cons((target, val_), a.arg-actions))

pub fun optional-value( a : arg-def, default : string ) : arg-def
  a(arg-optional-value = Just(default))

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

pub fun is-flag( a : arg-def ) : bool
  match a.arg-kind
    ArgFlag -> True
    _       -> False

pub fun is-option( a : arg-def ) : bool
  match a.arg-kind
    ArgOption -> True
    _         -> False

pub fun is-positional( a : arg-def ) : bool
  match a.arg-kind
    ArgPositional -> True
    _             -> False

// Does this arg-def match a given short char?
pub fun matches-short( a : arg-def, c : char ) : bool
  match a.arg-short
    Just(s) -> s == c
    Nothing -> False

// Does this arg-def match a given long string?
pub fun matches-long( a : arg-def, l : string ) : bool
  match a.arg-long
    Just(lg) -> lg == l
    Nothing  -> False
