%{
/**

  grammar.y - Reentrant (pure) Bison LALR Parser

  This file defines the productions necessary to interpret
  tokens found by the lexical analyzer, and subsquently build
  a valid abstract syntax tree to describe policy generators.

 */
#include "private.h"
%}

/*
  To get a reentrant Bison parser, we have to use the special
  '%pure-parser' directive.  Documentation on the 'net seems to
  disagree about whether this should be %pure-parser (with a hyphen)
  or %pure_parser (with an underscore).

  I have found %pure-parser to work just fine.  JRH */
%pure-parser

/* Define the lexical tokens used by the grammar.
      These definitions will be available to the lexer via the
      grammar.h header file, which is generated by bison */ 
%token T_KEYWORD_POLICY
%token T_KEYWORD_HOST
%token T_KEYWORD_ENFORCE
%token T_KEYWORD_EXTEND
%token T_KEYWORD_IF
%token T_KEYWORD_UNLESS
%token T_KEYWORD_ELSE
%token T_KEYWORD_MAP
%token T_KEYWORD_IS
%token T_KEYWORD_NOT
%token T_KEYWORD_DEPENDS_ON
%token T_KEYWORD_AFFECTS

/* These token definitions identify the expected type of the lvalue.
   The name 'string' comes from the union members of the YYSTYPE
   union, defined in private.h

   N.B.: I deliberately do not use the %union construct provided by
   bison, opting to define the union myself in private.h.  If one of
   the possible lvalue types is not a basic type (like char*, int, etc.)
   then lexer is required to include the necessary header files. */
%token <string> T_IDENTIFIER
%token <string> T_FACT
%token <string> T_QSTRING
%token <string> T_NUMERIC

/* Define the lvalue types of non-terminal productions.
   These definitions are necessary so that the $1..$n and $$ "magical"
   variables work in the generated C code. */
/*%type <node> definitions         /* AST_OP_PROG */
%type <manifest> manifest
%type <stree> host policy
%type <stree> enforcing enforce
%type <stree> blocks block
%type <stree> resource conditional extension
%type <stree> attributes attribute
%type <stree> dependency resource_id

%type <branch> conditional_test

%type <string>  value
%type <strings> value_list
%type <strings> explicit_value_list
%type <string> qstring

%type <map>         conditional_inline
%type <string_hash> mapped_value_set
%type <string_pair> mapped_value
%type <string>      mapped_value_default
%{
/* grammar_impl.c contains several static routines that only make sense
   within the context of a parser.  They deal with interim representations
   of abstract syntax trees, like if branches and map constructs.  They
   exist in a separate C file to keep this file clean and focues. */
#include "grammar_impl.c"

#define MANIFEST(ctx) (((spec_parser_context*)ctx)->root)
#define NODE(op,d1,d2) (manifest_new_stree(MANIFEST(ctx), (op), (d1), (d2)))
%}

%%

manifest:
		{ MANIFEST(ctx) = manifest_new(); }
	| manifest host
		{ stree_add(MANIFEST(ctx)->root, $2);
		  hash_set(MANIFEST(ctx)->hosts, $2->data1, $2); }
	| manifest policy
		{ stree_add(MANIFEST(ctx)->root, $2);
		  hash_set(MANIFEST(ctx)->policies, $2->data1, $2); }
	;

host: T_KEYWORD_HOST qstring '{' enforcing '}'
		{ $$ = $4;
		  $$->op = HOST;
		  $$->data1 = xstrdup($2); }
	;

enforcing:
		{ $$ = NODE(PROG, NULL, NULL); }
	| enforcing enforce
		{ stree_add($$, $2); }
	;

enforce: T_KEYWORD_ENFORCE qstring
		{ $$ = NODE(INCLUDE, $2, NULL); }
	;

policy: T_KEYWORD_POLICY qstring '{' blocks '}'
		{ $$ = $4;
		  $$->op = POLICY;
		  $$->data1 = xstrdup($2); }
	;

blocks:
		{ $$ = NODE(PROG, NULL, NULL); }
	| blocks block
		{ stree_add($$, $2); }
	;

block: resource | conditional | extension | dependency
	;

resource: T_IDENTIFIER value '{' attributes '}'
		{ $$ = $4;
		  $$->op = RESOURCE;
		  $$->data1 = xstrdup($1);
		  $$->data2 = xstrdup($2); }
	;

attributes:
		{ $$ = NODE(PROG, NULL, NULL); }
	| attributes attribute
		{ stree_add($$, $2); }
	;

attribute: T_IDENTIFIER ':' value
		{ $$ = NODE(ATTR, $1, $3); }
	| T_IDENTIFIER ':' conditional_inline
		{ $3->attribute = $1;
		  $$ = map_expand(MANIFEST(ctx),$3); }
	;

value: qstring | T_NUMERIC
	;

conditional: T_KEYWORD_IF '(' conditional_test ')' '{' blocks '}'
		{ branch_connect($3, $6, NODE(NOOP, NULL,  NULL));
		  $$ = branch_expand(MANIFEST(ctx), $3); }
	| T_KEYWORD_IF '(' conditional_test ')' '{' blocks '}' T_KEYWORD_ELSE '{' blocks '}'
		{ branch_connect($3, $6, $10);
		  $$ = branch_expand(MANIFEST(ctx), $3); }
	| T_KEYWORD_UNLESS '(' conditional_test ')' '{' blocks '}'
		{ $3->affirmative = ($3->affirmative == 1 ? 0 : 1);
		  branch_connect($3, $6, NODE(NOOP, NULL, NULL));
		  $$ = branch_expand(MANIFEST(ctx), $3); }
	| T_KEYWORD_UNLESS '(' conditional_test ')' '{' blocks '}' T_KEYWORD_ELSE '{' blocks '}'
		{ $3->affirmative = ($3->affirmative == 1 ? 0 : 1);
		  branch_connect($3, $6, $10);
		  $$ = branch_expand(MANIFEST(ctx), $3); }
	;

conditional_test: T_FACT T_KEYWORD_IS value_list
		{ $$ = branch_new($1, $3, 1); }
	| T_FACT T_KEYWORD_IS T_KEYWORD_NOT value_list
		{ $$ = branch_new($1, $4, 0); }
	;

value_list: value
		{ $$ = stringlist_new(NULL);
		  stringlist_add($$, $1); }
	| '[' explicit_value_list ']'
		{ $$ = $2; }
	;

explicit_value_list: value
		{ $$ = stringlist_new(NULL);
		  stringlist_add($$, $1); }
	| explicit_value_list ',' value
		{ stringlist_add($$, $3); }
	;

extension: T_KEYWORD_EXTEND qstring
		{ $$ = NODE(INCLUDE, $2, NULL); }
	;

dependency: resource_id T_KEYWORD_DEPENDS_ON resource_id
		{ $$ = NODE(DEPENDENCY, NULL, NULL);
		  stree_add($$, $1);
		  stree_add($$, $3); }
	  | resource_id T_KEYWORD_AFFECTS    resource_id
		{ $$ = NODE(DEPENDENCY, NULL, NULL);
		  stree_add($$, $3);
		  stree_add($$, $1); }
	  ;

resource_id: T_IDENTIFIER '(' value ')'
			{ $$ = NODE(RESOURCE_ID, $1, $3); }

conditional_inline: T_KEYWORD_MAP '(' T_FACT ')' '{' mapped_value_set mapped_value_default '}'
		{ $$ = map_new($3, NULL, $6[0], $6[1], $7); }
	;

mapped_value_set:
		{ $$[0] = stringlist_new(NULL);
		  $$[1] = stringlist_new(NULL); }
	| mapped_value_set mapped_value
		{ stringlist_add($$[0], $2[0]);
		  stringlist_add($$[1], $2[1]); }
	;

mapped_value: qstring ':' value
		{ $$[0] = $1;
		  $$[1] = $3; }
		;

mapped_value_default:
		{ $$ = NULL }
	| T_KEYWORD_ELSE ':' value
		{ $$ = $3; }
	;

qstring: T_QSTRING
	| T_IDENTIFIER
		{ spec_parser_warning(YYPARSE_PARAM, "unexpected identifier '%s', expected quoted string literal", $1); }
	;
