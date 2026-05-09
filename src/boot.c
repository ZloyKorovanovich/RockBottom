#include <efi.h>

static SIMPLE_TEXT_OUTPUT_INTERFACE* s_console_out   = NULL;
static EFI_BOOT_SERVICES*            s_boot_services = NULL;

#define PRINT(message) s_console_out->OutputString(s_console_out, message)
/*#define NULL           ((void*)0xFFFFFFFFFFFFFFFF)*/

extern void jump_to_core(void* data, void* code);

typedef struct {
    UINTN type;
    UINTN size;
    UINTN attributes;
    VOID* address;
} memory_descriptor_t;

typedef struct {
    VOID* frame_buffer;
    UINTN descriptor_count;
    UINTN frame_x;
    UINTN frame_y;
    UINTN frame_size;
    UINTN frame_line;
} core_data_t;

typedef struct {
    EFI_FILE_INFO file_info;
    CHAR16        string_data[256];
} file_info_t;

VOID* load_core_to_ram(
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL* file_system,
    CHAR16*                          file_name
) {
    file_info_t        file_info      = (file_info_t){0};
    UINTN              file_info_size = sizeof(file_info_t);

    EFI_GUID           file_info_guid = EFI_FILE_INFO_ID;
    EFI_FILE_PROTOCOL* root           = NULL;
    EFI_FILE_PROTOCOL* core           = NULL;
    VOID*              code           = NULL;

    if(file_system->OpenVolume(
        file_system,
        &root
    ) != EFI_SUCCESS) {
        PRINT(L"failed to open drive volume\r\n");
        goto fail;
    }

    if(root->Open(
        root,
        &core,
        file_name,
        EFI_FILE_MODE_READ,
        0
    ) != EFI_SUCCESS) {
        PRINT(L"failed to open core file\r\n");
        goto fail;
    }

    if(core->GetInfo(
        core,
        &file_info_guid,
        &file_info_size,
        &file_info
    ) != EFI_SUCCESS) {
        PRINT(L"failed to get core file info\r\n");
        goto fail;
    }

    if(s_boot_services->AllocatePages(
        AllocateAnyPages,
        EfiBootServicesCode,
        (file_info.file_info.FileSize + 0xfff) / 0x1000,
        (EFI_PHYSICAL_ADDRESS*)&code
    ) != EFI_SUCCESS) {
        PRINT(L"failed to allocate space for core\r\n");
        goto fail;
    }

    if(core->Read(
        core,
        &file_info.file_info.FileSize,
        code
    ) != EFI_SUCCESS) {
        PRINT(L"failed to read core file to buffer\r\n");
        goto fail;
    }

    core->Close(core);
    root->Close(root);

    return code;

    fail: {
        return NULL;
    }
}

VOID* compose_core_buffer(
    VOID*  frame_buffer,
    UINTN  frame_x,
    UINTN  frame_y,
    UINTN  frame_size,
    UINTN  frame_line,
    UINTN* memory_map_key
) {
    VOID*                  descriptors       = NULL;
    VOID*                  core_buffer       = NULL;
    EFI_MEMORY_DESCRIPTOR* descriptor_i      = NULL;
    UINTN                  memory_map_size   = 0;
    UINTN                  memory_dscr_size  = 0;
    UINTN                  memory_dscr_count = 0;
    UINT32                 memory_dscr_ver   = 0;

    if(s_boot_services->GetMemoryMap(
        &memory_map_size,
        NULL,
        memory_map_key,
        &memory_dscr_size,
        &memory_dscr_ver
    ) != EFI_BUFFER_TOO_SMALL) {
        PRINT(L"failed to get memory map size\r\n");
        goto fail;
    }

    memory_map_size   = memory_map_size + 32 * memory_dscr_size;
    memory_dscr_count = memory_map_size / memory_dscr_size;

    if(s_boot_services->AllocatePages(
        AllocateAnyPages,
        EfiLoaderData,
        ((memory_map_size + 0x0FFF) / 0x1000),
        (EFI_PHYSICAL_ADDRESS*)&descriptors
    ) != EFI_SUCCESS) {
        PRINT(L"failed to allocate memory map src\r\n");
        goto fail;
    }

    if(s_boot_services->AllocatePages(
        AllocateAnyPages,
        EfiLoaderData,
        (sizeof(core_data_t) + memory_dscr_count * sizeof(memory_descriptor_t) + 0x0FFF) / 0x1000,
        (EFI_PHYSICAL_ADDRESS*)&core_buffer
    ) != EFI_SUCCESS) {
        PRINT(L"failed to allocate memory map dst\r\n");
        goto fail;
    }

    if(s_boot_services->GetMemoryMap(
        &memory_map_size,
        descriptors,
        memory_map_key,
        &memory_dscr_size,
        &memory_dscr_ver
    ) != EFI_SUCCESS) {
        PRINT(L"failed to get memory map\r\n");
        goto fail;
    }

    memory_dscr_count = memory_map_size / memory_dscr_size;

    *((core_data_t*)core_buffer) = (core_data_t) {
        .descriptor_count = memory_dscr_count,
        .frame_buffer     = frame_buffer,
        .frame_x          = frame_x,
        .frame_y          = frame_y,
        .frame_size       = frame_size,
        .frame_line       = frame_line
    };
    for(UINT64 i = 0; i != memory_dscr_count; i++) {
        descriptor_i = (EFI_MEMORY_DESCRIPTOR*)(
            (UINT8*)descriptors + memory_dscr_size * i
        );

        ((memory_descriptor_t*)((UINT8*)core_buffer + sizeof(core_data_t)))[i] = (memory_descriptor_t) {
            .type       = (UINTN)descriptor_i->Type,
            .size       = (UINTN)descriptor_i->NumberOfPages,
            .attributes = (UINTN)descriptor_i->Attribute,
            .address    = (VOID*)descriptor_i->PhysicalStart
        };
    }
    
    /*s_boot_services->FreePool(descriptors);*/
    return core_buffer;

    fail: {
        return NULL;
    }
}

EFI_STATUS EFIAPI efi_main(
    EFI_HANDLE        image_handle,
    EFI_SYSTEM_TABLE* system_table
) {
    /* protocols */
    EFI_GUID                         loaded_image_guid     = EFI_LOADED_IMAGE_PROTOCOL_GUID;
    EFI_GUID                         file_system_guid      = EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID;
    EFI_GUID                         graphics_guid         = EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID;
    
    EFI_LOADED_IMAGE_PROTOCOL*       loaded_image          = NULL;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL* file_system           = NULL;
    EFI_GRAPHICS_OUTPUT_PROTOCOL*    graphics              = NULL;

    EFI_HANDLE                       device_handle         = NULL;
    EFI_HANDLE*                      graphics_handles      = NULL;
    UINTN                            graphics_handle_count = 0;

    /* other */
    VOID*                            core_program          = NULL;
    VOID*                            core_buffer           = NULL;
    UINTN                            memory_map_size       = 0;
    UINTN                            memory_dscr_size      = 0;
    UINT32                           memory_dsrc_ver       = 0;
    UINTN                            memory_map_key        = 0;

    s_console_out   = system_table->ConOut;
    s_boot_services = system_table->BootServices;

    /* load protocols */ {
        if(s_boot_services->HandleProtocol(
            image_handle,
            &loaded_image_guid,
            (void**)&loaded_image
        ) != EFI_SUCCESS) {
            PRINT(L"failed to handle loaded image protocol\r\n");
            goto fail;
        }

        if(s_boot_services->HandleProtocol(
            loaded_image->DeviceHandle,
            &file_system_guid,
            (void**)&file_system
        ) != EFI_SUCCESS) {
            PRINT(L"failed to get file system protocol\r\n");
            goto fail;
        }
        
        if(s_boot_services->LocateHandleBuffer(
            ByProtocol,
            &graphics_guid,
            NULL,
            &graphics_handle_count,
            &graphics_handles
        ) != EFI_SUCCESS) {
            PRINT(L"failed to locate graphics protocol handles buffer\r\n");
            goto fail;
        }

        for(UINT32 i = 0; i != graphics_handle_count; i++) {
            if(s_boot_services->HandleProtocol(
                graphics_handles[i],
                &graphics_guid,
                (void**)&graphics
            ) == EFI_SUCCESS) {
                goto located_gop;
            }
        }

        PRINT(L"failed to handle graphics protocol\r\n");
        goto fail;
       
        located_gop: {};
    }

    core_program = load_core_to_ram(
        file_system,
        L"x64\\core.bin"
    );
    if(core_program == NULL) {
        PRINT(L"failed to load core to ram\r\n");
        goto fail;
    }

    core_buffer = compose_core_buffer(
        (VOID*)graphics->Mode->FrameBufferBase,
        graphics->Mode->Info->HorizontalResolution,
        graphics->Mode->Info->VerticalResolution,
        graphics->Mode->FrameBufferSize,
        graphics->Mode->Info->PixelsPerScanLine,
        &memory_map_key
    );
    if(core_buffer == NULL) {
        PRINT(L"failed to create core buffer\r\n");
        goto fail;
    }

    PRINT(L"exiting boot services...\r\n");
    s_boot_services->Stall(1000000);
    s_boot_services->GetMemoryMap(
        &memory_map_size,
        NULL,
        &memory_map_key,
        &memory_dscr_size,
        &memory_dsrc_ver
    );
    if(s_boot_services->ExitBootServices(
        image_handle, 
        memory_map_key
    ) != EFI_SUCCESS) {
        PRINT(L"failed to exit boot services");
        goto fail;
    }
    jump_to_core(core_buffer, core_program);

    fail: {
        s_boot_services->Stall(1000000);
        return EFI_NOT_STARTED;
    }
}
