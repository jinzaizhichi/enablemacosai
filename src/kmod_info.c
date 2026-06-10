/*
 * kmod_info.c — provides the `_kmod_info` symbol the kext linker requires.
 * Without this, `kmutil load` fails with "must have a _kmod_info symbol".
 * Built and linked alongside RegionSpoof.cpp (see ../BUILD.md).
 */
#include <mach/mach_types.h>
#include <mach/kmod.h>

extern kern_return_t _start(kmod_info_t *ki, void *data);
extern kern_return_t _stop(kmod_info_t *ki, void *data);

KMOD_EXPLICIT_DECL(com.local.RegionSpoof, "1.0.0", _start, _stop)
__private_extern__ kmod_start_func_t *_realmain = 0;
__private_extern__ kmod_stop_func_t *_antimain = 0;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;
