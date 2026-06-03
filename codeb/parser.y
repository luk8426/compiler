%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "codeb.h"

#define PARSER_ERROR 2
#define NAME_SCOPE_ERROR 3
#define TECHNICAL_ERROR 4

extern int yylex();
int yyerror(const char *s);

typedef enum { TYPE_VAR, TYPE_LABEL } SymType;

// --------- Symbol table ---------
struct Symbol {
    char *name;
    SymType type;
    int offset; 
    char *label_start; 
    char *label_end;
    struct Symbol *next;
};

struct Symbol* create_st() {
    return NULL;
}

struct Symbol* insert_var_symbol(struct Symbol* s, const char* name, SymType type, int offset) {
    struct Symbol* curr = s;
    while (curr) {
        if (strcmp(curr->name, name) == 0 && curr->type == TYPE_VAR) {
            // Error, sym already exists!
            fprintf(stderr, "Error: Duplicate name '%s'\n", name);
            exit(NAME_SCOPE_ERROR);
        }
        curr = curr->next;
    }

    struct Symbol* new_sym = malloc(sizeof(struct Symbol));
    new_sym->name = strdup(name);
    new_sym->type = type;
    new_sym->offset = offset;
    new_sym->label_start = NULL;
    new_sym->label_end = NULL;    
    new_sym->next = s;
    return new_sym;
}

struct Symbol* insert_symbol(struct Symbol* s, const char* name, SymType type) {
    return insert_var_symbol(s, name, type, -1);
}

struct Symbol* insert_label_symbol(struct Symbol* s, const char* name, char* label_start, char* label_end) {
    if (strcmp("@inner", name) != 0) { // Check duplicates only for labelled conds
        struct Symbol* curr = s;
        while (curr) {
            if (strcmp(curr->name, name) == 0 && curr->type == TYPE_LABEL) {
                // Error, sym already exists!
                fprintf(stderr, "Error: Duplicate name '%s'\n", name);
                exit(NAME_SCOPE_ERROR);
            }
            curr = curr->next;
        }
    }
    struct Symbol* new_sym = malloc(sizeof(struct Symbol));
    new_sym->name = strdup(name);
    new_sym->type = TYPE_LABEL;
    new_sym->offset = -1;
    new_sym->label_start = label_start;
    new_sym->label_end = label_end;
    new_sym->next = s;
    return new_sym;
}

struct Symbol* lookup_symbol(struct Symbol* s, const char* name, SymType type) {
    struct Symbol* curr = s;
    while (curr) {
        if (strcmp(curr->name, name) == 0 && curr->type == type) return curr;
        curr = curr->next;
    }
    
    fprintf(stderr, "Error: Symbol with name '%s' not found in current scope\n", name);
    exit(NAME_SCOPE_ERROR);    
    return NULL;
}

int lookup_offset(struct Symbol* s, const char* name) {
    return lookup_symbol(s, name, TYPE_VAR)->offset;
}

const char* lookup_label_start(struct Symbol* s, const char* name) {
    return lookup_symbol(s, name, TYPE_LABEL)->label_start;
}

const char* lookup_label_end(struct Symbol* s, const char* name) {
    return lookup_symbol(s, name, TYPE_LABEL)->label_end;
}

char* new_label() {
    static int l_cnt = 0;
    char buf[32];
    snprintf(buf, sizeof(buf), ".L_cond_%d", l_cnt++);
    return strdup(buf);
}

// --------- End symbol table functions ---------

const char* reg_names[] = {"%rdi", "%rsi", "%rdx", "%rcx", "%r8", "%r9", "%rax", "%r10", "%r11"};
const char* reg8b_names[] = {"%dil", "%sil", "%dl", "%cl", "%r8b", "%r9b", "%al", "%r10b", "%r11b"};

%}

%token RETURN VAR COND END CONTINUE BREAK AND NOT
%token ASSIGN ARROW
%token NUM ID

%start  Program

@attributes { long val; } NUM
@attributes { char* name; } ID

@attributes { int stack_offset; struct Symbol* st_in; struct Symbol* st_syn; } Pars 
@attributes { struct Symbol* st_in; struct Symbol* st_syn; int stack_size_in; int stack_size_syn; } Stats Stat
@attributes { struct Symbol* st_in; int stack_size_in; int stack_size_syn; } GuardedList Conds Guarded

@attributes { struct Symbol* st_in; struct Symbol* st_syn; char* l_start; char* l_end; } CondHead
@attributes { char* l_end; } DummyEndCond
@attributes { char* l_next; } DummyEndGuarded
@attributes { struct Symbol* st_in; const char* target; } BocCall

@attributes { struct Symbol* st_in; } Args 
@attributes { struct Symbol* st_in; int offset; int is_array; treenode* base_tree; treenode* index_tree;} Lexpr

@attributes { treenode *tree; struct Symbol* st_in;} Expr Term

@attributes { treenode* tree_in; treenode* tree_syn; struct Symbol* st_in;} AddList MulList AndList
@attributes { int count; } NotList
@attributes { NodeType op; } LEM

@attributes {int res; } Dummy
    
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

Funcdef: ID '(' Pars ')' Stats END Dummy /* Function definition */
        @{
            @i @Pars.stack_offset@ = -8;
            @i @Pars.st_in@ = create_st();
            @i @Stats.st_in@ = @Pars.st_syn@;
            @i @Stats.stack_size_in@ = @Pars.stack_offset@;

            @m Dummy.res ; {
                printf(".global %s\n", @ID.name@);
                printf("%s:\n", @ID.name@);
                printf("\tpushq %%rbp\n");
                printf("\tmovq %%rsp, %%rbp\n");
                
                // Reserve some space on the stack for local vars and params
                printf("\tsubq $256, %%rsp\n");
                struct Symbol* curr = @Pars.st_syn@;
                while (curr) {
                    if (curr->type == TYPE_VAR && curr->offset < 0) {
                        int reg_idx = (-curr->offset / 8) - 1;                        
                        if (reg_idx < 6) {
                            printf("\tmovq %s, %d(%%rbp)\n", reg_names[reg_idx], curr->offset);
                        } else {
                            fprintf(stderr, "Error: More then 6 parameters in function %s", @ID.name@);
                            exit(TECHNICAL_ERROR);
                        }
                    }
                    curr = curr->next;
                }
            };
        @}
    ;

Pars: /* Can also be empty */
        @{  @i @Pars.st_syn@ = @Pars.st_in@; @} // unchanged if empty
    | ID     /* Parameter definition */
        @{ @i @Pars.st_syn@ = insert_var_symbol(@Pars.st_in@, @ID.name@, TYPE_VAR, @Pars.stack_offset@); @}
    | ID ',' Pars
        @{  
            @i @Pars.1.stack_offset@ = @Pars.0.stack_offset@ - 8;
            @i @Pars.1.st_in@ = @Pars.0.st_in@;
            @i @Pars.0.st_syn@ = insert_var_symbol(@Pars.1.st_syn@, @ID.name@, TYPE_VAR, @Pars.0.stack_offset@);
        @}
    ;

Stats: /* Can also be empty -> unchanged*/
        @{  
            @i @Stats.st_syn@ = @Stats.st_in@;
            @i @Stats.stack_size_syn@ = @Stats.stack_size_in@;
        @}
    | Stats Stat ';'
        @{
            @i @Stats.1.st_in@ = @Stats.0.st_in@;
            @i @Stats.1.stack_size_in@ = @Stats.0.stack_size_in@;

            @i @Stat.st_in@ = @Stats.1.st_syn@;
            @i @Stat.stack_size_in@ = @Stats.1.stack_size_syn@;

            @i @Stats.0.st_syn@ = @Stat.st_syn@;
            @i @Stats.0.stack_size_syn@ = @Stat.stack_size_syn@;            
        @}
    ;

Stat: RETURN Expr
        @{
            @i @Stat.st_syn@ = @Stat.st_in@;
            @i @Expr.st_in@ = @Stat.st_in@;
            @i @Stat.stack_size_syn@ = @Stat.stack_size_in@;
            @codegen {
                invoke_burm(@Expr.tree@);
                printf("\tmovq %%rbp, %%rsp\n");
                printf("\tpopq %%rbp\n");
                printf("\tret\n");
            }
        @}
    | Conds
        @{
            @i @Stat.st_syn@ = @Stat.st_in@;
            @i @Conds.st_in@ = @Stat.st_in@;
            @i @Conds.stack_size_in@ = @Stat.stack_size_in@;
            @i @Stat.stack_size_syn@ = @Conds.stack_size_syn@;
        @}    
    | VAR ID ASSIGN Expr /* variable definition */
        @{
            @i @Stat.stack_size_syn@ = @Stat.stack_size_in@ - 8;
            @i @Stat.st_syn@ = insert_var_symbol(@Stat.st_in@, @ID.name@, TYPE_VAR, @Stat.stack_size_syn@);
            @i @Expr.st_in@ = @Stat.st_in@;
            @codegen {
                invoke_burm(@Expr.tree@);
                printf("\tmovq %%rax, %d(%%rbp)\n", lookup_offset(@Stat.st_syn@, @ID.name@));
            }
        @}   
    | Lexpr ASSIGN Expr  /* Assignment */
        @{
            @i @Stat.st_syn@ = @Stat.st_in@;
            @i @Lexpr.st_in@ = @Stat.st_in@;
            @i @Expr.st_in@ = @Stat.st_in@;
            @i @Stat.stack_size_syn@ = @Stat.stack_size_in@;
            @codegen {
                invoke_burm(@Expr.tree@);                
                if (@Lexpr.is_array@ == 0) { // Direct write
                    printf("\tmovq %%rax, %d(%%rbp)\n", @Lexpr.offset@);
                } else { // Solution for expr must be stored somewhere to calculate the address in rax
                    printf("\tmovq %%rax, %%r11\n"); // value
                    invoke_burm(@Lexpr.base_tree@);
                    printf("\tmovq %%rax, %%r10\n"); // base address
                    invoke_burm(@Lexpr.index_tree@); // index is now in %rax
                    printf("\tleaq (%%r10,%%rax,8), %%rax\n");
                    printf("\tmovq %%r11, (%%rax)\n"); // store result of expr to address
                }
            }
        @}      
    | Term
        @{
            @i @Stat.st_syn@ = @Stat.st_in@;
            @i @Term.st_in@ = @Stat.st_in@;
            @i @Stat.stack_size_syn@ = @Stat.stack_size_in@;
            @codegen {
                invoke_burm(@Term.tree@); // Evalute and discard
            }
        @}     
    ;

Conds: CondHead GuardedList END DummyEndCond
        @{
            @i @CondHead.st_in@ = @Conds.st_in@;
            @i @GuardedList.st_in@ = @CondHead.st_syn@;
            @i @GuardedList.stack_size_in@ = @Conds.stack_size_in@;
            @i @Conds.stack_size_syn@ = @GuardedList.stack_size_syn@;
            @i @DummyEndCond.l_end@ = @CondHead.l_end@;
        @}
    ;

CondHead: COND
        @{
            @i @CondHead.l_start@ = new_label();
            @i @CondHead.l_end@ = new_label();
            @i @CondHead.st_syn@ = insert_label_symbol(@CondHead.st_in@, "@inner", @CondHead.l_start@, @CondHead.l_end@);
            @codegen { printf("%s:\n", @CondHead.l_start@); }
        @}
    | ID ':' COND
        @{
            @i @CondHead.l_start@ = new_label();
            @i @CondHead.l_end@ = new_label();
            @i @CondHead.st_syn@ = insert_label_symbol(
                                    insert_label_symbol(@CondHead.st_in@, "@inner", @CondHead.l_start@, @CondHead.l_end@),
                                    @ID.name@, @CondHead.l_start@, @CondHead.l_end@);
            @codegen { printf("%s:\n", @CondHead.l_start@); }
        @}
    ;

DummyEndCond: /* Empty */
        @{ @codegen { printf("%s:\n", @DummyEndCond.l_end@); }@}
    ;

GuardedList: /* Can also be empty -> unchanged*/
        @{  @i @GuardedList.stack_size_syn@ = @GuardedList.stack_size_in@; @}
    | GuardedList Guarded ';'
        @{
            @i @GuardedList.1.st_in@ = @GuardedList.0.st_in@;
            @i @Guarded.st_in@ = @GuardedList.0.st_in@;
            @i @GuardedList.1.stack_size_in@ = @GuardedList.0.stack_size_in@;
            @i @Guarded.stack_size_in@ = @GuardedList.1.stack_size_in@;
            @i @GuardedList.0.stack_size_syn@ = @Guarded.stack_size_syn@;
        @}    
    ;

Guarded: ARROW Stats BocCall DummyEndGuarded    
        @{ 
            @i @Stats.st_in@ = @Guarded.st_in@; 
            @i @BocCall.st_in@ = @Guarded.st_in@;
            @i @Stats.stack_size_in@ = @Guarded.stack_size_in@;
            @i @Guarded.stack_size_syn@ = @Stats.stack_size_syn@;
            @i @DummyEndGuarded.l_next@ = new_label();
        @}   
    | Expr ARROW Stats BocCall DummyEndGuarded  
        @{ 
            @i @Expr.st_in@ = @Guarded.st_in@; 
            @i @Stats.st_in@ = @Guarded.st_in@; 
            @i @BocCall.st_in@ = @Guarded.st_in@;
            @i @Stats.stack_size_in@ = @Guarded.stack_size_in@;
            @i @Guarded.stack_size_syn@ = @Stats.stack_size_syn@;            
            @i @DummyEndGuarded.l_next@ = new_label();

            @codegen {
                invoke_burm(@Expr.tree@);
                printf("\ttestq $1, %%rax\n"); // Test bit 1 (even/odd)
                printf("\tjz %s\n", @DummyEndGuarded.l_next@); // zero flag -> even result
            }
        @}
    ;

DummyEndGuarded: /* Empty */
        @{ @codegen { printf("%s:\n", @DummyEndGuarded.l_next@); }@}
    ;    

BocCall: BREAK
        @{  // This works because the first @inner that is encountered will be returned
            @i @BocCall.target@ = lookup_label_end(@BocCall.st_in@, "@inner");
            @codegen { printf("\tjmp %s\n", @BocCall.target@); }
        @}
    | CONTINUE
        @{  // This works because the first @inner that is encountered will be returned
            @i @BocCall.target@ = lookup_label_start(@BocCall.st_in@, "@inner");
            @codegen { printf("\tjmp %s\n", @BocCall.target@); }
        @}
    | BREAK ID
        @{
            @i @BocCall.target@ = lookup_label_end(@BocCall.st_in@, @ID.name@);
            @codegen { printf("\tjmp %s\n", @BocCall.target@); }
        @}
    | CONTINUE ID
        @{
            @i @BocCall.target@ = lookup_label_start(@BocCall.st_in@, @ID.name@);
            @codegen { printf("\tjmp %s\n", @BocCall.target@); }
        @}
    ;

Lexpr: ID        /* Writing variable */
        @{
            @i @Lexpr.is_array@ = 0;
            @i @Lexpr.offset@ = lookup_offset(@Lexpr.st_in@, @ID.name@);
            @i @Lexpr.base_tree@ = NULL;
            @i @Lexpr.index_tree@ = NULL;
        @} 
    | Term '[' Expr ']' /* writing to array */
        @{
            @i @Term.st_in@ = @Lexpr.st_in@;
            @i @Expr.st_in@ = @Lexpr.st_in@;
            @i @Lexpr.offset@ = 0;
            @i @Lexpr.base_tree@ = @Term.tree@;
            @i @Lexpr.index_tree@ = @Expr.tree@;
            @i @Lexpr.is_array@ = 1;
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
            @i @Term.tree@ = create_var_node(lookup_offset(@Term.st_in@, @ID.name@));
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

  if (newNode == NULL) { printf("Out of memory.\n"); exit(TECHNICAL_ERROR);}

  newNode->type = ntype;
  newNode->kids[0] = left;
  newNode->kids[1] = right;
  newNode->stack_offset = -1;
  newNode->val = 0;

  return newNode;
}

treenode *create_var_node(int offset)
{
  treenode *newNode = create_node(NODE_VAR,NULL,NULL);
  newNode->stack_offset = offset;
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
