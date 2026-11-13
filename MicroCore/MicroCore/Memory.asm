INCLUDE Irvine32.inc
INCLUDE MicroCore.inc


.data
	DataMemory DWORD MEMORY_SIZE DUP(0)
	ProgramMemory DWORD MEMORY_SIZE DUP(0)


.code

PUBLIC InitializeMemory

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

END


