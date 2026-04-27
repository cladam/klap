/*
 * klap/command – Command definition (the top-level app)
 */
module src/command

import src/arg

// ---------------------------------------------------------------------------
// Command — describes the CLI application
// ---------------------------------------------------------------------------

pub struct command
  cmd-name    : string                // program name
  cmd-version : string = ""           // --version output
  cmd-about   : string = ""           // description shown in help
  cmd-author  : string = ""           // author info
  cmd-args    : list<arg-def> = []    // registered arguments (reversed during building)
  cmd-usage   : string = ""           // custom usage line (auto-generated if empty)

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

pub fun command( name : string ) : command
  Command(cmd-name = name)

pub fun version( c : command, v : string ) : command
  c(cmd-version = v)

pub fun about( c : command, text : string ) : command
  c(cmd-about = text)

pub fun author( c : command, a : string ) : command
  c(cmd-author = a)

pub fun usage( c : command, u : string ) : command
  c(cmd-usage = u)

pub fun arg( c : command, a : arg-def ) : command
  c(cmd-args = Cons(a, c.cmd-args))

// Get args in definition order
pub fun args-ordered( c : command ) : list<arg-def>
  c.cmd-args.reverse
