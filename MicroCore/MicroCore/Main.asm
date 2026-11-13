INCLUDE Irvine32.inc
INCLUDE MicroCore.inc


.data

initMsg BYTE "MicroCore Initialized successfully.", 0

.code
main PROC

    call InitializeMemory
    call InitializeCPU

    mov edx, OFFSET initMsg
    call WriteString


    ; Load user's program here later

    ; Start dashboard/menu here later

    exit
main ENDP
end main
