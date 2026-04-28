/*
 * test-klap.kk — unit + integration tests for the klap CLI parsing library
 * Uses kunit for xUnit-style test structure.
 */
module tests/test-klap

import tests/kunit
import src/arg
import src/command
import src/matches
import src/parse
import src/help
import src/error

// ---------------------------------------------------------------------------
// Helper: build a sample command (mimics a simplified kls)
// ---------------------------------------------------------------------------

fun test-app() : command
  command("test-app")
    .version("1.0.0")
    .about("A test application")
    .arg(flag-short("all", 'a').help("do not ignore entries starting with ."))
    .arg(flag-short("reverse", 'r').help("reverse order while sorting"))
    .arg(flag-short("long-format", 'l').help("use a long listing format"))
    .arg(flag-short("recursive", 'R').help("list subdirectories recursively"))
    .arg(option-short("sort", 'S').values(["name", "size", "time", "none"]).default-value("name").help("sort by WORD"))
    .arg(option-short("ignore", 'I').value-name("PATTERN").multiple.help("ignore pattern"))
    .arg(flag("group-directories-first").no-long.help("group directories first"))
    .arg(positional("FILE").multiple)

// Helper: parse or fail the test
fun must-parse( args : list<string> ) : <div,exn,klap-error> arg-matches
  test-app().parse(args)

// ---------------------------------------------------------------------------
// String helper for help text assertions
// ---------------------------------------------------------------------------

fun str-contains( s : string, sub : string ) : bool
  val slen = s.count
  val sublen = sub.count
  if sublen > slen then False
  else
    var found := False
    for(0, slen - sublen) fn(i)
      if s.slice.drop(i).take(sublen).string == sub then
        found := True
    found

// ---------------------------------------------------------------------------
// Unit tests — arg builders (pure)
// ---------------------------------------------------------------------------

fun unit-tests()
  println("\n" ++ bold("=== klap: unit tests (arg builders) ==="))
  defaultKUnitHandler
    test("flag creates a flag arg-def")
      val a = flag-short("all", 'a').help("show all")
      assert/is-true(a.is-flag)
      assert/is-false(a.is-option)
      assert/is-false(a.is-positional)
      assert/is-true(a.arg-name == "all")

    test("flag matches short and long")
      val a = flag-short("all", 'a')
      assert/is-true(a.matches-short('a'))
      assert/is-false(a.matches-short('b'))
      assert/is-true(a.matches-long("all"))
      assert/is-false(a.matches-long("none"))

    test("option creates an option arg-def")
      val a = option-short("sort", 'S').values(["name", "size"])
      assert/is-true(a.is-option)
      assert/is-false(a.is-flag)
      assert/is-true(a.arg-values.length == 2)

    test("positional creates a positional arg-def")
      val a = positional("FILE").multiple
      assert/is-true(a.is-positional)
      assert/is-true(a.arg-multiple)

    test("no-long removes long option")
      val a = flag("verbose").no-long
      assert/is-true(a.arg-long.is-nothing)

    test("command builder chains")
      val c = test-app()
      assert/is-true(c.cmd-name == "test-app")
      assert/is-true(c.cmd-version == "1.0.0")
      assert/is-true(c.cmd-about == "A test application")

    test("matches: empty matches return defaults")
      val m = empty-matches
      assert/is-false(m.get-flag("all"))
      assert/is-true(m.get-count("all") == 0)
      assert/is-true(m.get-one("sort").is-nothing)
      assert/is-true(m.get-many("ignore").is-empty)
      assert/is-true(m.get-positionals.is-empty)

    test("matches: set-flag increments count")
      val m = empty-matches.set-flag("all").set-flag("all")
      assert/is-true(m.get-flag("all"))
      assert/is-true(m.get-count("all") == 2)

    test("matches: add-value collects values")
      val m = empty-matches.add-value("ignore", "*.bak").add-value("ignore", "*.tmp")
      assert/is-true(m.get-many("ignore").length == 2)
      assert/is-true(m.get-one("ignore") == Just("*.tmp"))  // last wins

    test("matches: get-one-or returns default")
      val m = empty-matches
      assert/is-true(m.get-one-or("sort", "name") == "name")

// ---------------------------------------------------------------------------
// Divergent tests — parsing (recursive, carries div)
// ---------------------------------------------------------------------------

fun parse-tests()
  println("\n" ++ bold("=== klap: parse tests (flags & options) ==="))
  defaultKDivHandler
    dtest("empty args produces empty matches")
      match try-klap({ must-parse([]) })
        Right(m) ->
          assert/is-false(m.get-flag("all"))
          assert/is-true(m.get-positionals.is-empty)
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("single short flag -a")
      match try-klap({ must-parse(["-a"]) })
        Right(m) ->
          assert/is-true(m.get-flag("all"))
          assert/is-false(m.get-flag("reverse"))
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("combined short flags -arR")
      match try-klap({ must-parse(["-arR"]) })
        Right(m) ->
          assert/is-true(m.get-flag("all"))
          assert/is-true(m.get-flag("reverse"))
          assert/is-true(m.get-flag("recursive"))
          assert/is-false(m.get-flag("long-format"))
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("long flag --all")
      match try-klap({ must-parse(["--all"]) })
        Right(m) -> assert/is-true(m.get-flag("all"))
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("long option --sort=size")
      match try-klap({ must-parse(["--sort=size"]) })
        Right(m) -> assert/is-true(m.get-one("sort") == Just("size"))
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("long option --sort time (space-separated)")
      match try-klap({ must-parse(["--sort", "time"]) })
        Right(m) -> assert/is-true(m.get-one("sort") == Just("time"))
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("short option -I PATTERN (next arg)")
      match try-klap({ must-parse(["-I", "*.bak"]) })
        Right(m) -> assert/is-true(m.get-one("ignore") == Just("*.bak"))
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("short option -I*.bak (attached value)")
      match try-klap({ must-parse(["-I*.bak"]) })
        Right(m) -> assert/is-true(m.get-one("ignore") == Just("*.bak"))
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("repeated option -I collects all values")
      match try-klap({ must-parse(["-I", "*.bak", "-I", "*.tmp"]) })
        Right(m) ->
          val pats = m.get-many("ignore")
          assert/is-true(pats.length == 2)
          assert/is-true(pats.any(fn(p) p == "*.bak"))
          assert/is-true(pats.any(fn(p) p == "*.tmp"))
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("-- ends flag parsing")
      match try-klap({ must-parse(["-a", "--", "-r", "file.txt"]) })
        Right(m) ->
          assert/is-true(m.get-flag("all"))
          assert/is-false(m.get-flag("reverse"))
          assert/is-true(m.get-positionals.length == 2)
          assert/is-true(m.get-positionals.any(fn(p) p == "-r"))
          assert/is-true(m.get-positionals.any(fn(p) p == "file.txt"))
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("positional arguments collected in order")
      match try-klap({ must-parse(["-a", "dir1", "dir2"]) })
        Right(m) ->
          assert/is-true(m.get-flag("all"))
          assert/is-true(m.get-positionals.length == 2)
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("mixed flags, options, and positionals")
      match try-klap({ must-parse(["-al", "--sort=size", "-I", "*.o", "src", "lib"]) })
        Right(m) ->
          assert/is-true(m.get-flag("all"))
          assert/is-true(m.get-flag("long-format"))
          assert/is-true(m.get-one("sort") == Just("size"))
          assert/is-true(m.get-one("ignore") == Just("*.o"))
          assert/is-true(m.get-positionals.length == 2)
        Left(msg) -> fatal("unexpected error: " ++ msg)

// ---------------------------------------------------------------------------
// Error handling tests
// ---------------------------------------------------------------------------

fun error-tests()
  println("\n" ++ bold("=== klap: error handling tests ==="))
  defaultKDivHandler
    dtest("invalid short flag -Z")
      match try-klap({ must-parse(["-Z"]) })
        Right(_) -> fatal("should have failed")
        Left(msg) -> assert/is-true(msg.str-contains("Z"))

    dtest("unrecognized long flag --bogus")
      match try-klap({ must-parse(["--bogus"]) })
        Right(_) -> fatal("should have failed")
        Left(msg) -> assert/is-true(msg.str-contains("bogus"))

    dtest("invalid value --sort=bogus")
      match try-klap({ must-parse(["--sort=bogus"]) })
        Right(_) -> fatal("should have failed")
        Left(msg) -> assert/is-true(msg.str-contains("bogus"))

    dtest("missing value for --sort")
      match try-klap({ must-parse(["--sort"]) })
        Right(_) -> fatal("should have failed")
        Left(msg) -> assert/is-true(msg.str-contains("requires"))

    dtest("missing value for short option -I")
      match try-klap({ must-parse(["-I"]) })
        Right(_) -> fatal("should have failed")
        Left(msg) -> assert/is-true(msg.str-contains("requires"))

    dtest("--help triggers __help__ signal")
      match try-klap({ must-parse(["--help"]) })
        Right(_) -> fatal("should have triggered help")
        Left(msg) -> assert/is-true(msg == "__help__")

    dtest("--version triggers __version__ signal")
      match try-klap({ must-parse(["--version"]) })
        Right(_) -> fatal("should have triggered version")
        Left(msg) -> assert/is-true(msg == "__version__")

// ---------------------------------------------------------------------------
// Help generation tests (pure)
// ---------------------------------------------------------------------------

fun help-tests()
  println("\n" ++ bold("=== klap: help generation tests ==="))
  defaultKUnitHandler
    test("format-help contains usage line")
      val h = test-app().format-help
      assert/is-true(h.str-contains("Usage: test-app"))

    test("format-help lists defined flags")
      val h = test-app().format-help
      assert/is-true(h.str-contains("--all"))
      assert/is-true(h.str-contains("--reverse"))
      assert/is-true(h.str-contains("--sort"))

    test("format-help includes built-in --help and --version")
      val h = test-app().format-help
      assert/is-true(h.str-contains("--help"))
      assert/is-true(h.str-contains("--version"))

    test("format-help shows positional in usage line")
      val h = test-app().format-help
      assert/is-true(h.str-contains("[FILE]"))

    test("format-version includes name and version")
      val v = test-app().format-version
      assert/is-true(v.str-contains("test-app"))
      assert/is-true(v.str-contains("1.0.0"))

    test("hidden args excluded from help")
      val c = command("hidden-test")
        .arg(flag-short("verbose", 'v').help("be verbose"))
        .arg(flag("debug").hidden.help("secret debug mode"))
      val h = c.format-help
      assert/is-true(h.str-contains("--verbose"))
      assert/is-false(h.str-contains("--debug"))

// ---------------------------------------------------------------------------
// Positional validation tests
// ---------------------------------------------------------------------------

fun positional-validation-tests()
  println("\n" ++ bold("=== klap: positional validation tests ==="))
  defaultKDivHandler
    dtest("positional with .values() rejects invalid value")
      val c = command("test")
        .arg(positional("COMMAND").values(["build", "run", "clean"]))
      match try-klap({ c.parse(["bogus"]) })
        Right(_) -> fatal("should have rejected 'bogus'")
        Left(msg) ->
          assert/is-true(msg.str-contains("bogus"))
          assert/is-true(msg.str-contains("possible values"))

    dtest("positional with .values() accepts valid value")
      val c = command("test")
        .arg(positional("COMMAND").values(["build", "run", "clean"]))
      match try-klap({ c.parse(["build"]) })
        Right(m) ->
          assert/is-true(m.get-one("COMMAND") == Just("build"))
          assert/is-true(m.get-positionals.length == 1)
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("required positional fails when missing")
      val c = command("test")
        .arg(positional("COMMAND").required)
      match try-klap({ c.parse([]) })
        Right(_) -> fatal("should have failed for missing required arg")
        Left(msg) -> assert/is-true(msg.str-contains("required"))

    dtest("non-multiple positional rejects extra args")
      val c = command("test")
        .arg(positional("FILE"))
      match try-klap({ c.parse(["a.txt", "b.txt"]) })
        Right(_) -> fatal("should have rejected extra positional")
        Left(msg) -> assert/is-true(msg.str-contains("unexpected"))

    dtest("multiple positional accepts many args")
      val c = command("test")
        .arg(positional("FILE").multiple)
      match try-klap({ c.parse(["a.txt", "b.txt", "c.txt"]) })
        Right(m) ->
          assert/is-true(m.get-positionals.length == 3)
          assert/is-true(m.get-many("FILE").length == 3)
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("positional queryable by name after parse")
      val c = command("test")
        .arg(positional("COMMAND").values(["build", "run"]))
        .arg(positional("FILE").multiple)
      match try-klap({ c.parse(["build", "main.kk", "util.kk"]) })
        Right(m) ->
          assert/is-true(m.get-one("COMMAND") == Just("build"))
          assert/is-true(m.get-many("FILE").length == 2)
        Left(msg) -> fatal("unexpected error: " ++ msg)

    dtest("positional validation works after --")
      val c = command("test")
        .arg(positional("COMMAND").values(["build", "run"]))
      match try-klap({ c.parse(["--", "bogus"]) })
        Right(_) -> fatal("should have rejected 'bogus' after --")
        Left(msg) -> assert/is-true(msg.str-contains("bogus"))

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

pub fun main() : io ()
  unit-tests()
  parse-tests()
  error-tests()
  help-tests()
  positional-validation-tests()
