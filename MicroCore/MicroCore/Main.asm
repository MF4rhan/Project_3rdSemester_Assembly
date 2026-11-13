INCLUDE Irvine32.inc
INCLUDE MicroCore.inc


.data


.code
main PROC

    call InitializeMemory
    call InitializeCPU

    ; Load user's program here later

    ; Start dashboard/menu here later

    exit
main ENDP
end main
