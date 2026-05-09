bits 64
default rel
global jump_to_core

section .text
; rcx data
; rdx proc
jump_to_core:
    jmp rdx
