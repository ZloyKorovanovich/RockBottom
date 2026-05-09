; - all important data should be aligned to 128 byte for efficient copy in xmm0-7 registers, its also easier to track
; - code pointers are redundant, its easy to identify them in runtime

; in long mode paging is necessary, so page tables need to be active, and in the beginning they are in boot services data
; that means its not free memory (boot services data), if you overwrite it you are fucked.

bits 64
default rel

; rtc port (time)
PORT_RTC_OUT                          equ 0x70 ; time port out
PORT_RTC_IN                           equ 0x71 ; time port in
PORT_RTC_SECONDS                      equ 0x00 ; seconds request
PORT_RTC_MINUTES                      equ 0x02 ; minutes request
PORT_RTC_HOURS                        equ 0x04 ; hours request
PORT_RTC_WEEK_DAY                     equ 0x06 ; week day request
PORT_RTC_MONTH_DAY                    equ 0x07 ; month day request
PORT_RTC_MONTH                        equ 0x08 ; month request
PORT_RTC_YEAR                         equ 0x09 ; year request

; memory types values stored in type of memory_descriptor_t
MEMORY_TYPE_RESERVED                  equ 0x00 ; do not touch
MEMORY_TYPE_LOADER_CODE               equ 0x01 ; use as you wish after ExitBootServices
MEMORY_TYPE_LOADER_DATA               equ 0x02 ; use as you wish after ExitBootServices
MEMORY_TYPE_BOOT_SERVICES_CODE        equ 0x03 ; use as you wish after ExitBootServices
MEMORY_TYPE_BOOT_SERVICES_DATA        equ 0x04 ; use as you wish after ExitBootServices
MEMORY_TYPE_RUNTIME_SERVICES_CODE     equ 0x05 ; do not touch
MEMORY_TYPE_RUNTIME_SERVICES_DATA     equ 0x06 ; do not touch
MEMORY_TYPE_CONVENTIONAL_MEMORY       equ 0x07 ; use as you wish, best memory types
MEMORY_TYPE_UNUSABLE_MEMORY           equ 0x08 ; bad memory with deffects, do not touch
MEMORY_TYPE_ACPI_RECLAIM_MEMORY       equ 0x09 ; use after copying data about HW
MEMORY_TYPE_ACPI_NVS_MEMORY           equ 0x0A ; do not touch
MEMORY_TYPE_IO_MAPPED_MEMORY          equ 0x0B ; do not touch
MEMORY_TYPE_IO_MAPPED_PORT_MEMORY     equ 0x0C ; do not touch
MEMORY_TYPE_PAL_CODE_MEMORY           equ 0x0D ; do not touch, paltform-specific 

; bit flags stored in attribues of memory_descriptor_t
MEMORY_ATTRIBUTES_NONE                equ 0x0000000000000000 ; empty
MEMORY_ATTRIBUTE_UNCACHEABLE          equ 0x0000000000000001 ; device memory
MEMORY_ATTRIBUTE_WRITE_COMBINING      equ 0x0000000000000002 ; frame buffers
MEMORY_ATTRIBUTE_WRITE_THROUGH_CACHE  equ 0x0000000000000004
MEMORY_ATTRIBUTE_WRITE_BACK_CACHE     equ 0x0000000000000008 ; normal RAM
MEMORY_ATTRIBUTE_UNCACHEABLE_EXPORTED equ 0x0000000000000010
MEMORY_ATTRIBUTE_WRITE_PROTECT        equ 0x0000000000001000 
MEMORY_ATTRIBUTE_READ_PROTECT         equ 0x0000000000002000
MEMORY_ATTRIBUTE_EXECUTE_PROTECT      equ 0x0000000000005000
MEMORY_ATTRIBUTE_NON_VOLATILE         equ 0x0000000000008000 ; persistent memory
MEMORY_ATTRIBUTE_MORE_RELIABLE        equ 0x0000000000010000
MEMORY_ATTRIBUTE_READ_ONLY            equ 0x0000000000020000
MEMORY_ATTRIBUTE_RUNTIME              equ 0x8000000000000000

%define MEMORY_ATTRIBUTE_UNSUITABLE_MASK  (MEMORY_ATTRIBUTE_RUNTIME | MEMORY_ATTRIBUTE_READ_ONLY | MEMORY_ATTRIBUTE_NON_VOLATILE)

; frame buffer modes stollen from EFI
FRAME_BUFFER_MODE_RGB_32              equ 0x00
FRAME_BUFFER_MODE_BGR_32              equ 0x01
FRAME_BUFFER_MODE_BIT_MASK            equ 0x02

; list of interrupts
EXCEPTION_INT_DIVIDE_BY_ZERO          equ 0x00 ; div, idiv, aam instructions
EXCEPTION_DEBUG                       equ 0x01 ; instruction and data accesses
INTERRUPT_NON_MASKABLE                equ 0x02 ; external NMI signal
EXCEPTION_BREAKPOINT                  equ 0x03 ; int3 instruction
EXCEPTION_OVERFLOW                    equ 0x04 ; into instruction
EXCEPTION_BOUND_RANGE                 equ 0x05 ; bound intruction
EXCEPTION_INVALID_OPCODE              equ 0x06 ; invalid instructions
EXCEPTION_DEVICE_NOT_AVAILABLE        equ 0x07 ; x87 instructions
EXCEPTION_DOUBLE_FAULT                equ 0x08 ; exception during the handling of another exception or interrupt
EXCEPTION_RESERVED_0x09               equ 0x09 ; (reserved)
EXCEPTION_INVALID_TSS                 equ 0x0A ; task-state segment access and task switch
EXCEPTION_SEGMENT_NOT_PRESENT         equ 0x0B ; segment register loads
EXCEPTION_STACK                       equ 0x0C ; ss register loads and stack references
EXCEPTION_GENERAL_PROTECTION          equ 0x0D ; memory accesses and protection checks
EXCEPTION_PAGE_FAULT                  equ 0x0E ; memory accesses when paging enabled
INTERRUPT_RESERVED_0x0F               equ 0x0F ; (reserved)
EXCEPTION_X87_FLOATING_POINT          equ 0x10 ; x87 floating-point instructions
EXCEPTION_ALIGNMENT_CHECK             equ 0x11 ; misaligned memory accesses
EXCEPTION_MACHINE_CHECK               equ 0x12 ; model specific
EXCEPTION_SIMD_FLOATING_POINT         equ 0x13 ; sse floating-point instructions
EXCEPTION_RESERVED_0x14               equ 0x14 ; (reserved)
EXCEPTION_CONTROL_PROTECTION          equ 0x15 ; ret/iret or other control transfer

; cpr0 register flags (memory table translations) (AMD 64 vol.2 page 191)
CPR0_PG                               equ 0x80000000 ; page-translation flag
CPR0_PAE                              equ 0x00000010 ; physical-address extension flag
CPR0_PSE                              equ 0x00000008 ; page-size extension flag
CPR0_PS                               equ 0x00000040 ; page-directory page size flag

INVALID_ADDRESS                       equ 0xFFFFFFFFFFFFFFFF
ERROR_DEBUG                           equ 0x0000000000000001
ERROR_TOO_SMALL_DATA_SIZE             equ 0x0000000000000002
ERROR_NO_SPACE_FOR_CORE               equ 0x0000000000000003

struc memory_descriptor_t
    .type:             resq 1
    .size:             resq 1 ; in 4KB pages
    .attributes:       resq 1
    .address:          resq 1
endstruc

struc core_data_t
    .frame_buffer:     resq 1
    .descriptor_count: resq 1
    .frame_x:          resq 1
    .frame_y:          resq 1
    .frame_size:       resq 1
    .frame_line:       resq 1
endstruc

%define STACK_SIZE (0x10000)
%define CODE_SIZE  ((core_end - core_entry + 0x0FFF) & 0xFFFFFFFFFFFFF000)
%define DATA_SIZE  (0x10000)

%define CORE_SIZE  (STACK_SIZE + CODE_SIZE + DATA_SIZE)

; %1 = reg val
; %2 = reg min
; %3 = reg max
%macro clamp 3
    cmp   %1, %2
    cmovb %1, %2
    cmp   %1, %3
    cmova %1, %3
%endmacro

; =======================================================
;   STAGE 0:
; =======================================================
; Only registers are available for use, no stack here.
; All memory from bs considered invalid except for core_buffer passed, 
; the job of program is to relocate core code, 
; copy memory descriptors and create stack for stage 1.

; core buffer contains [core_data_t, memory_descriptors]
; rcx = core_buffer
; r15 used for error codes
core_entry:
    ; r14 = core_buffer
    mov r14, rcx

    ; rax = descriptors_i
    ; rbx = descriptors_end
    ; r10 = descriptors_size
    lea rax, [r14 + core_data_t_size]
    mov rbx, [r14 + core_data_t.descriptor_count]
    shl rbx, 5
    mov r10, rbx
    add rbx, rax

    mov r15, ERROR_TOO_SMALL_DATA_SIZE
    cmp r10, DATA_SIZE
    ja critical_fail

    ; r8  = core_size
    ; rcx = best_descriptor
    ; rdx = best_descriptor_type
    ; rsi = best_descriptor_size
    ; rdi = best_descriptor_attributes
    mov r8, CORE_SIZE / 0x1000
    mov rcx, INVALID_ADDRESS
    xor rdx, rdx
    xor rsi, rsi
    xor rdi, rdi

    ; r9  = descriptors_i_type
    ; r10 = descriptors_i_size
    ; r11 = descriptors_i_attributes
    ; r12 = attributes_mask
    ; r13 = attributes_cmp_mask
    mov r12, MEMORY_ATTRIBUTE_UNSUITABLE_MASK
    .find_mem_loop:
        cmp rax, rbx
        je .find_mem_loop_end

        ; r9  = descriptors_i_type
        ; r10 = descriptors_i_size
        ; r11 = descriptors_i_attributes
        mov r9 , [rax + memory_descriptor_t.type      ]
        mov r10, [rax + memory_descriptor_t.size      ]
        mov r11, [rax + memory_descriptor_t.attributes]

        ; descriptors_i_size < core_size
        cmp r10, r8
        jb .find_mem_skip

        ; check descriptors_i_type
        cmp r9, MEMORY_TYPE_CONVENTIONAL_MEMORY
        je .find_mem_check_attribs        
        cmp r9, MEMORY_TYPE_BOOT_SERVICES_CODE
        je .find_mem_check_attribs
        cmp r9, MEMORY_TYPE_LOADER_CODE
        je .find_mem_check_attribs
        jmp .find_mem_skip

        .find_mem_check_attribs:
        test r11, r12
        jnz .find_mem_skip

        .find_mem_compare:
        mov  r13, MEMORY_ATTRIBUTE_WRITE_BACK_CACHE
        test r13, rdi
        jnz .find_mem_skip
        test r13, r11
        jnz .find_mem_found

        mov  r13, MEMORY_ATTRIBUTE_MORE_RELIABLE
        test r13, rdi
        jnz .find_mem_skip
        test r13, r11
        jnz .find_mem_found

        cmp r10, rsi
        jb .find_mem_skip
        
        .find_mem_found:
        mov rcx, rax
        mov rdx, r9
        mov rsi, r10
        mov rdi, r11

        .find_mem_skip:
        add rax, memory_descriptor_t_size
        jmp .find_mem_loop
    .find_mem_loop_end:

    mov r15, ERROR_NO_SPACE_FOR_CORE
    cmp rcx, INVALID_ADDRESS
    je critical_fail

    ; r13 = core_buffer
    ; rax = core_buffer_i
    ; rbx = stack_end
    ; rcx = code_end
    ; rdx = data_end
    mov r13, [rcx + memory_descriptor_t.address]
    mov rax, r13
    lea rbx, [r13 + STACK_SIZE]
    lea rcx, [r13 + STACK_SIZE + CODE_SIZE]
    lea rdx, [r13 + STACK_SIZE + CODE_SIZE + DATA_SIZE]

    ; zero stack
    ; xmm0 = 0
    xorps xmm0, xmm0
    .zero_stack_loop:
        cmp rax, rbx
        je .zero_stack_loop_end

        movdqa [rax], xmm0

        add rax, 16
        jmp .zero_stack_loop
    .zero_stack_loop_end:

    ; copy code
    ; rsi = src_code_i
    ; rdi = src_code_end
    lea rsi, [rel core_main]
    lea rdi, [rel core_end ]
    ; xmm0
    .copy_code_loop:
        cmp rsi, rdi
        je .copy_code_loop_end

        movdqa xmm0, [rsi]
        movdqa [rax], xmm0
        
        add rax, 16
        add rsi, 16
        jmp .copy_code_loop
    .copy_code_loop_end:

    ; fill rest of code with invalid ops
    ; r8   = invalid_opcodes_64
    ; xmm0 = invalid_opcodes_128
    mov r8, 0x0B0F0B0F0B0F0B0F
    movq xmm0, r8
    punpcklqdq xmm0, xmm0
    .fill_code_loop:
        cmp rax, rcx
        je .fill_code_loop_end

        movdqa [rax], xmm0

        add rax, 16
        jmp .fill_code_loop
    .fill_code_loop_end:

    ; first copy core data, then descriptors
    ; rsi = core_data
    mov rsi, r14

    ; xmm0, xmm1, xmm2
    movdqa xmm0, [rsi + 0 ]
    movdqa xmm1, [rsi + 16]
    movdqa xmm2, [rsi + 32]
    movdqa [rax + 0 ], xmm0
    movdqa [rax + 16], xmm1
    movdqa [rax + 32], xmm2

    add rsi, 48
    add rax, 48

    ; copy descriptors
    ; rsi = src_descriptors_i
    ; rdi = src_descriptors_end
    mov rdi, [r14 + core_data_t.descriptor_count]
    shl rdi, 5
    add rdi, rsi
    ; xmm0 
    .copy_dscr_loop:
        cmp rsi, rdi
        je .copy_dscr_loop_end

        movdqa xmm0, [rsi]
        movdqa [rax], xmm0

        add rax, 16
        add rsi, 16
        jmp .copy_dscr_loop
    .copy_dscr_loop_end:

    ; zero rest of data
    ; xmm0 = 0
    xorps xmm0, xmm0
    .fill_data_loop:
        cmp rax, rdx
        je .fill_data_loop_end

        movdqa [rax], xmm0

        add rax, 16
        jmp .fill_data_loop
    .fill_data_loop_end:

    
    ; rbp = stack_top
    ; rsp = stack_top
    ; rax = core_address
    ; rcx = core_buffer
    lea rbp, [r13 + STACK_SIZE - 16]
    lea rsp, [r13 + STACK_SIZE - 16]
    lea rax, [r13 + STACK_SIZE     ]
    mov rcx, r13

    xor rbx, rbx
    xor rdx, rdx
    xor rsi, rsi
    xor rdi, rdi
    xor r8 , r8
    xor r9 , r9
    xor r10, r10
    xor r11, r11
    xor r12, r12
    xor r13, r13
    xor r14, r14
    xor r15, r15

    xorps xmm0, xmm0
    xorps xmm1, xmm1
    xorps xmm2, xmm2
    xorps xmm3, xmm3
    xorps xmm4, xmm4
    xorps xmm5, xmm5
    xorps xmm6, xmm6
    xorps xmm7, xmm7

    ; jump to core_main
    jmp rax

; r15 error_code
critical_fail:
    mov [abs INVALID_ADDRESS], r15

; =======================================================
;   STAGE 1:
; =======================================================
; Stack is available, memory is valid, layout is:
; [STACK, CODE, DATA]

align 16
core_main:
    push rbp
    mov rbp, rsp
    sub rsp, 56

    ; rax        = core_data
    ; [rbp - 16] = core_buffer
    ; [rbp - 24] = core_data
    ; [rbp - 32] = memory_list
    lea rax, [rcx + STACK_SIZE + CODE_SIZE]
    mov [rbp - 16], rcx
    mov [rbp - 24], rax
    mov [rbp - 32], qword INVALID_ADDRESS

    ; rcx = core_data
    ; edx = color
    mov rcx, [rbp - 24]
    mov edx, 0x00000000
    call clear_screen

    mov rcx, [rbp - 24]
    mov rdx, [rbp - 16]
    call init_memory

    ; [rbp - 32] = memory_list
    mov [rbp - 32], rax

    cmp rax, INVALID_ADDRESS
    je .f_you

    mov rcx, [rbp - 32]
    call alloc_physical
    cmp rax, INVALID_ADDRESS
    je .f_you

    ; [rbp - 32] = memory_list
    mov [rbp - 32], rcx

    mov rcx, [rbp - 32]
    mov rdx, rax
    call free_physical

    mov rcx, [rbp - 24]
    mov rdx, rax
    mov r8 , 600
    call print_memory_list

    ; mov rcx, [rbp - 24]
    ; lea rdx, [rel welcome_message]
    ; call print_str

    .loop:
        nop
        jmp .loop

    .f_you:
        mov rcx, [rbp - 24]
        lea rdx, [rel .shitty_message]
        call print_str
        jmp .loop

    .shitty_message:
        db "good luck, you are fucked",0

; =======================================================
;   MEMORY ALLOCATOR
; =======================================================

; rcx = core_data
; rdx = core_base_address
; rax = pages_list (return)
init_memory:
    lea rax, [rcx + core_data_t_size            ]
    mov rbx, [rcx + core_data_t.descriptor_count]
    shl rbx, 5
    add rbx, rax

    ; rcx = core_base
    ; rdx = core_limit
    mov rcx, rdx
    add rdx, CORE_SIZE

    .descriptor_loop:
        cmp rax, rbx
        je .descriptor_loop_end

        ; r8  = memory_type
        ; r9  = memory_page_count
        ; r10 = memory_attributes
        ; r11 = memory_address
        mov r8,  [rax + memory_descriptor_t.type      ] 
        mov r9,  [rax + memory_descriptor_t.size      ]
        mov r10, [rax + memory_descriptor_t.attributes]
        mov r11, [rax + memory_descriptor_t.address   ]

        cmp r8, MEMORY_TYPE_CONVENTIONAL_MEMORY
        je .descriptor_loop_attributes
        cmp r8, MEMORY_TYPE_BOOT_SERVICES_CODE
        je .descriptor_loop_attributes
        cmp r8, MEMORY_TYPE_LOADER_CODE
        je .descriptor_loop_attributes
        cmp r8, MEMORY_TYPE_LOADER_DATA
        je .descriptor_loop_attributes
        jmp .descriptor_loop_skip

        .descriptor_loop_attributes:
        ; r12 = unsuitable_attributes
        mov  r12, MEMORY_ATTRIBUTE_UNSUITABLE_MASK
        test r12, r10
        jnz .descriptor_loop_skip

        ; r12  = previous_page_ptr
        ; r9   = page_count
        ; rsi  = page_mem_i
        ; xmm0 = 0
        mov   r12, INVALID_ADDRESS
        mov   rsi, r11
        xorps xmm0, xmm0
        .page_loop:
            test r9, r9
            jz .page_loop_end

            ; check core intersection
            cmp rsi, rcx
            jb .fill_page
            cmp rsi, rdx
            jae .fill_page

            add rsi, 4096
            dec r9
            jmp .page_loop

            .fill_page:
            mov [rsi + 0], r12
            mov [rsi + 8], qword 0
            mov r12, rsi

            ; rsi = page_mem_i
            ; rdi = page_mem_end
            lea rdi, [rsi + 4096]
            add rsi, 16
            
            .zero_loop:
                cmp rsi, rdi
                je .zero_loop_end

                movdqa [rsi], xmm0

                add rsi, 16
                jmp .zero_loop
            .zero_loop_end:

            dec r9
            jmp .page_loop
        .page_loop_end:

        .descriptor_loop_skip:
        add rax, 32
        jmp .descriptor_loop
    .descriptor_loop_end:

    mov rax, r12
    ret

; rcx = core_data
; rdx = memory_list
; r8  = stack_buffer_size (16 bytes aligned)
print_memory_list:
    push rbp
    mov rbp, rsp
    sub rsp, r8
    sub rsp, 8

    ; rax = str_begin
    ; rbx = str_end
    ; rcx = str_i
    ; rsi = memory_list
    ; r15 = core_data
    lea rax, [rsp + 8 ]
    lea rbx, [rbp - 24]
    mov rsi, rdx
    mov r15, rcx    
    mov rcx, rax    


    .loop: 
        cmp rsi, INVALID_ADDRESS
        je .loop_end
        cmp rcx, rbx
        jae .loop_end

        
        mov rdx, rsi
        call qw_to_str         
        mov [rcx + 0], byte 13
        mov [rcx + 1], byte 0
        inc rcx

        mov rsi, [rsi]
        jmp .loop
    .loop_end:
    
    mov rcx, r15
    mov rdx, rax
    call print_str
    
    mov rsp, rbp
    pop rbp
    ret

; inout rcx = memory_list
; out   rax = allocated_page
alloc_physical:
    mov rax, rcx
    cmp rcx, INVALID_ADDRESS
    je .fail
    test rcx, 0x0000000000000FFF
    jnz .fail

    mov rcx, [rax]
    mov [rax + 0], qword 0
    mov [rax + 8], qword 0
    ret

    .fail:
    mov rax, INVALID_ADDRESS
    ret

; inout rcx = memory_list
; in    rdx = page
; r8, rdx
free_physical:
    test rdx, 0x0000000000000FFF
    jnz .fail

    ; [page + 0] = previous_page
    ; [page + 8] = qw_0
    ; rcx        = page (new memory_list)
    mov [rdx + 0], rcx
    mov [rdx + 8], qword 0
    mov rcx, rdx

    ; rdx  = page_i (after [page + 0] and [page + 8] qwords)
    ; r8   = page_end
    ; xmm0 = oct_0
    lea r8 , [rdx + 4096]
    add rdx, 16
    xorps xmm0, xmm0
    .zero_loop:
        cmp rdx, r8
        je .zero_loop_end

        movdqa [rdx], xmm0
        
        add rdx, 16
        jmp .zero_loop
    .zero_loop_end:

    .fail:
    ret

; =======================================================
;   STRING OUTPUT
; ======================================================= 

; rcx = core_data
; edx = color
; rax, rbx
clear_screen:
    mov rax, [rcx + core_data_t.frame_buffer]
    mov rbx, [rcx + core_data_t.frame_size  ]
    add rbx, rax

    .fill_loop:
        cmp rax, rbx
        je .fill_loop_end

        mov [rax], edx

        add rax, 4
        jmp .fill_loop
    .fill_loop_end:
    ret

; rcx = core_data
; rax, rbx, rcx, rdx, rsi, rdi, r8-r14
print_abc:
    ; rax = frame_buffer
    ; rbx = frame_line_size (in bytes)
    ; rcx = resolution_x
    ; rdx = resolution_y
    mov rax, [rcx + core_data_t.frame_buffer]
    mov rbx, [rcx + core_data_t.frame_line  ]
    mov rdx, [rcx + core_data_t.frame_y     ]
    mov rcx, [rcx + core_data_t.frame_x     ]
    shl rbx, 2

    ; rsi = characters_i
    ; rdi = characters_end
    lea rsi, [rel characters ]
    lea rdi, [rsi + 0x60 * 32]

    ; r8   = x--
    ; r9   = y--
    ; r10  = character
    ; r11  = bit
    ; r12d = off_color
    ; r13d = on_color
    mov r9  , rdx
    mov r13d, 0x0000FF11
    .loop_y:
        cmp r9, 16
        jb .loop_y_end

        ; r8 = x--
        mov r8, rcx 
        .loop_x:
            cmp r8, 16
            jb .loop_x_end

            cmp rsi, rdi
            je .loop_y_end

            %rep 4
                mov r10, [rsi]
                mov r11, 0x8000000000000000

                %rep 4
                    %rep 16
                        mov r12d, [rax]
                        test r10, r11
                        cmovnz r12d, r13d
                        mov [rax], r12d
                        shr r11, 1
                        add rax, 4
                    %endrep
                    
                    add rax, rbx
                    sub rax, 64
                %endrep

                add rsi, 8
            %endrep

            mov r14, rbx
            shl r14, 4
            sub rax, r14
            add rax, 64

            sub r8, 16
            jmp .loop_x
        .loop_x_end:

        mov r14, rbx
        shl r14, 4
        sub r14, rbx
        shl r8 , 2
        add r14, r8
        add rax, r14

        sub r9, 16
        jmp .loop_y
    .loop_y_end:

    ret

; rcx = dst
; rdx = src
; r8
str_to_str:
    .cpy_loop:
        mov r8b, [rdx]
        mov [rcx], r8b

        test r8b, r8b
        jz .cpy_loop_end

        inc rcx
        inc rdx
        jmp .cpy_loop
    .cpy_loop_end:
    ret

; rcx = dst
; rdx = qw
; r8, r9
qw_to_str:
    add rcx, 15 

    %rep 16
        mov r8, rdx
        and r8, 0xF
        lea r9, [r8 + 'A' - 10]
        add r8, '0'
        cmp r8, '9'
        cmova r8, r9

        mov [rcx], r8b

        shr rdx, 4
        dec rcx
    %endrep

    ; 16 + 1 extra shift in the end
    add rcx, 17
    mov [rcx], byte 0
    ret

; rcx = core_data
; rdx = string
print_str:
    ; rax = frame_buffer_i
    ; rbx = frame_line_size
    ; rsi = resolution_x - 16
    ; rdi = resolution_y - 16
    mov rax, [rcx + core_data_t.frame_buffer]
    mov rbx, [rcx + core_data_t.frame_line  ]
    mov rsi, [rcx + core_data_t.frame_x     ]
    mov rdi, [rcx + core_data_t.frame_y     ]
    sub rsi, 16
    sub rdi, 16
    shl rbx, 2

    ; r15 = character_masks
    ; r8  = x
    ; r9  = y
    lea r15, [rel characters]
    xor r8, r8
    xor r9, r9

    .str_loop:
        ; r10 = char_code
        xor r10 , r10
        mov r10b, [rdx]
        inc rdx

        ; r10 == \0
        test r10, r10
        jz .str_loop_end
        ; r10 == \n
        cmp r10, 13 
        je .move_down

        ; if invalid ascii print ' '
        ; r11 = 0
        ; r10 = char_mask_i
        xor r11, r11
        sub r10, 0x20
        cmovc r10, r11
        cmp r10, 0x7F - 0x20
        cmova r10, r11
        shl r10, 5

        .render_glyph:
            ; rcx = pixel_i
            mov rcx, rax
            ; for each qword
            %rep 4
                ; r11 = char_mask
                ; r12 = bit_mask
                mov r11, [r15 + r10]
                mov r12, 0x8000000000000000
                add r10, 8

                ; for each row
                %rep 4
                    ; for each pixel
                    %rep 16
                        mov r13d, 0x00000000
                        mov r14d, 0x0000FF00

                        test r11, r12
                        cmovnz r13d, r14d
                        mov [rcx], r13d
                        shr r12, 1
                        add rcx, 4
                    %endrep

                    add rcx, rbx
                    sub rcx, 64
                %endrep
            %endrep
        .render_glyph_end:

        .move_next:
        add r8, 16
        cmp r8, rsi
        jb .move_right

        add r9, 16
        cmp r9, rdi
        jae .str_loop_end
        
        sub r8, 16
        .move_down:
        xor r10, r10
        mov r11, r8
        shl r11, 2
        lea r10, [r10 + rbx * 8]
        lea r10, [r10 + rbx * 8]
        ; sub r10 rbx for no space in between lines
        add r10, rbx ; 2 pixel spacing between lines
        sub r10, r11

        add rax, r10
        xor r8, r8
        jmp .str_loop

        .move_right:
        add rax, 64
        jmp .str_loop

    .str_loop_end:
    ret

welcome_message:
    db "hello! welcome to the ROCK BOTTOM", 13
    db "here is the manual:{", 13
    db "   f@$k you!", 13
    db "       f#%k you!", 13
    db "           f&*k you!", 13
    db "}", 0
    
align 16
; code E [0x20; 0x7F]
; 16x16 grid requires 256 bits (32 bytes) per glyph.
characters:
    dq 0x0000000000000000
    dq 0x0000000000000000
    dq 0x0000000000000000
    dq 0x0000000000000000

    dq 0x0000000001800180
    dq 0x0180018001800180
    dq 0x0180018000000000
    dq 0x0180018000000000

    dq 0x0000066006600660
    dq 0x0660066006600000
    dq 0x0000000000000000
    dq 0x0000000000000000

    dq 0x0000066006600660
    dq 0x06601FF81FF80660
    dq 0x06601FF81FF80660
    dq 0x0660066006600000

    dq 0x00000180018007F8
    dq 0x07F81980198007E0
    dq 0x07E0019801981FE0
    dq 0x1FE0018001800000

    dq 0x00001E181E181E60
    dq 0x1E60018001800600
    dq 0x060019E019E001E0
    dq 0x01E0000000000000

    dq 0x0000078007801860
    dq 0x1860198019800600
    dq 0x0600199819981860
    dq 0x1860079807980000

    dq 0x0000018001800180
    dq 0x0180060006000000
    dq 0x0000000000000000
    dq 0x0000000000000000

    dq 0x0000006000600180
    dq 0x0180060006000600
    dq 0x0600060006000180
    dq 0x0180006000600000

    dq 0x0000060006000180
    dq 0x0180006000600060
    dq 0x0060006000600180
    dq 0x0180060006000000

    dq 0x0000000000000180
    dq 0x01801998199807E0
    dq 0x07E0199819980180
    dq 0x0180000000000000

    dq 0x0000000000000180
    dq 0x0180018001801FF8
    dq 0x1FF8018001800180
    dq 0x0180000000000000

    dq 0x0000000000000000
    dq 0x0000000000000000
    dq 0x0000018001800180
    dq 0x0180060006000000

    dq 0x0000000000000000
    dq 0x0000000000001FF8
    dq 0x1FF8000000000000
    dq 0x0000000000000000

    dq 0x0000000000000000
    dq 0x0000000000000000
    dq 0x0000000000000180
    dq 0x0180018001800000

    dq 0x0000001800180060
    dq 0x0060018001800600
    dq 0x0600180018000000
    dq 0x0000000000000000

    dq 0x000007E007E01818
    dq 0x1818187818781998
    dq 0x19981E181E181818
    dq 0x181807E007E00000

    dq 0x0000018001800780
    dq 0x0780018001800180
    dq 0x0180018001800180
    dq 0x018007E007E00000

    dq 0x000007E007E01818
    dq 0x1818001800180060
    dq 0x0060018001800600
    dq 0x06001FF81FF80000

    dq 0x00001FE01FE00018
    dq 0x00180018001807E0
    dq 0x07E0001800180018
    dq 0x00181FE01FE00000

    dq 0x00000060006001E0
    dq 0x01E0066006601860
    dq 0x18601FF81FF80060
    dq 0x0060006000600000

    dq 0x00001FF81FF81800
    dq 0x1800180018001FE0
    dq 0x1FE0001800180018
    dq 0x00181FE01FE00000

    dq 0x000007E007E01800
    dq 0x1800180018001FE0
    dq 0x1FE0181818181818
    dq 0x181807E007E00000

    dq 0x00001FF81FF80018
    dq 0x0018006000600180
    dq 0x0180060006000600
    dq 0x0600060006000000

    dq 0x000007E007E01818
    dq 0x18181818181807E0
    dq 0x07E0181818181818
    dq 0x181807E007E00000

    dq 0x000007E007E01818
    dq 0x18181818181807F8
    dq 0x07F8001800180018
    dq 0x001807E007E00000

    dq 0x0000000000000180
    dq 0x0180018001800000
    dq 0x0000018001800180
    dq 0x0180000000000000

    dq 0x0000000000000180
    dq 0x0180018001800000
    dq 0x0000018001800180
    dq 0x0180060006000000

    dq 0x0000006000600180
    dq 0x0180060006001800
    dq 0x1800060006000180
    dq 0x0180006000600000

    dq 0x0000000000000000
    dq 0x00001FF81FF80000
    dq 0x00001FF81FF80000
    dq 0x0000000000000000

    dq 0x0000060006000180
    dq 0x0180006000600018
    dq 0x0018006000600180
    dq 0x0180060006000000

    dq 0x000007E007E01818
    dq 0x1818001800180060
    dq 0x0060018001800000
    dq 0x0000018001800000

    dq 0x000007E007E01818
    dq 0x181819F819F81998
    dq 0x199819F819F81800
    dq 0x180007E007E00000

    dq 0x000007E007E01818
    dq 0x1818181818181FF8
    dq 0x1FF8181818181818
    dq 0x1818181818180000

    dq 0x00001FE01FE01818
    dq 0x1818181818181FE0
    dq 0x1FE0181818181818
    dq 0x18181FE01FE00000

    dq 0x000007E007E01818
    dq 0x1818180018001800
    dq 0x1800180018001818
    dq 0x181807E007E00000

    dq 0x00001FE01FE01818
    dq 0x1818181818181818
    dq 0x1818181818181818
    dq 0x18181FE01FE00000

    dq 0x00001FF81FF81800
    dq 0x1800180018001FE0
    dq 0x1FE0180018001800
    dq 0x18001FF81FF80000

    dq 0x00001FF81FF81800
    dq 0x1800180018001FE0
    dq 0x1FE0180018001800
    dq 0x1800180018000000

    dq 0x000007E007E01818
    dq 0x18181800180019F8
    dq 0x19F8181818181818
    dq 0x181807E007E00000

    dq 0x0000181818181818
    dq 0x1818181818181FF8
    dq 0x1FF8181818181818
    dq 0x1818181818180000

    dq 0x000007E007E00180
    dq 0x0180018001800180
    dq 0x0180018001800180
    dq 0x018007E007E00000

    dq 0x000001F801F80060
    dq 0x0060006000600060
    dq 0x0060006000601860
    dq 0x1860078007800000

    dq 0x0000181818181860
    dq 0x1860198019801E00
    dq 0x1E00198019801860
    dq 0x1860181818180000

    dq 0x0000180018001800
    dq 0x1800180018001800
    dq 0x1800180018001800
    dq 0x18001FF81FF80000

    dq 0x0000181818181E78
    dq 0x1E78199819981998
    dq 0x1998181818181818
    dq 0x1818181818180000

    dq 0x0000181818181E18
    dq 0x1E18199819981878
    dq 0x1878181818181818
    dq 0x1818181818180000

    dq 0x000007E007E01818
    dq 0x1818181818181818
    dq 0x1818181818181818
    dq 0x181807E007E00000

    dq 0x00001FE01FE01818
    dq 0x1818181818181FE0
    dq 0x1FE0180018001800
    dq 0x1800180018000000

    dq 0x000007E007E01818
    dq 0x1818181818181818
    dq 0x1818199819981860
    dq 0x1860079807980000

    dq 0x00001FE01FE01818
    dq 0x1818181818181FE0
    dq 0x1FE0198019801860
    dq 0x1860181818180000

    dq 0x000007F807F81800
    dq 0x18001800180007E0
    dq 0x07E0001800180018
    dq 0x00181FE01FE00000

    dq 0x00001FF81FF80180
    dq 0x0180018001800180
    dq 0x0180018001800180
    dq 0x0180018001800000

    dq 0x0000181818181818
    dq 0x1818181818181818
    dq 0x1818181818181818
    dq 0x181807E007E00000

    dq 0x0000181818181818
    dq 0x1818181818181818
    dq 0x1818181818180660
    dq 0x0660018001800000

    dq 0x0000181818181818
    dq 0x1818181818181998
    dq 0x1998199819981998
    dq 0x1998066006600000

    dq 0x0000181818181818
    dq 0x1818066006600180
    dq 0x0180066006601818
    dq 0x1818181818180000

    dq 0x0000181818181818
    dq 0x1818066006600180
    dq 0x0180018001800180
    dq 0x0180018001800000

    dq 0x00001FF81FF80018
    dq 0x0018006000600180
    dq 0x0180060006001800
    dq 0x18001FF81FF80000

    dq 0x000007E007E00600
    dq 0x0600060006000600
    dq 0x0600060006000600
    dq 0x060007E007E00000

    dq 0x0000180018000600
    dq 0x0600018001800060
    dq 0x0060001800180000
    dq 0x0000000000000000

    dq 0x000007E007E00060
    dq 0x0060006000600060
    dq 0x0060006000600060
    dq 0x006007E007E00000

    dq 0x0000018001800660
    dq 0x0660181818180000
    dq 0x0000000000000000
    dq 0x0000000000000000

    dq 0x0000000000000000
    dq 0x0000000000000000
    dq 0x0000000000000000
    dq 0x00001FF81FF80000

    dq 0x0000060006000180
    dq 0x0180006000600000
    dq 0x0000000000000000
    dq 0x0000000000000000

    dq 0x0000000000000000
    dq 0x000007E007E00018
    dq 0x001807F807F81818
    dq 0x181807F807F80000

    dq 0x0000180018001800
    dq 0x180019E019E01E18
    dq 0x1E18181818181818
    dq 0x18181FE01FE00000

    dq 0x0000000000000000
    dq 0x000007E007E01818
    dq 0x1818180018001818
    dq 0x181807E007E00000

    dq 0x0000001800180018
    dq 0x0018079807981878
    dq 0x1878181818181818
    dq 0x181807F807F80000

    dq 0x0000000000000000
    dq 0x000007E007E01818
    dq 0x18181FF81FF81800
    dq 0x180007E007E00000

    dq 0x000001E001E00618
    dq 0x0618060006001F80
    dq 0x1F80060006000600
    dq 0x0600060006000000

    dq 0x00000000000007F8
    dq 0x07F8181818181818
    dq 0x181807F807F80018
    dq 0x001807E007E00000

    dq 0x0000180018001800
    dq 0x180019E019E01E18
    dq 0x1E18181818181818
    dq 0x1818181818180000

    dq 0x0000018001800000
    dq 0x0000078007800180
    dq 0x0180018001800180
    dq 0x018007E007E00000

    dq 0x0000006000600000
    dq 0x000001E001E00060
    dq 0x0060006000601860
    dq 0x1860078007800000

    dq 0x0000180018001800
    dq 0x1800186018601980
    dq 0x19801E001E001980
    dq 0x1980186018600000

    dq 0x0000078007800180
    dq 0x0180018001800180
    dq 0x0180018001800180
    dq 0x018007E007E00000

    dq 0x0000000000000000
    dq 0x00001E601E601998
    dq 0x1998199819981998
    dq 0x1998199819980000

    dq 0x0000000000000000
    dq 0x000019E019E01E18
    dq 0x1E18181818181818
    dq 0x1818181818180000

    dq 0x0000000000000000
    dq 0x000007E007E01818
    dq 0x1818181818181818
    dq 0x181807E007E00000

    dq 0x0000000000001FE0
    dq 0x1FE0181818181818
    dq 0x18181FE01FE01800
    dq 0x1800180018000000

    dq 0x00000000000007F8
    dq 0x07F8181818181818
    dq 0x181807F807F80018
    dq 0x0018001800180000

    dq 0x0000000000000000
    dq 0x000019E019E01E18
    dq 0x1E18180018001800
    dq 0x1800180018000000

    dq 0x0000000000000000
    dq 0x000007F807F81800
    dq 0x180007E007E00018
    dq 0x00181FE01FE00000

    dq 0x0000060006000600
    dq 0x06001F801F800600
    dq 0x0600060006000618
    dq 0x061801E001E00000

    dq 0x0000000000000000
    dq 0x0000181818181818
    dq 0x1818181818181878
    dq 0x1878079807980000

    dq 0x0000000000000000
    dq 0x0000181818181818
    dq 0x1818181818180660
    dq 0x0660018001800000

    dq 0x0000000000000000
    dq 0x0000181818181818
    dq 0x1818199819981998
    dq 0x1998066006600000

    dq 0x0000000000000000
    dq 0x0000181818180660
    dq 0x0660018001800660
    dq 0x0660181818180000

    dq 0x0000000000001818
    dq 0x1818181818181818
    dq 0x181807F807F80018
    dq 0x001807E007E00000

    dq 0x0000000000000000
    dq 0x00001FF81FF80060
    dq 0x0060018001800600
    dq 0x06001FF81FF80000

    dq 0x0000006000600180
    dq 0x0180018001800600
    dq 0x0600018001800180
    dq 0x0180006000600000

    dq 0x0000018001800180
    dq 0x0180018001800180
    dq 0x0180018001800180
    dq 0x0180018001800000

    dq 0x0000060006000180
    dq 0x0180018001800060
    dq 0x0060018001800180
    dq 0x0180060006000000

    dq 0x0000000000000000
    dq 0x0000060006001998
    dq 0x1998006000600000
    dq 0x0000000000000000

    dq 0x000000001FF81FF8
    dq 0x18181C38166813C8
    dq 0x13C816681C381818
    dq 0x1FF81FF800000000

align 16
core_end:
