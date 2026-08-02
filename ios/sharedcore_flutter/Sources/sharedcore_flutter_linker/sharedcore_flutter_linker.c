#include "sharedcore_flutter_linker.h"
#include <stddef.h>
#include <stdint.h>

#if defined(__aarch64__)
extern void frb_create_shutdown_callback(void);
extern void frb_dart_fn_deliver_output(void);
extern void frb_dart_opaque_dart2rust_encode(void);
extern void frb_dart_opaque_drop_thread_box_persistent_handle(void);
extern void frb_dart_opaque_rust2dart_decode(void);
extern void frb_free_wire_sync_rust2dart_dco(void);
extern void frb_free_wire_sync_rust2dart_sse(void);
extern void frb_get_rust_content_hash(void);
extern void frb_init_frb_dart_api_dl(void);
extern void frb_pde_ffi_dispatcher_primary(void);
extern void frb_pde_ffi_dispatcher_sync(void);
extern void frb_rust_vec_u8_free(void);
extern void frb_rust_vec_u8_new(void);
extern void frb_rust_vec_u8_resize(void);
extern void frbgen_sharedcore_flutter_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerRustSharedCoreClient(void);
extern void frbgen_sharedcore_flutter_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerRustSharedCoreClient(void);

static void *volatile sharedcore_flutter_symbols[] = {
      (void *)&frb_create_shutdown_callback,
      (void *)&frb_dart_fn_deliver_output,
      (void *)&frb_dart_opaque_dart2rust_encode,
      (void *)&frb_dart_opaque_drop_thread_box_persistent_handle,
      (void *)&frb_dart_opaque_rust2dart_decode,
      (void *)&frb_free_wire_sync_rust2dart_dco,
      (void *)&frb_free_wire_sync_rust2dart_sse,
      (void *)&frb_get_rust_content_hash,
      (void *)&frb_init_frb_dart_api_dl,
      (void *)&frb_pde_ffi_dispatcher_primary,
      (void *)&frb_pde_ffi_dispatcher_sync,
      (void *)&frb_rust_vec_u8_free,
      (void *)&frb_rust_vec_u8_new,
      (void *)&frb_rust_vec_u8_resize,
      (void *)&frbgen_sharedcore_flutter_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerRustSharedCoreClient,
      (void *)&frbgen_sharedcore_flutter_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerRustSharedCoreClient,
};
static volatile uintptr_t sharedcore_flutter_symbol_sink;
#endif

int sharedcore_flutter_retain_symbols(void) {
#if defined(__aarch64__)
  uintptr_t checksum = 0;
  const size_t count = sizeof(sharedcore_flutter_symbols) /
                       sizeof(sharedcore_flutter_symbols[0]);
  for (size_t index = 0; index < count; ++index) {
    checksum ^= (uintptr_t)sharedcore_flutter_symbols[index];
  }
  sharedcore_flutter_symbol_sink = checksum;
  return (int)count;
#else
  return 0;
#endif
}

__attribute__((constructor)) static void sharedcore_flutter_initialize_symbols(void) {
  (void)sharedcore_flutter_retain_symbols();
}
