/*
 * set-dynamic-resolution.c
 *
 * Enables "Dynamic Resolution" (SLSDisplaySetDynamicGeometryEnabled) for every
 * display that supports it.  This is the same private SkyLight API that
 * System Settings > Displays uses for the "Dynamic resolution" toggle.
 *
 * Compile:
 *   cc -framework CoreGraphics -o set-dynamic-resolution set-dynamic-resolution.c
 *
 * Usage:
 *   ./set-dynamic-resolution          # enable on all displays that support it
 *   ./set-dynamic-resolution --off    # disable
 *   ./set-dynamic-resolution --query  # print current state and exit 0
 */

#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

typedef bool (*SLSFn_Supports)(CGDirectDisplayID);
typedef bool (*SLSFn_IsEnabled)(CGDirectDisplayID);
typedef void (*SLSFn_SetEnabled)(CGDirectDisplayID, bool);

int main(int argc, char *argv[]) {
    bool enable = true;
    bool query  = false;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--off")   == 0) enable = false;
        if (strcmp(argv[i], "--query") == 0) query  = true;
    }

    void *lib = dlopen(
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        RTLD_NOW | RTLD_LOCAL);
    if (!lib) {
        fprintf(stderr, "ERROR: Could not load SkyLight framework: %s\n", dlerror());
        return 1;
    }

    SLSFn_Supports   supports   = (SLSFn_Supports)  dlsym(lib, "SLSDisplaySupportsDynamicGeometry");
    SLSFn_IsEnabled  isEnabled  = (SLSFn_IsEnabled) dlsym(lib, "SLSDisplayIsDynamicGeometryEnabled");
    SLSFn_SetEnabled setEnabled = (SLSFn_SetEnabled)dlsym(lib, "SLSDisplaySetDynamicGeometryEnabled");

    if (!supports || !setEnabled) {
        fprintf(stderr, "ERROR: SkyLight symbols not found (macOS version mismatch?)\n");
        return 1;
    }

    CGDirectDisplayID displays[16];
    uint32_t count = 0;
    CGGetOnlineDisplayList(16, displays, &count);

    int acted = 0;
    for (uint32_t i = 0; i < count; i++) {
        CGDirectDisplayID id = displays[i];
        bool sup = supports(id);
        bool cur = isEnabled ? isEnabled(id) : false;

        if (query) {
            printf("display %u: supportsDynamicGeometry=%s  isEnabled=%s\n",
                   id, sup ? "YES" : "NO", cur ? "YES" : "NO");
            continue;
        }

        if (sup) {
            setEnabled(id, enable);
            printf("display %u: dynamic geometry -> %s\n",
                   id, enable ? "ON" : "OFF");
            acted++;
        }
    }

    if (!query && acted == 0) {
        fprintf(stderr, "WARNING: No displays found that support dynamic geometry\n");
        return 1;
    }

    return 0;
}
