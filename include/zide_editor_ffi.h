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

enum {
    ZIDE_EDITOR_STRING_ABI_VERSION = 1,
};

typedef struct ZideEditorStringBuffer {
    uint32_t abi_version;
    uint32_t struct_size;
    const uint8_t *ptr;
    size_t len;
    void *_ctx;
} ZideEditorStringBuffer;

typedef struct ZideEditorCaretOffset {
    size_t offset;
} ZideEditorCaretOffset;

typedef struct ZideEditorSearchMatch {
    size_t start;
    size_t end;
} ZideEditorSearchMatch;

int zide_editor_create(ZideEditorHandle **out_handle);
void zide_editor_destroy(ZideEditorHandle *handle);

int zide_editor_set_text(ZideEditorHandle *handle, const uint8_t *bytes, size_t len);
int zide_editor_insert_text(ZideEditorHandle *handle, const uint8_t *bytes, size_t len);
int zide_editor_replace_range(ZideEditorHandle *handle, size_t start, size_t end, const uint8_t *bytes, size_t len);
int zide_editor_delete_range(ZideEditorHandle *handle, size_t start, size_t end);
int zide_editor_begin_undo_group(ZideEditorHandle *handle);
int zide_editor_end_undo_group(ZideEditorHandle *handle);
int zide_editor_text_alloc(ZideEditorHandle *handle, ZideEditorStringBuffer *out_string);
void zide_editor_string_free(ZideEditorStringBuffer *string);
uint32_t zide_editor_string_abi_version(void);

int zide_editor_set_cursor_offset(ZideEditorHandle *handle, size_t offset);
int zide_editor_primary_caret_offset(ZideEditorHandle *handle, size_t *out_offset);
int zide_editor_aux_caret_count(ZideEditorHandle *handle, size_t *out_count);
int zide_editor_aux_caret_get(ZideEditorHandle *handle, size_t index, size_t *out_offset);
int zide_editor_clear_selections(ZideEditorHandle *handle);
int zide_editor_set_carets(
    ZideEditorHandle *handle,
    size_t primary_offset,
    const ZideEditorCaretOffset *aux,
    size_t aux_count
);
int zide_editor_cursor_offset(ZideEditorHandle *handle, size_t *out_offset);

int zide_editor_undo(ZideEditorHandle *handle, uint8_t *out_changed);
int zide_editor_redo(ZideEditorHandle *handle, uint8_t *out_changed);

int zide_editor_line_count(ZideEditorHandle *handle, size_t *out_lines);
int zide_editor_total_len(ZideEditorHandle *handle, size_t *out_len);

int zide_editor_search_set_query(ZideEditorHandle *handle, const uint8_t *bytes, size_t len, uint8_t use_regex);
int zide_editor_search_match_count(ZideEditorHandle *handle, size_t *out_count);
int zide_editor_search_match_get(ZideEditorHandle *handle, size_t index, ZideEditorSearchMatch *out_match);
int zide_editor_search_active_index(ZideEditorHandle *handle, size_t *out_index, uint8_t *out_has_active);
int zide_editor_search_next(ZideEditorHandle *handle, uint8_t *out_activated);
int zide_editor_search_prev(ZideEditorHandle *handle, uint8_t *out_activated);
int zide_editor_search_replace_active(ZideEditorHandle *handle, const uint8_t *bytes, size_t len, uint8_t *out_replaced);
int zide_editor_search_replace_all(ZideEditorHandle *handle, const uint8_t *bytes, size_t len, size_t *out_count);

const char *zide_editor_status_string(int status);

#ifdef __cplusplus
}
#endif

#endif
