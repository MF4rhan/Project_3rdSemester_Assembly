; ======================================================================
; Main.asm — Program Controller & Instruction Parser (Module 3)
; Coordinates CPU.asm, Memory.asm, and Dashboard.asm:
;   1. Initializes Memory and CPU at startup.
;   2. Reads assembly-like lines from the user until END.
;   3. Parses, validates, and encodes instructions into 32-bit DWORDs.
;   4. Stages and loads the program into ProgramMemory.
;   5. Runs the menu loop for Step, Run, Display, Reset, and Exit.
; ======================================================================

INCLUDE Irvine32.inc
INCLUDE MicroCore.inc

; Dashboard procedures implemented in Dashboard.asm (DisplayDashboard is in MicroCore.inc)
DisplayRegisters PROTO
DisplayMemory PROTO
DisplayProgram PROTO
DisplayStatus PROTO
GetUserChoice PROTO

; Internal parser procedure prototype
ParseInstructionLine PROTO, lineNum:DWORD, pOutDword:PTR DWORD

; Parser status codes
PARSE_OK	EQU 0
PARSE_END	EQU 1
PARSE_EMPTY	EQU 2
PARSE_ERROR	EQU 3

; Instruction operand formats
FMT_NONE	EQU 0	; HALT
FMT_ADDR	EQU 1	; JMP, JZ, JNZ
FMT_REG_REG	EQU 2	; MOV, ADD, SUB, MUL, DIV, CMP
FMT_REG_IMM	EQU 3	; LOADI
FMT_RD_ADDR	EQU 4	; LOAD
FMT_RS_ADDR	EQU 5	; STORE

MAX_LINE_LEN EQU 127
MAX_EMPTY_LINES EQU 50

.data
	; Exported program length used by Dashboard.asm
	PUBLIC programLength
	programLength	DWORD 0

	; Backup of encoded program for Reset functionality
	programBuffer	DWORD MEMORY_SIZE DUP(0)

	; Staging buffer during parsing so invalid programs are not committed
	stagingBuffer	DWORD MEMORY_SIZE DUP(0)
	stagingCount	DWORD 0

	; Input buffers
	inputLine		BYTE (MAX_LINE_LEN + 1) DUP(0)
	mnemonicBuf		BYTE 32 DUP(0)
	op1Buf			BYTE 64 DUP(0)
	op2Buf			BYTE 64 DUP(0)

	; Instruction mnemonic strings
	strLOADI		BYTE "LOADI", 0
	strMOV			BYTE "MOV", 0
	strADD			BYTE "ADD", 0
	strSUB			BYTE "SUB", 0
	strMUL			BYTE "MUL", 0
	strDIV			BYTE "DIV", 0
	strLOAD			BYTE "LOAD", 0
	strSTORE		BYTE "STORE", 0
	strCMP			BYTE "CMP", 0
	strJMP			BYTE "JMP", 0
	strJZ			BYTE "JZ", 0
	strJNZ			BYTE "JNZ", 0
	strHALT			BYTE "HALT", 0
	strEND			BYTE "END", 0

	; Instruction table: (OFFSET mnemonic, opcode, format)
	INSTR_COUNT EQU 13
	instrTable		DWORD OFFSET strLOADI, OP_LOADI, FMT_REG_IMM
					DWORD OFFSET strMOV,   OP_MOV,   FMT_REG_REG
					DWORD OFFSET strADD,   OP_ADD,   FMT_REG_REG
					DWORD OFFSET strSUB,   OP_SUB,   FMT_REG_REG
					DWORD OFFSET strMUL,   OP_MUL,   FMT_REG_REG
					DWORD OFFSET strDIV,   OP_DIV,   FMT_REG_REG
					DWORD OFFSET strLOAD,  OP_LOAD,  FMT_RD_ADDR
					DWORD OFFSET strSTORE, OP_STORE, FMT_RS_ADDR
					DWORD OFFSET strCMP,   OP_CMP,   FMT_REG_REG
					DWORD OFFSET strJMP,   OP_JMP,   FMT_ADDR
					DWORD OFFSET strJZ,    OP_JZ,    FMT_ADDR
					DWORD OFFSET strJNZ,   OP_JNZ,   FMT_ADDR
					DWORD OFFSET strHALT,  OP_HALT,  FMT_NONE

	; Startup and program entry messages
	initMsg			BYTE "MicroCore initialized successfully.", 0Dh, 0Ah, 0
	enterProgMsg	BYTE 0Dh, 0Ah, "Enter your Assembly program.", 0Dh, 0Ah
					BYTE "Enter END when finished.", 0Dh, 0Ah, 0Dh, 0Ah, 0
	linePromptPrefix BYTE "> ", 0
	loadedOkMsg		BYTE 0Dh, 0Ah, "Program loaded successfully (", 0
	loadedOkSuffix	BYTE " instructions).", 0Dh, 0Ah, 0
	noInstrWarn		BYTE "Warning: No instructions entered. Program memory remains empty.", 0Dh, 0Ah, 0
	loadFailMsg		BYTE "Error: Failed to load program into ProgramMemory.", 0Dh, 0Ah, 0

	; Parser error messages
	errPrefix		BYTE "Error on input line ", 0
	errColon		BYTE ": ", 0
	errUnknownInstr	BYTE "Unknown instruction mnemonic.", 0Dh, 0Ah, 0
	errEndExtra		BYTE "Unexpected operand(s) after END.", 0Dh, 0Ah, 0
	errUnexpectedOp	BYTE "Unexpected operand(s) for HALT.", 0Dh, 0Ah, 0
	errMissingOp	BYTE "Missing operand.", 0Dh, 0Ah, 0
	errMissingComma	BYTE "Expected ',' separating two operands.", 0Dh, 0Ah, 0
	errTooManyOps	BYTE "Too many operands.", 0Dh, 0Ah, 0
	errBadReg1		BYTE "Invalid register in first operand (expected R0-R3).", 0Dh, 0Ah, 0
	errBadReg2		BYTE "Invalid register in second operand (expected R0-R3).", 0Dh, 0Ah, 0
	errBadImm		BYTE "Invalid numeric immediate value.", 0Dh, 0Ah, 0
	errImmRange		BYTE "Immediate value out of 16-bit range (-32768 to 65535).", 0Dh, 0Ah, 0
	errBadAddr		BYTE "Invalid numeric memory address.", 0Dh, 0Ah, 0
	errAddrRange	BYTE "Memory address out of range (must be 0 to 63).", 0Dh, 0Ah, 0
	errTokenLen		BYTE "Instruction token is too long.", 0Dh, 0Ah, 0
	errCapacity		BYTE "Program capacity exceeded (maximum 64 instructions). Enter END to finish.", 0Dh, 0Ah, 0

	; Execution and control messages
	msgNoProgram	BYTE "No program is loaded.", 0Dh, 0Ah, 0
	msgAlreadyHalt	BYTE "CPU is already halted. Select Reset (6) to restart.", 0Dh, 0Ah, 0
	msgStepDone		BYTE "Executed 1 instruction.", 0Dh, 0Ah, 0
	msgRunDone		BYTE "Program execution finished.", 0Dh, 0Ah, 0
	msgResetDone	BYTE "Emulator reset to initial state. Program restored.", 0Dh, 0Ah, 0
	msgResetEmpty	BYTE "Emulator reset to initial state.", 0Dh, 0Ah, 0
	msgResetFail	BYTE "Error: Reset could not reload the saved program.", 0Dh, 0Ah, 0
	msgExit			BYTE "Exiting MicroCore. Goodbye!", 0Dh, 0Ah, 0

.code

;-----------------------------------------------------------------------
; SkipSpaces
; Purpose : Moves ESI forward past any space (' ') or tab (09h) chars.
; Input   : ESI = current position in a null-terminated string.
; Output  : ESI = pointer to the first non-whitespace character (or 0).
;-----------------------------------------------------------------------
SkipSpaces PROC
SkipLoop:
	mov al, BYTE PTR [esi]
	cmp al, ' '
	je NextSpace
	cmp al, 09h
	je NextSpace
	ret
NextSpace:
	inc esi
	jmp SkipLoop
SkipSpaces ENDP

;-----------------------------------------------------------------------
; TrimTrailingSpaces
; Purpose : Removes spaces/tabs at the end of a string by overwriting
;           them with null terminators (0).
; Input   : EDI = start of a null-terminated string.
;-----------------------------------------------------------------------
TrimTrailingSpaces PROC USES eax ecx edi
	; Walk to the end of the string while counting its length in ECX.
	mov ecx, 0
FindEndLoop:
	cmp BYTE PTR [edi], 0
	je CheckBack
	inc edi
	inc ecx
	jmp FindEndLoop
CheckBack:
	cmp ecx, 0
	je TrimDone
	dec edi
	mov al, BYTE PTR [edi]
	cmp al, ' '
	je DoTrim
	cmp al, 09h
	je DoTrim
	jmp TrimDone
DoTrim:
	mov BYTE PTR [edi], 0
	dec ecx
	jmp CheckBack
TrimDone:
	ret
TrimTrailingSpaces ENDP

;-----------------------------------------------------------------------
; ToUpperChar
; Purpose : Converts a lowercase ASCII letter ('a'..'z') in AL to
;           uppercase ('A'..'Z') for case-insensitive matching.
;-----------------------------------------------------------------------
ToUpperChar PROC
	cmp al, 'a'
	jb UpperDone
	cmp al, 'z'
	ja UpperDone
	sub al, 32						; ASCII 'a' - 'A' = 32
UpperDone:
	ret
ToUpperChar ENDP

;-----------------------------------------------------------------------
; StrEqualNoCase
; Purpose : Compares two null-terminated strings ignoring letter case.
; Input   : ESI = first string, EDI = second string.
; Output  : EAX = 1 if equal, 0 if different.
;-----------------------------------------------------------------------
StrEqualNoCase PROC USES ebx esi edi
CmpLoop:
	mov al, BYTE PTR [esi]
	call ToUpperChar
	mov bl, al

	mov al, BYTE PTR [edi]
	call ToUpperChar

	cmp bl, al
	jne NotEqual
	cmp bl, 0						; Both strings reached null terminator
	je AreEqual
	inc esi
	inc edi
	jmp CmpLoop
AreEqual:
	mov eax, 1
	ret
NotEqual:
	xor eax, eax
	ret
StrEqualNoCase ENDP

;-----------------------------------------------------------------------
; ParseRegister
; Purpose : Converts a register name ("R0".."R3", case-insensitive) into
;           its numeric ID (0..3).
; Input   : ESI = trimmed operand string.
; Output  : EAX = 0..3 with CF=0 if valid; CF=1 if invalid (e.g. "R5").
;-----------------------------------------------------------------------
ParseRegister PROC USES esi
	mov al, BYTE PTR [esi]
	call ToUpperChar
	cmp al, 'R'
	jne RegFail

	mov al, BYTE PTR [esi + 1]
	cmp al, '0'
	jb RegFail
	cmp al, '3'
	ja RegFail

	; Ensure there are no extra characters after R0..R3 (e.g. "R01").
	cmp BYTE PTR [esi + 2], 0
	jne RegFail

	movzx eax, al
	sub eax, '0'
	clc								; Clear Carry Flag to signal success
	ret
RegFail:
	stc								; Set Carry Flag to signal invalid register
	ret
ParseRegister ENDP

;-----------------------------------------------------------------------
; ParseInteger
; Purpose : Converts a trimmed decimal string (optional '+' or '-') into
;           a signed 32-bit integer, rejecting non-digits and overflow.
; Input   : ESI = trimmed numeric string.
; Output  : EAX = parsed integer with CF=0 on success; CF=1 on failure.
; Uses    : EBX = sign flag (0 positive, 1 negative), ECX = base 10.
;-----------------------------------------------------------------------
ParseInteger PROC USES ebx ecx edx esi edi
	xor ebx, ebx					; EBX = 0 (positive), 1 (negative)
	xor eax, eax					; EAX = running numeric total

	mov dl, BYTE PTR [esi]
	cmp dl, 0
	je IntFail
	cmp dl, '-'
	jne CheckPlus
	mov ebx, 1
	inc esi
	jmp CheckFirstDigit
CheckPlus:
	cmp dl, '+'
	jne CheckFirstDigit
	inc esi

CheckFirstDigit:
	; Require at least one digit after an optional sign.
	mov dl, BYTE PTR [esi]
	cmp dl, '0'
	jb IntFail
	cmp dl, '9'
	ja IntFail

	mov ecx, 10
DigitLoop:
	mov dl, BYTE PTR [esi]
	cmp dl, 0
	je ApplySign
	cmp dl, '0'
	jb IntFail
	cmp dl, '9'
	ja IntFail

	sub dl, '0'						; Convert ASCII digit to 0..9
	movzx edi, dl

	; Multiply current total by 10; MUL puts upper 32 bits in EDX.
	; If EDX != 0 or ADD carries, the number overflowed 32 bits.
	mul ecx
	cmp edx, 0
	jne IntFail
	add eax, edi
	jc IntFail

	; Keep value within signed 32-bit range (-2147483648..2147483647).
	cmp ebx, 1
	je CheckNegLimit
	cmp eax, 7FFFFFFFh
	ja IntFail
	jmp NextDigit
CheckNegLimit:
	cmp eax, 80000000h
	ja IntFail

NextDigit:
	inc esi
	jmp DigitLoop

ApplySign:
	cmp ebx, 1
	jne IntOk
	neg eax
IntOk:
	clc
	ret
IntFail:
	stc
	ret
ParseInteger ENDP

;-----------------------------------------------------------------------
; ReportLineError
; Purpose : Prints "Error on input line <N>: <reason>".
; Input   : EBX = 1-based line number, EDX = error message offset.
;-----------------------------------------------------------------------
ReportLineError PROC USES eax edx
	push edx
	mov edx, OFFSET errPrefix
	call WriteString
	mov eax, ebx
	call WriteDec
	mov edx, OFFSET errColon
	call WriteString
	pop edx
	call WriteString
	ret
ReportLineError ENDP

;-----------------------------------------------------------------------
; LookupMnemonic
; Purpose : Searches instrTable for mnemonicBuf to find its opcode and
;           expected operand format.
; Output  : EAX = opcode (1..13), EDX = format constant, CF = 0 if found;
;           CF = 1 if unknown mnemonic.
;-----------------------------------------------------------------------
LookupMnemonic PROC USES ebx ecx esi edi
	mov ecx, INSTR_COUNT
	mov ebx, OFFSET instrTable
LookupLoop:
	mov esi, OFFSET mnemonicBuf
	mov edi, DWORD PTR [ebx]		; Column 0: mnemonic string pointer
	call StrEqualNoCase
	cmp eax, 1
	je FoundInstr
	add ebx, 12						; Each table row is 3 DWORDs (12 bytes)
	loop LookupLoop
	stc
	ret
FoundInstr:
	mov eax, DWORD PTR [ebx + 4]	; Column 1: opcode
	mov edx, DWORD PTR [ebx + 8]	; Column 2: operand format
	clc
	ret
LookupMnemonic ENDP

;-----------------------------------------------------------------------
; ParseInstructionLine
; Purpose : Parses and encodes one line from inputLine into a 32-bit
;           instruction DWORD using the layout:
;             Bits 31-24: Opcode (8 bits)
;             Bits 23-20: RD, destination register (4 bits)
;             Bits 19-16: RS, source register (4 bits)
;             Bits 15-0 : Immediate value or address (16 bits)
; Input   : lineNum   = 1-based line number (for error messages)
;           pOutDword = address where the encoded DWORD is stored
; Output  : EAX = PARSE_OK, PARSE_END, PARSE_EMPTY, or PARSE_ERROR
;-----------------------------------------------------------------------
ParseInstructionLine PROC USES ebx ecx edx esi edi,
	lineNum:DWORD,
	pOutDword:PTR DWORD

	LOCAL opcodeVal:DWORD
	LOCAL fmtVal:DWORD
	LOCAL reg1Val:DWORD
	LOCAL reg2Val:DWORD
	LOCAL immVal:DWORD

	; Skip leading spaces; if nothing remains, treat as an empty line.
	mov esi, OFFSET inputLine
	call SkipSpaces
	cmp BYTE PTR [esi], 0
	jne ExtractMnemonic
	mov eax, PARSE_EMPTY
	ret

ExtractMnemonic:
	; Read the first word (mnemonic) into mnemonicBuf, converting to uppercase.
	mov edi, OFFSET mnemonicBuf
	mov ecx, 0
MnemLoop:
	mov al, BYTE PTR [esi]
	cmp al, 0
	je MnemDone
	cmp al, ' '
	je MnemDone
	cmp al, 09h
	je MnemDone
	cmp ecx, 30
	jae ErrLen
	call ToUpperChar
	mov BYTE PTR [edi], al
	inc esi
	inc edi
	inc ecx
	jmp MnemLoop
MnemDone:
	mov BYTE PTR [edi], 0

	; Check for END first (END stops program entry and is not encoded).
	push esi
	mov esi, OFFSET mnemonicBuf
	mov edi, OFFSET strEND
	call StrEqualNoCase
	pop esi
	cmp eax, 1
	jne NotEndDirective

	; Make sure nothing extra follows END on the same line.
	call SkipSpaces
	cmp BYTE PTR [esi], 0
	jne ErrEndTrailing
	mov eax, PARSE_END
	ret

NotEndDirective:
	; Look up opcode and operand format in instrTable.
	call LookupMnemonic
	jc ErrUnknown
	mov opcodeVal, eax
	mov fmtVal, edx

	call SkipSpaces

	; --- Format 0: No operands (HALT) ---
	cmp fmtVal, FMT_NONE
	jne CheckOneOp
	cmp BYTE PTR [esi], 0
	jne ErrExtraForHalt
	mov eax, opcodeVal
	shl eax, 24						; Place opcode in bits 31-24
	mov edi, pOutDword
	mov DWORD PTR [edi], eax
	mov eax, PARSE_OK
	ret

CheckOneOp:
	; --- Format 1: One address operand (JMP, JZ, JNZ) ---
	cmp fmtVal, FMT_ADDR
	jne ParseTwoOps

	cmp BYTE PTR [esi], 0
	je ErrMissingOperand

	mov edi, OFFSET op1Buf
	mov ecx, 0
ReadOneOp:
	mov al, BYTE PTR [esi]
	cmp al, 0
	je OneOpCopied
	cmp al, ','
	je ErrTooMany
	cmp ecx, 62
	jae ErrLen
	mov BYTE PTR [edi], al
	inc esi
	inc edi
	inc ecx
	jmp ReadOneOp
OneOpCopied:
	mov BYTE PTR [edi], 0
	mov edi, OFFSET op1Buf
	call TrimTrailingSpaces

	; Address must be an unsigned integer in ProgramMemory range (0..63).
	mov esi, OFFSET op1Buf
	call ParseInteger
	jc ErrInvalidAddr
	cmp eax, MEMORY_SIZE
	jae ErrInvalidAddrRange

	mov edx, opcodeVal
	shl edx, 24						; Opcode -> bits 31-24
	or edx, eax						; Address -> bits 15-0
	mov edi, pOutDword
	mov DWORD PTR [edi], edx
	mov eax, PARSE_OK
	ret

ParseTwoOps:
	; --- Formats 2-5: Two operands separated by ',' ---
	cmp BYTE PTR [esi], 0
	je ErrMissingOperand

	; Copy first operand into op1Buf up to the comma.
	mov edi, OFFSET op1Buf
	mov ecx, 0
ReadOp1Loop:
	mov al, BYTE PTR [esi]
	cmp al, 0
	je ErrNoComma
	cmp al, ','
	je Op1Done
	cmp ecx, 62
	jae ErrLen
	mov BYTE PTR [edi], al
	inc esi
	inc edi
	inc ecx
	jmp ReadOp1Loop
Op1Done:
	mov BYTE PTR [edi], 0
	mov edi, OFFSET op1Buf
	call TrimTrailingSpaces

	; Skip ',' and whitespace before reading the second operand.
	inc esi
	call SkipSpaces
	cmp BYTE PTR [esi], 0
	je ErrMissingOperand

	; Copy second operand into op2Buf up to end of line.
	mov edi, OFFSET op2Buf
	mov ecx, 0
ReadOp2Loop:
	mov al, BYTE PTR [esi]
	cmp al, 0
	je Op2Done
	cmp al, ','
	je ErrTooMany
	cmp ecx, 62
	jae ErrLen
	mov BYTE PTR [edi], al
	inc esi
	inc edi
	inc ecx
	jmp ReadOp2Loop
Op2Done:
	mov BYTE PTR [edi], 0
	mov edi, OFFSET op2Buf
	call TrimTrailingSpaces

	; In all two-operand instructions, the first operand is a register (R0-R3).
	mov esi, OFFSET op1Buf
	call ParseRegister
	jc ErrInvalidReg1
	mov reg1Val, eax

	; Validate the second operand and encode according to instruction format.
	cmp fmtVal, FMT_REG_REG
	je EncodeRegReg
	cmp fmtVal, FMT_REG_IMM
	je EncodeRegImm
	cmp fmtVal, FMT_RD_ADDR
	je EncodeRdAddr
	jmp EncodeRsAddr

EncodeRegReg:
	; MOV, ADD, SUB, MUL, DIV, CMP: second operand is RS (bits 19-16).
	mov esi, OFFSET op2Buf
	call ParseRegister
	jc ErrInvalidReg2
	mov reg2Val, eax

	mov eax, opcodeVal
	shl eax, 24						; Opcode -> bits 31-24
	mov edx, reg1Val
	shl edx, 20						; RD -> bits 23-20
	or eax, edx
	mov edx, reg2Val
	shl edx, 16						; RS -> bits 19-16
	or eax, edx
	jmp StoreEncoded

EncodeRegImm:
	; LOADI RD, immediate: validate 16-bit range before masking to bits 15-0.
	mov esi, OFFSET op2Buf
	call ParseInteger
	jc ErrInvalidImm
	cmp eax, -32768
	jl ErrImmOutOfRange
	cmp eax, 65535
	jg ErrImmOutOfRange
	and eax, 0FFFFh					; Keep lower 16 bits without corrupting upper fields
	mov immVal, eax

	mov eax, opcodeVal
	shl eax, 24						; Opcode -> bits 31-24
	mov edx, reg1Val
	shl edx, 20						; RD -> bits 23-20
	or eax, edx
	or eax, immVal					; Immediate -> bits 15-0
	jmp StoreEncoded

EncodeRdAddr:
	; LOAD RD, address: RD -> bits 23-20, DataMemory address (0..63) -> bits 15-0.
	mov esi, OFFSET op2Buf
	call ParseInteger
	jc ErrInvalidAddr
	cmp eax, MEMORY_SIZE
	jae ErrInvalidAddrRange
	mov immVal, eax

	mov eax, opcodeVal
	shl eax, 24						; Opcode -> bits 31-24
	mov edx, reg1Val
	shl edx, 20						; RD -> bits 23-20
	or eax, edx
	or eax, immVal					; Address -> bits 15-0
	jmp StoreEncoded

EncodeRsAddr:
	; STORE RS, address: RS -> bits 19-16, DataMemory address (0..63) -> bits 15-0.
	mov esi, OFFSET op2Buf
	call ParseInteger
	jc ErrInvalidAddr
	cmp eax, MEMORY_SIZE
	jae ErrInvalidAddrRange
	mov immVal, eax

	mov eax, opcodeVal
	shl eax, 24						; Opcode -> bits 31-24
	mov edx, reg1Val
	shl edx, 16						; RS -> bits 19-16
	or eax, edx
	or eax, immVal					; Address -> bits 15-0

StoreEncoded:
	mov edi, pOutDword
	mov DWORD PTR [edi], eax
	mov eax, PARSE_OK
	ret

; --- Centralized error handlers ---
ErrLen:
	mov edx, OFFSET errTokenLen
	jmp PrintErrAndFail
ErrUnknown:
	mov edx, OFFSET errUnknownInstr
	jmp PrintErrAndFail
ErrEndTrailing:
	mov edx, OFFSET errEndExtra
	jmp PrintErrAndFail
ErrExtraForHalt:
	mov edx, OFFSET errUnexpectedOp
	jmp PrintErrAndFail
ErrMissingOperand:
	mov edx, OFFSET errMissingOp
	jmp PrintErrAndFail
ErrNoComma:
	mov edx, OFFSET errMissingComma
	jmp PrintErrAndFail
ErrTooMany:
	mov edx, OFFSET errTooManyOps
	jmp PrintErrAndFail
ErrInvalidReg1:
	mov edx, OFFSET errBadReg1
	jmp PrintErrAndFail
ErrInvalidReg2:
	mov edx, OFFSET errBadReg2
	jmp PrintErrAndFail
ErrInvalidImm:
	mov edx, OFFSET errBadImm
	jmp PrintErrAndFail
ErrImmOutOfRange:
	mov edx, OFFSET errImmRange
	jmp PrintErrAndFail
ErrInvalidAddr:
	mov edx, OFFSET errBadAddr
	jmp PrintErrAndFail
ErrInvalidAddrRange:
	mov edx, OFFSET errAddrRange

PrintErrAndFail:
	mov ebx, lineNum
	call ReportLineError
	mov eax, PARSE_ERROR
	ret
ParseInstructionLine ENDP

;-----------------------------------------------------------------------
; InputAndLoadProgram
; Purpose : Reads lines from the user until END, parses/stages valid
;           instructions in stagingBuffer, backs them up in programBuffer,
;           and loads them into ProgramMemory via Memory.asm LoadProgram.
;-----------------------------------------------------------------------
InputAndLoadProgram PROC USES eax ebx ecx edx esi
	LOCAL encodedDword:DWORD
	LOCAL lineCounter:DWORD
	LOCAL emptyStreak:DWORD

	mov stagingCount, 0
	mov lineCounter, 1
	mov emptyStreak, 0

	mov edx, OFFSET enterProgMsg
	call WriteString

ReadProgramLoop:
	mov edx, OFFSET linePromptPrefix
	call WriteString

	; Read the next line entered by the user.
	mov edx, OFFSET inputLine
	mov ecx, SIZEOF inputLine
	call ReadString

	; Guard against an infinite loop if input stream closes (EOF).
	cmp eax, 0
	jne ResetEmptyStreak
	inc emptyStreak
	cmp emptyStreak, MAX_EMPTY_LINES
	jae EndInputReached
	jmp ReadProgramLoop

ResetEmptyStreak:
	mov emptyStreak, 0

	; Parse and validate the line before adding it to stagingBuffer.
	INVOKE ParseInstructionLine, lineCounter, ADDR encodedDword

	cmp eax, PARSE_EMPTY
	je ReadProgramLoop
	cmp eax, PARSE_END
	je EndInputReached
	cmp eax, PARSE_ERROR
	je LineHadError

	; Reject instructions beyond the 64-instruction ProgramMemory limit.
	mov ecx, stagingCount
	cmp ecx, MEMORY_SIZE
	jae ProgramFull

	; Save valid encoded DWORD into stagingBuffer[stagingCount].
	mov eax, encodedDword
	mov stagingBuffer[ecx * 4], eax
	inc stagingCount
	inc lineCounter
	jmp ReadProgramLoop

ProgramFull:
	mov ebx, lineCounter
	mov edx, OFFSET errCapacity
	call ReportLineError
	jmp ReadProgramLoop

LineHadError:
	; Invalid lines are not staged, so ProgramMemory stays clean.
	inc lineCounter
	jmp ReadProgramLoop

EndInputReached:
	mov ecx, stagingCount
	cmp ecx, 0
	jne CommitProgram

	mov programLength, 0
	mov edx, OFFSET noInstrWarn
	call WriteString
	ret

CommitProgram:
	; Copy stagingBuffer into programBuffer using a simple indexed loop.
	; Keeping programBuffer lets Reset restore the program after clearing memory.
	xor esi, esi
	mov ecx, stagingCount
CopyStagingLoop:
	mov eax, stagingBuffer[esi * 4]
	mov programBuffer[esi * 4], eax
	inc esi
	loop CopyStagingLoop

	mov eax, stagingCount
	mov programLength, eax

	; Load the complete validated program into Memory.asm ProgramMemory.
	INVOKE LoadProgram, OFFSET programBuffer, programLength
	cmp eax, 0
	je LoadFailed

	mov edx, OFFSET loadedOkMsg
	call WriteString
	mov eax, programLength
	call WriteDec
	mov edx, OFFSET loadedOkSuffix
	call WriteString
	ret

LoadFailed:
	mov programLength, 0
	mov edx, OFFSET loadFailMsg
	call WriteString
	ret
InputAndLoadProgram ENDP

;-----------------------------------------------------------------------
; main
; Purpose : Entry point. Initializes Memory and CPU, loads the user's
;           program, and dispatches menu choices (Step, Run, Display,
;           Reset, Exit).
;-----------------------------------------------------------------------
main PROC
	INVOKE InitializeMemory
	INVOKE InitializeCPU

	mov edx, OFFSET initMsg
	call WriteString

	call InputAndLoadProgram

MainMenuLoop:
	INVOKE DisplayDashboard
	INVOKE GetUserChoice			; Returns validated choice (0-6) in EAX

	cmp eax, 0
	je HandleExit
	cmp eax, 1
	je HandleStep
	cmp eax, 2
	je HandleRun
	cmp eax, 3
	je HandleShowRegs
	cmp eax, 4
	je HandleShowMem
	cmp eax, 5
	je HandleShowProg
	cmp eax, 6
	je HandleReset
	jmp MainMenuLoop

HandleStep:
	; Execute exactly one virtual instruction; CPU.asm updates PC and IR.
	cmp programLength, 0
	je WarnNoProg
	cmp CPUHalted, 0
	jne WarnAlreadyHalted

	INVOKE ExecuteNextInstruction
	mov edx, OFFSET msgStepDone
	call WriteString
	INVOKE DisplayRegisters
	INVOKE DisplayStatus
	jmp MainMenuLoop

HandleRun:
	; Repeatedly call ExecuteNextInstruction until CPU.asm sets CPUHalted.
	cmp programLength, 0
	je WarnNoProg
	cmp CPUHalted, 0
	jne WarnAlreadyHalted

RunCycleLoop:
	INVOKE ExecuteNextInstruction
	cmp CPUHalted, 0
	je RunCycleLoop

	mov edx, OFFSET msgRunDone
	call WriteString
	INVOKE DisplayRegisters
	INVOKE DisplayStatus
	jmp MainMenuLoop

HandleShowRegs:
	INVOKE DisplayRegisters
	jmp MainMenuLoop

HandleShowMem:
	INVOKE DisplayMemory
	jmp MainMenuLoop

HandleShowProg:
	INVOKE DisplayProgram
	jmp MainMenuLoop

HandleReset:
	; InitializeMemory clears both DataMemory and ProgramMemory, so we
	; reload programBuffer to restore the user's program from the start.
	INVOKE InitializeMemory
	INVOKE InitializeCPU
	cmp programLength, 0
	je ResetEmptyProg

	INVOKE LoadProgram, OFFSET programBuffer, programLength
	cmp eax, 0
	je ResetLoadFailed
	mov edx, OFFSET msgResetDone
	call WriteString
	jmp MainMenuLoop

ResetLoadFailed:
	mov edx, OFFSET msgResetFail
	call WriteString
	jmp MainMenuLoop

ResetEmptyProg:
	mov edx, OFFSET msgResetEmpty
	call WriteString
	jmp MainMenuLoop

WarnNoProg:
	mov edx, OFFSET msgNoProgram
	call WriteString
	jmp MainMenuLoop

WarnAlreadyHalted:
	mov edx, OFFSET msgAlreadyHalt
	call WriteString
	jmp MainMenuLoop

HandleExit:
	mov edx, OFFSET msgExit
	call WriteString
	exit
main ENDP

END main
