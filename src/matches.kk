/*
 * klap/matches – Parsed argument matches (query results)
 */
module src/matches

// ---------------------------------------------------------------------------
// A single matched value
// ---------------------------------------------------------------------------

pub struct arg-match
  match-name   : string         // arg name
  match-values : list<string>   // collected values (empty for flags)
  match-count  : int            // how many times this flag/option appeared

// ---------------------------------------------------------------------------
// All matches from parsing
// ---------------------------------------------------------------------------

pub struct arg-matches
  matched      : list<arg-match>    // named args that were matched
  positionals  : list<string>       // positional arguments in order

pub val empty-matches = Arg-matches([], [])

// ---------------------------------------------------------------------------
// Query functions
// ---------------------------------------------------------------------------

// Was this flag present?
pub fun get-flag( m : arg-matches, name : string ) : bool
  m.matched.any(fn(am) am.match-name == name && am.match-count > 0)

// Get the flag count (e.g., -vvv → 3)
pub fun get-count( m : arg-matches, name : string ) : int
  match m.matched.filter(fn(am) am.match-name == name)
    Cons(am, _) -> am.match-count
    Nil -> 0

// Get a single option value (last one wins if repeated)
pub fun get-one( m : arg-matches, name : string ) : maybe<string>
  match m.matched.filter(fn(am) am.match-name == name)
    Cons(am, _) -> am.match-values.last
    Nil -> Nothing

// Get a single option value with a default
pub fun get-one-or( m : arg-matches, name : string, default : string ) : string
  match m.get-one(name)
    Just(v) -> v
    Nothing -> default

// Get all values for a repeated option (e.g., -I PAT1 -I PAT2)
pub fun get-many( m : arg-matches, name : string ) : list<string>
  match m.matched.filter(fn(am) am.match-name == name)
    Cons(am, _) -> am.match-values
    Nil -> []

// Get positional arguments
pub fun get-positionals( m : arg-matches ) : list<string>
  m.positionals

// ---------------------------------------------------------------------------
// Internal: building matches during parsing
// ---------------------------------------------------------------------------

// Set a flag (increment count)
pub fun set-flag( m : arg-matches, name : string ) : arg-matches
  val found = m.matched.any(fn(am) am.match-name == name)
  if found then
    m(matched = m.matched.map fn(am)
      if am.match-name == name then am(match-count = am.match-count + 1)
      else am
    )
  else
    m(matched = Cons(Arg-match(name, [], 1), m.matched))

// Add a value to an option
pub fun add-value( m : arg-matches, name : string, val_ : string ) : arg-matches
  val found = m.matched.any(fn(am) am.match-name == name)
  if found then
    m(matched = m.matched.map fn(am)
      if am.match-name == name then am(match-values = am.match-values ++ [val_], match-count = am.match-count + 1)
      else am
    )
  else
    m(matched = Cons(Arg-match(name, [val_], 1), m.matched))

// Add a positional argument
pub fun add-positional( m : arg-matches, val_ : string ) : arg-matches
  m(positionals = m.positionals ++ [val_])
