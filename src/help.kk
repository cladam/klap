/*
 * klap/help – Auto-generated help and version output
 */
module src/help

import src/arg
import src/command

// ---------------------------------------------------------------------------
// Format help text from command definition
// ---------------------------------------------------------------------------

pub fun format-help( c : command ) : string
  val args = c.args-ordered
  val flags = args.filter(fn(a) !a.is-positional && !a.arg-hidden)
  val poss  = args.filter(fn(a) a.is-positional)
  
  // Usage line
  val usage-line = if c.cmd-usage.is-empty then
    val pos-str = poss.map(fn(a) 
      val n = if a.arg-value-name.is-empty then a.arg-name else a.arg-value-name
      if a.arg-multiple then "[" ++ n ++ "]..." else "[" ++ n ++ "]"
    ).join(" ")
    val opts = if flags.is-empty then "" else " [OPTIONS]"
    "Usage: " ++ c.cmd-name ++ opts ++ (if pos-str.is-empty then "" else " " ++ pos-str)
  else c.cmd-usage

  // About
  val about-line = if c.cmd-about.is-empty then "" else c.cmd-about ++ "\n"

  // Format each flag/option line
  val flag-lines = flags.map(fn(a) format-arg-help(a))

  // Built-in --help and --version
  val builtins = [
    "      --help                 display this help and exit",
    "      --version              output version information and exit"
  ]

  [usage-line, about-line, "Options:"].join("\n") ++ "\n" ++
    (flag-lines ++ builtins).join("\n")

fun format-arg-help( a : arg-def ) : string
  // Short part: "  -a, " or "      "
  val short-part = match a.arg-short
    Just(c) -> "  -" ++ string(c) ++ ", "
    Nothing -> "      "
  
  // Long part: "--all" or "--sort=WORD"
  val long-part = match a.arg-long
    Just(l) ->
      if a.is-option then
        val vn = if a.arg-value-name.is-empty then "VALUE" else a.arg-value-name
        "--" ++ l ++ "=" ++ vn
      else "--" ++ l
    Nothing -> ""

  val left = short-part ++ long-part
  
  // Pad to column 30 for help text
  val padded = if left.count < 25 then
    left ++ pad-spaces(25 - left.count)
  else
    left ++ "\n" ++ pad-spaces(25)
  
  padded ++ a.arg-help

// (removed str-replicate — using pad-spaces instead)

fun pad-spaces( n : int ) : string
  if n <= 0 then ""
  else
    var s := ""
    for(1, n) fn(_)
      s := s ++ " "
    s

// ---------------------------------------------------------------------------
// Format version output
// ---------------------------------------------------------------------------

pub fun format-version( c : command ) : string
  if c.cmd-version.is-empty then c.cmd-name
  else c.cmd-name ++ " " ++ c.cmd-version
