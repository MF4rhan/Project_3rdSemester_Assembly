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
	jge invalidDataRead

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
	jge invalidDataWrite

	mov edx, value
	mov DataMemory[eax*4], edx

	mov eax, 1
	ret

invalidDataWrite:
	xor eax, eax
	ret

WriteDataMemory ENDP



ReadProgramMemory PROC


	ret

ReadProgramMemory ENDP



LoadProgram PROC


	ret

LoadProgram ENDP



ValidateAddress PROC
	
	mov eax, address

	cmp eax, MEMORY_SIZE
	jge invalidAddress

	mov eax, 1
	ret

invalidAddress:
	xor eax, eax
	ret

ValidateAddress ENDP


END


