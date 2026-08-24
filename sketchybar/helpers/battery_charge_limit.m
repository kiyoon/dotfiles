#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <errno.h>
#import <stdint.h>
#import <stdlib.h>
#import <string.h>

// PowerUI is private, but macOS 26.4 exposes the same manual charge-limit
// operation through System Settings and Shortcuts. Resolve it at runtime so an
// older macOS release or a desktop Mac fails cleanly instead of preventing the
// rest of SketchyBar from loading.
@interface PowerUISmartChargeClient : NSObject
- (instancetype)initWithClientName:(NSString *)name;
- (BOOL)isMCLSupported;
- (NSArray<NSNumber *> *)availableChargeLimitsWithError:(NSError **)error;
- (uint8_t)getMCLLimitWithError:(NSError **)error;
- (BOOL)setMCLLimit:(uint8_t)limit error:(NSError **)error;
- (uint64_t)isMCLCurrentlyEnabled:(NSError **)error;
- (BOOL)enableMCL:(NSError **)error;
- (uint64_t)isSmartChargingCurrentlyEnabled:(NSError **)error;
- (BOOL)enableSmartCharging:(NSError **)error;
@end

static int reportError(NSString *operation, NSError *error) {
    NSString *message = error.localizedDescription ?: @"unknown PowerUI error";
    fprintf(stderr, "%s failed: %s\n", operation.UTF8String, message.UTF8String);
    return 1;
}

static BOOL readStatus(PowerUISmartChargeClient *client,
                       uint8_t *limit,
                       uint64_t *manualLimitState,
                       uint64_t *optimizedChargingState) {
    NSError *error = nil;
    *limit = [client getMCLLimitWithError:&error];
    if (error != nil) {
        reportError(@"getMCLLimit", error);
        return NO;
    }

    error = nil;
    *manualLimitState = [client isMCLCurrentlyEnabled:&error];
    if (error != nil) {
        reportError(@"isMCLCurrentlyEnabled", error);
        return NO;
    }

    error = nil;
    *optimizedChargingState = [client isSmartChargingCurrentlyEnabled:&error];
    if (error != nil) {
        reportError(@"isSmartChargingCurrentlyEnabled", error);
        return NO;
    }

    return YES;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        BOOL statusMode = argc == 1 ||
                          (argc == 2 && strcmp(argv[1], "status") == 0);
        BOOL setMode = argc == 3 && strcmp(argv[1], "set") == 0;
        if (!statusMode && !setMode) {
            fprintf(stderr, "usage: %s [status | set PERCENT]\n", argv[0]);
            return 2;
        }

        void *powerUI = dlopen(
            "/System/Library/PrivateFrameworks/PowerUI.framework/PowerUI",
            RTLD_NOW | RTLD_LOCAL);
        if (powerUI == NULL) {
            fprintf(stderr, "PowerUI unavailable: %s\n", dlerror());
            return 3;
        }

        Class clientClass = NSClassFromString(@"PowerUISmartChargeClient");
        if (clientClass == Nil) {
            fprintf(stderr, "PowerUISmartChargeClient unavailable\n");
            return 3;
        }
        if (![(id)clientClass
                instancesRespondToSelector:@selector(initWithClientName:)]) {
            fprintf(stderr, "PowerUISmartChargeClient API unavailable\n");
            return 3;
        }

        PowerUISmartChargeClient *client =
            [[(id)clientClass alloc] initWithClientName:@"sketchybar-charge-limit"];
        if (client == nil) {
            fprintf(stderr, "PowerUISmartChargeClient initialization failed\n");
            return 3;
        }

        SEL requiredSelectors[] = {
            @selector(isMCLSupported),
            @selector(availableChargeLimitsWithError:),
            @selector(getMCLLimitWithError:),
            @selector(setMCLLimit:error:),
            @selector(isMCLCurrentlyEnabled:),
            @selector(enableMCL:),
            @selector(isSmartChargingCurrentlyEnabled:),
            @selector(enableSmartCharging:),
        };
        for (size_t index = 0;
             index < sizeof(requiredSelectors) / sizeof(requiredSelectors[0]);
             index++) {
            if (![client respondsToSelector:requiredSelectors[index]]) {
                fprintf(stderr, "PowerUISmartChargeClient API unavailable\n");
                return 3;
            }
        }

        if (!client.isMCLSupported) {
            fprintf(stderr, "native manual charge limits unsupported\n");
            return 3;
        }

        NSError *error = nil;
        NSArray<NSNumber *> *available =
            [client availableChargeLimitsWithError:&error];
        if (available == nil || error != nil) {
            return reportError(@"availableChargeLimits", error);
        }

        if (setMode) {
            char *end = NULL;
            errno = 0;
            unsigned long parsed = strtoul(argv[2], &end, 10);
            if (errno != 0 || end == argv[2] || *end != '\0' ||
                parsed > UINT8_MAX || ![available containsObject:@(parsed)]) {
                fprintf(stderr, "unsupported limit; available=%s\n",
                        available.description.UTF8String);
                return 2;
            }

            // Optimized Battery Charging is independent of the fixed limit.
            // Ensure it is active first so choosing 100 never turns protection
            // into an unprotected always-full state.
            error = nil;
            uint64_t optimizedState =
                [client isSmartChargingCurrentlyEnabled:&error];
            if (error != nil) {
                return reportError(@"isSmartChargingCurrentlyEnabled", error);
            }
            if (optimizedState != 1) {
                error = nil;
                if (![client enableSmartCharging:&error] || error != nil) {
                    return reportError(@"enableSmartCharging", error);
                }
            }

            uint8_t desired = (uint8_t)parsed;
            error = nil;
            if (![client setMCLLimit:desired error:&error] || error != nil) {
                return reportError(@"setMCLLimit", error);
            }

            // A sub-100 target is useful only while the manual policy is
            // engaged. At 100, leave PowerUI's native representation alone;
            // optimized charging above remains independently enabled.
            if (desired < 100) {
                error = nil;
                uint64_t manualState =
                    [client isMCLCurrentlyEnabled:&error];
                if (error != nil) {
                    return reportError(@"isMCLCurrentlyEnabled", error);
                }
                if (manualState != 1) {
                    error = nil;
                    if (![client enableMCL:&error] || error != nil) {
                        return reportError(@"enableMCL", error);
                    }
                }
            }
        }

        uint8_t limit = 0;
        uint64_t manualState = 0;
        uint64_t optimizedState = 0;
        if (!readStatus(client, &limit, &manualState, &optimizedState)) {
            return 1;
        }

        if (setMode) {
            uint8_t desired = (uint8_t)strtoul(argv[2], NULL, 10);
            if (limit != desired || optimizedState != 1 ||
                (desired < 100 && manualState != 1)) {
                fprintf(stderr,
                        "charge-limit verification failed: "
                        "limit=%u mcl=%llu optimized=%llu\n",
                        limit, (unsigned long long)manualState,
                        (unsigned long long)optimizedState);
                return 1;
            }
        }

        printf("limit=%u mcl=%llu optimized=%llu\n", limit,
               (unsigned long long)manualState,
               (unsigned long long)optimizedState);
        (void)powerUI;
    }
    return 0;
}
