boot:
	gcc -c -Iext/inc src/boot.c -o bin/boot.o
	ld -m i386pep --subsystem=10 -nostdlib -e efi_main bin/boot.o -o root/efi/boot/bootx64.efi

core:
	nasm -f bin src/core.asm -o root/x64/core.bin

run:
	qemu-system-x86_64															\
	-cpu EPYC                                                                   \
  	-drive if=pflash,format=raw,file="C:/Program Files/qemu/edk2-ovmf/OVMF.fd"  \
  	-drive format=raw,file=fat:rw:root 											\
  	-net none																	\
	-vga std 
