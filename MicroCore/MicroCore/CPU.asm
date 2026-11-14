; ======================================================================
; CPU.asm - Virtual Processor 
; Implements the miniature CPU: registers, Fetch-Decode-Execute cycle,
; the 13 instructions, the Zero Flag, and error detection.
;
; Instruction format (32 bits), produced by the parser in Main.asm:
;   Bits 31-24 : Opcode
;   Bits 23-20 : RD (destination register, 0..3)
;   Bits 19-16 : RS (source register, 0..3)
;   Bits 15-0  : Immediate value or address
;
; Public interface:
;   InitializeCPU           - resets all CPU registers and flags to 0
;   ExecuteNextInstruction  - runs ONE Fetch-Decode-Execute cycle
;                             EAX = 1 if the instruction executed,
;                             EAX = 0 if the CPU was already halted or an
;                                     error occurred (CPU is then halted).
; ======================================================================

INCLUDE Irvine32.inc
INCLUDE MicroCore.inc

; Bit 0 of CPUFlags is the Zero Flag (ZF).
ZF_MASK EQU 1

.data

	; RegisterFile is just another name for the address of R0. Because R0..R3
	; are declared one after another, RegisterFile[n*4] gives register Rn.
	; This lets us pick a register using its number (0..3) with no long cmp chains.
	RegisterFile LABEL DWORD
	R0 DWORD 0
	R1 DWORD 0
	R2 DWORD 0
	R3 DWORD 0

	PC DWORD 0
	IR DWORD 0
	CPUFlags DWORD 0
	CPUHalted DWORD 0

	; The lines above are the Virtual CPU's registers and status variables

	; Error messages (printed when the CPU stops because of an error)
	errFetch		BYTE "CPU Error: cannot fetch instruction (PC outside program memory). CPU halted.", 0Dh, 0Ah, 0
	errOpcode		BYTE "CPU Error: invalid instruction (unknown opcode). CPU halted.", 0Dh, 0Ah, 0
	errRegister		BYTE "CPU Error: invalid register number in instruction. CPU halted.", 0Dh, 0Ah, 0
	errDivZero		BYTE "CPU Error: division by zero. CPU halted.", 0Dh, 0Ah, 0
	errDivOverflow	BYTE "CPU Error: division overflow. CPU halted.", 0Dh, 0Ah, 0
	errDataLoad		BYTE "CPU Error: LOAD from invalid data memory address. CPU halted.", 0Dh, 0Ah, 0
	errDataStore	BYTE "CPU Error: STORE to invalid data memory address. CPU halted.", 0Dh, 0Ah, 0

.code

PUBLIC R0, R1, R2, R3
PUBLIC PC, IR, CPUFlags, CPUHalted
PUBLIC InitializeCPU
PUBLIC ExecuteNextInstruction

;-----------------------------------------------------------------------
; InitializeCPU
; Purpose : Sets every register, flag and status variable back to 0.
;-----------------------------------------------------------------------
InitializeCPU PROC

	mov R0, 0
	mov R1, 0
	mov R2, 0
	mov R3, 0

	mov PC, 0
	mov IR, 0
	mov CPUFlags, 0
	mov CPUHalted, 0

	ret

InitializeCPU ENDP


;-----------------------------------------------------------------------
; UpdateZeroFlag
; Purpose : Sets ZF in CPUFlags if EAX = 0, otherwise clears ZF.
; Input   : EAX = result of the last arithmetic / compare operation.
;-----------------------------------------------------------------------
UpdateZeroFlag PROC

	cmp eax, 0
	jne ResultNotZero

	or CPUFlags, ZF_MASK			; result is 0 -> set ZF
	ret

ResultNotZero:
	and CPUFlags, NOT ZF_MASK		; result is not 0 -> clear ZF
	ret

UpdateZeroFlag ENDP


;-----------------------------------------------------------------------
; ExecuteNextInstruction
; Purpose : Performs one complete Fetch-Decode-Execute cycle.
;
; Registers used while executing (after the decode step):
;   EAX = opcode, then scratch / result
;   EBX = RD  (destination register number)
;   ECX = RS  (source register number)
;   EDX = 16-bit immediate value or address
;   ESI = scratch (divisor, value to store)
;
; PC convention: PC points to the NEXT instruction. It is increased by 1
; right after the fetch; jump instructions then overwrite it.
;-----------------------------------------------------------------------
ExecuteNextInstruction PROC USES ebx ecx edx esi

	; If the CPU has already halted, do nothing.
	cmp CPUHalted, 0
	jne AlreadyHalted

	; ================= FETCH =================
	; Read ProgramMemory[PC] (EAX = instruction, CF = 1 if PC is invalid).
	INVOKE ReadProgramMemory, PC
	jc FetchFailed

	mov IR, eax					; put the instruction in the Instruction Register
	inc PC						; PC now points to the next instruction

	; ================= DECODE =================
	; Split IR into its fields using shifts and masks.
	mov eax, IR
	shr eax, 24					; EAX = opcode (bits 31-24)

	mov ebx, IR
	shr ebx, 20
	and ebx, 0Fh				; EBX = RD (bits 23-20)

	mov ecx, IR
	shr ecx, 16
	and ecx, 0Fh				; ECX = RS (bits 19-16)

	mov edx, IR
	and edx, 0FFFFh				; EDX = immediate / address (bits 15-0)

	; Choose the instruction by its opcode.
	cmp eax, OP_LOADI
	je ExecLOADI
	cmp eax, OP_MOV
	je ExecMOV
	cmp eax, OP_ADD
	je ExecADD
	cmp eax, OP_SUB
	je ExecSUB
	cmp eax, OP_MUL
	je ExecMUL
	cmp eax, OP_DIV
	je ExecDIV
	cmp eax, OP_LOAD
	je ExecLOAD
	cmp eax, OP_STORE
	je ExecSTORE
	cmp eax, OP_CMP
	je ExecCMP
	cmp eax, OP_JMP
	je ExecJMP
	cmp eax, OP_JZ
	je ExecJZ
	cmp eax, OP_JNZ
	je ExecJNZ
	cmp eax, OP_HALT
	je ExecHALT
	jmp BadOpcode				; none matched -> invalid instruction

	; ================= EXECUTE =================

ExecLOADI:						; LOADI RD, immediate
	cmp ebx, 3
	ja BadRegister
	movsx eax, dx				; sign-extend the 16-bit immediate to 32 bits
	mov RegisterFile[ebx*4], eax
	jmp ExecOK

ExecMOV:						; MOV RD, RS   (RD = RS)
	cmp ebx, 3
	ja BadRegister
	cmp ecx, 3
	ja BadRegister
	mov eax, RegisterFile[ecx*4]
	mov RegisterFile[ebx*4], eax
	jmp ExecOK

ExecADD:						; ADD RD, RS   (RD = RD + RS)
	cmp ebx, 3
	ja BadRegister
	cmp ecx, 3
	ja BadRegister
	mov eax, RegisterFile[ebx*4]
	add eax, RegisterFile[ecx*4]
	mov RegisterFile[ebx*4], eax
	call UpdateZeroFlag
	jmp ExecOK

ExecSUB:						; SUB RD, RS   (RD = RD - RS)
	cmp ebx, 3
	ja BadRegister
	cmp ecx, 3
	ja BadRegister
	mov eax, RegisterFile[ebx*4]
	sub eax, RegisterFile[ecx*4]
	mov RegisterFile[ebx*4], eax
	call UpdateZeroFlag
	jmp ExecOK

ExecMUL:						; MUL RD, RS   (RD = RD * RS, lower 32 bits kept)
	cmp ebx, 3
	ja BadRegister
	cmp ecx, 3
	ja BadRegister
	mov eax, RegisterFile[ebx*4]
	imul eax, RegisterFile[ecx*4]
	mov RegisterFile[ebx*4], eax
	call UpdateZeroFlag
	jmp ExecOK

ExecDIV:						; DIV RD, RS   (RD = RD / RS, signed, quotient only)
	cmp ebx, 3
	ja BadRegister
	cmp ecx, 3
	ja BadRegister

	mov esi, RegisterFile[ecx*4]	; ESI = divisor
	cmp esi, 0
	je DivideByZero				; cannot divide by zero

	mov eax, RegisterFile[ebx*4]	; EAX = dividend
	cmp esi, -1
	jne DoDivide
	cmp eax, 80000000h			; the smallest number / -1 does not fit in 32 bits
	je DivideOverflow

DoDivide:
	cdq							; sign-extend EAX into EDX:EAX
	idiv esi					; EAX = quotient
	mov RegisterFile[ebx*4], eax
	call UpdateZeroFlag
	jmp ExecOK

ExecLOAD:						; LOAD RD, address   (RD = DataMemory[address])
	cmp ebx, 3
	ja BadRegister
	INVOKE ReadDataMemory, edx	; EAX = value, CF = 1 if address is invalid
	jc LoadFailed
	mov RegisterFile[ebx*4], eax
	jmp ExecOK

ExecSTORE:						; STORE RS, address   (DataMemory[address] = RS)
	cmp ecx, 3
	ja BadRegister
	mov esi, RegisterFile[ecx*4]	; ESI = value held in RS
	INVOKE WriteDataMemory, edx, esi	; EAX = 1 on success, 0 if address is invalid
	cmp eax, 0
	je StoreFailed
	jmp ExecOK

ExecCMP:						; CMP RD, RS   (sets ZF if RD = RS, changes no register)
	cmp ebx, 3
	ja BadRegister
	cmp ecx, 3
	ja BadRegister
	mov eax, RegisterFile[ebx*4]
	sub eax, RegisterFile[ecx*4]	; subtract only to get a result; it is not stored
	call UpdateZeroFlag
	jmp ExecOK

ExecJMP:						; JMP address   (always jump)
	mov PC, edx
	jmp ExecOK

ExecJZ:							; JZ address    (jump if ZF = 1)
	test CPUFlags, ZF_MASK
	jz ExecOK					; ZF is 0 -> do not jump
	mov PC, edx
	jmp ExecOK

ExecJNZ:						; JNZ address   (jump if ZF = 0)
	test CPUFlags, ZF_MASK
	jnz ExecOK					; ZF is 1 -> do not jump
	mov PC, edx
	jmp ExecOK

ExecHALT:						; HALT   (stop execution)
	mov CPUHalted, 1
	jmp ExecOK

	; ================= RESULTS =================

ExecOK:
	mov eax, 1					; instruction executed successfully
	ret

AlreadyHalted:
	xor eax, eax				; nothing executed
	ret

	; ---------- Error handling ----------
	; Each error loads EDX with a message, then falls into ReportError, which
	; prints it and halts the CPU (Main.asm's Run loop waits for CPUHalted).
FetchFailed:
	mov edx, OFFSET errFetch
	jmp ReportError
BadOpcode:
	mov edx, OFFSET errOpcode
	jmp ReportError
BadRegister:
	mov edx, OFFSET errRegister
	jmp ReportError
DivideByZero:
	mov edx, OFFSET errDivZero
	jmp ReportError
DivideOverflow:
	mov edx, OFFSET errDivOverflow
	jmp ReportError
LoadFailed:
	mov edx, OFFSET errDataLoad
	jmp ReportError
StoreFailed:
	mov edx, OFFSET errDataStore

ReportError:
	call WriteString			; print the message in EDX
	mov CPUHalted, 1			; stop the CPU
	xor eax, eax				; 0 = instruction did not complete
	ret

ExecuteNextInstruction ENDP

END