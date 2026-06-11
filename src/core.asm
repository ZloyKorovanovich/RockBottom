bits 64

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

; ACPI 2.0 root
struc rsdp_t
    .signature:          resb 8
    .check_sum:          resb 1
    .oem_id:             resb 6
    .revision:           resb 1
    .rsdt_address:       resb 4 ; deprectaed in v.2.0
    .length:             resb 4
    .xsdt_address:       resb 8
    .extended_check_sum: resb 1
    .reserved:           resb 3
endstruc

; entries are stored right after the struct
; entries_count = .length - xsdp_t_size
struc acpi_std_t
    .signature:        resb 4
    .length:           resb 4
    .revision:         resb 1
    .check_sum:        resb 1
    .oem_id:           resb 6
    .oem_table_id:     resb 8
    .oem_revision:     resb 4
    .creator_id:       resb 4
    .creator_revision: resb 4
endstruc

struc mcfg_t
    .acpi_std: resb 36
    .reserved: resb 8
endstruc

struc mcfg_entry_t
    .base_address:      resb 8
    .pci_segment_group: resb 2
    .pci_bus_start:     resb 1
    .pci_bus_end:       resb 1
    .reserved:          resb 4
endstruc

struc core_data_header_t
    .memory_descriptors_count: resb 8
    .frame_buffer_base:        resb 8
    .frame_buffer_limit:       resb 8
    .frame_buffer_x:           resb 8
    .frame_buffer_y:           resb 8
    .frame_buffer_scanline:    resb 8
    .core_code:                resb 8 ; set in core entry
    .reserved_1:               resb 8
endstruc

struc pci_config_space_t
    .vendor_id:           resb 2
    .device_id:           resb 2
    .command:             resb 2
    .status:              resb 2
    .revision_id:         resb 1
    .class_code:          resb 3
    .cache_line:          resb 1
    .latency_timer:       resb 1
    .header_type:         resb 1
    .bist:                resb 1
    .bar_0:               resb 4
    .bar_1:               resb 4
    .bar_2:               resb 4
    .bar_3:               resb 4
    .bar_4:               resb 4
    .bar_5:               resb 4
    .cardbus_cis_ptr:     resb 4
    .subsystem_vendor_id: resb 2
    .subsystem_device_id: resb 2
    .expansion_rom_bar:   resb 4
    .cap_ptr:             resb 1
    .reserved_0:          resb 3
    .reserved_1:          resb 4
    .intr_line:           resb 1
    .intr_pin:            resb 1
    .min_gnt:             resb 1
    .max_lat:             resb 1

    ; MMIO BAR (in bits)
    ; [0   ] zero
    ; [1:2 ] type
    ; [3   ] prefetchable
    ; [4:31] 16-byte aligned address

    ; I/O PORT BAR (in bits)
    ; [0   ] one
    ; [1   ] reserved
    ; [2:31] 4-byte aligned address
endstruc


; yeah, its not aligned
struc idt_pointer_t
    .size:   resb 2
    .offset: resb 8
endstruc

struc idt_gate_t
    .offset_0:   resb 2 ; 0-15 bits
    .selector:   resb 2
    .ist:        resb 1 ; 3-bit value to TSS stack (optional)
    .attributes: resb 1
    .offset_1:   resb 2 ; 16-31 bits
    .offset_3:   resb 4 ; 32-63 bits
    .reserved:   resb 4 ; zero
endstruc

%include "src/renoir.asm"

; rax = core_code
; rcx = core_data
; rdx = acpi
core_entry:
    cli
    mov rsp, rax
    mov rbp, rax
    sub rsp, 64

    ; qword [rbp - 8 ] = core_code
    ; qword [rbp - 16] = core_data
    ; qword [rbp - 24] = acpi
    ; qword [rbp - 32] = idt_pointer_h
    ; word  [rbp - 34] = idt_pointer_l
    ; qword [rbp - 48] = mcfg
    ; qword [rbp - 56] = mcfg_entries_i
    ; qword [rbp - 64] = mcfg_entries_end
    mov qword [rbp - 8 ], rax
    mov qword [rbp - 16], rcx
    mov qword [rbp - 24], rdx
    mov qword [rbp - 32], 0
    mov qword [rbp - 40], 0
    mov qword [rbp - 48], 0
    mov qword [rbp - 56], 0
    mov qword [rbp - 64], 0

    ; core_data_header.core_code = core_code
    mov qword [rcx + core_data_header_t.core_code], rax

    ; main_data.core_data = core_data
    ; main_data.acpi_tree = acpi
    mov qword [rax + main_data.core_data], rcx
    mov qword [rax + main_data.acpi_tree], rdx

    mov rcx, qword [rbp - 16]
    mov edx, 0x00000000
    call frame_buffer_clear

    ; SETUP INTERRUPTS
    ; rbx = interrupt_proc
    ; rcx = idt_table
    mov rax, qword [rbp - 8 ]
    lea rbx, [rax + handle_interrupt]
    lea rcx, [rax + idt_table       ]

    ; r8 = idt_gate_low
    ; r9 = idt_gate_high
    ; rdx = temp_mask
    xor r8, r8
    xor r9, r9
    ; offset_0
    mov rax, rbx
    mov rdx, 0x000000000000FFFF
    and rax, rdx
    or r8, rax
    ; offset_1
    mov rax, rbx
    mov rdx, 0x00000000FFFF0000
    and rax, rdx
    shl rax, 32
    or r8, rax
    ; offset_2
    mov rax, rbx
    mov rdx, 0xFFFFFFFF00000000
    and rax, rdx
    shr rax, 32
    or r9, rax
    ; attributes
    mov rax, 0b10001110 << 40
    or r8, rax
    ; segment selector
    xor rax, rax
    mov ax, cs
    shl rax, 16
    or r8, rax

    ; xmm0 = idt_gate
    movq xmm0, r8
    movq xmm1, r9
    punpcklqdq xmm0, xmm1

    ; rsi = idt_table_i
    ; rdi = idt_table_end
    mov rsi, rcx
    lea rdi, [rcx + 256 * 16]
    .loop:
        movdqa [rsi], xmm0
        add rsi, 16
        cmp rsi, rdi
        jne .loop
    .loop_end:

    mov word  [rbp - 34], 256 * 16
    mov qword [rbp - 32], rcx
    lidt [rbp - 34]

    ; SCAN ACPI
    ; CHECK RSDP
    ; rbx = rsdp
    ; rax = signature
    ; rdx = correct_signature
    mov rbx, qword [rbp - 24]
    mov rax, qword [rbx + rsdp_t.signature]
    mov rdx, qword 'RSD PTR '
    cmp rax, rdx
    jne .rsdp_bad_sig
    ; al  = check_sum
    ; rsi = bytes_i
    ; rdi = bytes_end
    xor al, al
    mov rsi, rbx
    mov edi, dword [rbx + rsdp_t.length]
    add rdi, rsi
    .check_sum_loop:
        cmp rsi, rdi
        je .check_sum_loop_end
        add al, byte [rsi]
        inc rsi
        jmp .check_sum_loop
    .check_sum_loop_end:
    test al, al
    jnz .rsdp_bad_sum

    ; CHECK XSDT
    ; rbx = xsdt
    ; eax = signature
    ; rdx = correct_signature
    mov rbx, qword [rbx + rsdp_t.xsdt_address]
    mov eax, dword [rbx + acpi_std_t.signature]
    mov edx, dword 'XSDT'
    cmp eax, edx
    jne .xsdt_bad_sig
    ; al  = check_sum
    ; rsi = bytes_i
    ; rdi = bytes_end
    xor al, al
    mov rsi, rbx
    mov edi, dword [rbx + acpi_std_t.length]
    add rdi, rsi
    .check_sum_1_loop:
        cmp rsi, rdi
        je .check_sum_1_loop_end
        add al, byte [rsi]
        inc rsi
        jmp .check_sum_1_loop
    .check_sum_1_loop_end:
    test al, al
    jnz .xsdt_bad_sum

    ; SEARCH FOR MCFG
    ; rbx := xsdt
    ; edx = correct_siganture 
    ; rsi = entries_i
    ; rdi = entries_end
    lea rsi, [rbx + acpi_std_t_size]
    mov edi, dword [rbx + acpi_std_t.length]
    add rdi, rbx
    mov edx, dword 'MCFG'

    .search_mcfg_loop:
        cmp rsi, rdi
        jae .search_mcfg_loop_end

        ; eax = signature
        ; rbx = table_pointer
        mov rbx, qword [rsi]
        mov eax, dword [rbx + acpi_std_t.signature]
        cmp eax, edx
        je .found_mcfg

        add rsi, 8
        jmp .search_mcfg_loop
    .search_mcfg_loop_end:
    jmp .mcfg_not_present
    .found_mcfg:
    ; check_sum
    ; rbx = mcfg
    ; al  = check_sum
    ; rsi = bytes_i
    ; rdi = bytes_end
    xor al, al
    mov rsi, rbx
    mov edi, dword [rbx + acpi_std_t.length]
    add rdi, rsi
    .check_sum_2_loop:
        cmp rsi, rdi
        je .check_sum_2_loop_end
        add al, byte [rsi]
        inc rsi
        jmp .check_sum_2_loop
    .check_sum_2_loop_end:
    test al, al
    jnz .mcfg_bad_sum

    ; qword [rbp - 48] = mcfg
    lea rsi, [rbx + mcfg_t_size]
    mov rdi, [rbx + acpi_std_t.length]
    mov qword [rbp - 48], rbx

    ; scan pcie
    .scan_pcie_loop:
        cmp rsi, rdi
        jae .scan_pcie_loop_end
        mov qword [rbp - 56], rsi
        mov qword [rbp - 64], rdi

        mov rcx, 0x1002
        mov rdx, 0x1638
        mov rsi, qword [rbp - 48]
        add rsi, mcfg_t_size
        call scan_pcie_entry
        cmp rax, 0xFFFFFFFFFFFFFFFF
        jne .found_1002_1638

        mov rsi, qword [rbp - 56]
        mov rdi, qword [rbp - 64]
        add rsi, mcfg_entry_t_size
        jmp .scan_pcie_loop
    .scan_pcie_loop_end:
    jmp .1002_1638_not_found

    .found_1002_1638:
    mov rcx, qword [rbp - 8]
    mov rdx, rax
    call check_registers
    
    ; SUCCESS
    ;mov rax, qword [rbp - 8]
    ;mov rcx, qword [rbp - 16]
    ;mov edx, 0x0000FF00
    ;lea rsi, [rax + msg.success_begin]
    ;lea rdi, [rax + msg.success_end  ]
    ;call frame_buffer_print  
    hlt

    .rsdp_bad_sig:
        mov rax, qword [rbp - 8 ]
        mov rcx, qword [rbp - 16]
        mov edx, 0x00FFFF00
        lea rsi, [rax + msg.rsdp_bad_sig_begin]
        lea rdi, [rax + msg.rsdp_bad_sig_end  ]
        call frame_buffer_print
    hlt
    .rsdp_bad_sum:
        mov rax, qword [rbp - 8 ]
        mov rcx, qword [rbp - 16]
        mov edx, 0x00FFFF00
        lea rsi, [rax + msg.rsdp_bad_sum_begin]
        lea rdi, [rax + msg.rsdp_bad_sum_end  ]
        call frame_buffer_print
    hlt
    .xsdt_bad_sig:
        mov rax, qword [rbp - 8 ]
        mov rcx, qword [rbp - 16]
        mov edx, 0x00FFFF00
        lea rsi, [rax + msg.xsdt_bad_sig_begin]
        lea rdi, [rax + msg.xsdt_bad_sig_end  ]
        call frame_buffer_print
    hlt
    .xsdt_bad_sum:
        mov rax, qword [rbp - 8 ]
        mov rcx, qword [rbp - 16]
        mov edx, 0x00FFFF00
        lea rsi, [rax + msg.xsdt_bad_sum_begin]
        lea rdi, [rax + msg.xsdt_bad_sum_end  ]
        call frame_buffer_print
    hlt
    .mcfg_not_present:
        mov rax, qword [rbp - 8 ]
        mov rcx, qword [rbp - 16]
        mov edx, 0x00FFFF00
        lea rsi, [rax + msg.mcfg_not_present_begin]
        lea rdi, [rax + msg.mcfg_not_present_end  ]
        call frame_buffer_print
    hlt
    .mcfg_bad_sum:
        mov rax, qword [rbp - 8 ]
        mov rcx, qword [rbp - 16]
        mov edx, 0x00FFFF00
        lea rsi, [rax + msg.mcfg_bad_sum_begin]
        lea rdi, [rax + msg.mcfg_bad_sum_end  ]
        call frame_buffer_print
    hlt
    .1002_1638_not_found:
        mov rax, qword [rbp - 8 ]
        mov rcx, qword [rbp - 16]
        mov edx, 0x00FFFF00
        lea rsi, [rax + msg.1002_1638_not_found_begin]
        lea rdi, [rax + msg.1002_1638_not_found_end  ]
        call frame_buffer_print
    hlt
;

; cx  = vendor_id
; dx  = device_id
; rsi = mcfg_entry
scan_pcie_entry:
    ; rbx = base_address
    ; rsi = buses_i
    ; rdi = buses_end_inclsive
    mov rbx, qword [rsi + mcfg_entry_t.base_address] 
    movzx rdi, byte [rsi + mcfg_entry_t.pci_bus_end  ]
    movzx rsi, byte [rsi + mcfg_entry_t.pci_bus_start]

    .bus_loop:
        cmp rsi, rdi
        ja .bus_loop_end

        ; r9 = device
        mov r9, 31
        .device_loop:

            ; r10 = funciton
            mov r10, 7
            .function_loop:
                ; rax = base_address | (bus << 20) | (device << 15) | (function << 12)
                mov rax, rbx
                ; bus
                mov r8, rsi
                shl r8, 20
                or rax, r8
                ; device
                mov r8, r9
                shl r8, 15
                or rax, r8
                ; function
                mov r8, r10
                shl r8, 12
                or rax, r8

                ; r11w = vendor_id
                ; r12w = device_id
                mov r11w, word [rax + pci_config_space_t.vendor_id]
                mov r12w, word [rax + pci_config_space_t.device_id]

                cmp r11w, cx
                jne .continue
                cmp r12w, dx
                jne .continue

                jmp .found_device

                .continue:
                sub r10, 1
                jnc .function_loop
            .function_loop_end:

            sub r9, 1
            jnc .device_loop
        .device_loop_end:

        inc rsi
        jmp .bus_loop
    .bus_loop_end:

    .failed:
    mov rax, 0xFFFFFFFFFFFFFFFF
    ret

    .found_device:
    ;mov rax, rax
    ret
;

; rcx = core_address
; rdx = pci_device
check_registers:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; qword [rbp - 8 ] = core_address
    ; qword [rbp - 16] = pci_device
    ; qword [rbp - 24] = BAR5
    ; rax = BAR5
    mov eax, dword [rdx + pci_config_space_t.bar_5]
    and eax, 0xFFFFFFFC ; actually not necessary for MMIO
    mov qword [rbp - 8 ], rcx
    mov qword [rbp - 16], rdx
    mov qword [rbp - 24], rax

    ; rax : BAR5
    ; rbx = mmGRBM_STATUS_offset
    mov rbx, (GC_BASE__INST0_SEG0 + mmGRBM_STATUS) * 4
    add rbx, rax
    
    mov rax, qword [rbp - 8 ]
    lea rcx, [rax + msg.device_registers_begin + 16]
    lea rdx, [rax + msg.device_registers_end   + 32]
    mov esi, dword [rbx]
    call print_qword

    ; rax = BAR5
    mov rax, qword [rbp - 24]
    
    ; OUT0
    ; R1 = R
    mov rbx, (DCN_BASE__INST0_SEG2 + mmMPC_OUT0_CSC_C11_C12_A) * 4
    add rbx, rax
    mov dword [rbx], AMD_ONE
    mov rbx, (DCN_BASE__INST0_SEG2 + mmMPC_OUT0_CSC_C13_C14_A) * 4
    add rbx, rax
    mov dword [rbx], AMD_ZERO
    ; G1 = B
    mov rbx, (DCN_BASE__INST0_SEG2 + mmMPC_OUT0_CSC_C21_C22_A) * 4
    add rbx, rax
    mov dword [rbx], AMD_ZERO
    mov rbx, (DCN_BASE__INST0_SEG2 + mmMPC_OUT0_CSC_C23_C24_A) * 4
    add rbx, rax
    mov dword [rbx], AMD_ONE
    ; B1 = G
    mov rbx, (DCN_BASE__INST0_SEG2 + mmMPC_OUT0_CSC_C31_C32_A) * 4
    add rbx, rax
    mov dword [rbx], AMD_ONE << 16
    mov rbx, (DCN_BASE__INST0_SEG2 + mmMPC_OUT0_CSC_C33_C34_A) * 4
    add rbx, rax
    mov dword [rbx], AMD_ZERO
    ; ENABLE MODE
    mov rbx, (DCN_BASE__INST0_SEG2 + mmMPC_OUT0_CSC_MODE) * 4
    add rbx, rax
    mov dword [rbx], 1

    mov rax, qword [rbp - 8 ]
    mov rcx, qword [rax + main_data.core_data]
    mov edx, 0x0000FF00
    lea rsi, [rax + msg.device_registers_begin]
    lea rdi, [rax + msg.device_registers_end  ]
    call frame_buffer_print

    mov rsp, rbp
    pop rbp
    ret
;

; rcx = core_address
; rdx = pci_device
process_gpu:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; qword [rbp - 8 ] = msg_i
    ; qword [rbp - 16] = msg_end
    ; qword [rbp - 24] = pci_device
    ; qword [rbp - 24] = core_address
    mov rax, rcx
    mov rbx, rcx
    add rax, msg.pci_device_begin
    add rbx, msg.pci_device_end
    mov qword [rbp - 8 ], rax
    mov qword [rbp - 16], rbx
    mov qword [rbp - 24], rdx
    mov qword [rbp - 32], rcx

    ; vendor
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, word [rbx + pci_config_space_t.vendor_id]
    call print_qword

    ; device
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp -8 ], rdx
    mov rbx, qword [rbp -24]
    movzx rsi, word [rbx + pci_config_space_t.device_id]
    call print_qword

    ; command 
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, word [rbx + pci_config_space_t.command]
    call print_qword

    ; status
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, word [rbx + pci_config_space_t.status]
    call print_qword

    ; revision_id
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, byte [rbx + pci_config_space_t.revision_id]
    call print_qword

    ; class_code
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.class_code]
    and   rsi, 0x0000000000FFFFFF
    call print_qword

    ; cache_line
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, byte [rbx + pci_config_space_t.cache_line]
    call print_qword

    ; latency_timer
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, byte [rbx + pci_config_space_t.latency_timer]
    call print_qword

    ; header_type
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, byte [rbx + pci_config_space_t.header_type]
    call print_qword

    ; bist
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, byte [rbx + pci_config_space_t.bist]
    call print_qword

    ; bar_0
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.bar_0]
    call print_qword

    ; bar_1
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.bar_1]
    call print_qword

    ; bar_2
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.bar_2]
    call print_qword

    ; bar_3
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.bar_3]
    call print_qword

    ; bar_4
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.bar_4]
    call print_qword

    ; bar_5
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.bar_5]
    call print_qword

    ; cardbus_cis_ptr
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.cardbus_cis_ptr]
    call print_qword

    ; subsystem_vendor_id
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, word [rbx + pci_config_space_t.subsystem_vendor_id]
    call print_qword

    ; subsystem_device_id
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, word [rbx + pci_config_space_t.subsystem_device_id]
    call print_qword

    ; expansion_rom_bar
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.expansion_rom_bar]
    call print_qword

    ; cap_ptr
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, byte [rbx + pci_config_space_t.cap_ptr]
    call print_qword

    ; reserved_0
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.reserved_0]
    and   rsi, 0x0000000000FFFFFF
    call print_qword

    ; reserved_1
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, dword [rbx + pci_config_space_t.reserved_1]
    call print_qword

    ; intr_line
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, byte [rbx + pci_config_space_t.intr_line]
    call print_qword

    ; intr_pin
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, byte [rbx + pci_config_space_t.intr_pin]
    call print_qword

    ; min_gnt
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, byte [rbx + pci_config_space_t.min_gnt]
    call print_qword

    ; max_lat
    mov rcx, qword [rbp - 8 ]
    mov rdx, qword [rbp - 8 ]
    add   rcx, 21
    add   rdx, 38
    mov qword [rbp - 8 ], rdx
    mov rbx, qword [rbp - 24]
    movzx rsi, byte [rbx + pci_config_space_t.max_lat]
    call print_qword

    ; rax = core_address
    mov rax, qword [rbp - 32]
    mov rcx, qword [rax + main_data.core_data]
    mov edx, 0x0000FF00
    lea rsi, [rax + msg.pci_device_begin]
    lea rdi, [rax + msg.pci_device_end  ]
    call frame_buffer_print

    mov rsp, rbp
    pop rbp
    ret
;

; rcx = dst_begin
; rdx = dst_end
; rsi = src_begin
; rdi = src_end
str_copy:
    ; al = temp_char
    .loop:
        cmp rsi, rdi
        jae .loop_end
        cmp rcx, rdx
        jae .loop_end

        mov al, byte [rsi]
        mov byte [rcx], al
        inc rsi
        inc rcx
        jmp .loop
    .loop_end:
    ret
;

; rcx = dst_begin 
; rdx = dst_end
; rsi = qword
print_qword:
    ; rbx = dst_i
    ; rdx = dst_end
    ; cl  = bits_shift
    mov rbx, rcx
    mov cl, 60
    .loop:
        cmp rbx, rdx
        jae .loop_end

        ; r8 = hex_digit
        mov rax, rsi
        shr rax, cl
        and rax, 0xF
        lea r8 , [rax - 10 + 'A']
        add rax, '0'
        cmp rax, '9'
        cmova rax, r8

        mov byte [rbx], al
        inc rbx
        sub cl, 4
        jnc .loop
    .loop_end:
    ret
;

; rcx = core_data_header
; edx = color
frame_buffer_clear:
    mov rsi, qword [rcx + core_data_header_t.frame_buffer_base ]
    mov rdi, qword [rcx + core_data_header_t.frame_buffer_limit]

    cmp rsi, rdi
    je .fill_loop_end
    .fill_loop:
        mov dword [rsi], edx
        add rsi, 4
        cmp rsi, rdi
        jne .fill_loop 
    .fill_loop_end:
    ret
;

; rcx = core_data_header
; edx = color
; rsi = string_begin
; rdi = string_end
frame_buffer_print:
    ; convert to old ABI
    ; r8  = core_data
    ; r9d = glyph_color
    ; r10 = ascii_str
    ; r11 = ascii_str_end
    mov r8 , rcx
    mov r9d, edx
    mov r10, rsi
    mov r11, rdi

    ; rax = frame_buffer_i
    ; rbx = resolution_x - 16
    ; rcx = resolution_y - 16
    ; rdx = scanline_size
    mov rax, qword [r8 + core_data_header_t.frame_buffer_base    ]
    mov rbx, qword [r8 + core_data_header_t.frame_buffer_x       ]
    mov rcx, qword [r8 + core_data_header_t.frame_buffer_y       ]
    mov rdx, qword [r8 + core_data_header_t.frame_buffer_scanline]
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
        cmp r15b, 10
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
            lea r13, [rel ascii_glyphs]
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

; FIX: can not iretq because rsp might be different
handle_interrupt:
    ; qword [rbp + 32] = old_rflags
    ; qword [rbp + 24] = old_cs
    ; qword [rbp + 16] = old_rip
    ; qword [rbp + 8 ] = error_code (optional)
    ; qword [rbp + 0 ] = old_rbp
    and  rsp, 0xFFFFFFFFFFFFFFF0
    push rbp
    sub  rsp, 64

    ; qword [rbp - 8 ] = rax
    ; qword [rbp - 16] = rbx
    ; qword [rbp - 24] = rcx
    ; qword [rbp - 32] = rdx
    ; qword [rbp - 40] = rsi
    ; qword [rbp - 48] = rdi
    mov qword [rbp - 8 ], rax
    mov qword [rbp - 16], rbx 
    mov qword [rbp - 24], rcx
    mov qword [rbp - 32], rdx
    mov qword [rbp - 40], rsi
    mov qword [rbp - 48], rdi

    ; rax = core_address
    ; rcx = core_data
    ; qword [rbp - 56] = core_address
    ; qword [rbp - 64] = core_data
    lea rax, [rel handle_interrupt]
    sub rax, handle_interrupt
    mov rcx, qword [rax + main_data.core_data]
    mov qword [rbp - 56], rax
    mov qword [rbp - 64], rcx

    ; rcx = core_data_header
    ; edx = color_black
    mov rcx, qword [rbp - 64]
    mov edx, 0x00000000
    call frame_buffer_clear

    ; print rax
    mov rax, qword [rbp - 56]
    lea rcx, [rax + msg.rax_val + 6 ]
    lea rdx, [rax + msg.rax_val + 22]
    mov rsi, qword [rbp - 8 ]
    call print_qword
    ; print rbx
    mov rax, qword [rbp - 56]
    lea rcx, [rax + msg.rbx_val + 6 ]
    lea rdx, [rax + msg.rbx_val + 22]
    mov rsi, qword [rbp - 16]
    call print_qword
    ; print rcx
    mov rax, qword [rbp - 56]
    lea rcx, [rax + msg.rcx_val + 6 ]
    lea rdx, [rax + msg.rcx_val + 22]
    mov rsi, qword [rbp - 24]
    call print_qword
    ; print rdx
    mov rax, qword [rbp - 56]
    lea rcx, [rax + msg.rdx_val + 6 ]
    lea rdx, [rax + msg.rdx_val + 22]
    mov rsi, qword [rbp - 32]
    call print_qword
    ; print rsi
    mov rax, qword [rbp - 56]
    lea rcx, [rax + msg.rsi_val + 6 ]
    lea rdx, [rax + msg.rsi_val + 22]
    mov rsi, qword [rbp - 40]
    call print_qword
    ; print rdi
    mov rax, qword [rbp - 56]
    lea rcx, [rax + msg.rdi_val + 6 ]
    lea rdx, [rax + msg.rdi_val + 22]
    mov rsi, qword [rbp - 48]
    call print_qword


    ; rax = core_address
    ; rcx = core_data
    ; edx = color_red
    ; rsi = message_begin
    ; rdi = message_end
    mov rax, qword [rbp - 56]
    mov rcx, qword [rbp - 64]
    mov edx, 0x00FF0000
    lea rsi, [rax + msg.exception_begin]
    lea rdi, [rax + msg.exception_end  ]
    call frame_buffer_print

    hlt
;

; =======================================================
;   DATA
; =======================================================
; everything here is addressed as [core_address + compile-time global lable]

align 16
idt_table:
    times 256 * 16 db 0x0
;


main_data:
    .core_data: dq 0xFFFFFFFFFFFFFFFF
    .acpi_tree: dq 0xFFFFFFFFFFFFFFFF
;

align 16
msg:
    .exception_begin:
        db "  ^___^   ",10
        db " /O  O \  ",10
        db "(  ___  ) FUCK YOU! ",10
        db " \ \_/ /  ",10
        db "  U   U   ",10
        db "  (   )   ",10
        db "  O-v-O   ",10
    .rax_val:
        db " RAX: 0000000000000000",10
    .rbx_val:
        db " RBX: 0000000000000000",10
    .rcx_val:
        db " RCX: 0000000000000000",10
    .rdx_val:
        db " RDX: 0000000000000000",10
    .rsi_val:
        db " RSI: 0000000000000000",10
    .rdi_val:
        db " RDI: 0000000000000000",10
    .exception_end:

    ; 21
    ; 38
    .pci_device_begin:
        db "vendor_id:           0000000000000000",10
        db "device_id:           0000000000000000",10
        db "command:             0000000000000000",10
        db "status:              0000000000000000",10
        db "revision_id:         0000000000000000",10
        db "class_code:          0000000000000000",10
        db "cache_line:          0000000000000000",10
        db "latency_timer:       0000000000000000",10
        db "header_type:         0000000000000000",10
        db "bist:                0000000000000000",10
        db "bar_0:               0000000000000000",10
        db "bar_1:               0000000000000000",10
        db "bar_2:               0000000000000000",10
        db "bar_3:               0000000000000000",10
        db "bar_4:               0000000000000000",10
        db "bar_5:               0000000000000000",10
        db "cardbus_cis_ptr:     0000000000000000",10
        db "subsystem_vendor_id: 0000000000000000",10
        db "subsystem_device_id: 0000000000000000",10
        db "expansion_rom_bar:   0000000000000000",10
        db "cap_ptr:             0000000000000000",10
        db "reserved_0:          0000000000000000",10
        db "reserved_1:          0000000000000000",10
        db "intr_line:           0000000000000000",10
        db "intr_pin:            0000000000000000",10
        db "min_gnt:             0000000000000000",10
        db "max_lat:             0000000000000000",10
        db "-------------------------------------",10
    .pci_device_end:

    ; 16
    ; 32
    .device_registers_begin:
        db "mmGRBM_STATUS: 0000000000000000",10
    .device_registers_end:

    .rsdp_bad_sig_begin:
        db "invalid rsdp signature",10
    .rsdp_bad_sig_end:
    .rsdp_bad_sum_begin:
        db "invalid rsdp checksum",10
    .rsdp_bad_sum_end:
    .xsdt_bad_sig_begin:
        db "invalid xsdt signature",10
    .xsdt_bad_sig_end:
    .xsdt_bad_sum_begin:
        db "invalid xsdt checksum",10
    .xsdt_bad_sum_end:
    .mcfg_not_present_begin:
        db "not found mcfg",10
    .mcfg_not_present_end:
    .mcfg_bad_sum_begin:
        db "invalid mcfg checksum",10
    .mcfg_bad_sum_end:
    .1002_1638_not_found_begin:
        db "could not find 1002 1638 in pcie",10
    .1002_1638_not_found_end:
;

; code E [0x20; 0x7F]
; 16x16 grid requires 256 bits (32 bytes) per glyph.
align 16
ascii_glyphs:
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
