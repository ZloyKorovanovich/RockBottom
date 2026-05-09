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
    ; r8 = core_main
    ; r9 = core_buffer
    lea rbp, [r13 + STACK_SIZE - 16]
    lea rsp, [r13 + STACK_SIZE - 16]
    lea r8 , [r13 + STACK_SIZE     ]
    mov r9 ,  r13

    ; register suicide
    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx
    xor rdx, rdx
    xor rsi, rsi
    xor rdi, rdi

    ; r8 and r9 are input params, should be preserved
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
    jmp r8

;

; r15 error_code
critical_fail:
    mov [abs INVALID_ADDRESS], r15

;

; =======================================================
;   STAGE 1:
; =======================================================
; Stack is available, memory is valid, layout is:
; [STACK, CODE, DATA]

; Calling conventions
; r8-r15 good integer params (no useful instructions use these registers implicitly)
; all params can be in/inout/out
; there is no such thing as return value, use inout/out instead
; #no_return - never returns
; #no_stack  - doesnt use stack except for call-ret rbp storage

; #no_return
; in: r8 = core_main_address
; in: r9 = core_buffer_address
align 16
core_main:
    ; stack:
    ;   qword [rbp - 8 ] : core_address
    ;   qword [rbp - 16] : core_data

    push rbp
    mov  rsp, rbp
    sub  rsp, 24

    ; qword [rbp - 8 ] = core_address 
    ; qword [rbp - 16] = core_data
    lea r8, [r9 + STACK_SIZE + CODE_SIZE]
    mov qword [rbp - 8 ], r9
    mov qword [rbp - 16], r8

    ;mov [abs INVALID_ADDRESS], rax

    ; r8 = core_data
    ; r9 = balck
    mov r8, qword [rbp - 16]
    xor r9, r9
    call screen_out_clear

    ; r8  = core_data
    ; r9  = green
    ; r10 = .hello_message_begin
    ; r11 = .hello_message_end
    mov r8 , qword [rbp - 16]
    mov r9 , 0x0000FF00
    lea r10, [rel .abc    ]
    lea r11, [rel .abc_end]
    call screen_out_print_ascii

    hlt

    .abc:
        db 0x01,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F
        db 0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F
        db 0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,0x2F
        db 0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F
        db 0x40,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F
        db 0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,0x5B,0x5C,0x5D,0x5E,0x5F
        db 0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x6F
        db 0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x7B,0x7C,0x7D,0x7E,0x7F
    .abc_end:
;

; === SCREEN_OUT ===
; screen_out_clear
; 

; #no_stack
; in: r8 = core_data
; in: r9 = clear_color
; use: rax, rbx
; estimation is frame buffer consists of 4-byte pixels
screen_out_clear:
    ; rax = frame_buffer_i
    ; rbx = frame_buffer_end
    mov rax, qword [r8 + core_data_t.frame_buffer]
    mov rbx, qword [r8 + core_data_t.frame_size  ]
    add rbx, rax

    cmp rax, rbx
    je .end
    .fill_loop:
        mov dword [rax], r9d
        add rax, 4
        cmp rax, rbx
        jne .fill_loop

    .end:
    ret
;

; #no_stack
; in: r8  = core_data
; in: r9  = glyph_color
; in: r10 = ascii_str
; in: r11 = ascii_str_end
; glyphs are 16x16 pixel size
; all invalid symbols replaced with del
; supported special symbols are 0-termination and 13-next_line
screen_out_print_ascii:
    ; rax = frame_buffer_i
    ; rbx = resolution_x - 16
    ; rcx = resolution_y - 16
    ; rdx = scanline_size
    mov rax, qword [r8 + core_data_t.frame_buffer]
    mov rbx, qword [r8 + core_data_t.frame_x     ]
    mov rcx, qword [r8 + core_data_t.frame_y     ]
    mov rdx, qword [r8 + core_data_t.frame_line  ]
    sub rbx, 16
    sub rcx, 16
    shl rdx, 2

    ; r10 = str_i
    ; r11 = str_end
    ; rsi = pixel_x
    ; rdi = pixel_y
    ; r12 : bit_mask
    ; r13 : char_mask
    ; r14 : dst_color    | del
    ; r15 : char_qword_i | scan_line_shift
    xor rsi, rsi
    xor rdi, rdi
    ; check if string is not zero len
    cmp r10, r11
    jae .end
    ; check if we can at least print 1 row of glyphs
    cmp rsi, rbx
    ja .end
    cmp rdi, rcx
    ja .end
    ; print string
    .str_loop:
        cmp r10, r11
        je .str_loop_end

        ; if pixel_x > resolution_x - 16 goto next row
        cmp rsi, rbx
        ja .next_row
        
        ; r14 = del
        ; r15 = char_qword_i
        xor r15, r15
        mov r14, 0x7F
        mov r15b, byte [r10]
        ; special codes
        test r15b, r15b
        jz .end
        cmp r15b, 13
        je .next_row_symbol

        ; ascii glyphs
        cmp r15b, 0x20
        cmovb r15, r14
        cmp r15b, 0x7F
        cmova r15, r14
        sub r15, 0x20
        shl r15, 5

        ; for each qword of glyph
        %rep 4
            ; r13 = char_mask
            ; r12 = bit_mask
            ; r15 = char_qword_i
            lea r13, [rel characters]
            mov r13, qword [r13 + r15]
            mov r12, 0x8000000000000000

            ; for each row of qword
            %rep 4
                ; for each pixel in line
                %rep 16
                    ; dst_color = bit set ? glyph_color : background_color
                    mov r14d, dword [rax]
                    test r12, r13
                    cmovnz r14d, r9d
                    mov dword [rax], r14d

                    ; bit_mask       = bit_mask >> 1
                    ; frame_buffer_i = frame_buffer_i + 4
                    add rax, 4
                    shr r12, 1
                %endrep

                sub rax, 16 * 4
                add rax, rdx
            %endrep
            ; char_qword_i = char_qword_i + 8
            add r15, 8
        %endrep

        ; r15            = scan_line_shift = scanline_size * 16
        ; frame_buffer_i = frame_buffer_i - scan_line_shift + 16 * 4
        ; pixel_x        = pixel_x + 16
        ; str_i          = str_i + 1
        mov r15, rdx
        shl r15, 4
        sub rax, r15
        add rax, 16 * 4
        add rsi, 16
        inc r10
        jmp .str_loop

        .next_row_symbol:
        inc r10
        .next_row:
        ; frame_buffer_i = frame_buffer_i + scanline_size * 16 - pixel_x * 4
        ; pixel_x = 0
        ; pixel_y = pixel_y + 17
        lea rax, [rax + rdx * 8]
        lea rax, [rax + rdx * 8]
        shl rsi, 2
        sub rax, rsi
        xor rsi, rsi
        add rdi, 17
        ; check y boundary
        cmp rdi, rcx
        jbe .str_loop
    .str_loop_end:

    .end:
    ret
;

; code E [0x20; 0x7F]
; FIX FUCKING p lowercase,
; 16x16 grid requires 256 bits (32 bytes) per glyph.
align 16
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

    dq 0x00000000000019E0
    dq 0x19E01E181E181818
    dq 0x18181FE01FE01800
    dq 0x1800180018000000

    dq 0x0000000000000798
    dq 0x0798187818781818
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

;

align 16
core_end:
