/*
 * klap/error – Parse error effect
 */
module src/error

// ---------------------------------------------------------------------------
// Parse error effect — like anyhow for CLI parsing
// ---------------------------------------------------------------------------

pub effect klap-error
  ctl klap-fail( msg : string ) : a

// Run an action, returning either the result or an error message
pub fun try-klap( action : () -> <klap-error|e> a ) : e either<string,a>
  with ctl klap-fail(msg) Left(msg)
  Right(action())
