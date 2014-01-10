/*
 * Parser specification for Modelica 3.3.
 * Generate moparser.js with:
 * $ jison moparser.jison molexer.jisonlex -p lr
 */
 
/* Copyright (c) 2013 -- 2014 Ruediger Franke */

%left OR
%left AND
%right NOT
%left REL_OP
%left add_op ADD_OP_PARTIAL "+"
%left mul_op MUL_OP_PARTIAL DOT_STAR
%right EXP_OP

%%

start:
        stored_definition EOF
        {
            return $1;
        }
    ;

/* B2.1 Stored Definition -- Within */
    
stored_definition:
        /* empty */
        {
            $$ = new StoredDefinition(track(@$));
        }
    |   WITHIN opt_name ";"
        {
            $$ = new StoredDefinition(track(@$));
            $$.name = $2;
        }
    |   stored_definition opt_final class_definition ";"
        {
            if ($2) $3.isFinal = true;
            if (!$$.classDefinitionList)
                $$.classDefinitionList = [];
            $$.classDefinitionList.push($3);
            updateTrack($$, @$);
        }
/*
    |   stored_definition error ";"
        {
            console.log("Error parsing stored_definition");
        }
*/
    ;

/* B2.2 Class Definition */

class_definition:
        opt_encapsulated class_prefixes class_specifier
        {
            $$ = $2;
            if ($1) $$.isEncapsulated = true;
            copyAttributes($3, $$);
            updateTrack($$, @$);
            /* console.log("parsed %s %s", $2.constructor.name, $3.ident); */
        }
    ;

class_prefixes:
        opt_partial kind
        {
            if ($1) $2.isPartial = true;
            $$ = $2;
            updateTrack($$, @$);
        }
    ;

kind:
        CLASS
        {
            $$ = new ClassDefinition(track(@$));
        }
    |   MODEL
        {
            $$ = new ModelDefinition(track(@$));
        }
    |   opt_operator RECORD
        {
            $$ = new RecordDefinition(track(@$));
            if ($1) $$.isOperator = true;
        }
    |   BLOCK
        {
            $$ = new BlockDefinition(track(@$));
        }
    |   opt_expandable CONNECTOR
        {
            $$ = new ConnectorDefinition(track(@$));
            if ($1) $$.isExpandable = true;
        }
    |   TYPE
        {
            $$ = new TypeDefinition(track(@$));
        }
    |   PACKAGE
        {
            $$ = new PackageDefinition(track(@$));
        }
    |   opt_purity FUNCTION
        {
            $$ = new FunctionDefinition(track(@$));
            if ($1 === "pure") $$.isPure = true;
            if ($1 === "impure") $$.isImpure = true;
        }
    |   opt_purity OPERATOR_FUNCTION
        {
            $$ = new FunctionDefinition(track(@$));
            $$.isOperator = true;
            if ($1 === "pure") $$.isPure = true;
            if ($1 === "impure") $$.isImpure = true;
        }
    |   OPERATOR
        {
            $$ = new OpertaorDefinition(track(@$));
        }
    ;

opt_purity:
        /* empty */
    |   PURE
    |   IMPURE
    ;

class_specifier:
        IDENT string_comment composition end_ident
        {
            if ($1 != $4) {
                throw new SyntaxError((new Track(@4)).toString() + ": end " +
                                      $4 + " does not match class ident " + $1);
            }
            $$ = new ClassSpecifier(track(@$));
            $$.ident = $1;
            $$.stringComment = $2;
            copyAttributes($3, $$);
        }
/*
    |   IDENT error end_ident
        {
            console.log("Error: %s: bad class_specifier for \"%s\"",
                        (new Track(@1)).toString(), $1);
        }
*/
    |   short_class_specifier
    |   IDENT "=" DER "(" name "," ident_list ")" comment
        {
            $$ = new ClassSpecifier(track(@$));
            $$.ident = $1;
            $$.isDer = true;
            $$.name = $5;
            $$.identList = $7;
            copyAttributes($9, $$);
        }
    |   EXTENDS IDENT opt_class_modification string_comment
                      composition end_ident
        {
            $$ = new ClassSpecifier(track(@$));
            $$.ident = $2;
            $$.isExtends = true;
            if ($3) $$.classModification = $3;
            if ($4) $$.stringComment = $4;
            copyAttributes($5, $$);
        }
    ;

short_class_specifier: 
        IDENT "=" base_prefix name 
                      opt_array_subscripts opt_class_modification comment
        {
            $$ = new ClassSpecifier(track(@$));
            $$.ident = $1;
            copyAttributes($3, $$);
            $$.name = $4;
            if ($5) $$.arraySubscripts = $5;
            if ($6) $$.classModification = $6;
            copyAttributes($7, $$);
        }
    |   IDENT "=" ENUMERATION "(" opt_enum_list_or_colon ")" comment
        {
            $$ = new ClassSpecifier(track(@$));
            $$.ident = $1;
            $$.isEnumeration = true;
            if ($5) $$.enumList = $5;
            copyAttributes($7, $$);
        }
    ;

ident_list:
        IDENT
        {
            $$ = new IdentList;
            $$.push($1);
        }
    |   ident_list "," IDENT
        {
            $$.push($3);
        }
    ;

end_ident:
        END_IDENT
        {
            $$ = $1.split(/\s+/)[1];
        }
    ;

base_prefix:
        type_prefix
    ;

opt_enum_list_or_colon:
        opt_enum_list
    | ":"
    ;

opt_enum_list:
        /* empty */
    |   enum_list
    ;

enum_list:
        enumeration_literal
        {
            $$ = new EnumList;
            $$.push($1);
        }
    |   enum_list "," enumeration_literal
        {
            $$.push($3);
        }
    ;

enumeration_literal:
        IDENT comment
        {
            $$ = new EnumerationLiteral(track(@$));
            $$.ident = $1;
            copyAttributes($2, $$);
        }
    ;

composition:
        element_list section_list \
            opt_external opt_annotation_semicolon
        {
            $$ = new Composition();
            if ($1) $$.storeElementList($1);
            if ($2) $$.storeSectionList($2);
            if ($3) $$.external = $3;
            if ($4) $$.annotation = $4;
        }
    ;

element_list:
        /* empty */
    |   element_list element ";"
        {
            $$ = $1 || new ElementList;
            $$.push($2);
        }
    ;

element:
        import_clause
    |   extends_clause
    |   element_decorations class_definition_or_component_clause
        {
            $$ = $2;
            copyAttributes($1, $$);
            updateTrack($$, @$);
        }
    |   element_decorations REPLACEABLE class_definition_or_component_clause 
            opt_constraining_clause_comment
        {
            $$ = $3;
            copyAttributes($1, $$);
            $$.isReplaceable = true;
            copyAttributes($4, $$);
            updateTrack($$, @$);
        }
    ;

element_decorations:
        opt_redeclare opt_final opt_inner opt_outer
        {
            $$ = {};
            if ($1) $$.isRedeclare = true;
            if ($2) $$.isFinal = true;
            if ($3) $$.isInner = true;
            if ($4) $$.isOuter = true;
        }
    ;

class_definition_or_component_clause:
        class_definition
    |   component_clause
    ;

opt_constraining_clause_comment:
        /* empty */
    |   constraining_clause comment
        {
            $$ = {};
            $$.constrainingClause = $1;
            copyAttributes($2, $$);
        }
    ;

import_clause:
        IMPORT IDENT "=" name comment
        {
            $$ = new ImportClause(track(@$));
            $$.ident = $2;
            $$.name = $4;
            copyAttributes($5, $$);
        }
    |   IMPORT name opt_import_filter comment
        {
            $$ = new ImportClause(track(@$));
            $$.name = $2;
            copyAttributes($3, $$);
            copyAttributes($4, $$);
        }
    ;

opt_import_filter:
        /* empty */
    |   DOT_STAR
        {
            $$ = {isStar: true};
        }
    |   "." "*" /* with blanks in between */
        {
            $$ = {isStar: true};
        }
    |   "." "{" import_list "}"
        {
            $$ = {importList: $3};
        }
    ;

import_list:
        IDENT
        {
            $$ = [$1];
        }
    |   IDENT "," import_list
        {
            $$ = $3;
            $$.splice(0, 0, $1);
        }
    ;

section_list:
        /* empty */
    |   section_list section
        {
            $$ = $1 || new SectionList;
            $$.push($2);
        }
    ;

section:
        PUBLIC element_list
        {
            $$ = $2;
            for (var element in $$)
                element.isPublic = true;
        }
    |   PROTECTED element_list
        {
            $$ = $2;
            for (var element in $$)
                element.isProtected = true;
        }
    |   algorithm_section
    |   equation_section
    ;

opt_external:
        /* empty */
    |   EXTERNAL opt_language_specification
            opt_external_function_call opt_annotation ";"
        {
            $$ = $3 || new External(track(@$));
            if ($2) $$.languageSpecification = $2;
            if ($4) $$.annotation = $4;
        }
    ;

opt_language_specification:
        /* empty */
    |   STRING
    ;

opt_external_function_call:
        /* empty */
    |   IDENT "(" opt_expression_list ")"
        {
            $$ = new External(track(@$));
            $$.ident = $1;
            if ($3) $$.expressionList = $3;
        }
    |   component_reference "=" IDENT "(" opt_expression_list ")"
        {
            $$ = new External(track(@$));
            $$.componentReference = $1;
            $$.ident = $3;
            if ($5) $$.expressionList = $5;
        }
    ;

/* B2.3 Extends */

extends_clause:
        EXTENDS name opt_class_modification opt_annotation
        {
            $$ = new ExtendsClause(track(@$));
            $$.name = $2;
            if ($3) $$.classModification = $3;
            if ($4) $$.annotation = $4;
        }
    ;

opt_constraining_clause:
        /* empty */
    |   constraining_clause
    ;

constraining_clause:
        CONSTRAINEDBY name opt_class_modification
        {
            $$ = new ConstrainingClause(track(@$));
            $$.name = $2;
            if ($3) $$.classModification = $3;
        }
    ;

/* B2.4 Component Clause */

component_clause:
        type_prefix type_specifier opt_array_subscripts component_list
        {
            $$ = new ComponentClause(track(@$));
            copyAttributes($1, $$);
            $$.typeSpecifier = $2;
            if ($3) $$.arraySubscripts = $3;
            $$.componentList = $4;
            /* setup backwards links to clause, to obtain type_specifier */
            $$.componentList.forEach(function(componentDeclaration) {
                componentDeclaration.componentClause = $$;
            });
        }
    ;

type_prefix:
        flow_prefix variability_prefix causality_prefix
        {
            $$ = {};
            if ($1 === "flow")      $$.isFlow = true;
            if ($1 === "stream")    $$.isStream = true;
            if ($2 === "discrete")  $$.isDiscrete = true;
            if ($2 === "parameter") $$.isParameter = true;
            if ($2 === "constant")  $$.isConstant = true;
            if ($3 === "input")     $$.isInput = true;
            if ($3 === "output")    $$.isOutput = true;
        }
    ;

flow_prefix:
        /* empty */
    |   FLOW
    |   STREAM
    ;

variability_prefix:
        /* empty */
    |   DISCRETE
    |   PARAMETER
    |   CONSTANT
    ;

causality_prefix:
        /* empty */
    |   INPUT
    |   OUTPUT
    ;

type_specifier:
        name
    ;

component_list:
        component_declaration
        {
            $$ = new ComponentList;
            $$.push($1);
        }
    |   component_list "," component_declaration
        {
            $$.push($3);
        }
    ;

component_declaration:
        declaration opt_condition_attribute comment
        {
            if ($2) $$.conditionAttribute = $2;
            copyAttributes($3, $$);
        }
    ;

declaration:
        IDENT opt_array_subscripts opt_modification
        {
            $$ = new ComponentDeclaration(track(@$));
            $$.ident = $1;
            if ($2) $$.arraySubscripts = $2;
            if ($3) $$.modification = $3;
        }
    ;

opt_condition_attribute:
        /* empty */
    |   IF expression
        {
            $$ = $2;
        }
    ;

/* B2.5 Modification */

opt_modification:
        /* empty */
    |   modification
    ;

modification:
        class_modification opt_eq_expression
        {
            $$ = new Modification;
            $$.classModification = $1;
            if ($2) $$.expression = $2;
        }
    |   "=" expression
        {
            $$ = new Modification;
            $$.expression = $2;
        }
    |   ASSIGN_OP expression
        {
            $$ = new Modification;
            $$.expression = $2;
        }
    ;

opt_eq_expression:
        /* empty */
    |   "=" expression
        {
            $$ = $2;
        }
    ;

opt_class_modification:
        /* empty */
    |   class_modification
    ;

class_modification:
        "(" opt_argument_list ")"
        {
            $$ = new ClassModification(track(@$));
            copyAttributes($2, $$);
        }
    ;

opt_argument_list:
        /* empty */
    |   argument_list
    ;

argument_list:
        argument
        {
            $$ = new ArgumentList;
            $$.push($1);
        }
    |   argument_list "," argument
        {
            $$.push($3);
        }
    ;

argument:
        element_modification_or_replaceable
    |   element_redeclaration
    ;

element_modification_or_replaceable:
        opt_each opt_final element_modification_or_replaceable_definition
        {
            $$ = $3;
            if ($1) $$.isEach = true;
            if ($2) $$.isFinal = true;
        }
    ;

element_modification_or_replaceable_definition:
        element_modification
    |   element_replaceable
    ;

element_modification:
        name opt_modification string_comment
        {
            $$ = new ElementModification(track(@$));
            $$.name = $1;
            if ($2) $$.modification = $2;
            if ($3) $$.stringComment = $3;
        }
    ;

element_redeclaration:
        REDECLARE opt_each opt_final element_redeclaration_definition
        {
            $$ = $4;
            $$.isRedeclare = true;
            if ($1) $$.isEach = true;
            if ($2) $$.isFinal = true;
        }
    ;

element_redeclaration_definition:
        short_class_definition
    |   component_clause1
    |   element_replaceable
    ;

element_replaceable:
        REPLACEABLE short_class_definition opt_constraining_clause
        {
            $$ = $2;
            $$.isReplaceable = true;
            if ($3) $$.constrainingClause = $3;
        }
    |   REPLACEABLE component_clause1 opt_constraining_clause
        {
            $$ = $2;
            $$.isReplaceable = true;
            if ($3) $$.constrainingClause = $3;
        }
    ;

component_clause1:
        type_prefix type_specifier component_declaration1
        {
            $$ = new ComponentClause1(track(@$));
            copyAttributes($1, $$);
            $$.typeSpecifier = $2;
            $$.componentDeclaration1 = $3;
        }
    ;

component_declaration1:
        declaration comment
        {
            copyAttributes($2, $$);
        }
    ;

short_class_definition:
        class_prefixes short_class_specifier
        {
            copyAttributes($2, $$);
        }
    ;


/* B2.6 Equations */

equation_section:
        INITIAL_EQUATION equation_list
        {
            $$ = new EquationSection(track(@$));
            $$.isInitial = true;
            if ($2) $$.equationList = $2;
        }
    |   EQUATION equation_list
        {
            $$ = new EquationSection(track(@$));
            if ($2) $$.equationList = $2;
        }
    ;

equation_list:
        /* empty */
    |   equation_list equation ";"
        {
            $$ = $1 || [];
            $$.push($2);
        }
    ;

algorithm_section:
        INITIAL_ALGORITHM statement_list
        {
            $$ = new AlgorithmSection(track(@$));
            $$.isInitial = true;
            if ($2) $$.statementList = $2;
        }
    |   ALGORITHM statement_list
        {
            $$ = new AlgorithmSection(track(@$));
            if ($2) $$.statementList = $2;
        }
    ;

statement_list:
        /* empty */
    |   statement_list statement ";"
        {
            $$ = $1 || [];
            $$.push($2);
        }
    ;

equation:
        simple_expression "=" expression comment
        {
            $$ = new SimpleEquation(track(@$));
            $$.simpleExpression = $1;
            $$.expression = $3;
            copyAttributes($4, $$);
        }
    |   if_equation comment    {copyAttributes($2, $$);}
    |   for_equation comment   {copyAttributes($2, $$);}
    |   connect_clause comment {copyAttributes($2, $$);}
    |   when_equation comment  {copyAttributes($2, $$);}
    |   fname function_call_args comment
        {
            $$ = new FunctionCallEquation(track(@$));
            $$.name = $1;
            $$.functionCallArgs = $2;
            copyAttributes($3, $$);
        }
    ;

statement:
        component_reference ASSIGN_OP expression comment
        {
            $$ = new SimpleStatement(track(@$));
            $$.componentReference = $1;
            $$.expression = $3;
            copyAttributes($4, $$);
        }
    |   component_reference function_call_args comment
        {
            $$ = new FunctionCallStatement(track(@$));
            $$.componentReference = $1;
            $$.functionCallArgs = $2;
            copyAttributes($3, $$);
        }
    |   "(" output_expression_list ")" ASSIGN_OP
            component_reference function_call_args comment
        {
            $$ = new FunctionCallStatement(track(@$));
            $$.componentReference = $5;
            $$.functionCallArgs = $6;
            $$.outputExpressionList = $2;
            copyAttributes($7, $$);
        }
    |   BREAK comment
        {
            $$ = new KeywordStatement(track(@$));
            $$.keyword = $1;
            copyAttributes($2, $$);
        }
    |   RETURN comment
        {
            $$ = new KeywordStatement(track(@$));
            $$.keyword = $1;
            copyAttributes($2, $$);
        }
    |   if_statement comment    {copyAttributes($2, $$);}
    |   for_statement comment   {copyAttributes($2, $$);}
    |   while_statement comment {copyAttributes($2, $$);}
    |   when_statement comment  {copyAttributes($2, $$);}
    ;

if_equation:
        IF expression THEN equation_list elseif_equation END_IF
        {
            $$ = new IfEquation(track(@$));
            $$.keyword = $1;
            $$.expression = $2;
            $$.equationList = $4;
            $$.elseEquation = $5;
        }
    ;

elseif_equation:
        /* empty */
    |   ELSEIF expression THEN equation_list elseif_equation
        {
            $$ = new IfEquation(track(@$));
            $$.keyword = $1;
            $$.expression = $2;
            $$.equationList = $4;
            $$.elseEquation = $5;
        }
    |   ELSE equation_list
        {
            $$ = new IfEquation(track(@$));
            $$.keyword = $1;
            $$.equationList = $2;
        }
    ;

if_statement:
        IF expression THEN statement_list elseif_statement END_IF
        {
            $$ = new IfStatement(track(@$));
            $$.keyword = $1;
            $$.expression = $2;
            $$.statementList = $4;
            $$.elseEquation = $5;
        }
    ;

elseif_statement:
        /* empty */
    |   ELSEIF expression THEN statement_list elseif_statement
        {
            $$ = new IfStatement(track(@$));
            $$.keyword = $1;
            $$.expression = $2;
            $$.statementList = $4;
            $$.elseEquation = $5;
        }
    |   ELSE statement_list
        {
            $$ = new IfStatement(track(@$));
            $$.keyword = $1;
            $$.statementList = $2;
        }
    ;

for_equation:
        FOR for_indices LOOP equation_list END_FOR
        {
            $$ = new ForEquation(track(@$));
            $$.forIndices = $2;
            $$.equationList = $4;
        }
    ;

for_statement:
        FOR for_indices LOOP statement_list END_FOR
        {
            $$ = new ForStatement(track(@$));
            $$.forIndices = $2;
            $$.statementList = $4;
        }
    ;

for_indices:
        for_index
        {
            $$ = [$1];
        }
    |   for_indices "," for_index
        {
            $$.push($3);
        }
    ;

for_index:
        IDENT opt_in_expression
        {
            $$ = new ForIndex(track(@$));
            $$.ident = $1;
            $$.expression = $2;
        }
    ;

opt_in_expression:
        /* empty */
    |   IN expression
        {
            $$ = $2;
        }
    ;

while_statement:
        WHILE expression LOOP statement_list END_WHILE
        {
            $$ = new WhileStatement(track(@$));
            $$.expression = $2;
            $$.statementList = $4;
        }
    ;

when_equation:
        WHEN expression THEN equation_list elsewhen_equation END_WHEN
        {
            $$ = new WhenEquation(track(@$));
            $$.keyword = $1;
            $$.expression = $2;
            $$.equationList = $4;
            $$.elseEquation = $5;
        }
    ;

elsewhen_equation:
        /* empty */
    |   ELSEWHEN expression THEN equation_list elsewhen_equation
        {
            $$ = new WhenEquation(track(@$));
            $$.keyword = $1;
            $$.expression = $2;
            $$.equationList = $4;
            $$.elseEquation = $5;
        }
    |   ELSE equation_list
        {
            $$ = new WhenEquation(track(@$));
            $$.keyword = $1;
            $$.equationList = $2;
        }
    ;

when_statement:
        WHEN expression THEN statement_list elsewhen_statement END_WHEN
        {
            $$ = new WhenStatement(track(@$));
            $$.keyword = $1;
            $$.expression = $2;
            $$.statementList = $4;
            $$.elseEquation = $5;
        }
    ;

elsewhen_statement:
        /* empty */
    |   ELSEWHEN expression THEN statement_list elsewhen_statement
        {
            $$ = new WhenStatement(track(@$));
            $$.keyword = $1;
            $$.expression = $2;
            $$.statementList = $4;
            $$.elseEquation = $5;
        }
    |   ELSE statement_list
        {
            $$ = new WhenStatement(track(@$));
            $$.keyword = $1;
            $$.statementList = $2;
        }
    ;

connect_clause:
        CONNECT "(" component_reference "," component_reference ")"
        {
            $$ = new ConnectClause(track(@$));
            $$.componentReference1 = $3;
            $$.componentReference2 = $5;
        }
    ;

/* B2.7 Expressions */

expression:
        simple_expression
    |   if_expression
    ;

if_expression:
        IF expression THEN expression elseif_else_expression
        {
            $$ = new IfExpression(track(@$));
            $$.operator = $1;
            $$.expression = $2;
            $$.expression2 = $4;
            $$.expression3 = $5;
        }
    ;

elseif_else_expression:
        ELSEIF expression THEN expression elseif_else_expression
        {
            $$ = new IfExpression(track(@$));
            $$.operator = $1;
            $$.expression = $2;
            $$.expression2 = $4;
            $$.expression3 = $5;
        }
    |   ELSE expression
        {
            $$ = new IfExpression(track(@$));
            $$.operator = $1;
            $$.expression = $2;
        }
    ;
///*
simple_expression:
        basic_expression
    |   basic_expression ":" basic_expression
        {
            $$ = new SimpleExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    |   basic_expression ":" basic_expression ":" basic_expression
        {
            $$ = new SimpleExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
            $$.expression3 = $5;
        }
    ;

basic_expression:
        primary
    |   basic_expression OR basic_expression
        {
            $$ = new LogicalExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    |   basic_expression AND basic_expression
        {
            $$ = new LogicalExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    |   NOT basic_expression
        {
            $$ = new LogicalExpression(track(@$));
            $$.operator = $1;
            $$.expression = $2;
        }
    |   basic_expression REL_OP basic_expression
        {
            $$ = new Relation(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    |   basic_expression add_op basic_expression
        {
            $$ = new ArithmeticExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    |   add_op basic_expression
        {
            $$ = new ArithmeticExpression(track(@$));
            $$.operator = $1;
            $$.expression = $2;
        }
    |   basic_expression mul_op basic_expression
        {
            $$ = new ArithmeticExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    |   basic_expression EXP_OP basic_expression
        {
            $$ = new ArithmeticExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    ;
//*/
/*
simple_expression:
        logical_expression
    |   logical_expression ":" logical_expression
        {
            $$ = new SimpleExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    |   logical_expression ":" logical_expression ":" logical_expression
        {
            $$ = new SimpleExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
            $$.expression3 = $5;
        }
    ;

logical_expression:
        logical_term
    |   logical_expression OR logical_term
        {
            $$ = new LogicalExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    ;

logical_term:
        logical_factor
    |   logical_term AND logical_factor
        {
            $$ = new LogicalExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    ;

logical_factor:
        relation
    |   NOT relation
        {
            $$ = new LogicalExpression(track(@$));
            $$.operator = $1;
            $$.expression = $2;
        }
    ;

relation:
        arithmetic_expression
    |   arithmetic_expression REL_OP arithmetic_expression
        {
            $$ = new Relation(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    ;

arithmetic_expression:
        term
    |   add_op term
        {
            $$ = new ArithmeticExpression(track(@$));
            $$.operator = $1;
            $$.expression = $2;
        }
    |   arithmetic_expression add_op term
        {
            $$ = new ArithmeticExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    ;

term:
        factor
    |   term mul_op factor
        {
            $$ = new ArithmeticExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    ;

factor:
        primary
    |   primary EXP_OP primary
        {
            $$ = new ArithmeticExpression(track(@$));
            $$.expression = $1;
            $$.operator = $2;
            $$.expression2 = $3;
        }
    ;
*/

add_op:
        ADD_OP_PARTIAL
    |   "+"
    ;

mul_op:
        MUL_OP_PARTIAL
    |   DOT_STAR
    ;

primary:
        UNSIGNED_NUMBER
        {
            $$ = new PrimaryUnsignedNumber(track(@$));
            $$.value = $1;
        }
    |   STRING
        {
            $$ = new PrimaryString(track(@$));
            $$.value = $1;
        }
    |   component_reference
        {
            $$ = new PrimaryComponentReference(track(@$));
            $$.value = $1;
        }
    |   primary_boolean
        {
            $$ = new PrimaryBoolean(track(@$));
            $$.value = $1;
        }
    |   fname function_call_args
        {
            $$ = new PrimaryFunctionCall(track(@$));
            $$.name = $1;
            $$.functionCallArgs = $2;
        }
    |   primary_operator function_call_args
        {
            $$ = new PrimaryFunctionCall(track(@$));
            $$.name = $1;
            $$.functionCallArgs = $2;
        }
    |   "(" output_expression_list ")"
        {
            $$ = new PrimaryTuple(track(@$));
            $$.value = $2;
        }
    |   "[" expression_matrix "]"
        {
            $$ = new PrimaryMatrix(track(@$));
            $$.value = $2;
        }
    |   "{" function_arguments "}"
        {
            $$ = new PrimaryArray(track(@$));
            $$.value = $2;
        }
    |   END
        {
            $$ = new PrimaryEnd(track(@$));
            $$.value = $1;
        }
    ;

primary_boolean:
        TRUE
    |   FALSE
    ;

primary_operator:
        DER
    |   INITIAL
    ;

opt_name:
        /* empty */
    |   name
    ;

name:
        IDENT
        {
            $$ = new Name(track(@$));
            $$.identList = [$1];
        }
    |   "." IDENT
        {
            $$ = new Name(track(@$));
            $$.isGlobal = true;
            $$.identList = [$2];
        }
    |   name "." IDENT
        {
            $$.identList.push($3);
            updateTrack($$, @$);
        }
    ;

fname:
        component_reference
        {
           /*
           Treat fname as special component_reference to avoid parse conflict;
           Note: name must not have array subscripts
           */
           $$ = new Name(track(@$));
           if ($1.isGlobal) $$.isGlobal = true;
           $$.identList = $1.identList;
           $1.arraySubscriptsList.forEach(function (arraySubscripts) {
               if (arraySubscripts) {
                   throw new SyntaxError((new Track(@1)).toString() + 
                                 ": bad function name with array subscripts");
               }
           });
        }
    ;

component_reference:
        IDENT opt_array_subscripts
        {
            $$ = new ComponentReference(track(@$));
            $$.identList = [$1];
            $$.arraySubscriptsList = [$2];
        }
    |   "." IDENT opt_array_subscripts
        {
            $$ = new ComponentReference(track(@$));
            $$.isGlobal = true;
            $$.identList = [$2];
            $$.arraySubscriptsList = [$3];
        }
    |   component_reference "." IDENT opt_array_subscripts
        {
            $$.identList.push($3);
            $$.arraySubscriptsList.push($4);
            updateTrack($$, @$);
        }
    ;

function_call_args:
        "(" opt_function_arguments ")"
        {
           $$ = new FunctionCallArgs(track(@$));
           copyAttributes($2, $$);
        }
    ;

opt_function_arguments:
        /* empty */
    |   function_arguments
    ;

function_arguments:
        function_argument
        {
            $$ = new FunctionArguments(track(@$));
            $$.positionalArgumentList = [$1];
        }
    |   function_argument "," function_arguments
        {
            $$ = $3;
            if (!$$.positionalArgumentList) /* if named_arguments present */
                $$.positionalArgumentList = [$1];
            else
                $$.positionalArgumentList.splice(0, 0, $1);
            updateTrack($$, @$);
        }
    |   function_argument FOR for_indices
        {
            $$ = new ForArgument(track(@$));
            $$.functionArgument = $1;
            $$.forIndices = $3;
        }
    |   named_arguments
    ;

opt_named_arguments:
        /* empty */
    |   named_arguments
    ;

named_arguments:
        named_argument
        {
            $$ = new FunctionArguments(track(@$));
            $$.namedArgumentList = [$1];
        }
    |   named_argument "," named_arguments
        {
            $$ = $3;
            $$.namedArgumentList.splice(0, 0, $1);
            updateTrack($$, @$);
        }
    ;

named_argument:
        IDENT "=" function_argument
        {
            $$ = new NamedArgument(track(@$));
            $$.ident = $1;
            $$.functionArgument = $3;
        }
    ;

function_argument:
        FUNCTION name "(" opt_named_arguments ")"
        {
            $$ = new FunctionReference(track(@$));
            $$.name = $2;
            if ($4) $$.namedArgumentList = $4;
        }
    |   expression
    ;

output_expression_list:
        /* empty */
    |   expression
        {
            $$ = new OutputExpressionList(track(@$));
            $$.push($1);
        }
    |   output_expression_list "," expression
        {
            $$.push($3);
            updateTrack($$, @$);
        }
    |   output_expression_list "," /* empty */
        {
            $$.push(undefined);
            updateTrack($$, @$);
        }
    ;

opt_expression_list:
        /* empty */
    |   expression_list
    ;

expression_list:
        expression
        {
            $$ = new ExpressionList(track(@$));
            $$.push($1);
        }
    |   expression_list "," expression
        {
            $$.push($3);
            updateTrack($$, @$);
        }
    ;

expression_matrix:
        expression_list
        {
            $$ = new ExpressionMatrix(track(@$));
            $$.push($1);
        }
    |   expression_matrix ";" expression_list
        {
            $$.push($3);
            updateTrack($$, @$);
        }
    ;

opt_array_subscripts:
        /* empty */
    |   array_subscripts
    ;

array_subscripts:
        "[" subscripts "]"
    ;

subscripts:
        subscript
        {
            $$ = new ArraySubscripts(track(@$));
            $$.push($1);
        }
    |   subscripts "," subscript
        {
            $$.push($3);
            updateTrack($$, @$);
        }
    ;

subscript:
        expression
        {
            $$ = new Subscript(track(@$));
            $$.value = $1;
        }
    |   ":"
        {
            $$ = new Subscript(track(@$));
            $$.value = $1;
        }
    ;

comment:
        string_comment opt_annotation
        {
            $$ = {};
            if ($1) $$.stringComment = $1;
            if ($2) $$.annotation = $2;
        }
    ;

string_comment:
        /* empty */
    |   string_concatenation
    ;

string_concatenation:
        STRING
        {
            $$ = new StringComment();
            $$.push($1);
        }
    |   string_concatenation "+" STRING
        {
            $$.push($3);
        }
    ;

opt_annotation:
        /* empty */
    |   annotation
    ;

annotation:
        ANNOTATION class_modification
        {
            $$ = new Annotation(track(@$));
            $$.classModification = $2;
        }
    ;

opt_annotation_semicolon:
        /* empty */
    |   annotation ";"
    ;

opt_each:         /* empty */ | EACH;
opt_encapsulated: /* empty */ | ENCAPSULATED;
opt_expandable:   /* empty */ | EXPANDABLE;
opt_inner:        /* empty */ | INNER;
opt_final:        /* empty */ | FINAL;
opt_operator:     /* empty */ | OPERATOR;
opt_outer:        /* empty */ | OUTER;
opt_partial:      /* empty */ | PARTIAL;
opt_redeclare:    /* empty */ | REDECLARE;

%%

/*
 * Tracking of locations
 */

/* factory function for Track objects
   (return undefined to skip tracking) */
function track(location) {
    return new Track(location);
}

/* update the track object of a production */
function updateTrack(production, location) {
    if (production.track)
        production.track = location;
}

/* constructor for Track objects storing locations */
function Track(location) {
    this.fileName = parser.lexer.fileName;
    this.location = location;
}

Track.prototype.toString = function() {
    var result = this.fileName? this.fileName + ": ": "";
    return result + this.location.first_line
                  + "." + this.location.first_column
                  + ": " + this.location.last_line
                  + "." + this.location.last_column;
};

/* 
 * Object types for the AST
 */

function defineSubclass(superclass, subclass) {
    subclass.prototype = new superclass;
    subclass.prototype.constructor = subclass;
}

function copyAttributes(src, dst) {
    for (var item in src)
        if (typeof(src[item]) !== "function" && item !== "track")
            dst[item] = src[item];
}

function Definition(track) {
    /* Common base class for Modelica definitions */
    if (track) this.track = track;
}

function List() {
    /* Common base class for lists */
}
defineSubclass(Array, List);

// See Modelica Spec 3.3, Appendix B2.1

function StoredDefinition(track) {
    Definition.call(this, track);
    /*
    this.name = undefined;
    this.classDefinitionList = [];
    */
}
defineSubclass(Definition, StoredDefinition);

// See Modelica Spec 3.3, Appendix B.2.2

function Element(track) {
    if (track) this.track = track;
    /*
    this.isPublic = false;
    this.isProtected = false;
    */
}

function ImportClause(track) {
    Element.call(this, track);
    /*
    this.ident = undefined;
    this.name = undefined;
    this.isStar = false;
    this.importList = undefined;
    this.stringComment = undefined;
    this.annotation = undefined;
    */
}
defineSubclass(Element, ImportClause);

function ElementList() {
}
defineSubclass(List, ElementList);

function SectionList() {
}
defineSubclass(List, SectionList);

function External(track) {
    Definition.call(this, track);
    /*
    this.ident = undefined;
    this.expressionList = undefined;
    this.componentReference = undefined;
    this.languageSpecification = undefined;
    this.annotation = undefined;
    */
}
defineSubclass(Definition, External);

function Composition() {
    // Flat representation of composition -- will go into ClassDefinition
    // sort different parts for simplified later use
    /*
    this.importClauseList = [];
    this.extendsClauseList = [];
    this.classDefinitionList = [];
    this.componentClauseList = [];
    this.initialEquationList = [];  // from equation sections
    this.equationList = [];
    this.initialStatementList = []; // from algorithm sections
    this.statementList = [];
    this.external = undefined;
    this.annotation = undefined;
    */
}

Composition.prototype.storeElementList = function (elementList) {
    var composition = this;
    (elementList || []).forEach(function(element) {
        if (element instanceof ImportClause) {
            if (!composition.importClauseList)
                composition.importClauseList = [];
            composition.importClauseList.push(element);
        }
        else if (element instanceof ExtendsClause) {
            if (!composition.extendsClauseList)
                composition.extendsClauseList = [];
            composition.extendsClauseList.push(element);
        }
        else if (element instanceof ComponentClause) {
            if (!composition.componentClauseList)
                composition.componentClauseList = [];
            composition.componentClauseList.push(element);
        }
        else if (element instanceof ClassDefinition) {
            if (!composition.classDefinitionList)
                composition.classDefinitionList = [];
            composition.classDefinitionList.push(element);
        }
        else {
            throw new SyntaxError(element.track?
                                  element.track.toString() + ": ": ""
                                  + "wrong element type "
                                  + element.constructor.name);
        }
    });
};

Composition.prototype.storeSectionList = function (sectionList) {
    var composition = this;
    (sectionList || []).forEach(function(section) {
        if (section instanceof EquationSection) {
            if (section.isInitial)
                (section.equationList || []).forEach(function(equation) {
                    if (!composition.initialEquationList)
                        composition.initialEquationList = [];
                    composition.initialEquationList.push(equation);
                });
            else
                (section.equationList || []).forEach(function(equation) {
                    if (!composition.equationList)
                        composition.equationList = [];
                    composition.equationList.push(equation);
                });
        }
        else if (section instanceof AlgorithmSection) {
            if (section.isInitial)
                (section.statementList || []).forEach(function(statement) {
                    if (!composition.initialStatementList)
                        composition.initialStatementList = [];
                    composition.initialStatementList.push(statement);
                });
            else
                (section.statementList || []).forEach(function(statement) {
                    if (!composition.statementList)
                        composition.statementList = [];
                    composition.statementList.push(statement);
                });
        }
        else if (section instanceof ElementList) {
            composition.storeElementList(section);
        }
        else {
            throw new SyntaxError(section.track?
                                    section.track.toString() + ": ": ""
                                  + "wrong section type "
                                  + section.constructor.name);
        }
    });
};

function EnumerationLiteral(track) {
    if (track) this.track = track;
    /*
    this.ident = undefined;
    this.stringComment = undefined;
    this.annotation = undefined;
    */
}

function EnumList() {
}
defineSubclass(List, EnumList);

function IdentList() {
}
defineSubclass(List, IdentList);

function ClassSpecifier(track) {
    if (track) this.track = track;
    /*
    this.ident = undefined;
    this.shortSpecifier = undefined;
    this.isExtends = false;
    this.classModification = undefined;
    this.stringComment = undefined;
    this.composition = undefined;
    // base_prefix of extends_specifier, i.e. type_prefix
    this.isFlow = false;
    this.isStream = false;
    this.isDiscrete = false;
    this.isParameter = false;
    this.isConstant = false;
    this.isInput = false;
    this.isOutput = false;
    // additional attributes of extends_specifier
    this.name = undefined;
    this.arraySubscripts = undefined; 
    // additional attributes of enumeration_specifier
    this.enumList = undefined;
    this.isEnumeration = true;
    // additional attributes of der_specifier
    this.identList = undefined;
    */
}

function ClassDefinition(track) {
    // Flat representation of class_prefixes, class_specifier, and composition
    Definition.call(this, track);
    /*
    // class_prefixes
    this.isFinal = false;
    this.isEncapsulated = false;
    this.isPartial = false;
    this.isOperator = false;
    this.isExpandable = false;
    this.isPure = false;
    this.isImpure = false;
    // class_specifier
    this.shortSpecifier = undefined;
    this.isExtends = false;
    this.ident = undefined;
    this.classModification = undefined;
    this.stringComment = undefined;
    // composition
    this.importClauseList = [];
    this.extendsClauseList = [];
    this.classDefinitionList = [];
    this.componentClauseList = [];
    this.initialEquationList = [];  // from equation sections
    this.equationList = [];
    this.initialStatementList = []; // from algorithm sections
    this.statementList = [];
    this.external = undefined;
    this.annotation = undefined;
    // optional element decorations
    this.isRedeclare = false;
    this.isFinal = false;
    this.isInner = false;
    this.isOuter = false;
    this.isReplaceable = false;
    // optional constraining clause for element_replaceable
    this.constrainingClause = undefined;
    */
}
defineSubclass(Definition, ClassDefinition);

function ModelDefinition(track) {
    ClassDefinition.call(this, track);
}
defineSubclass(ClassDefinition, ModelDefinition);

function RecordDefinition(track) {
    ClassDefinition.call(this, track);
}
defineSubclass(ClassDefinition, RecordDefinition);

function BlockDefinition(track) {
    ClassDefinition.call(this, track);
}
defineSubclass(ClassDefinition, BlockDefinition);

function ConnectorDefinition(track) {
    ClassDefinition.call(this, track);
}
defineSubclass(ClassDefinition, ConnectorDefinition);

function TypeDefinition(track) {
    ClassDefinition.call(this, track);
}
defineSubclass(ClassDefinition, TypeDefinition);

function PackageDefinition(track) {
    ClassDefinition.call(this, track);
}
defineSubclass(ClassDefinition, PackageDefinition);

function FunctionDefinition(track) {
    ClassDefinition.call(this, track);
}
defineSubclass(ClassDefinition, FunctionDefinition);

function OperatorDefinition(track) {
    ClassDefinition.call(this, track);
}
defineSubclass(ClassDefinition, OperatorDefinition);

// See Modelica Spec 3.3, Appendix B.2.3

function ExtendsClause(track) {
    Element.call(this, track);
    /*
    this.name = undefined;
    this.classModification = undefined;
    this.annotation = undefined;
    */
}
defineSubclass(Element, ExtendsClause);

function ConstrainingClause(track) {
    Element.call(this, track);
    /*
    this.name = undefined;
    this.classModification = undefined;
    */
}
defineSubclass(Element, ConstrainingClause);

// See Modelica Spec 3.3, Appendix B.2.4

function ComponentDeclaration(track) {
    if (track) this.track = track;
    /*
    this.componentClause = undefined; // required for e.g. typeSpecifier
    this.ident = undefined;
    this.arraySubscripts = undefined;
    this.modification = undefined;
    this.conditionAttribute = undefined;
    this.stringComment = undefined;
    this.annotation = undefined;
    */
}

function ComponentList() {
}
defineSubclass(List, ComponentList);

function ComponentClause(track) {
    if (track) this.track = track;
    /*
    // type_prefix
    this.isFlow = false;
    this.isStream = false;
    this.isDiscrete = false;
    this.isParameter = false;
    this.isConstant = false;
    this.isInput = false;
    this.isOutput = false;
    // type_specifier, array_subscripts, component_list
    this.typeSpecifier = undefined;
    this.arraySubscripts = undefined;
    this.componentList = undefined;
    // optional element decorations
    this.isRedeclare = false;
    this.isFinal = false;
    this.isInner = false;
    this.isOuter = false;
    this.isReplaceable = false;
    this.constrainingClause = undefined;
    this.stringComment = undefined;
    this.annotation = undefined;
    */
}

// See Modelica Spec 3.3, Appendix B.2.5

function ComponentClause1(track) {
    if (track) this.track = track;
    /*
    // type_prefix
    this.isFlow = false;
    this.isStream = false;
    this.isDiscrete = false;
    this.isParameter = false;
    this.isConstant = false;
    this.isInput = false;
    this.isOutput = false;
    // type_specifier, component_declaration1
    this.typeSpecifier = undefined;
    this.componentDeclaration = undefined;
    // decorations
    this.isRedeclare = false;
    this.isEach = false;
    this.isFinal = false;
    this.isReplaceable = false;
    this.constrainingClause = undefined;
    */
}

function ElementModification(track) {
    if (track) this.track = track;
    /*
    this.isEach = false;
    this.isFinal = false;
    this.name = undefined;
    this.modification = undefined;
    this.stringComment = undefined;
    */
}

function ArgumentList() {
}
defineSubclass(List, ArgumentList);

function ClassModification() {
}
defineSubclass(List, ClassModification);

function Modification() {
    /*
    this.argumentList = [];
    this.expression = undefined;
    */
}

// See Modelica Spec 3.3, Appendix B.2.6

function ForIndex(track) {
    Definition.call(this, track);
    /*
    this.ident = undefined;
    this.expression = undefined;
    */
}
defineSubclass(Definition, ForIndex);

function Equation(track) {
    Definition.call(this, track);
    /*
    this.stringComment = undefined;
    this.annotation = undefined;
    */
}
defineSubclass(Definition, Equation);

function SimpleEquation(track) {
    Equation.call(this, track);
    /*
    this.simpleExpression = undefined;
    this.expression = undefined;
    */
}
defineSubclass(Equation, SimpleEquation);

function Statement(track) {
    Definition.call(this, track);
}
defineSubclass(Definition, Statement);

function EquationStatement(track) {
    // object assignment in command mode (i.e. outside Modelica classes)
    Statement.call(this, track);
    this.componentReference = undefined;
    this.expression = undefined;
}
defineSubclass(Statement, EquationStatement);

function SimpleStatement() {
    Statement.call(this, track);
    this.componentReference = undefined;
    this.expression = undefined;
}
defineSubclass(Statement, EquationStatement);

function FunctionCallEquation(track) {
    Equation.call(this, track);
    /*
    this.name = undefined;
    this.functionCallArgs = undefined;
    */
}
defineSubclass(Equation, FunctionCallEquation);

function FunctionCallStatement(track) {
    Statement.call(this, track);
    /*
    this.componentReference = undefined;
    this.functionCallArgs = undefined;
    this.outputExpressionList = undefined;
    */
}
defineSubclass(Statement, FunctionCallStatement);

function ConditionalEquation(track) {
    Equation.call(this, track);
    /*
    this.keyword = undefined;
    this.expression = undefined;
    this.equationList = undefined;
    this.elseEquation = undefined;
    */
}
defineSubclass(Equation, ConditionalEquation);

function IfEquation(track) {
    ConditionalEquation.call(this, track);
}
defineSubclass(ConditionalEquation, IfEquation);

function WhenEquation(track) {
    ConditionalEquation.call(this, track);
}
defineSubclass(ConditionalEquation, WhenEquation);

function ConditionalStatement(track) {
    Equation.call(this, track);
    /*
    this.keyword = undefined;
    this.expression = undefined;
    this.statementList = undefined;
    this.elseStatement = undefined;
    */
}
defineSubclass(Statement, ConditionalStatement);

function IfStatement(track) {
    ConditionalStatement.call(this, track);
}
defineSubclass(ConditionalStatement, IfStatement);

function WhenStatement(track) {
    ConditionalStatement.call(this, track);
}
defineSubclass(ConditionalStatement, WhenStatement);

function ForEquation(track) {
    Equation.call(this, track);
    /*
    this.forIndices = undefined;
    this.equationList = undefined;
    */
}
defineSubclass(Equation, ForEquation);

function ForStatement(track) {
    Statement.call(this, track);
    /*
    this.forIndices = undefined;
    this.statementList = undefined;
    */
}
defineSubclass(Statement, ForStatement);

function WhileStatement(track) {
    Statement.call(this, track);
    /*
    this.expression = undefined;
    this.statementList = undefined;
    */
}
defineSubclass(Statement, WhileStatement);

function KeywordStatement(track) {
    Statement.call(this, track);
    this.keyword = undefined;
}
defineSubclass(Statement, KeywordStatement);

function AlgorithmSection(track) {
    Definition.call(this, track);
    /*
    this.isInitial = false;
    this.statementList = undefined;
    */
}
defineSubclass(Definition, AlgorithmSection);

function EquationSection(track) {
    Definition.call(this, track);
    /*
    this.isInitial = false;
    this.equationList = undefined;
    */
}
defineSubclass(Definition, EquationSection);

function ConnectClause(track) {
    Equation.call(this, track);
    /*
    this.componentReference1 = undefined;
    this.componentReference2 = undefined;
    */
}
defineSubclass(Equation, ConnectClause);


// See Modelica Spec 3.3, Appendix B.2.7

function StringComment() {
}
defineSubclass(List, StringComment);

function Annotation(track) {
    Definition.call(this, track);
}
defineSubclass(Definition, Annotation);

function Subscript(track) {
    if (track) this.track = track;
    this.value = undefined;
}

function ArraySubscripts(track) {
    if (track) this.track = track;
}
defineSubclass(List, ArraySubscripts);

function ComponentReference(track) {
    if (track) this.track = track;
    /*
    this.isGlobal = undefined;  // name is starting with "."
    this.identList = undefined;
    this.arraySubscriptsList = undefined;
    */
}

function Name(track) {
    if (track) this.track = track;
    /*
    this.isGlobal = undefined;
    this.identList = [];
    */
}

Name.prototype.toString = function () {
    return (this.isGlobal? ".": "") + this.identList.join(".");
};

function NamedArgument(track) {
    if (track) this.track = track;
    /*
    this.ident = undefined;
    this.functionArgument = undefined;
    */
}

function ForArgument(track) {
    if (track) this.track = track;
    this.functionArgument = undefined;
    this.forIndices = undefined;
}

function FunctionArguments(track) {
    if (track) this.track = track;
    /*
    this.positionalArgumentList = undefined;
    this.namedArgumentList = undefined;
    */
}

function FunctionCallArgs(track) {
    if (track) this.track = track;
    /*
    this.positionalArgumentList = undefined;
    this.namedArgumentList = undefined;
    */
}

function FunctionReference(track) {
    if (track) this.track = track;
    /*
    this.name = undefined;
    this.namedArgumentList = undefined;
    */
}

function Expression(track) {
    Definition.call(this, track);
}
defineSubclass(Definition, Expression);

function Primary(track) {
    Expression.call(this, track);
    /*
    this.value = undefined;
    */
}
defineSubclass(Expression, Primary);

function PrimaryUnsignedNumber(track) {
    Primary.call(this, track);
}
defineSubclass(Primary, PrimaryUnsignedNumber);

function PrimaryString(track) {
    Primary.call(this, track);
}
defineSubclass(Primary, PrimaryString);

function PrimaryBoolean(track) {
    Primary.call(this, track);
}
defineSubclass(Primary, PrimaryBoolean);

function PrimaryFunctionCall(track) {
    Primary.call(this, track);
    /*
    this.name = undefined;
    this.functionCallArgs = undefined;
    */
}
defineSubclass(Primary, PrimaryFunctionCall);

function PrimaryComponentReference(track) {
    Primary.call(this, track);
}
defineSubclass(Primary, PrimaryComponentReference);

function PrimaryTuple(track) {
    Primary.call(this, track);
}
defineSubclass(Primary, PrimaryTuple);

function PrimaryMatrix(track) {
    Primary.call(this, track);
}
defineSubclass(Primary, PrimaryMatrix);

function PrimaryArray(track) {
    Primary.call(this, track);
}
defineSubclass(Primary, PrimaryArray);

function PrimaryEnd(track) {
    Primary.call(this, track);
}
defineSubclass(Primary, PrimaryEnd);

function NonPrimaryExpression(track) {
    // Base class for composed expressions.
    // It provides a common constructor and common member variables.
    Expression.call(this, track);
    /*
    this.expression = undefined;
    this.operator = undefined;
    this.expression2 = undefined;
    this.expression3 = undefined;
    */
}
defineSubclass(Expression, NonPrimaryExpression);

function IfExpression(track) {
    NonPrimaryExpression.call(this, track);
}
defineSubclass(NonPrimaryExpression, IfExpression);

function SimpleExpression(track) {
    NonPrimaryExpression.call(this, track);
}
defineSubclass(NonPrimaryExpression, SimpleExpression);

function LogicalExpression(track) {
    NonPrimaryExpression.call(this, track);
}
defineSubclass(NonPrimaryExpression, LogicalExpression);

function Relation(track) {
    NonPrimaryExpression.call(this, track);
}
defineSubclass(NonPrimaryExpression, Relation);

function ArithmeticExpression(track) {
    NonPrimaryExpression.call(this, track);
}
defineSubclass(NonPrimaryExpression, ArithmeticExpression);

function ExpressionList(track) {
    if (track) this.track = track;
}
defineSubclass(List, ExpressionList);

function OutputExpressionList(track) {
    if (track) this.track = track;
}
defineSubclass(List, OutputExpressionList);

function ExpressionMatrix(track) {
    if (track) this.track = track;
}
defineSubclass(List, ExpressionMatrix);

/* export parser classes */
parser.Definition = Definition;
parser.List = List;
parser.StoredDefinition = StoredDefinition;
parser.Element = Element;
parser.ImportClause = ImportClause;
parser.ElementList = ElementList;
parser.SectionList = SectionList;
parser.External = External;
//parser.Composition = Composition;
parser.EnumerationLiteral = EnumerationLiteral;
parser.EnumList = EnumList;
parser.IdentList = IdentList;
parser.ClassDefinition = ClassDefinition;
parser.ModelDefinition = ModelDefinition;
parser.RecordDefinition = RecordDefinition;
parser.BlockDefinition = BlockDefinition;
parser.ConnectorDefinition = ConnectorDefinition;
parser.TypeDefinition = TypeDefinition;
parser.PackageDefinition = PackageDefinition;
parser.FunctionDefinition = FunctionDefinition;
parser.OperatorDefinition = OperatorDefinition;
parser.ExtendsClause = ExtendsClause;
parser.ConstrainingClause = ConstrainingClause;
parser.ComponentDeclaration = ComponentDeclaration;
parser.ComponentList = ComponentList;
parser.ComponentClause = ComponentClause;
parser.ComponentClause1 = ComponentClause1;
parser.ElementModification = ElementModification;
parser.ArgumentList = ArgumentList;
parser.ClassModification = ClassModification;
parser.Modification = Modification;
parser.ForIndex = ForIndex;
parser.Equation = Equation;
parser.SimpleEquation = SimpleEquation;
parser.Statement = Statement;
parser.EquationStatement = EquationStatement;
parser.SimpleStatement = SimpleStatement;
parser.FunctionCallEquation = FunctionCallEquation;
parser.FunctionCallStatement = FunctionCallStatement;
parser.ConditionalEquation = ConditionalEquation;
parser.IfEquation = IfEquation;
parser.WhenEquation = WhenEquation;
parser.ConditionalStatement = ConditionalStatement;
parser.IfStatement = IfStatement;
parser.WhenStatement = WhenStatement;
parser.ForEquation = ForEquation;
parser.ForStatement = ForStatement;
parser.WhileStatement = WhileStatement;
parser.KeywordStatement = KeywordStatement;
//parser.AlgorithmSection = AlgorithmSection;
//parser.EquationSection = EquationSection;
parser.ConnectClause = ConnectClause;
parser.StringComment = StringComment;
parser.Annotation = Annotation;
parser.Subscript = Subscript;
parser.ArraySubscripts = ArraySubscripts;
parser.ComponentReference = ComponentReference;
parser.Name = Name;
parser.NamedArgument = NamedArgument;
parser.ForArgument = ForArgument;
parser.FunctionArguments = FunctionArguments;
parser.FunctionCallArgs = FunctionCallArgs;
parser.FunctionReference = FunctionReference;
parser.Expression = Expression;
parser.Primary = Primary;
parser.PrimaryUnsignedNumber = PrimaryUnsignedNumber;
parser.PrimaryString = PrimaryString;
parser.PrimaryBoolean = PrimaryBoolean;
parser.PrimaryFunctionCall = PrimaryFunctionCall;
parser.PrimaryComponentReference = PrimaryComponentReference;
parser.PrimaryTuple = PrimaryTuple;
parser.PrimaryMatrix = PrimaryMatrix;
parser.PrimaryArray = PrimaryArray;
parser.PrimaryEnd = PrimaryEnd;
parser.NonPrimaryExpression = NonPrimaryExpression;
parser.IfExpression = IfExpression;
parser.SimpleExpression = SimpleExpression;
parser.LogicalExpression = LogicalExpression;
parser.Relation = Relation;
parser.ArithmeticExpression = ArithmeticExpression;
parser.ExpressionList = ExpressionList;
parser.OutputExpressionList = OutputExpressionList;
parser.ExpressionMatrix = ExpressionMatrix;
