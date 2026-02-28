#ifndef ZIDE_EDITOR_FFI_H
#define ZIDE_EDITOR_FFI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ZideEditorHandle ZideEditorHandle;

typedef enum ZideEditorStatus {
    ZIDE_EDITOR_STATUS_OK = 0,
    ZIDE_EDITOR_STATUS_INVALID_ARGUMENT = 1,
    ZIDE_EDITOR_STATUS_OUT_OF_MEMORY = 2,
    ZIDE_EDITOR_STATUS_BACKEND_ERROR = 3,
} ZideEditorStatus;

typedef struct ZideEditorStringBuffer {
    const uint8_t *ptr;
    size_t len;
    void *_ctx;
} ZideEditorStringBuffer;

int zide_editor_create(ZideEditorHandle **out_handle);
void zide_editor_destroy(ZideEditorHandle *handle);

int zide_editor_set_text(ZideEditorHandle *handle, const uint8_t *bytes, size_t len);
int zide_editor_insert_text(ZideEditorHandle *handle, const uint8_t *bytes, size_t len);
int zide_editor_text_alloc(ZideEditorHandle *handle, ZideEditorStringBuffer *out_string);
void zide_editor_string_free(ZideEditorStringBuffer *string);

int zide_editor_set_cursor_offset(ZideEditorHandle *handle, size_t offset);
int zide_editor_cursor_offset(ZideEditorHandle *handle, size_t *out_offset);

int zide_editor_undo(ZideEditorHandle *handle, uint8_t *out_changed);
int zide_editor_redo(ZideEditorHandle *handle, uint8_t *out_changed);

int zide_editor_line_count(ZideEditorHandle *handle, size_t *out_lines);
int zide_editor_total_len(ZideEditorHandle *handle, size_t *out_len);

const char *zide_editor_status_string(int status);

#ifdef __cplusplus
}
#endif

#endif
