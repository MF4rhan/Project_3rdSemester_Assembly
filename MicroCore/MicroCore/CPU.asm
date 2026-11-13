INCLUDE Irvine32.inc
INCLUDE MicroCore.inc


.data

	R0 DWORD 0
	R1 DWORD 0
	R2 DWORD 0
	R3 DWORD 0

	PC DWORD 0
	IR DWORD 0
	CPUFlags DWORD 0
	CPUHalted DWORD 0
	
	; The 8 lines above are for Virtual CPU's registers and status variables

.code

PUBLIC InitializeCPU

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
END

