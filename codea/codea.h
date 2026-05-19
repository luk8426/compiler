#ifndef CODEA_H_
#define CODEA_H_

typedef enum { 
	NODE_NUM, 
	NODE_VAR,
	NODE_ADD,
	NODE_SUB,
	NODE_MUL,
	NODE_AND,
	NODE_NOT,
	NODE_GT,
	NODE_EQ,
	NODE_ARRAY 
} NodeType;

typedef struct burm_state *STATEPTR_TYPE;

typedef struct s_node {
	NodeType type;
	struct s_node   *kids[2];
	STATEPTR_TYPE	state;
	int reg_idx;
	long val;
} treenode;

typedef treenode *treenodep;

#define NODEPTR_TYPE	treenodep
#define OP_LABEL(p)	((p)->type)
#define LEFT_CHILD(p)	((p)->kids[0])
#define RIGHT_CHILD(p)	((p)->kids[1])
#define STATE_LABEL(p)	((p)->state)
#define PANIC		printf

#endif
