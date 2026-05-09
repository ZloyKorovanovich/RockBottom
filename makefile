compile:


boot:
	gcc -c -Iext/inc src/boot.c -o bin/boot.o
	nasm -f elf64 src/boot.asm -o bin/boot_asm.o
	ld -m i386pep --subsystem=10 -nostdlib -e efi_main bin/boot.o bin/boot_asm.o -o bin/bootx64.efi

	cp bin/bootx64.efi root/efi/boot/bootx64.efi
	rm bin/boot.o
	rm bin/boot_asm.o

core:
	nasm -f bin src/core.asm -o bin/core.bin
	cp bin/core.bin root/x64/core.bin

run:
	qemu-system-x86_64															\
	-cpu EPYC                                                                   \
  	-drive if=pflash,format=raw,file="C:/Program Files/qemu/edk2-ovmf/OVMF.fd"  \
  	-drive format=raw,file=fat:rw:root 											\
  	-net none																	\
	-vga std 

run_no_graphics: 
	qemu-system-x86_64 															\
	-nographic                                                                  \
  	-drive if=pflash,format=raw,file="C:/Program Files/qemu/edk2-ovmf/OVMF.fd"  \
  	-drive format=raw,file=fat:rw:root 											\
  	-net none	
