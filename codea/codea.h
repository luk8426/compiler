#ifndef CODE_H_
#define CODE_H_

typedef enum { 
	NODE_NUM, 
	NODE_PARAM,
	NODE_ADD,
	NODE_SUB,
	NODE_MUL,
	NODE_AND,
	NODE_NOT,
	NODE_GT,
	NODE_EQ,
	NODE_ARRAY 
} NodeType;


#ifdef USE_IBURG
#ifndef BURM
typedef struct burm_state *STATEPTR_TYPE;
#endif
#else
#define STATEPTR_TYPE int
#endif

typedef struct s_node {
	NodeType type;
	struct s_node   *kids[2];
	STATEPTR_TYPE	state;
	int param_reg_idx;
	long val;
} treenode;

typedef treenode *treenodep;

#define NODEPTR_TYPE	treenodep
#define OP_LABEL(p)	((p)->op)
#define LEFT_CHILD(p)	((p)->kids[0])
#define RIGHT_CHILD(p)	((p)->kids[1])
#define STATE_LABEL(p)	((p)->state)
#define PANIC		printf

const char* param_regs[] = {"%rdi", "%rsi", "%rdx", "%rcx", "%r8", "%r9"};
const char* caller_safe_regs[] = {"%rax", "%r10", "%r11"};

#endif
