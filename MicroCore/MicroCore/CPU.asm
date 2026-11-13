INCLUDE Irvine32.inc
INCLUDE MicroCore.inc


.data

	R0 DWORD 0
	R1 DWORD 0
	R2 DWORD 0
	R3 DWORD 0

	PC DWORD 0
	IR DWORD 0
	FLAGS DWORD 0
	HALTED DWORD 0
	
	; The 8 lines above are for Virtual CPU's registers and status variables

.code
main PROC



exit
main ENDP
end main

