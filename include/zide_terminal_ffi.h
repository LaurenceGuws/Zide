#ifndef ZIDE_TERMINAL_FFI_H
#define ZIDE_TERMINAL_FFI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ZideTerminalHandle ZideTerminalHandle;

typedef enum ZideTerminalStatus {
    ZIDE_TERMINAL_STATUS_OK = 0,
    ZIDE_TERMINAL_STATUS_INVALID_ARGUMENT = 1,
    ZIDE_TERMINAL_STATUS_OUT_OF_MEMORY = 2,
    ZIDE_TERMINAL_STATUS_BACKEND_ERROR = 3,
} ZideTerminalStatus;

typedef enum ZideTerminalEventKind {
    ZIDE_TERMINAL_EVENT_NONE = 0,
    ZIDE_TERMINAL_EVENT_TITLE_CHANGED = 1,
    ZIDE_TERMINAL_EVENT_CWD_CHANGED = 2,
    ZIDE_TERMINAL_EVENT_CLIPBOARD_WRITE = 3,
    ZIDE_TERMINAL_EVENT_CHILD_EXIT = 4,
    ZIDE_TERMINAL_EVENT_ALIVE_CHANGED = 5,
    ZIDE_TERMINAL_EVENT_REDRAW_READY = 6,
} ZideTerminalEventKind;

enum {
    ZIDE_TERMINAL_SNAPSHOT_ABI_VERSION = 1,
    ZIDE_TERMINAL_EVENT_ABI_VERSION = 3,
    ZIDE_TERMINAL_SCROLLBACK_ABI_VERSION = 1,
    ZIDE_TERMINAL_RENDERER_METADATA_ABI_VERSION = 1,
    ZIDE_TERMINAL_METADATA_ABI_VERSION = 1,
    ZIDE_TERMINAL_REDRAW_STATE_ABI_VERSION = 1,
};

enum {
    ZIDE_TERMINAL_GLYPH_CLASS_BOX = 1u << 0,
    ZIDE_TERMINAL_GLYPH_CLASS_BOX_ROUNDED = 1u << 1,
    ZIDE_TERMINAL_GLYPH_CLASS_GRAPH = 1u << 2,
    ZIDE_TERMINAL_GLYPH_CLASS_BRAILLE = 1u << 3,
    ZIDE_TERMINAL_GLYPH_CLASS_POWERLINE = 1u << 4,
    ZIDE_TERMINAL_GLYPH_CLASS_POWERLINE_ROUNDED = 1u << 5,
};

enum {
    ZIDE_TERMINAL_DAMAGE_POLICY_ADVISORY_BOUNDS = 1u << 0,
    ZIDE_TERMINAL_DAMAGE_POLICY_FULL_REDRAW_SAFE_DEFAULT = 1u << 1,
};

typedef struct ZideTerminalCreateConfig {
    uint16_t rows;
    uint16_t cols;
    uint32_t scrollback_rows;
    uint8_t cursor_shape;
    uint8_t cursor_blink;
} ZideTerminalCreateConfig;

typedef struct ZideTerminalColor {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t a;
} ZideTerminalColor;

typedef struct ZideTerminalCell {
    uint32_t codepoint;
    uint8_t combining_len;
    uint8_t width;
    uint8_t height;
    uint8_t x;
    uint8_t y;
    uint32_t combining_0;
    uint32_t combining_1;
    ZideTerminalColor fg;
    ZideTerminalColor bg;
    ZideTerminalColor underline_color;
    uint8_t bold;
    uint8_t blink;
    uint8_t blink_fast;
    uint8_t reverse;
    uint8_t underline;
    uint8_t _padding0[3];
    uint32_t link_id;
} ZideTerminalCell;

typedef struct ZideTerminalSnapshot {
    uint32_t abi_version;
    uint32_t struct_size;
    uint32_t rows;
    uint32_t cols;
    uint64_t generation;
    size_t cell_count;
    const ZideTerminalCell *cells;
    uint32_t cursor_row;
    uint32_t cursor_col;
    uint8_t cursor_visible;
    uint8_t cursor_shape;
    uint8_t cursor_blink;
    uint8_t alt_active;
    uint8_t screen_reverse;
    uint8_t has_damage;
    uint32_t damage_start_row;
    uint32_t damage_end_row;
    uint32_t damage_start_col;
    uint32_t damage_end_col;
    const uint8_t *title_ptr;
    size_t title_len;
    const uint8_t *cwd_ptr;
    size_t cwd_len;
    void *_ctx;
} ZideTerminalSnapshot;

typedef struct ZideTerminalScrollbackBuffer {
    uint32_t abi_version;
    uint32_t struct_size;
    uint32_t total_rows;
    uint32_t start_row;
    uint32_t row_count;
    uint32_t cols;
    size_t cell_count;
    const ZideTerminalCell *cells;
    void *_ctx;
} ZideTerminalScrollbackBuffer;

typedef struct ZideTerminalMetadata {
    uint32_t abi_version;
    uint32_t struct_size;
    uint32_t scrollback_count;
    uint32_t scrollback_offset;
    uint8_t alive;
    uint8_t has_exit_code;
    uint8_t _padding0[2];
    int32_t exit_code;
    const uint8_t *title_ptr;
    size_t title_len;
    const uint8_t *cwd_ptr;
    size_t cwd_len;
    void *_ctx;
} ZideTerminalMetadata;

typedef struct ZideTerminalRedrawState {
    uint32_t abi_version;
    uint32_t struct_size;
    uint64_t published_generation;
    uint64_t acknowledged_generation;
    uint8_t needs_redraw;
    uint8_t _padding0[7];
} ZideTerminalRedrawState;

typedef struct ZideTerminalKeyEvent {
    uint32_t key;
    uint8_t modifiers;
} ZideTerminalKeyEvent;

typedef struct ZideTerminalMouseEvent {
    uint8_t kind;
    uint8_t button;
    uint32_t row;
    uint32_t col;
    uint32_t pixel_x;
    uint32_t pixel_y;
    uint8_t has_pixel;
    uint8_t modifiers;
    uint8_t buttons_down;
} ZideTerminalMouseEvent;

typedef struct ZideTerminalEvent {
    int kind;
    const uint8_t *data_ptr;
    size_t data_len;
    int32_t int0;
    int32_t int1;
} ZideTerminalEvent;

typedef struct ZideTerminalEventBuffer {
    const ZideTerminalEvent *events;
    size_t count;
    void *_ctx;
} ZideTerminalEventBuffer;

typedef struct ZideTerminalStringBuffer {
    const uint8_t *ptr;
    size_t len;
    void *_ctx;
} ZideTerminalStringBuffer;

typedef struct ZideTerminalRendererMetadata {
    uint32_t abi_version;
    uint32_t struct_size;
    uint32_t codepoint;
    uint32_t glyph_class_flags;
    uint32_t damage_policy_flags;
} ZideTerminalRendererMetadata;

int zide_terminal_create(const ZideTerminalCreateConfig *config, ZideTerminalHandle **out_handle);
void zide_terminal_destroy(ZideTerminalHandle *handle);
int zide_terminal_start(ZideTerminalHandle *handle, const char *shell);
int zide_terminal_poll(ZideTerminalHandle *handle);
int zide_terminal_resize(ZideTerminalHandle *handle, uint16_t cols, uint16_t rows, uint16_t cell_width, uint16_t cell_height);
int zide_terminal_send_bytes(ZideTerminalHandle *handle, const uint8_t *bytes, size_t len);
int zide_terminal_send_text(ZideTerminalHandle *handle, const uint8_t *text, size_t len);
int zide_terminal_feed_output(ZideTerminalHandle *handle, const uint8_t *bytes, size_t len);
int zide_terminal_close_input(ZideTerminalHandle *handle);
int zide_terminal_present_ack(ZideTerminalHandle *handle, uint64_t generation);
int zide_terminal_acknowledged_generation(ZideTerminalHandle *handle, uint64_t *out_generation);
int zide_terminal_published_generation(ZideTerminalHandle *handle, uint64_t *out_generation);
int zide_terminal_redraw_state(ZideTerminalHandle *handle, ZideTerminalRedrawState *out_state);
uint8_t zide_terminal_needs_redraw(ZideTerminalHandle *handle);
int zide_terminal_send_key(ZideTerminalHandle *handle, const ZideTerminalKeyEvent *event);
int zide_terminal_send_mouse(ZideTerminalHandle *handle, const ZideTerminalMouseEvent *event);
int zide_terminal_snapshot_acquire(ZideTerminalHandle *handle, ZideTerminalSnapshot *out_snapshot);
void zide_terminal_snapshot_release(ZideTerminalSnapshot *snapshot);
int zide_terminal_scrollback_acquire(
    ZideTerminalHandle *handle,
    uint32_t start_row,
    uint32_t max_rows,
    ZideTerminalScrollbackBuffer *out_buffer);
void zide_terminal_scrollback_release(ZideTerminalScrollbackBuffer *scrollback);
int zide_terminal_metadata_acquire(ZideTerminalHandle *handle, ZideTerminalMetadata *out_metadata);
void zide_terminal_metadata_release(ZideTerminalMetadata *metadata);
int zide_terminal_event_drain(ZideTerminalHandle *handle, ZideTerminalEventBuffer *out_events);
void zide_terminal_events_free(ZideTerminalEventBuffer *events);
uint8_t zide_terminal_is_alive(ZideTerminalHandle *handle);
int zide_terminal_selection_text(ZideTerminalHandle *handle, ZideTerminalStringBuffer *out_string);
int zide_terminal_scrollback_plain_text(ZideTerminalHandle *handle, ZideTerminalStringBuffer *out_string);
int zide_terminal_scrollback_ansi_text(ZideTerminalHandle *handle, ZideTerminalStringBuffer *out_string);
void zide_terminal_string_free(ZideTerminalStringBuffer *string);
int zide_terminal_child_exit_status(ZideTerminalHandle *handle, int32_t *out_code, uint8_t *out_has_status);
uint32_t zide_terminal_snapshot_abi_version(void);
uint32_t zide_terminal_event_abi_version(void);
uint32_t zide_terminal_scrollback_abi_version(void);
uint32_t zide_terminal_metadata_abi_version(void);
uint32_t zide_terminal_redraw_state_abi_version(void);
uint32_t zide_terminal_renderer_metadata_abi_version(void);
int zide_terminal_renderer_metadata(uint32_t codepoint, ZideTerminalRendererMetadata *out_metadata);
const char *zide_terminal_status_string(int status);

#ifdef __cplusplus
}
#endif

#endif
