/*
 * klap/parse – Core argument parser
 *
 * Supports:
 *   - Short flags: -a, combined: -arF
 *   - Short options with next-arg value: -I PATTERN
 *   - Long flags: --all
 *   - Long options: --sort=name, --sort name
 *   - Optional long option values: --classify[=WHEN]
 *   - -- end of flags
 *   - --help and --version (built-in)
 *   - Positional arguments
 *   - Value validation against allowed values
 */
module src/parse

import src/arg
import src/command
import src/matches
import src/error
import src/help

// ---------------------------------------------------------------------------
// Parse result — used internally before effect-based API
// ---------------------------------------------------------------------------

pub type parse-action
  ShowHelp
  ShowVersion
  ParsedOk( matches : arg-matches )

// ---------------------------------------------------------------------------
// Main parse function — returns matches or fails via klap-error effect
// ---------------------------------------------------------------------------

pub fun parse( c : command, args : list<string> ) : <klap-error,div> arg-matches
  val defs = c.args-ordered
  val pos-defs = defs.filter(fn(d) d.is-positional)
  val result = parse-loop(c, defs, pos-defs, args, empty-matches, False)
  match result
    ShowHelp    -> klap-fail("__help__")
    ShowVersion -> klap-fail("__version__")
    ParsedOk(m) ->
      check-required-positionals(pos-defs, m)
      m

// ---------------------------------------------------------------------------
// Parse with automatic --help/--version handling and exit
// Prints help/version to stdout and exits. Prints errors to stderr.
// ---------------------------------------------------------------------------

pub fun parse-or-exit( c : command, args : list<string> ) : <console,div> arg-matches
  match try-klap({ c.parse(args) })
    Right(m) -> m
    Left("__help__") ->
      println(c.format-help)
      klap-exit(0)
    Left("__version__") ->
      println(c.format-version)
      klap-exit(0)
    Left(msg) ->
      println(c.cmd-name ++ ": " ++ msg)
      println("Try '" ++ c.cmd-name ++ " --help' for more information.")
      klap-exit(2)

// Clean process exit without throwing exceptions
extern klap-exit( code : int ) : a
  c inline "(exit(kk_integer_clamp32(#1, kk_context())), kk_box_null())"

// ---------------------------------------------------------------------------
// Recursive parse loop
// ---------------------------------------------------------------------------

fun parse-loop( c : command, defs : list<arg-def>, pos-defs : list<arg-def>,
                args : list<string>, m : arg-matches,
                past-double-dash : bool ) : <klap-error,div> parse-action
  match args
    Nil -> ParsedOk(m)
    
    // After --, everything is positional
    Cons(a, rest) | past-double-dash ->
      val (pdefs1, m1) = consume-positional(pos-defs, m, a)
      parse-loop(c, defs, pdefs1, rest, m1, True)
    
    // -- separator
    Cons("--", rest) ->
      parse-loop(c, defs, pos-defs, rest, m, True)
    
    // --help (built-in)
    Cons("--help", _) -> ShowHelp
    
    // --version (built-in)
    Cons("--version", _) -> ShowVersion
    
    // Long option with = value: --sort=name
    Cons(a, rest) | a.starts-with("--").bool && a.contains("=") ->
      val eq-idx = index-of-char(a, '=')
      val name = a.slice.drop(2).take(eq-idx - 2).string
      val value = a.slice.drop(eq-idx + 1).string
      match find-long(defs, name)
        Just(d) ->
          if d.is-flag then
            klap-fail("option '--" ++ name ++ "' doesn't take a value")
          else
            validate-value(d, value)
            parse-loop(c, defs, pos-defs, rest, m.add-value(d.arg-name, value), False)
        Nothing -> klap-fail("unrecognized option '--" ++ name ++ "'")
    
    // Long flag or option without =: --all, --sort name
    Cons(a, rest) | a.starts-with("--").bool ->
      val name = a.slice.drop(2).string
      match find-long(defs, name)
        Just(d) ->
          if d.is-flag then
            parse-loop(c, defs, pos-defs, rest, m.set-flag(d.arg-name), False)
          else
            // Option: consume next arg as value
            match rest
              Cons(val_, rest2) ->
                validate-value(d, val_)
                parse-loop(c, defs, pos-defs, rest2, m.add-value(d.arg-name, val_), False)
              Nil ->
                klap-fail("option '--" ++ name ++ "' requires a value")
        Nothing -> klap-fail("unrecognized option '--" ++ name ++ "'")
    
    // Short flags (possibly combined): -arF, -I PATTERN
    Cons(a, rest) | a.starts-with("-").bool && a != "-" ->
      val chars = a.slice.drop(1).string.list
      parse-short-chars(c, defs, pos-defs, chars, rest, m)
    
    // Positional argument
    Cons(a, rest) ->
      val (pdefs2, m2) = consume-positional(pos-defs, m, a)
      parse-loop(c, defs, pdefs2, rest, m2, False)


// ---------------------------------------------------------------------------
// Parse combined short flags: e.g. -arF, -I PATTERN
// ---------------------------------------------------------------------------

fun parse-short-chars( c : command, defs : list<arg-def>, pos-defs : list<arg-def>,
                       chars : list<char>, rest : list<string>,
                       m : arg-matches ) : <klap-error,div> parse-action
  match chars
    Nil -> parse-loop(c, defs, pos-defs, rest, m, False)
    Cons(ch, remaining) ->
      match find-short(defs, ch)
        Nothing -> klap-fail("invalid option -- '" ++ string(ch) ++ "'")
        Just(d) ->
          if d.is-flag then
            // Flag: set and continue with remaining chars
            parse-short-chars(c, defs, pos-defs, remaining, rest, m.set-flag(d.arg-name))
          else
            // Option: remaining chars are the value, or consume next arg
            match remaining
              Cons(_, _) ->
                // Rest of the combined string is the value: -IPATTERN
                val value = remaining.map(string).join
                validate-value(d, value)
                parse-loop(c, defs, pos-defs, rest, m.add-value(d.arg-name, value), False)
              Nil ->
                // Value is the next argument: -I PATTERN
                match rest
                  Cons(val_, rest2) ->
                    validate-value(d, val_)
                    parse-loop(c, defs, pos-defs, rest2, m.add-value(d.arg-name, val_), False)
                  Nil ->
                    klap-fail("option '-" ++ string(ch) ++ "' requires a value")


// ---------------------------------------------------------------------------
// Positional argument consumption
// ---------------------------------------------------------------------------

fun consume-positional( pos-defs : list<arg-def>, m : arg-matches, value : string ) : klap-error (list<arg-def>, arg-matches)
  match pos-defs
    Cons(pd, prest) ->
      validate-value(pd, value)
      val next-defs = if pd.arg-multiple then pos-defs else prest
      (next-defs, m.add-positional(value).add-value(pd.arg-name, value))
    Nil ->
      klap-fail("unexpected argument '" ++ value ++ "'")

fun check-required-positionals( pos-defs : list<arg-def>, m : arg-matches ) : <klap-error,div> ()
  match pos-defs
    Nil -> ()
    Cons(pd, rest) ->
      if pd.arg-required && m.get-many(pd.arg-name).is-empty then
        klap-fail("missing required argument '<" ++ pd.arg-value-name ++ ">'")
      check-required-positionals(rest, m)

// ---------------------------------------------------------------------------
// Lookup helpers
// ---------------------------------------------------------------------------

fun find-long( defs : list<arg-def>, name : string ) : maybe<arg-def>
  match defs.filter(fn(d) d.matches-long(name))
    Cons(d, _) -> Just(d)
    Nil -> Nothing

fun find-short( defs : list<arg-def>, c : char ) : maybe<arg-def>
  match defs.filter(fn(d) d.matches-short(c))
    Cons(d, _) -> Just(d)
    Nil -> Nothing

// ---------------------------------------------------------------------------
// Value validation
// ---------------------------------------------------------------------------

fun validate-value( d : arg-def, value : string ) : klap-error ()
  match d.arg-values
    Nil -> ()  // no restriction
    allowed ->
      if allowed.any(fn(v) v == value) then ()
      else
        val choices = allowed.join(", ")
        val label = if d.is-positional then "'" ++ d.arg-name ++ "'"
                    else "'--" ++ d.arg-name ++ "'"
        klap-fail("invalid value '" ++ value ++ "' for " ++ label ++ 
                   " [possible values: " ++ choices ++ "]")

// ---------------------------------------------------------------------------
// String helpers
// ---------------------------------------------------------------------------

fun contains( s : string, c : char ) : bool
  s.list.any(fn(ch) ch == c)

fun index-of-char( s : string, c : char ) : int
  index-of-char-loop(s.list, c, 0)

fun index-of-char-loop( cs : list<char>, c : char, idx : int ) : int
  match cs
    Nil -> idx
    Cons(ch, rest) ->
      if ch == c then idx
      else index-of-char-loop(rest, c, idx + 1)
