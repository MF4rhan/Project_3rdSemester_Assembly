; Memory constants
MEMORY_SIZE EQU 64

; Instruction opcodes
OP_LOADI EQU 1
OP_MOV   EQU 2
OP_ADD   EQU 3
OP_SUB   EQU 4
OP_MUL   EQU 5
OP_DIV   EQU 6
OP_LOAD  EQU 7
OP_STORE EQU 8
OP_CMP   EQU 9
OP_JMP   EQU 10
OP_JZ    EQU 11
OP_JNZ   EQU 12
OP_HALT  EQU 13

; Procedure declarations
InitializeMemory PROTO
InitializeCPU PROTO
ExecuteNextInstruction PROTO
DisplayDashboard PROTO