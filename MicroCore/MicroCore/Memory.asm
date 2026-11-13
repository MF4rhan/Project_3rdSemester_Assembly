INCLUDE Irvine32.inc
INCLUDE MicroCore.inc


.data
	DataMemory DWORD MEMORY_SIZE DUP(0)
	ProgramMemory DWORD MEMORY_SIZE DUP(0)


.code

PUBLIC DataMemory, ProgramMemory
PUBLIC InitializeMemory
PUBLIC ValidateAddress
PUBLIC ReadDataMemory, WriteDataMemory
PUBLIC ReadProgramMemory, WriteProgramMemory
PUBLIC LoadProgram

; InitializeMemory clears both memory arrays
InitializeMemory PROC
	
	mov ecx, MEMORY_SIZE
	mov edi, offset DataMemory

ClearData:
	mov DWORD PTR [edi], 0
	add edi, 4
	loop clearData

	mov ecx, MEMORY_SIZE
	mov edi, offset ProgramMemory

ClearProgram:
	mov DWORD PTR [edi], 0
	add edi, 4
	loop clearProgram

	ret

InitializeMemory ENDP



ReadDataMemory PROC STDCALL, address:DWORD

	mov eax, address

	cmp eax, MEMORY_SIZE
	jae invalidDataRead

	mov eax, DataMemory[eax*4]

	clc
	ret

invalidDataRead:
	xor eax, eax
	stc
	ret	
	
ReadDataMemory ENDP



WriteDataMemory PROC STDCALL, address:DWORD, value:DWORD

	mov eax, address
	
	cmp eax, MEMORY_SIZE
	jae invalidDataWrite

	mov edx, value
	mov DataMemory[eax*4], edx

	mov eax, 1
	ret

invalidDataWrite:
	xor eax, eax
	ret

WriteDataMemory ENDP



ReadProgramMemory PROC STDCALL, address:DWORD

	mov eax, address

	cmp eax, MEMORY_SIZE
	jge invalidDataRead
	
	mov eax, ProgramMemory[eax*4]

	clc
	ret

InvalidDataRead:
	xor eax, eax
	stc
	ret

ReadProgramMemory ENDP



WriteProgramMemory PROC STDCALL, address:DWORD, instruction:DWORD

	mov eax, address

	cmp eax, MEMORY_SIZE
	jae invalidProgramWrite

	mov edx, instruction
	mov ProgramMemory[eax*4], edx

	mov eax, 1
	ret

invalidProgramWrite:
	xor eax, eax
	ret

WriteProgramMemory ENDP



LoadProgram PROC STDCALL, pProgram:PTR DWORD, instructionCount:DWORD

	push esi
	push edi

	mov eax, instructionCount

	cmp eax, MEMORY_SIZE
	ja loadProgramFailed

	cmp eax, 0
	je clearProgramOnly

	cmp pProgram, 0
	je loadProgramFailed

ClearProgramOnly:

	cld
	mov edi, OFFSET ProgramMemory
	mov ecx, MEMORY_SIZE
	xor eax, eax
	rep stosd   ; store string doubleword, writes eax value to memory location pointed by edi, rep repeats ecx times

	mov esi, pProgram
	mov edi, OFFSET ProgramMemory
	mov ecx, instructionCount
	rep movsd   ; MOVSD copies one DWORD from the memory location pointed to by ESI into the memory location pointed to by EDI.

	mov eax, 1
	jmp LoadProgramDone

LoadProgramFailed:
	xor	eax, eax

LoadProgramDone:
	pop edi
	pop esi
	ret

LoadProgram ENDP



ValidateAddress PROC STDCALL, address:DWORD
	
	mov eax, address

	cmp eax, MEMORY_SIZE
	jae invalidAddress

	mov eax, 1
	ret

invalidAddress:
	xor eax, eax
	ret

ValidateAddress ENDP


END


