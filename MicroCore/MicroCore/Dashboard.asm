; ======================================================================
; Dashboard.asm — Console Interface (Module 3)
; Displays the main menu, CPU registers, DataMemory, ProgramMemory,
; CPU status, and validates menu selections from the user.
; Reads CPU state via EXTERN variables from CPU.asm and reads memory
; non-destructively via INVOKE procedures from Memory.asm.
; ======================================================================

INCLUDE Irvine32.inc
INCLUDE MicroCore.inc

; Shared program length owned by Main.asm so DisplayProgram only prints
; the instructions actually loaded into ProgramMemory.
EXTERN programLength:DWORD

.data
	; Dashboard banner and menu strings
	dashHeader1		BYTE "========================================", 0Dh, 0Ah, 0
	dashTitle1		BYTE "              MICROCORE", 0Dh, 0Ah, 0
	dashTitle2		BYTE "        MINIATURE CPU EMULATOR", 0Dh, 0Ah, 0
	dashDivider		BYTE "----------------------------------------", 0Dh, 0Ah, 0

	lblProgLoaded	BYTE "Program loaded: ", 0
	lblYes			BYTE "Yes", 0
	lblNo			BYTE "No", 0
	lblInstrCount	BYTE "Instructions  : ", 0

	menuOpt1		BYTE "1. Step", 0Dh, 0Ah, 0
	menuOpt2		BYTE "2. Run", 0Dh, 0Ah, 0
	menuOpt3		BYTE "3. Display Registers", 0Dh, 0Ah, 0
	menuOpt4		BYTE "4. Display Data Memory", 0Dh, 0Ah, 0
	menuOpt5		BYTE "5. Display Program", 0Dh, 0Ah, 0
	menuOpt6		BYTE "6. Reset", 0Dh, 0Ah, 0
	menuOpt0		BYTE "0. Exit", 0Dh, 0Ah, 0

	; Status strings
	lblCpuStatus	BYTE "CPU Status    : ", 0
	statusReady		BYTE "READY", 0
	statusHalted	BYTE "HALTED", 0

	; Register display strings
	regHeader		BYTE "========== CPU REGISTERS ==========", 0Dh, 0Ah, 0
	regFooter		BYTE "===================================", 0Dh, 0Ah, 0
	lblR0			BYTE "R0        : ", 0
	lblR1			BYTE "R1        : ", 0
	lblR2			BYTE "R2        : ", 0
	lblR3			BYTE "R3        : ", 0
	lblPC			BYTE "PC        : ", 0
	lblIR			BYTE "IR        : ", 0
	lblFlags		BYTE "CPUFlags  : ", 0
	lblZeroFlag		BYTE "Zero Flag : ", 0
	lblZFNote		BYTE "(ZF bit position not yet defined in CPU.asm/MicroCore.inc)", 0
	lblHalted		BYTE "CPU Halted: ", 0
	strHexOpen		BYTE " (", 0
	strHexClose		BYTE "h)", 0
	strHexSuffix	BYTE "h", 0

	; Memory display strings
	memHeader		BYTE "========== DATA MEMORY ==========", 0Dh, 0Ah, 0
	memColHeader	BYTE "Address      Value (Dec)      Value (Hex)", 0Dh, 0Ah, 0
	memColLine		BYTE "-----------------------------------------", 0Dh, 0Ah, 0
	memFooter		BYTE "=================================", 0Dh, 0Ah, 0
	memReadErrMsg	BYTE " [Read Error]", 0

	; Program display strings
	progHeader		BYTE "========== LOADED PROGRAM ==========", 0Dh, 0Ah, 0
	progColHeader	BYTE "Address     Instruction", 0Dh, 0Ah, 0
	progColLine		BYTE "------------------------------------", 0Dh, 0Ah, 0
	progFooter		BYTE "====================================", 0Dh, 0Ah, 0
	progEmptyMsg	BYTE "(No program loaded)", 0Dh, 0Ah, 0
	progReadErrMsg	BYTE "[Read Error]", 0
	progInvalidMsg	BYTE "INVALID (", 0

	; Decoded instruction mnemonics
	mnLOADI			BYTE "LOADI ", 0
	mnMOV			BYTE "MOV ", 0
	mnADD			BYTE "ADD ", 0
	mnSUB			BYTE "SUB ", 0
	mnMUL			BYTE "MUL ", 0
	mnDIV			BYTE "DIV ", 0
	mnLOAD			BYTE "LOAD ", 0
	mnSTORE			BYTE "STORE ", 0
	mnCMP			BYTE "CMP ", 0
	mnJMP			BYTE "JMP ", 0
	mnJZ			BYTE "JZ ", 0
	mnJNZ			BYTE "JNZ ", 0
	mnHALT			BYTE "HALT", 0

	regName0		BYTE "R0", 0
	regName1		BYTE "R1", 0
	regName2		BYTE "R2", 0
	regName3		BYTE "R3", 0
	regNames		DWORD OFFSET regName0, OFFSET regName1, OFFSET regName2, OFFSET regName3
	commaSpace		BYTE ", ", 0

	; User choice input strings and buffer
	promptChoice	BYTE "Enter choice (0-6): ", 0
	invalidChoice	BYTE "Invalid choice. Please enter a number between 0 and 6.", 0Dh, 0Ah, 0
	choiceBuf		BYTE 32 DUP(0)

.code

; Export all 6 dashboard procedures so Main.asm can invoke them.
PUBLIC DisplayDashboard
PUBLIC DisplayRegisters
PUBLIC DisplayMemory
PUBLIC DisplayProgram
PUBLIC DisplayStatus
PUBLIC GetUserChoice

;-----------------------------------------------------------------------
; PrintSpaces
; Purpose : Prints ECX space characters for simple column alignment.
; Input   : ECX = number of spaces to print.
; Uses    : EAX, ECX (preserved via USES).
;-----------------------------------------------------------------------
PrintSpaces PROC USES eax ecx
	cmp ecx, 0
	jle PrintSpacesDone
PrintSpacesLoop:
	mov al, ' '
	call WriteChar
	loop PrintSpacesLoop
PrintSpacesDone:
	ret
PrintSpaces ENDP

;-----------------------------------------------------------------------
; PrintSignedVal
; Purpose : Prints EAX as a signed decimal without a leading '+'.
;           (Irvine32 WriteInt prints '+', so we handle '-' manually
;           and call WriteDec for cleaner register/memory output.)
; Input   : EAX = 32-bit signed integer.
;-----------------------------------------------------------------------
PrintSignedVal PROC USES eax
	; Check bit 31 (sign bit). If 0, value is non-negative.
	test eax, 80000000h
	jz PrintUnsigned

	; Negative value: print '-' and negate to get positive magnitude.
	push eax
	mov al, '-'
	call WriteChar
	pop eax
	neg eax
PrintUnsigned:
	call WriteDec
	ret
PrintSignedVal ENDP

;-----------------------------------------------------------------------
; PrintRegWithHex
; Purpose : Helper for DisplayRegisters to avoid repeating formatting
;           code for R0, R1, R2, and R3.
; Input   : EDX = offset of label string, EAX = register value.
;-----------------------------------------------------------------------
PrintRegWithHex PROC USES eax edx
	push eax
	call WriteString
	pop eax
	push eax
	call PrintSignedVal
	mov edx, OFFSET strHexOpen
	call WriteString
	pop eax
	call WriteHex
	mov edx, OFFSET strHexClose
	call WriteString
	call Crlf
	ret
PrintRegWithHex ENDP

;-----------------------------------------------------------------------
; PrintRegisterName
; Purpose : Prints the virtual register name ("R0".."R3") for a 0..3 ID.
; Input   : EAX = register code (0 to 3).
; Output  : CF = 0 on success, CF = 1 if register code > 3.
;-----------------------------------------------------------------------
PrintRegisterName PROC USES edx
	cmp eax, 3
	ja InvalidRegCode
	; Index into the 4-element DWORD table of string offsets.
	mov edx, regNames[eax * 4]
	call WriteString
	clc
	ret
InvalidRegCode:
	stc
	ret
PrintRegisterName ENDP

;-----------------------------------------------------------------------
; DisplayStatus
; Purpose : Prints whether the virtual CPU is READY or HALTED.
; Reads   : CPUHalted (EXTERN DWORD owned by CPU.asm).
; Note    : CPU.asm does not currently expose an error flag, so only
;           READY and HALTED can be reported safely.
;-----------------------------------------------------------------------
DisplayStatus PROC USES edx
	mov edx, OFFSET lblCpuStatus
	call WriteString

	cmp CPUHalted, 0
	jne ShowHalted
	mov edx, OFFSET statusReady
	jmp PrintStatusStr
ShowHalted:
	mov edx, OFFSET statusHalted
PrintStatusStr:
	call WriteString
	call Crlf
	ret
DisplayStatus ENDP

;-----------------------------------------------------------------------
; DisplayDashboard
; Purpose : Displays the main title banner, whether a program is loaded,
;           the instruction count, CPU status, and the 0-6 menu options.
;-----------------------------------------------------------------------
DisplayDashboard PROC USES eax edx
	call Crlf
	mov edx, OFFSET dashHeader1
	call WriteString
	mov edx, OFFSET dashTitle1
	call WriteString
	mov edx, OFFSET dashTitle2
	call WriteString
	mov edx, OFFSET dashHeader1
	call WriteString
	call Crlf

	; Show whether at least 1 instruction is loaded.
	mov edx, OFFSET lblProgLoaded
	call WriteString
	cmp programLength, 0
	je ProgNotLoaded
	mov edx, OFFSET lblYes
	jmp PrintLoadedFlag
ProgNotLoaded:
	mov edx, OFFSET lblNo
PrintLoadedFlag:
	call WriteString
	call Crlf

	; Show the number of loaded instructions.
	mov edx, OFFSET lblInstrCount
	call WriteString
	mov eax, programLength
	call WriteDec
	call Crlf

	call DisplayStatus
	call Crlf

	; Print the interactive menu choices.
	mov edx, OFFSET dashDivider
	call WriteString
	mov edx, OFFSET menuOpt1
	call WriteString
	mov edx, OFFSET menuOpt2
	call WriteString
	mov edx, OFFSET menuOpt3
	call WriteString
	mov edx, OFFSET menuOpt4
	call WriteString
	mov edx, OFFSET menuOpt5
	call WriteString
	mov edx, OFFSET menuOpt6
	call WriteString
	mov edx, OFFSET menuOpt0
	call WriteString
	mov edx, OFFSET dashDivider
	call WriteString
	ret
DisplayDashboard ENDP

;-----------------------------------------------------------------------
; DisplayRegisters
; Purpose : Displays R0-R3, PC, IR, CPUFlags, Zero Flag note, and CPUHalted.
; Reads   : Virtual CPU variables from CPU.asm (read-only).
;-----------------------------------------------------------------------
DisplayRegisters PROC USES eax edx
	call Crlf
	mov edx, OFFSET regHeader
	call WriteString
	call Crlf

	mov edx, OFFSET lblR0
	mov eax, R0
	call PrintRegWithHex

	mov edx, OFFSET lblR1
	mov eax, R1
	call PrintRegWithHex

	mov edx, OFFSET lblR2
	mov eax, R2
	call PrintRegWithHex

	mov edx, OFFSET lblR3
	mov eax, R3
	call PrintRegWithHex
	call Crlf

	mov edx, OFFSET lblPC
	call WriteString
	mov eax, PC
	call WriteDec
	call Crlf

	mov edx, OFFSET lblIR
	call WriteString
	mov eax, IR
	call WriteHex
	mov edx, OFFSET strHexSuffix
	call WriteString
	call Crlf
	call Crlf

	mov edx, OFFSET lblFlags
	call WriteString
	mov eax, CPUFlags
	call WriteHex
	mov edx, OFFSET strHexOpen
	call WriteString
	mov eax, CPUFlags
	call WriteDec
	mov al, ')'
	call WriteChar
	call Crlf

	; CPU.asm / MicroCore.inc does not define a ZF bit constant yet,
	; so we explain that instead of guessing a bitmask position.
	mov edx, OFFSET lblZeroFlag
	call WriteString
	mov edx, OFFSET lblZFNote
	call WriteString
	call Crlf

	mov edx, OFFSET lblHalted
	call WriteString
	mov eax, CPUHalted
	call WriteDec
	call Crlf
	call Crlf

	mov edx, OFFSET regFooter
	call WriteString
	ret
DisplayRegisters ENDP

;-----------------------------------------------------------------------
; DisplayMemory
; Purpose : Displays all 64 DataMemory entries (addresses 0-63) without
;           modifying memory.
; Calls   : INVOKE ReadDataMemory, address (returns value in EAX, CF=1 on error).
; Uses    : EBX as the address loop counter (0..63).
;-----------------------------------------------------------------------
DisplayMemory PROC USES eax ebx ecx edx
	call Crlf
	mov edx, OFFSET memHeader
	call WriteString
	call Crlf
	mov edx, OFFSET memColHeader
	call WriteString
	mov edx, OFFSET memColLine
	call WriteString

	xor ebx, ebx					; EBX = current DataMemory address (0..63)
MemLoop:
	cmp ebx, MEMORY_SIZE
	jae MemDone

	; Print address and align column (1-digit vs 2-digit address).
	mov eax, ebx
	call WriteDec
	mov ecx, 12
	cmp ebx, 10
	jb PadAddrSingle
	dec ecx
PadAddrSingle:
	call PrintSpaces

	; Read value from Memory.asm; Carry Flag indicates invalid address.
	INVOKE ReadDataMemory, ebx
	jc MemReadFailed

	; Print signed decimal value followed by 8-digit hex representation.
	push eax
	call PrintSignedVal
	mov ecx, 10
	call PrintSpaces
	pop eax
	call WriteHex
	mov edx, OFFSET strHexSuffix
	call WriteString
	call Crlf
	jmp MemNext

MemReadFailed:
	mov edx, OFFSET memReadErrMsg
	call WriteString
	call Crlf

MemNext:
	inc ebx
	jmp MemLoop

MemDone:
	call Crlf
	mov edx, OFFSET memFooter
	call WriteString
	ret
DisplayMemory ENDP

;-----------------------------------------------------------------------
; DecodeAndPrintInstruction
; Purpose : Decodes a 32-bit instruction DWORD and prints its mnemonic
;           and operands for DisplayProgram.
; Input   : EAX = 32-bit encoded instruction.
; Bit layout:
;   Bits 31-24 = Opcode (8 bits)
;   Bits 23-20 = RD, destination register (4 bits)
;   Bits 19-16 = RS, source register (4 bits)
;   Bits 15-0  = Immediate value or address (16 bits)
;-----------------------------------------------------------------------
DecodeAndPrintInstruction PROC USES eax ebx ecx edx esi
	mov esi, eax					; Keep original DWORD in ESI for error printing

	; Extract opcode (bits 31-24) by shifting right 24 bits.
	mov eax, esi
	shr eax, 24
	and eax, 0FFh					; EAX = opcode

	; Extract RD (bits 23-20) by shifting right 20 bits and masking 4 bits.
	mov ebx, esi
	shr ebx, 20
	and ebx, 0Fh					; EBX = RD

	; Extract RS (bits 19-16) by shifting right 16 bits and masking 4 bits.
	mov ecx, esi
	shr ecx, 16
	and ecx, 0Fh					; ECX = RS

	; Extract immediate/address (bits 15-0) using a 16-bit mask.
	mov edx, esi
	and edx, 0FFFFh					; EDX = immediate / address

	; Dispatch by opcode
	cmp eax, OP_LOADI
	je DecLOADI
	cmp eax, OP_MOV
	je DecMOV
	cmp eax, OP_ADD
	je DecADD
	cmp eax, OP_SUB
	je DecSUB
	cmp eax, OP_MUL
	je DecMUL
	cmp eax, OP_DIV
	je DecDIV
	cmp eax, OP_LOAD
	je DecLOAD
	cmp eax, OP_STORE
	je DecSTORE
	cmp eax, OP_CMP
	je DecCMP
	cmp eax, OP_JMP
	je DecJMP
	cmp eax, OP_JZ
	je DecJZ
	cmp eax, OP_JNZ
	je DecJNZ
	cmp eax, OP_HALT
	je DecHALT
	jmp DecUnknown

DecLOADI:
	cmp ebx, 3
	ja DecUnknown
	push edx
	mov edx, OFFSET mnLOADI
	call WriteString
	mov eax, ebx
	call PrintRegisterName
	mov edx, OFFSET commaSpace
	call WriteString
	pop eax
	call WriteDec
	ret

DecMOV:
	mov edx, OFFSET mnMOV
	jmp DecTwoRegs
DecADD:
	mov edx, OFFSET mnADD
	jmp DecTwoRegs
DecSUB:
	mov edx, OFFSET mnSUB
	jmp DecTwoRegs
DecMUL:
	mov edx, OFFSET mnMUL
	jmp DecTwoRegs
DecDIV:
	mov edx, OFFSET mnDIV
	jmp DecTwoRegs
DecCMP:
	mov edx, OFFSET mnCMP

DecTwoRegs:
	cmp ebx, 3
	ja DecUnknown
	cmp ecx, 3
	ja DecUnknown
	call WriteString
	mov eax, ebx
	call PrintRegisterName
	mov edx, OFFSET commaSpace
	call WriteString
	mov eax, ecx
	call PrintRegisterName
	ret

DecLOAD:
	cmp ebx, 3
	ja DecUnknown
	push edx
	mov edx, OFFSET mnLOAD
	call WriteString
	mov eax, ebx
	call PrintRegisterName
	mov edx, OFFSET commaSpace
	call WriteString
	pop eax
	call WriteDec
	ret

DecSTORE:
	; STORE RS, address uses RS field (bits 19-16)
	cmp ecx, 3
	ja DecUnknown
	push edx
	mov edx, OFFSET mnSTORE
	call WriteString
	mov eax, ecx
	call PrintRegisterName
	mov edx, OFFSET commaSpace
	call WriteString
	pop eax
	call WriteDec
	ret

DecJMP:
	push edx
	mov edx, OFFSET mnJMP
	jmp DecAddrOnly
DecJZ:
	push edx
	mov edx, OFFSET mnJZ
	jmp DecAddrOnly
DecJNZ:
	push edx
	mov edx, OFFSET mnJNZ

DecAddrOnly:
	call WriteString
	pop eax
	call WriteDec
	ret

DecHALT:
	mov edx, OFFSET mnHALT
	call WriteString
	ret

DecUnknown:
	mov edx, OFFSET progInvalidMsg
	call WriteString
	mov eax, esi
	call WriteHex
	mov edx, OFFSET strHexClose
	call WriteString
	ret
DecodeAndPrintInstruction ENDP

;-----------------------------------------------------------------------
; DisplayProgram
; Purpose : Reads ProgramMemory up to programLength and prints each
;           encoded instruction in readable assembly format.
; Reads   : programLength (from Main.asm), ProgramMemory via ReadProgramMemory.
; Uses    : EBX = instruction index (0..programLength-1), ECX = limit.
;-----------------------------------------------------------------------
DisplayProgram PROC USES eax ebx ecx edx
	call Crlf
	mov edx, OFFSET progHeader
	call WriteString
	call Crlf

	; Only display loaded instructions instead of all 64 empty slots.
	mov ecx, programLength
	cmp ecx, 0
	je ProgEmpty
	cmp ecx, MEMORY_SIZE
	jbe ProgCountOk
	mov ecx, MEMORY_SIZE
ProgCountOk:

	mov edx, OFFSET progColHeader
	call WriteString
	mov edx, OFFSET progColLine
	call WriteString

	xor ebx, ebx					; EBX = current instruction address
ProgLoop:
	cmp ebx, ecx
	jae ProgDone

	; Save ECX (programLength) because PrintSpaces modifies ECX internally,
	; though it restores it; explicit push/pop keeps the loop limit clear.
	push ecx
	mov eax, ebx
	call WriteDec
	mov ecx, 11
	cmp ebx, 10
	jb ProgPadSingle
	dec ecx
ProgPadSingle:
	call PrintSpaces

	; Fetch encoded DWORD from Memory.asm and decode it for display.
	INVOKE ReadProgramMemory, ebx
	jc ProgReadErr
	call DecodeAndPrintInstruction
	call Crlf
	jmp ProgNext

ProgReadErr:
	mov edx, OFFSET progReadErrMsg
	call WriteString
	call Crlf

ProgNext:
	pop ecx
	inc ebx
	jmp ProgLoop

ProgEmpty:
	mov edx, OFFSET progEmptyMsg
	call WriteString

ProgDone:
	call Crlf
	mov edx, OFFSET progFooter
	call WriteString
	ret
DisplayProgram ENDP

;-----------------------------------------------------------------------
; GetUserChoice
; Purpose : Reads and validates the user's menu selection (0-6).
;           Uses ReadString instead of ReadDec/ReadInt so empty lines
;           or letters like "abc" are rejected instead of returning 0.
; Output  : EAX = validated integer choice from 0 to 6.
;-----------------------------------------------------------------------
GetUserChoice PROC USES ecx edx esi
ChoicePromptLoop:
	mov edx, OFFSET promptChoice
	call WriteString

	; Read up to SIZEOF choiceBuf - 1 characters into choiceBuf.
	mov edx, OFFSET choiceBuf
	mov ecx, SIZEOF choiceBuf
	call ReadString

	; Skip any leading spaces or tabs (09h).
	mov esi, OFFSET choiceBuf
SkipLeadSpaces:
	mov al, BYTE PTR [esi]
	cmp al, ' '
	je AdvanceLead
	cmp al, 09h
	je AdvanceLead
	jmp CheckDigit
AdvanceLead:
	inc esi
	jmp SkipLeadSpaces

CheckDigit:
	; Accept only a single digit between '0' and '6'.
	mov al, BYTE PTR [esi]
	cmp al, '0'
	jb BadChoice
	cmp al, '6'
	ja BadChoice

	; Convert ASCII character ('0'..'6') to numeric value (0..6).
	movzx eax, al
	sub eax, '0'
	inc esi

SkipTrailSpaces:
	; Ensure nothing other than spaces/tabs follows the digit.
	mov dl, BYTE PTR [esi]
	cmp dl, 0
	je ChoiceValid
	cmp dl, ' '
	je AdvanceTrail
	cmp dl, 09h
	je AdvanceTrail
	jmp BadChoice
AdvanceTrail:
	inc esi
	jmp SkipTrailSpaces

BadChoice:
	mov edx, OFFSET invalidChoice
	call WriteString
	jmp ChoicePromptLoop

ChoiceValid:
	ret
GetUserChoice ENDP

END
