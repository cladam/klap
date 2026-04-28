# klap

A command-line argument parsing library for [Koka](https://koka-lang.github.io/), inspired by Rust's [clap](https://docs.rs/clap).

## Features

- **Flags** — boolean switches with short (`-v`) and long (`--verbose`) forms
- **Options** — key-value arguments (`--sort=name`, `-S name`)
- **Positional arguments** — unnamed trailing arguments (`FILE...`)
- **Positional validation** — `.values()`, `.required`, and `.multiple` enforced at parse time
- **Combined short flags** — `-alR` expands to `-a -l -R`
- **Multiple values** — collect repeated options into a list
- **Allowed values** — restrict an option to a set of choices
- **Default values** — fall back when an option is not supplied
- **Auto-generated help** — `--help` and `--version` out of the box
- **Error handling** — structured `klap-error` effect for parse failures

## Setup

Add klap as a git submodule in your project:

```sh
git submodule add https://github.com/cladam/klap.git lib/klap
```

Then compile with `-i` pointing at the submodule:

```sh
koka -ilib/klap myapp.kk
```

To update klap later:

```sh
git submodule update --remote lib/klap
```

## Usage

Import the top-level `klap` module, which re-exports everything:

```koka
import klap

fun main()
  val app = command("myapp")
    .version("0.1.0")
    .about("My awesome tool")
    .arg(flag-short("verbose", 'v').help("Enable verbose output"))
    .arg(option-short("output", 'o').value-name("FILE").help("Output file"))
    .arg(positional("INPUT").multiple)

  val m = app.parse-or-exit(get-args())

  if m.get-flag("verbose") then
    println("verbose mode on")

  match m.get-one("output")
    Just(f) -> println("writing to " ++ f)
    Nothing -> println("writing to stdout")

  m.get-positionals().foreach fn(p)
    println("input: " ++ p)
```

### Defining arguments

```koka
// Boolean flag: --all / -a
flag-short("all", 'a').help("show all entries")

// Long-only flag: --recursive
flag("recursive")

// Option with value: --sort <WORD> / -S <WORD>
option-short("sort", 'S')
  .values(["name", "size", "time"])
  .default-value("name")
  .help("sort by WORD")

// Option that can be repeated: --ignore <PATTERN> / -I <PATTERN>
option-short("ignore", 'I')
  .value-name("PATTERN")
  .multiple
  .help("ignore pattern")

// Positional argument (collects all trailing args)
positional("FILE").multiple

// Positional with allowed values and required
positional("COMMAND")
  .values(["build", "run", "check", "clean", "help"])
  .required
```

### Querying results

```koka
val m : arg-matches = app.parse-or-exit(get-args())

m.get-flag("verbose")            // bool
m.get-one("output")              // maybe<string>
m.get-one-or("sort", "name")     // string (with default)
m.get-many("ignore")             // list<string>
m.get-positionals()              // list<string> (flat list, all positionals)
m.get-one("COMMAND")             // maybe<string> (positional by name)
m.get-many("FILE")               // list<string> (multiple positional by name)
m.get-count("verbose")           // int (number of occurrences)
```

### Error handling

`parse-or-exit` prints an error message and exits on failure. For programmatic error handling, use the `klap-error` effect directly:

```koka
match try-klap({ app.parse(args) })
  Right(m) -> // use matches
  Left(msg) -> println("error: " ++ msg)
```

## License

MIT — see [LICENSE](LICENSE) for details.