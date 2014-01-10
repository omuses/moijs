/*
 * Lexical specification for Modelica 3.3.
 * To be used together with a Jison parser.
 */

/* Copyright (c) 2013 -- 2014 Ruediger Franke */
 
/* Lexical units, see Appendix B.1 */
IDENT            {NONDIGIT} ( {DIGIT} | {NONDIGIT} )* | {Q-IDENT}
Q-IDENT          \' ( {Q-CHAR} | {S-ESCAPE} )+ \'
NONDIGIT         [_a-zA-Z]
STRING           \" ( {S-CHAR} | {S-ESCAPE} )* \"
S-CHAR           [^\"\\]
Q-CHAR           {NONDIGIT} | {DIGIT} | [!#$%&()*+,\-./:;<>=?@[\]\^{}|~ ]
S-ESCAPE         \\[\'\"\?\\abfnrtv]
DIGIT            [0-9]
UNSIGNED_INTEGER {DIGIT}+
UNSIGNED_NUMBER  {UNSIGNED_INTEGER} ("." {UNSIGNED_INTEGER}? )? \
                    ([eE][+\-]? {UNSIGNED_INTEGER} )?

/* Keywords, see Section 2.3.3 -- excluding assert, that is no keyword */
KEYWORD          "algorithm" | "and" | "annotation" | /* "assert" | */ "block" | "break" | \
                 "class" | "connector" | "connect" | "constant" | "constrainedby" | "der" | \
                 "discrete" | "each" | "else" | "elseif" | "elsewhen" | "encapsulated" | \
                 "end" | "enumeration" | "equation" | "expandable" | "extends" | "external" | \
                 "false" | "final" | "flow" | "for" | "function" | "if" | "import" | \
                 "impure" | "in" | "initial" | "inner" | "input" | \
                 "loop" | "model" | "not" | "operator" | "or" | "outer" | "output" | \
                 "package" | "parameter" | "partial" | "protected" | "public" | \
                 "pure" | "record" | "redeclare" | "replaceable" | "return" | "stream" | \
                 "then" | "true" | "type" | "when" | "while" | "within"
                 
COMBINED_KEYWORD     ("end" [\s]+ ("if" | "for" | "when" | "while")) | \
                     ("initial" [\s]+ ("equation" | "algorithm")) | \
                     ("operator" [\s]+ "function")

/* operators */
ASSIGN_OP        ":="
REL_OP           "==" | "<>" | "<=" | "<" | ">=" | ">"
ADD_OP_PARTIAL   ".+" | ".-" | "-"        /* note: partial due to string concat */
MUL_OP_PARTIAL   "./" | "/" | "*"         /* note: partial due to import name.* */
EXP_OP           ".^" | "^"

DOT_STAR         ".*"

/* Literals used for code structuring, including "+" as used for sting concatenation */
LITERAL          "." | "," | ";" | ":" | "(" | ")" | "[" | "]" | "{" | "}" | "=" | "+"

%s COMMENT

%%

\s+                     /* skip whitespaces */
<COMMENT>"*/"           {this.begin('INITIAL');}
<COMMENT>.              /* skip block comments */
"/*"                    {this.begin('COMMENT');}
"//".*                  /* skip comments */
{COMBINED_KEYWORD}\b    {this.mo_kind = 'KEYWORD';
                         return yytext.toUpperCase().replace(/\s+/, "_");}
end\s+{IDENT}           {this.mo_kind = 'KEYWORD';
                         return 'END_IDENT';}
{KEYWORD}\b             {this.mo_kind = 'KEYWORD';
                         return yytext.toUpperCase();}
{IDENT}                 {return 'IDENT';}
{STRING}                {return 'STRING';}
{UNSIGNED_NUMBER}       {return 'UNSIGNED_NUMBER';}
{DOT_STAR}              {return 'DOT_STAR'}
{ASSIGN_OP}             {return 'ASSIGN_OP'}
{REL_OP}                {return 'REL_OP'}
{ADD_OP_PARTIAL}        {return 'ADD_OP_PARTIAL'}
{MUL_OP_PARTIAL}        {return 'MUL_OP_PARTIAL'}
{EXP_OP}                {return 'EXP_OP'}
{LITERAL}               {return yytext;}
<<EOF>>                 {return 'EOF';}
