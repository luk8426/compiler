%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "codea.h"

#define PARSER_ERROR 2
#define NAME_SCOPE_ERROR 3

extern int yylex();
int yyerror(const char *s);

typedef enum { TYPE_VAR, TYPE_LABEL } SymType;

// --------- Symbol table ---------
struct Symbol {
    char *name;
    SymType type;
    int index; // To identify the location/register
    struct Symbol *next;
};

struct Symbol* create_st() {
    return NULL;
}

struct Symbol* insert_param_symbol(struct Symbol* s, const char* name, SymType type, int index) {
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
    new_sym->index = index;
    new_sym->next = s;
    return new_sym;
}

struct Symbol* insert_symbol(struct Symbol* s, const char* name, SymType type) {
    return insert_param_symbol(s, name, type, -1);
}

int lookup_symbol(struct Symbol* s, const char* name, SymType type) {
    struct Symbol* curr = s;
    while (curr) {
        if (strcmp(curr->name, name) == 0 && curr->type == type) return curr->index;
        curr = curr->next;
    }
    
    fprintf(stderr, "Error: Symbol with name '%s' not found in current scope\n", name);
    exit(NAME_SCOPE_ERROR);    
    return 0;
}

int lookup_index(struct Symbol* s, const char* name) {
    return lookup_symbol(s, name, TYPE_VAR);
}

// --------- End symbol table functions ---------

const char* reg_names[] = {"%rdi", "%rsi", "%rdx", "%rcx", "%r8", "%r9", "%rax", "%r10", "%r11"};

%}

%token RETURN VAR COND END CONTINUE BREAK AND NOT
%token ASSIGN ARROW
%token NUM ID

%start  Program

@attributes { long val; } NUM
@attributes { char* name; } ID

@attributes { int reg_idx; struct Symbol* st_in; struct Symbol* st_syn; } Pars
@attributes { struct Symbol* st_in; struct Symbol* st_syn; } Stats Stat

@attributes { struct Symbol* st_in; } Args GuardedList Conds Lexpr Guarded

@attributes { treenode *tree; struct Symbol* st_in;} Expr Term

@attributes { treenode* tree_in; treenode* tree_syn; struct Symbol* st_in;} AddList MulList AndList
@attributes { int count; } NotList
@attributes { NodeType op; } LEM

@attributes {int res; } 
    Dummy
    
@traversal @preorder codegen

%{
treenode *create_node(NodeType ntype, treenode *left, treenode *right);
treenode *create_var_node(int idx);
treenode *create_num_node(long num);
extern void invoke_burm(NODEPTR_TYPE root);
%}

%%

Program: /* Can also be empty bc {} says 0 or multiple times  */
    | Program Funcdef ';' 
    ;

Funcdef: ID '(' Pars ')' Stats END  /* Function definition */
        @{
            @i @Pars.reg_idx@ = 0;
            @i @Pars.st_in@ = create_st();
            @i @Stats.st_in@ = @Pars.st_syn@;
        @}
    ;

Pars: /* Can also be empty */
        @{  @i @Pars.st_syn@ = @Pars.st_in@; @} // unchanged if empty
    | ID     /* Parameter definition */
        @{  @i @Pars.st_syn@ = insert_param_symbol(@Pars.st_in@, @ID.name@, TYPE_VAR, @Pars.reg_idx@); @}
    | ID ',' Pars
        @{  
            @i @Pars.1.reg_idx@ = @Pars.0.reg_idx@ + 1;
            @i @Pars.1.st_in@ = @Pars.0.st_in@;
            @i @Pars.0.st_syn@ = insert_param_symbol(@Pars.1.st_syn@, @ID.name@, TYPE_VAR, @Pars.0.reg_idx@);
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
            @codegen invoke_burm(@Expr.tree@);
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

Expr: Term              
        @{ 
            @i @Term.st_in@ = @Expr.st_in@; 
            @i @Expr.tree@ = @Term.tree@;
        @}
    | NOT NotList Term
        @{ 
            @i @Term.st_in@ = @Expr.st_in@; 
            @i @Expr.tree@ = (@NotList.count@%2==0) ? create_node(NODE_NOT, @Term.tree@, NULL) : @Term.tree@;
        @}
    | Term '[' Expr ']' /* Reading from array */
        @{ 
            @i @Term.st_in@ = @Expr.0.st_in@; 
            @i @Expr.1.st_in@ = @Expr.0.st_in@;
            @i @Expr.0.tree@ = create_node(NODE_ARRAY, @Term.tree@, @Expr.1.tree@);
        @} 
    | Term AddList      
        @{ 
            @i @Term.st_in@ = @Expr.st_in@; 
            @i @AddList.st_in@ = @Expr.st_in@;
            @i @AddList.tree_in@ = @Term.tree@; 
            @i @Expr.tree@ = @AddList.tree_syn@;
        @}
    | Term MulList      
        @{ 
            @i @Term.st_in@ = @Expr.st_in@; 
            @i @MulList.st_in@ = @Expr.st_in@; 
            @i @MulList.tree_in@ = @Term.tree@; 
            @i @Expr.tree@ = @MulList.tree_syn@;
        @}
    | Term AndList      
        @{ 
            @i @Term.st_in@ = @Expr.st_in@; 
            @i @AndList.st_in@ = @Expr.st_in@; 
            @i @AndList.tree_in@ = @Term.tree@; 
            @i @Expr.tree@ = @AndList.tree_syn@;
        @}
    | Term LEM Term     
        @{ 
            @i @Term.0.st_in@ = @Expr.st_in@; 
            @i @Term.1.st_in@ = @Expr.st_in@; 
            @i @Expr.tree@ = create_node(@LEM.op@, @Term.0.tree@, @Term.1.tree@);
        @}
    ;

LEM: '>' @{ @i @LEM.op@ = NODE_GT; @}
   | '=' @{ @i @LEM.op@ = NODE_EQ; @}
   | '-' @{ @i @LEM.op@ = NODE_SUB; @}
   ;

NotList: /* leer */   @{ @i @NotList.count@ = 0; @}
    | NotList NOT     @{ @i @NotList.0.count@ = @NotList.1.count@ + 1; @}
    ;

AddList: '+' Term        
        @{ 
            @i @Term.st_in@ = @AddList.st_in@; 
            @i @AddList.tree_syn@ = create_node(NODE_ADD, @AddList.tree_in@, @Term.tree@); 
        @}
    | AddList '+' Term   
        @{ 
            @i @Term.st_in@ = @AddList.0.st_in@; 
            @i @AddList.1.st_in@ = @AddList.0.st_in@; 
            @i @AddList.1.tree_in@ = @AddList.0.tree_in@; 
            @i @AddList.0.tree_syn@ = create_node(NODE_ADD, @AddList.1.tree_syn@, @Term.tree@); 
        @}
    ;    

MulList: '*' Term        
        @{ 
            @i @Term.st_in@ = @MulList.st_in@; 
            @i @MulList.tree_syn@ = create_node(NODE_MUL, @MulList.tree_in@, @Term.tree@); 
        @}
    | MulList '*' Term   
        @{ 
            @i @Term.st_in@ = @MulList.0.st_in@; 
            @i @MulList.1.st_in@ = @MulList.0.st_in@; 
            @i @MulList.1.tree_in@ = @MulList.0.tree_in@; 
            @i @MulList.0.tree_syn@ = create_node(NODE_MUL, @MulList.1.tree_syn@, @Term.tree@); 
        @}
    ;

AndList: AND Term        
        @{ 
            @i @Term.st_in@ = @AndList.st_in@; 
            @i @AndList.tree_syn@ = create_node(NODE_AND, @AndList.tree_in@, @Term.tree@); 
        @}
    | AndList AND Term   
        @{ 
            @i @Term.st_in@ = @AndList.0.st_in@; 
            @i @AndList.1.st_in@ = @AndList.0.st_in@; 
            @i @AndList.1.tree_in@ = @AndList.0.tree_in@; 
            @i @AndList.0.tree_syn@ = create_node(NODE_AND, @AndList.1.tree_syn@, @Term.tree@); 
        @}
    ;

Term: '(' Expr ')'      
        @{ 
            @i @Expr.st_in@ = @Term.st_in@;
            @i @Term.tree@ = @Expr.tree@;
        @}
    | NUM   @{ @i @Term.tree@ = create_num_node(@NUM.val@); @}
    | ID Dummy          /* variable usage */
        @{ 
            @m Dummy.res ; lookup_symbol(@Term.st_in@, @ID.name@, TYPE_VAR); 
            @i @Term.tree@ = create_var_node(lookup_index(@Term.st_in@, @ID.name@));
        @}         
    | ID '(' Args ')'   /* Function call */  
        @{ 
            @i @Args.st_in@ = @Term.st_in@; 
            @i @Term.tree@ = NULL; 
        @}
    ;

Args: /* Empty */
    | Expr              @{ @i @Expr.st_in@ = @Args.st_in@; @}
    | Expr ',' Args     @{ @i @Expr.st_in@ = @Args.0.st_in@; @i @Args.1.st_in@ = @Args.0.st_in@; @}
    ;

Dummy: /* Empty */ ; /* Dummy dependent for lookup_symbol */

%%

treenode *create_node(NodeType ntype, treenode *left, treenode *right)
{
  treenode *newNode = malloc(sizeof(treenode));

  if (newNode == NULL) { printf("Out of memory.\n"); exit(4);}

  newNode->type = ntype;
  newNode->kids[0] = left;
  newNode->kids[1] = right;
  newNode->reg_idx = -1;
  newNode->val = 0;

  return newNode;
}

treenode *create_var_node(int idx)
{
  treenode *newNode = create_node(NODE_VAR,NULL,NULL);
  newNode->reg_idx = idx; // -1 if var is no parameter
  return newNode;
}

treenode *create_num_node(long num)
{
  treenode *newNode = create_node(NODE_NUM,NULL,NULL);
  newNode->val = num;
  return newNode;
}

int yyerror(const char *e){
    printf("Parser error: '%s'...\n",e);
    exit(PARSER_ERROR);
}

int main(void){
    return yyparse();
}
