prefer immutability. let types be inferred by final, not explicitly declared
every method should aim to return an object
use guard clauses to return edge cases
instead of using nested conditions, identify if its negation is a simpler invariant that can be dismissed using return/continue/break
for statements and conditions with complexity > 3, extract intentionally named variables for clarity
extract long edge cases out into intentionally named methods
the end of the method body, having addressed all edge cases, should directly do/return what the method name states
method names should start with verbs:
	buildX when the generated output consumes resources
	composeX when no arguments taken
	generateX when arguments taken
for long widget trees:
	extract into separate widget when component
		state is clearly scoped independently
		is intended to be reused
		is frequently updating
	extract into final variable in same scope when
		purpose is clearly scoped - e.g. some button or bar
		to reduce nesting
code should fundamentally be divided based on a clearly scoped feature or subdomain of the app that has its own entities, use cases and presentation layer. the presentation folder can be structured and nested depending on usage. e.g. a screen can be a file or a folder with multiple files or folders within them, based on how the widgets are scoped by domain and design.
multiple screens that share a specific scope may be grouped into one folder suffixed with "flow".
external services, APIs should sit at the top decoupled from features. They have their own entities modeled as models for ease of using them elsewhere.
