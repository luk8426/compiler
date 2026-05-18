%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PARSER_ERROR 2
#define NAME_SCOPE_ERROR 3

extern int yylex();
int yyerror(const char *s);

typedef enum { TYPE_VAR, TYPE_LABEL } SymType;

// --------- Symbol table ---------
struct Symbol {
    char *name;
    SymType type;
    struct Symbol *next;
};

struct Symbol* create_st() {
    return NULL;
}

struct Symbol* insert_symbol(struct Symbol* s, const char* name, SymType type) {
    struct Symbol* curr = s;
    while (curr) {
        if (strcmp(curr->name, name) == 0) {
            // Error, sym already exists!
            fprintf(stderr, "Error: Duplicate name '%s'\n", name);
            exit(NAME_SCOPE_ERROR);
        }
        curr = curr->next;
    }

    struct Symbol* new_sym = malloc(sizeof(struct Symbol));
    new_sym->name = strdup(name);
    new_sym->type = type;
    new_sym->next = s;
    return new_sym;
}

int lookup_symbol(struct Symbol* s, const char* name, SymType type) {
    struct Symbol* curr = s;
    while (curr) {
        if (strcmp(curr->name, name) == 0 && curr->type == type) return 1;
        curr = curr->next;
    }
    
    fprintf(stderr, "Error: Symbol with name '%s' not found in current scope\n", name);
    exit(NAME_SCOPE_ERROR);    
    return 0;
}

// --------- End symbol table functions ---------

%}

%token RETURN VAR COND END CONTINUE BREAK AND NOT
%token ASSIGN ARROW
%token NUM ID

%start  Program

@attributes { long val; } NUM
@attributes { char* name; } ID

@attributes { struct Symbol* st_in; struct Symbol* st_syn; } 
    Pars Stats Stat 

@attributes { struct Symbol* st_in; } 
    Expr Args AddList MulList AndList GuardedList Conds Term Lexpr Guarded

@attributes {int res; } 
    Dummy
    

%%

Program: /* Can also be empty bc {} says 0 or multiple times  */
    | Program Funcdef ';' 
    ;

Funcdef: ID '(' Pars ')' Stats END  /* Function definition */
        @{
            @i @Pars.st_in@ = create_st();
            @i @Stats.st_in@ = @Pars.st_syn@;
        @}
    ;

Pars: /* Can also be empty */
        @{  @i @Pars.st_syn@ = @Pars.st_in@; @} // unchanged if empty
    | ID     /* Parameter definition */
        @{  @i @Pars.st_syn@ = insert_symbol(@Pars.st_in@, @ID.name@, TYPE_VAR); @}
    | ID ',' Pars
        @{
            @i @Pars.1.st_in@ = @Pars.0.st_in@;
            @i @Pars.0.st_syn@ = insert_symbol(@Pars.1.st_syn@, @ID.name@, TYPE_VAR);
        @}
    ;

Stats: /* Can also be empty */
        @{  @i @Stats.st_syn@ = @Stats.st_in@; @} // unchanged if empty
    | Stats Stat ';'
        @{
            @i @Stats.1.st_in@ = @Stats.0.st_in@;
            @i @Stat.st_in@ = @Stats.1.st_syn@;
            @i @Stats.0.st_syn@ = @Stat.st_syn@;
        @}
    ;

Stat: RETURN Expr
        @{
            @i @Stat.st_syn@ = @Stat.st_in@;
            @i @Expr.st_in@ = @Stat.st_in@;
        @}
    | Conds
        @{
            @i @Stat.st_syn@ = @Stat.st_in@;
            @i @Conds.st_in@ = @Stat.st_in@;
        @}    
    | VAR ID ASSIGN Expr /* variable definition */
        @{
            @i @Stat.st_syn@ = insert_symbol(@Stat.st_in@, @ID.name@, TYPE_VAR);
            @i @Expr.st_in@ = @Stat.st_in@;
        @}    
    | Lexpr ASSIGN Expr  /* Assignment */
        @{
            @i @Stat.st_syn@ = @Stat.st_in@;
            @i @Lexpr.st_in@ = @Stat.st_in@;
            @i @Expr.st_in@ = @Stat.st_in@;
        @}    
    | Term
        @{
            @i @Stat.st_syn@ = @Stat.st_in@;
            @i @Term.st_in@ = @Stat.st_in@;
        @}    
    ;

Conds: COND GuardedList END
        @{  @i @GuardedList.st_in@ = @Conds.st_in@; @}
    | ID ':' COND GuardedList END     
        @{  @i @GuardedList.st_in@ = insert_symbol(@Conds.st_in@, @ID.name@, TYPE_LABEL); @}    
    ;

GuardedList: /* leer */
    | GuardedList Guarded ';'
        @{
            @i @GuardedList.1.st_in@ = @GuardedList.0.st_in@;
            @i @Guarded.st_in@ = @GuardedList.0.st_in@;
        @}    
    ;

Guarded: ARROW Stats BOC    
        @{ @i @Stats.st_in@ = @Guarded.st_in@; @}   
    | Expr ARROW Stats BOC  
        @{ 
            @i @Stats.st_in@ = @Guarded.st_in@; 
            @i @Expr.st_in@ = @Guarded.st_in@; 
        @}
    | ARROW Stats BOC ID Dummy
        @{  
            @i @Stats.st_in@ = @Guarded.st_in@; 
            @m Dummy.res ; lookup_symbol(@Guarded.st_in@, @ID.name@, TYPE_LABEL);
        @}   

    | Expr ARROW Stats BOC ID Dummy
        @{ 
            @i @Expr.st_in@ = @Guarded.st_in@; 
            @i @Stats.st_in@ = @Guarded.st_in@; 
            @m Dummy.res ; lookup_symbol(@Guarded.st_in@, @ID.name@, TYPE_LABEL);
        @}    
    ;

BOC: BREAK | CONTINUE ;

Lexpr: ID Dummy        /* Writing variable */
        @{  @m Dummy.res ; lookup_symbol(@Lexpr.st_in@, @ID.name@, TYPE_VAR); @}  
    | Term '[' Expr ']' /* writing to array */
        @{
            @i @Term.st_in@ = @Lexpr.st_in@;
            @i @Expr.st_in@ = @Lexpr.st_in@;
        @}       
    ;

Expr: Term              @{ @i @Term.st_in@ = @Expr.st_in@; @}
    | NOT NotList Term  @{ @i @Term.st_in@ = @Expr.st_in@; @}
    | Term '[' Expr ']' @{ @i @Term.st_in@ = @Expr.0.st_in@; @i @Expr.1.st_in@ = @Expr.0.st_in@; @} /* Reading from array */
    | Term AddList      @{ @i @Term.st_in@ = @Expr.st_in@; @i @AddList.st_in@ = @Expr.st_in@; @}
    | Term MulList      @{ @i @Term.st_in@ = @Expr.st_in@; @i @MulList.st_in@ = @Expr.st_in@; @}
    | Term AndList      @{ @i @Term.st_in@ = @Expr.st_in@; @i @AndList.st_in@ = @Expr.st_in@; @}
    | Term LEM Term     @{ @i @Term.0.st_in@ = @Expr.st_in@; @i @Term.1.st_in@ = @Expr.st_in@; @}
    ;

LEM: '>' | '=' | '-' ;

 /* Helper for Expr */
NotList: /* Empty */ | NotList NOT ;
AddList: '+' Term        @{ @i @Term.st_in@ = @AddList.st_in@; @}
    | AddList '+' Term   @{ @i @Term.st_in@ = @AddList.0.st_in@; @i @AddList.1.st_in@ = @AddList.0.st_in@; @}
    ;
MulList: '*' Term        @{ @i @Term.st_in@ = @MulList.st_in@; @}
    | MulList '*' Term   @{ @i @Term.st_in@ = @MulList.0.st_in@; @i @MulList.1.st_in@ = @MulList.0.st_in@; @}
    ;
AndList: AND Term        @{ @i @Term.st_in@ = @AndList.st_in@; @}
    | AndList AND Term   @{ @i @Term.st_in@ = @AndList.0.st_in@; @i @AndList.1.st_in@ = @AndList.0.st_in@; @}
    ;

Term: '(' Expr ')'      @{ @i @Expr.st_in@ = @Term.st_in@; @} 
    | NUM
    | ID Dummy          @{ @m Dummy.res ; lookup_symbol(@Term.st_in@, @ID.name@, TYPE_VAR); @}  /* variable usage */  
    | ID '(' Args ')'   @{ @i @Args.st_in@ = @Term.st_in@; @}                                   /* Function call */  
    ;

Args: /* Empty */
    | Expr              @{ @i @Expr.st_in@ = @Args.st_in@; @}
    | Expr ',' Args     @{ @i @Expr.st_in@ = @Args.0.st_in@; @i @Args.1.st_in@ = @Args.0.st_in@; @}
    ;

Dummy: /* Empty */ ; /* Dummy dependent for lookup_symbol */

%%

int yyerror(const char *e){
    printf("Parser error: '%s'...\n",e);
    exit(PARSER_ERROR);
}

int main(void){
    return yyparse();
}
