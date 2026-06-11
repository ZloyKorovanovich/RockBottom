#include <efi.h>

typedef struct {
    EFI_FILE_INFO info;
    CHAR16        name[512];
} NAMED_FILE_INFO;

typedef struct {
    EFI_PHYSICAL_ADDRESS address_base;
    EFI_PHYSICAL_ADDRESS address_limit;
    UINTN                type;
    UINTN                attributes;
} CORE_MEMORY_DESCRIPTOR;

typedef struct {
    UINTN                  memory_descriptors_count;
    EFI_PHYSICAL_ADDRESS   frame_buffer_base;
    EFI_PHYSICAL_ADDRESS   frame_buffer_limit;
    UINTN                  frame_buffer_x;
    UINTN                  frame_buffer_y;
    UINTN                  frame_buffer_scanline;
    UINTN                  reserved_0;
    UINTN                  reserved_1;
} CORE_DATA_HEADER;

#define ARRAY_SIZE(array) (sizeof(array) / sizeof(array[0]))

#define STACK_SIZE (1024 * 1024)

BOOLEAN compare_guids(
    EFI_GUID guid_a,
    EFI_GUID guid_b
) {
    return (
        guid_a.Data1    == guid_b.Data1    &&
        guid_a.Data2    == guid_b.Data2    &&
        guid_a.Data3    == guid_b.Data3    &&
        guid_a.Data4[0] == guid_b.Data4[0] &&
        guid_a.Data4[1] == guid_b.Data4[1] &&
        guid_a.Data4[2] == guid_b.Data4[2] &&
        guid_a.Data4[3] == guid_b.Data4[3] &&
        guid_a.Data4[4] == guid_b.Data4[4] &&
        guid_a.Data4[5] == guid_b.Data4[5] &&
        guid_a.Data4[6] == guid_b.Data4[6] &&
        guid_a.Data4[7] == guid_b.Data4[7]
    ) ? TRUE : FALSE;
}

/* core_file_address + STACK_SIZE = core_entry */
EFI_STATUS load_core(
    SIMPLE_TEXT_OUTPUT_INTERFACE*    console_out,
    EFI_BOOT_SERVICES*               boot_services,
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL* protocol_file_system,
    EFI_PHYSICAL_ADDRESS*            core_file_address
) { 
    EFI_GUID             guid_file_info  = EFI_FILE_INFO_ID;
    EFI_FILE_PROTOCOL*   root            = NULL;
    EFI_FILE_PROTOCOL*   core_file       = NULL;
    NAMED_FILE_INFO      file_info       = (NAMED_FILE_INFO){0}; 
    UINTN                file_info_size  = sizeof(NAMED_FILE_INFO);
    UINTN                file_page_count = 0;

    /* open root */
    if(protocol_file_system->OpenVolume(
        protocol_file_system,
        &root
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to open root volume\r\n");
        goto fail;
    }

    /* open file */
    if(root->Open(
        root,
        &core_file,
        L"x64\\core.bin",
        EFI_FILE_MODE_READ,
        0
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to open core file\r\n");
        goto fail;
    }

    /* get size info */
    if(core_file->GetInfo(
        core_file,
        &guid_file_info,
        &file_info_size,
        &file_info
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to get core file info\r\n");
        goto fail;
    }

    file_page_count = (file_info.info.FileSize + 0xFFF + STACK_SIZE) / 0x1000;

    /* allocate ram */
    if(boot_services->AllocatePages(
        AllocateAnyPages,
        EfiLoaderCode,
        file_page_count,
        core_file_address
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to allocate core file ram\r\n");
        goto fail;
    }

    /* failed to read */
    if(core_file->Read(
        core_file,
        &file_info.info.FileSize,
        ((UINT8*)*core_file_address + STACK_SIZE)
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to read core file to ram\r\n");
        goto fail;
    }

    core_file->Close(core_file);
    root->Close(root);

    return EFI_SUCCESS;

    fail: {
        return EFI_NOT_STARTED;
    }
}

EFI_STATUS form_core_buffer(
    SIMPLE_TEXT_OUTPUT_INTERFACE* console_out,
    EFI_BOOT_SERVICES*            boot_services,
    EFI_GRAPHICS_OUTPUT_PROTOCOL* graphics_output_protocol,
    EFI_PHYSICAL_ADDRESS*         core_data_address,
    UINTN*                        map_key
) {
    VOID*                   map_array                = NULL;
    VOID*                   map_array_end            = NULL;
    UINTN                   map_size                 = 0;
    UINTN                   map_descriptor_size      = 0;
    UINT32                  map_descriptor_version   = 0;

    UINTN                   core_data_page_count     = 0;
    CORE_MEMORY_DESCRIPTOR* core_memory_descriptors  = NULL;
    CORE_DATA_HEADER*       core_header              = NULL;

    /* get memory map size and descriptor size */
    if(boot_services->GetMemoryMap(
        &map_size,
        NULL,
        map_key,
        &map_descriptor_size,
        &map_descriptor_version
    ) != EFI_BUFFER_TOO_SMALL) {
        console_out->OutputString(console_out, L"failed to get memory map size\r\n");
        goto fail;
    }

    /* calculate sizes */
    map_size             = map_size + 2 * map_descriptor_size;
    core_data_page_count = ((map_size / map_descriptor_size) * sizeof(CORE_MEMORY_DESCRIPTOR) + 0xFFF) / 0x1000;
    
    /* allocate persistent */
    if(boot_services->AllocatePages(
        AllocateAnyPages,
        EfiBootServicesData,
        core_data_page_count,
        core_data_address
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to allocate core data pages\r\n");
        goto fail;
    }
    /* allocate temp map */
    if(boot_services->AllocatePool(
        EfiBootServicesData,
        map_size,
        &map_array
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to allocate memory map\r\n");
        goto fail;
    }

    /* get memory map */
    if(boot_services->GetMemoryMap(
        &map_size,
        map_array,
        map_key,
        &map_descriptor_size,
        &map_descriptor_version
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to get memory map\r\n");
        goto fail;
    }
    map_array_end = (UINT8*)map_array + map_size;

    /* copy descriptors */
    core_header             = (CORE_DATA_HEADER*      )(*core_data_address);
    core_memory_descriptors = (CORE_MEMORY_DESCRIPTOR*)(*core_data_address + sizeof(CORE_DATA_HEADER));
    
    while(map_array != map_array_end) {
        *core_memory_descriptors = (CORE_MEMORY_DESCRIPTOR) {
            .address_base  = ((EFI_MEMORY_DESCRIPTOR*)map_array)->PhysicalStart,
            .address_limit = ((EFI_MEMORY_DESCRIPTOR*)map_array)->PhysicalStart + ((EFI_MEMORY_DESCRIPTOR*)map_array)->NumberOfPages * 0x1000,
            .type          = (UINTN)((EFI_MEMORY_DESCRIPTOR*)map_array)->Type,
            .attributes    = ((EFI_MEMORY_DESCRIPTOR*)map_array)->Attribute
        };

        map_array               = (UINT8*)map_array + map_descriptor_size;
        core_memory_descriptors = core_memory_descriptors + 1;
    }

    *core_header = (CORE_DATA_HEADER) {
        .memory_descriptors_count = map_size / map_descriptor_size,
        .frame_buffer_base        = graphics_output_protocol->Mode->FrameBufferBase,
        .frame_buffer_limit       = graphics_output_protocol->Mode->FrameBufferBase + graphics_output_protocol->Mode->FrameBufferSize,
        .frame_buffer_x           = graphics_output_protocol->Mode->Info->HorizontalResolution,
        .frame_buffer_y           = graphics_output_protocol->Mode->Info->VerticalResolution,
        .frame_buffer_scanline    = graphics_output_protocol->Mode->Info->PixelsPerScanLine
    };

    return EFI_SUCCESS;

    fail: {
        return EFI_NOT_STARTED;
    }
}

EFI_STATUS find_acpi_2_0_table(
    EFI_CONFIGURATION_TABLE*      config_tables,
    UINTN                         config_tables_count,
    VOID**                        acpi_2_0_address
) {
    EFI_GUID guid_acpi_2_0 = ACPI_20_TABLE_GUID;

    for(UINTN i = 0; i != config_tables_count; i++) {
        if(compare_guids(
            config_tables[i].VendorGuid, 
            guid_acpi_2_0
        )) {
            *acpi_2_0_address = config_tables[i].VendorTable;
            goto success;
        }
    }

    fail: {
        return EFI_NOT_FOUND;
    }
    success: {
        return EFI_SUCCESS;
    };
}

EFI_STATUS EFIAPI efi_main(
    EFI_HANDLE        image_handle,
    EFI_SYSTEM_TABLE* system_table
) {
    SIMPLE_TEXT_OUTPUT_INTERFACE*    console_out              = system_table->ConOut;
    EFI_BOOT_SERVICES*               boot_services            = system_table->BootServices;
    EFI_GUID                         guid_loaded_image        = EFI_LOADED_IMAGE_PROTOCOL_GUID;
    EFI_GUID                         guid_file_system         = EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID;
    EFI_GUID                         guid_graphics_output     = EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID;
    EFI_GUID                         guid_pci_io              = EFI_PCI_IO_PROTOCOL_GUID;
    EFI_LOADED_IMAGE_PROTOCOL*       protocol_loaded_image    = NULL;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL* protocol_file_system     = NULL;
    EFI_GRAPHICS_OUTPUT_PROTOCOL*    protocol_graphics_output = NULL;
    EFI_PCI_IO_PROTOCOL*             protocol_pci_io          = NULL;

    EFI_HANDLE*                      graphics_handles         = NULL;
    UINTN                            graphics_handles_count   = 0;
    UINT32                           pci_id                   = UINT32_MAX;
    UINT16                           vendor_id                = UINT16_MAX;
    UINT16                           device_id                = UINT16_MAX;

    EFI_PHYSICAL_ADDRESS             core_address             = 0;
    EFI_PHYSICAL_ADDRESS             data_address             = 0;
    VOID*                            acpi_2_0_table           = NULL;
    UINTN                            memory_map_key           = 0;

    console_out->ClearScreen(console_out);
    console_out->OutputString(console_out, L"entered loader\r\n");

    /* image handle protocol */
    if(boot_services->HandleProtocol(
        image_handle,
        &guid_loaded_image,
        (void**)&protocol_loaded_image
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to handle loaded image protocol\r\n");
        goto fail;
    }
    /* file system protocol */
    if(boot_services->HandleProtocol(
        protocol_loaded_image->DeviceHandle,
        &guid_file_system,
        (void**)&protocol_file_system
    )) {
        console_out->OutputString(console_out, L"failed to handle file system protocol\r\n");
        goto fail;
    }
    /* graphics output protocol */
    if(boot_services->LocateHandleBuffer(
        ByProtocol,
        &guid_graphics_output,
        NULL,
        &graphics_handles_count,
        &graphics_handles
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to get graphics handles\r\n");
        goto fail;
    }
    for(UINTN i = 0; i != graphics_handles_count; i++) {
        /* FIX: ensure correct device is selected */
        /*
        pci_id    = UINT32_MAX;
        vendor_id = UINT16_MAX;
        device_id = UINT16_MAX;

        console_out->OutputString(console_out, L"LOOP FUCK YOU 1\r\n");

        if(boot_services->HandleProtocol(
            graphics_handles[i],
            &guid_pci_io,
            (void**)&protocol_pci_io
        ) != EFI_SUCCESS) {
            continue;
        }

        console_out->OutputString(console_out, L"LOOP FUCK YOU 2\r\n");

        protocol_pci_io->Pci.Read(
            protocol_pci_io,
            EfiPciIoWidthUint32,
            0x00,
            1,
            &pci_id
        );

        console_out->OutputString(console_out, L"LOOP FUCK YOU 3\r\n");

        vendor_id = (pci_id      ) & 0xFFFF;
        device_id = (pci_id >> 16) & 0xFFFF; 

        if(vendor_id != 0x1002 && device_id != 0x1638) {
            continue;
        }

        console_out->OutputString(console_out, L"LOOP FUCK YOU 4\r\n");*/

        if(boot_services->HandleProtocol(
            graphics_handles[i],
            &guid_graphics_output,
            (void**)&protocol_graphics_output
        ) == EFI_SUCCESS) {
            goto located_gop;
        }
    }
    /* failed to locate gop */ {
        console_out->OutputString(console_out, L"failed to get graphics handles\r\n");
        goto fail;
    }
    located_gop: {};

    console_out->OutputString(console_out, L"loaded protocols\r\n");

    /* load core file to ram */
    if(load_core(
        console_out,
        boot_services,
        protocol_file_system,
        &core_address
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to load core file\r\n");
        goto fail;
    }

    console_out->OutputString(console_out, L"loaded core file\r\n");

    /* get acpi 2.0 */
    if(find_acpi_2_0_table(
        system_table->ConfigurationTable,
        system_table->NumberOfTableEntries,
        &acpi_2_0_table
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to get acpi 2.0 table\r\n");
        goto fail;
    }

    console_out->OutputString(console_out, L"found acpi 2.0 table\r\n");
    console_out->OutputString(console_out, L"exiting...\r\n");
    boot_services->Stall(100000);

    if(form_core_buffer(
        console_out,
        boot_services,
        protocol_graphics_output,
        &data_address,
        &memory_map_key
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to form core buffer\r\n");
        goto fail;
    }

    if(boot_services->ExitBootServices(
        image_handle,
        memory_map_key
    ) != EFI_SUCCESS) {
        console_out->OutputString(console_out, L"failed to exit boot services\r\n");
        goto fail;
    }

    __asm__ __volatile__(
        ".intel_syntax noprefix\n\t"

        "mov rax, %[core_address]\n\t"
        "mov rcx, %[core_data]   \n\t"
        "mov rdx, %[acpi]        \n\t"
        "jmp rax                 \n\t"

        ".att_syntax prefix\n\t"
        :
        :           
        [core_address] "r"((UINTN)core_address + STACK_SIZE),
        [core_data] "r"((UINTN)data_address),
        [acpi]      "r"((UINTN)acpi_2_0_table)
        : "rax", "rcx", "rdx", "memory"
    );


    fail: {
        boot_services->Stall(10000000);
        return EFI_NOT_STARTED;
    }
}
