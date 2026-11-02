// kcshim.c — file-backed keychain shim for app clones.
// Interposes SecItemAdd/CopyMatching/Update/Delete UNCONDITIONALLY: every call is
// served from a per-clone plist file ($HOME/Library/Application Support/<KCSHIM_BUNDLE_ID>/KeychainShim/),
// the real Security.framework is never consulted. Clones therefore start with an
// EMPTY keychain (first launch = logged out) and can never see the original's
// tickets — including group-less items like com.tencent.ima.account that an
// ad-hoc signature is allowed to read. KCSHIM_BUNDLE_ID must be unique per clone
// or the clones will share one file store with EACH OTHER.
#include <Security/Security.h>
#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static pthread_mutex_t gLock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableDictionaryRef gStore = NULL;
static char gStorePath[1024];
static char gLogPath[1024];
static int gInit = 0;

static char gNs[256];

static void slog(const char *fmt, const char *a, const char *b, int rc) {
    FILE *f = fopen(gLogPath, "a");
    if (!f) return;
    fprintf(f, "%s svc=%s acct=%s rc=%d\n", fmt, a ? a : "-", b ? b : "-", rc);
    fclose(f);
}

static void cstr(CFTypeRef v, char *out, size_t n) {
    out[0] = 0;
    if (v && CFGetTypeID(v) == CFStringGetTypeID())
        CFStringGetCString((CFStringRef)v, out, (CFIndex)n, kCFStringEncodingUTF8);
}

static void ensureInit(void) {
    if (gInit) return;
    gInit = 1;
    const char *home = getenv("HOME");
    if (!home) home = "/tmp";
    const char *ns = getenv("KCSHIM_BUNDLE_ID");
    if (!ns || !*ns) ns = "default";
    snprintf(gNs, sizeof(gNs), "%s", ns);
    char dir[1024];
    snprintf(dir, sizeof(dir), "%s/Library/Application Support/%s/KeychainShim", home, gNs);
    // mkdir -p
    char tmp[1024]; snprintf(tmp, sizeof(tmp), "%s", dir);
    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') { *p = 0; mkdir(tmp, 448); *p = '/'; } /* 448 == 0700 */
    }
    mkdir(tmp, 448); /* 448 == 0700 */
    snprintf(gStorePath, sizeof(gStorePath), "%s/store.plist", dir);
    snprintf(gLogPath, sizeof(gLogPath), "%s/shim.log", dir);
    { FILE *lf = fopen(gLogPath, "a"); if (lf) { fprintf(lf, "INIT ns=%s pid=%d\n", gNs, (int)getpid()); fclose(lf); } }
    CFDataRef d = NULL;
    FILE *f = fopen(gStorePath, "rb");
    if (f) {
        fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
        if (sz > 0 && sz < 10*1024*1024) {
            UInt8 *buf = malloc(sz);
            if (fread(buf, 1, sz, f) == (size_t)sz)
                d = CFDataCreate(NULL, buf, sz);
            free(buf);
        }
        fclose(f);
    }
    if (d) {
        CFPropertyListRef pl = CFPropertyListCreateWithData(NULL, d, kCFPropertyListMutableContainers, NULL, NULL);
        if (pl && CFGetTypeID(pl) == CFDictionaryGetTypeID())
            gStore = (CFMutableDictionaryRef)pl;
        else if (pl) CFRelease(pl);
        CFRelease(d);
    }
    if (!gStore)
        gStore = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

static void persist(void) {
    CFDataRef d = CFPropertyListCreateData(NULL, gStore, kCFPropertyListBinaryFormat_v1_0, 0, NULL);
    if (!d) return;
    char tmp[1100]; snprintf(tmp, sizeof(tmp), "%s.tmp", gStorePath);
    FILE *f = fopen(tmp, "wb");
    if (f) {
        fwrite(CFDataGetBytePtr(d), 1, CFDataGetLength(d), f);
        fclose(f);
        rename(tmp, gStorePath);
    }
    CFRelease(d);
}

// key = class|service|account
static CFStringRef itemKey(CFDictionaryRef q) {
    char c[64], s[256], a[256];
    cstr(CFDictionaryGetValue(q, kSecClass), c, sizeof(c));
    cstr(CFDictionaryGetValue(q, kSecAttrService), s, sizeof(s));
    cstr(CFDictionaryGetValue(q, kSecAttrAccount), a, sizeof(a));
    return CFStringCreateWithFormat(NULL, NULL, CFSTR("%s|%s|%s"), c, s, a);
}

OSStatus my_SecItemAdd(CFDictionaryRef attrs, CFTypeRef *result) {
    pthread_mutex_lock(&gLock);
    ensureInit();
    char s[256], a[256];
    cstr(CFDictionaryGetValue(attrs, kSecAttrService), s, sizeof(s));
    cstr(CFDictionaryGetValue(attrs, kSecAttrAccount), a, sizeof(a));
    CFStringRef k = itemKey(attrs);
    OSStatus rc = errSecDuplicateItem;
    if (!CFDictionaryGetValue(gStore, k)) {
        CFMutableDictionaryRef item = CFDictionaryCreateMutableCopy(NULL, 0, attrs);
        CFDictionaryRemoveValue(item, kSecAttrAccessGroup); // strip: meaningless in file store
        CFDictionarySetValue(gStore, k, item);
        CFRelease(item);
        persist();
        rc = errSecSuccess;
    }
    if (result) *result = NULL;
    slog("ADD", s, a, rc);
    CFRelease(k);
    pthread_mutex_unlock(&gLock);
    return rc;
}

static int matchItem(CFDictionaryRef q, CFStringRef storedKey, CFDictionaryRef stored) {
    // compare class/service/account when present in query (absent = wildcard)
    CFTypeRef qc = CFDictionaryGetValue(q, kSecClass);
    CFTypeRef qs = CFDictionaryGetValue(q, kSecAttrService);
    CFTypeRef qa = CFDictionaryGetValue(q, kSecAttrAccount);
    if (qc && !CFEqual(qc, CFDictionaryGetValue(stored, kSecClass))) return 0;
    if (qs && !CFEqual(qs, CFDictionaryGetValue(stored, kSecAttrService))) {
        if (!(CFDictionaryGetValue(stored, kSecAttrService) == NULL && qs == NULL)) {
            // stored may lack service while query has one
            if (CFDictionaryGetValue(stored, kSecAttrService) != NULL || qs != NULL) {
                // both-null handled above; compare strings safely
                char b1[256], b2[256];
                cstr(qs, b1, sizeof(b1));
                cstr(CFDictionaryGetValue(stored, kSecAttrService), b2, sizeof(b2));
                if (strcmp(b1, b2) != 0) return 0;
            }
        }
    }
    if (qa) {
        char b1[256], b2[256];
        cstr(qa, b1, sizeof(b1));
        cstr(CFDictionaryGetValue(stored, kSecAttrAccount), b2, sizeof(b2));
        if (strcmp(b1, b2) != 0) return 0;
    }
    (void)storedKey;
    return 1;
}

static CFDictionaryRef buildResult(CFDictionaryRef q, CFDictionaryRef stored) {
    CFTypeRef rd = CFDictionaryGetValue(q, kSecReturnData);
    CFTypeRef ra = CFDictionaryGetValue(q, kSecReturnAttributes);
    int wantData = (rd == NULL && ra == NULL) || (rd == kCFBooleanTrue);
    int wantAttrs = (ra == kCFBooleanTrue) || (rd == NULL && ra == NULL);
    if (!wantData && !wantAttrs) wantAttrs = 1;
    if (wantData && !wantAttrs) {
        CFTypeRef d = CFDictionaryGetValue(stored, kSecValueData);
        if (d) CFRetain(d);
        return (CFDictionaryRef)d; // caller treats as CFTypeRef
    }
    CFMutableDictionaryRef out = CFDictionaryCreateMutableCopy(NULL, 0, stored);
    if (!wantData) CFDictionaryRemoveValue(out, kSecValueData);
    return out;
}

OSStatus my_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    pthread_mutex_lock(&gLock);
    ensureInit();
    char s[256], a[256];
    cstr(CFDictionaryGetValue(query, kSecAttrService), s, sizeof(s));
    cstr(CFDictionaryGetValue(query, kSecAttrAccount), a, sizeof(a));
    CFTypeRef lim = CFDictionaryGetValue(query, kSecMatchLimit);
    int wantAll = (lim == kSecMatchLimitAll);
    CFMutableArrayRef arr = wantAll ? CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks) : NULL;
    CFDictionaryRef first = NULL;
    CFIndex n = CFDictionaryGetCount(gStore);
    const void **keys = malloc(sizeof(void*) * (n ? n : 1));
    const void **vals = malloc(sizeof(void*) * (n ? n : 1));
    CFDictionaryGetKeysAndValues(gStore, keys, vals);
    for (CFIndex i = 0; i < n; i++) {
        if (matchItem(query, keys[i], vals[i])) {
            CFDictionaryRef r = buildResult(query, vals[i]);
            if (!r) continue;
            if (wantAll) {
                CFArrayAppendValue(arr, r);
                CFRelease(r);
            } else {
                first = r;
                break;
            }
        }
    }
    free(keys); free(vals);
    OSStatus rc;
    if (wantAll) {
        if (CFArrayGetCount(arr) == 0) { CFRelease(arr); rc = errSecItemNotFound; if (result) *result = NULL; }
        else { rc = errSecSuccess; if (result) *result = arr; else CFRelease(arr); }
    } else {
        if (!first) { rc = errSecItemNotFound; if (result) *result = NULL; }
        else { rc = errSecSuccess; if (result) *result = first; else CFRelease(first); }
    }
    slog("COPY", s, a, rc);
    pthread_mutex_unlock(&gLock);
    return rc;
}

OSStatus my_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attrsToUpdate) {
    pthread_mutex_lock(&gLock);
    ensureInit();
    char s[256], a[256];
    cstr(CFDictionaryGetValue(query, kSecAttrService), s, sizeof(s));
    cstr(CFDictionaryGetValue(query, kSecAttrAccount), a, sizeof(a));
    OSStatus rc = errSecItemNotFound;
    CFIndex n = CFDictionaryGetCount(gStore);
    const void **keys = malloc(sizeof(void*) * (n ? n : 1));
    const void **vals = malloc(sizeof(void*) * (n ? n : 1));
    CFDictionaryGetKeysAndValues(gStore, keys, vals);
    for (CFIndex i = 0; i < n; i++) {
        if (matchItem(query, keys[i], vals[i])) {
            CFMutableDictionaryRef item = CFDictionaryCreateMutableCopy(NULL, 0, vals[i]);
            CFIndex m = CFDictionaryGetCount(attrsToUpdate);
            const void **uk = malloc(sizeof(void*) * (m ? m : 1));
            const void **uv = malloc(sizeof(void*) * (m ? m : 1));
            CFDictionaryGetKeysAndValues(attrsToUpdate, uk, uv);
            for (CFIndex j = 0; j < m; j++) {
                if (CFEqual(uk[j], kSecClass) || CFEqual(uk[j], kSecAttrAccessGroup)) continue;
                CFDictionarySetValue(item, uk[j], uv[j]);
            }
            free(uk); free(uv);
            CFDictionarySetValue(gStore, keys[i], item);
            CFRelease(item);
            rc = errSecSuccess;
        }
    }
    free(keys); free(vals);
    if (rc == errSecSuccess) persist();
    slog("UPDATE", s, a, rc);
    pthread_mutex_unlock(&gLock);
    return rc;
}

OSStatus my_SecItemDelete(CFDictionaryRef query) {
    pthread_mutex_lock(&gLock);
    ensureInit();
    char s[256], a[256];
    cstr(CFDictionaryGetValue(query, kSecAttrService), s, sizeof(s));
    cstr(CFDictionaryGetValue(query, kSecAttrAccount), a, sizeof(a));
    OSStatus rc = errSecItemNotFound;
    CFIndex n = CFDictionaryGetCount(gStore);
    const void **keys = malloc(sizeof(void*) * (n ? n : 1));
    const void **vals = malloc(sizeof(void*) * (n ? n : 1));
    CFDictionaryGetKeysAndValues(gStore, keys, vals);
    // collect first (mutating while iterating is unsafe)
    CFMutableArrayRef kill = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    for (CFIndex i = 0; i < n; i++)
        if (matchItem(query, keys[i], vals[i])) CFArrayAppendValue(kill, keys[i]);
    free(keys); free(vals);
    if (CFArrayGetCount(kill) > 0) {
        for (CFIndex i = 0; i < CFArrayGetCount(kill); i++)
            CFDictionaryRemoveValue(gStore, CFArrayGetValueAtIndex(kill, i));
        persist();
        rc = errSecSuccess;
    }
    CFRelease(kill);
    slog("DELETE", s, a, rc);
    pthread_mutex_unlock(&gLock);
    return rc;
}

// ---- interposition table ----
#define INTERPOSE(newf, oldf) \
    __attribute__((used)) static const struct { const void *replacement; const void *replacee; } interpose_##newf \
    __attribute__((section("__DATA,__interpose"))) = { (const void*)(unsigned long)&my_##newf, (const void*)(unsigned long)&oldf }

INTERPOSE(SecItemAdd, SecItemAdd);
INTERPOSE(SecItemCopyMatching, SecItemCopyMatching);
INTERPOSE(SecItemUpdate, SecItemUpdate);
INTERPOSE(SecItemDelete, SecItemDelete);

// ---- hardware-identity spoofing (per-clone device) ----
// turing_sdk reads IOPlatformSerialNumber / IOPlatformUUID via IOKit and
// kern.uuid via sysctlbyname; the server binds sessions to that hardware
// identity, so clones on the same Mac look like one device. We serve stable
// per-clone fakes (persisted in the shim dir) and pass everything else through.
#include <IOKit/IOKitLib.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <uuid/uuid.h>

static char gFakeSerial[64] = "";
static char gFakeUUID[64] = "";
static int gHwidInit = 0;

// Real-function lookup MUST NOT use dlsym(RTLD_NEXT): dyld resolves it back
// to our own interposer (even post-main) -> 65000-deep recursion -> stack-guard
// SIGSEGV (seen 2026-10-27, both in-app and in a 20-line test program).
// sysctlbyname is therefore forwarded via sysctlnametomib + the raw
// SYS___sysctl syscall (no dyld involvement, init-safe). No dlsym anywhere.

static void hwidDir(char *out, size_t n) {
    const char *home = getenv("HOME");
    if (!home) home = "/tmp";
    const char *ns = getenv("KCSHIM_BUNDLE_ID");
    if (!ns || !*ns) ns = "default";
    snprintf(out, n, "%s/Library/Application Support/%s/KeychainShim", home, ns);
    char *p;
    for (p = out + 1; *p; p++) { if (*p == '/') { *p = 0; mkdir(out, 448); *p = '/'; } }
    mkdir(out, 448); /* 448 == 0700 */
}

static void hwidLog(const char *line) {
    char dir[1024]; hwidDir(dir, sizeof(dir));
    // gLogPath belongs to the keychain part; rebuild here without touching CF
    const char *home = getenv("HOME");
    if (!home) home = "/tmp";
    const char *ns = getenv("KCSHIM_BUNDLE_ID");
    if (!ns || !*ns) ns = "default";
    char lp[1100]; snprintf(lp, sizeof(lp), "%s/Library/Application Support/%s/KeychainShim/shim.log", home, ns);
    FILE *lf = fopen(lp, "a");
    if (lf) { fprintf(lf, "%s pid=%d\n", line, (int)getpid()); fclose(lf); }
    (void)dir;
}

static void hwidInit(void) {
    if (gHwidInit) return;
    gHwidInit = 1;
    char dir[1024]; hwidDir(dir, sizeof(dir));
    char sp[1100], up[1100];
    snprintf(sp, sizeof(sp), "%s/serial.txt", dir);
    snprintf(up, sizeof(up), "%s/uuid.txt", dir);
    char s[64] = "", u[64] = "";
    FILE *f = fopen(sp, "r");
    if (f) { if (fgets(s, sizeof(s), f)) s[strcspn(s, "\r\n")] = 0; fclose(f); }
    f = fopen(up, "r");
    if (f) { if (fgets(u, sizeof(u), f)) u[strcspn(u, "\r\n")] = 0; fclose(f); }
    if (!s[0] || !u[0]) {
        const char *hex = "0123456789ABCDEF";
        for (int i = 0; i < 12; i++) s[i] = hex[arc4random_uniform(16)];
        s[12] = 0;
        uuid_t uu; uuid_generate_random(uu); uuid_unparse_lower(uu, u);
        f = fopen(sp, "w"); if (f) { fprintf(f, "%s\n", s); fclose(f); }
        f = fopen(up, "w"); if (f) { fprintf(f, "%s\n", u); fclose(f); }
    }
    snprintf(gFakeSerial, sizeof(gFakeSerial), "%s", s);
    snprintf(gFakeUUID, sizeof(gFakeUUID), "%s", u);
    // pre-create the device-id redirect target so readers never see ENOENT
    const char *cd = getenv("WORKBUDDY_CONFIG_DIR");
    if (cd && *cd) {
        char dp[1100]; snprintf(dp, sizeof(dp), "%s/device-id", cd);
        FILE *df = fopen(dp, "r");
        if (!df) { df = fopen(dp, "w"); if (df) { fprintf(df, "%s\n", u); fclose(df); df = NULL; } }
        if (df) fclose(df);
    }
    char line[256]; snprintf(line, sizeof(line), "HWID serial=%s uuid=%s", gFakeSerial, gFakeUUID);
    hwidLog(line);
}

static int isHwidKey(CFStringRef key) {
    if (!key || CFGetTypeID(key) != CFStringGetTypeID()) return 0;
    return CFEqual(key, CFSTR("IOPlatformSerialNumber")) || CFEqual(key, CFSTR("serial-number")) ||
           CFEqual(key, CFSTR("IOPlatformUUID"));
}

CFTypeRef my_IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    int fake = isHwidKey(key);
    if (fake) {
        char kb[128]; cstr(key, kb, sizeof(kb));
        pthread_mutex_lock(&gLock);
        hwidInit();
        pthread_mutex_unlock(&gLock);
        const char *v = (strstr(kb, "UUID") || strstr(kb, "uuid")) ? gFakeUUID : gFakeSerial;
        char line[256]; snprintf(line, sizeof(line), "HW key=%s FAKE", kb);
        hwidLog(line);
        return CFStringCreateWithCString(allocator, v, kCFStringEncodingUTF8);
    }
    // resolve WITHOUT dlsym (it self-resolves, see note above): non-identity
    // keys get NULL. All queried keys are logged — revisit if the SDK
    // proves intolerant of a NULL here.
    hwidLog("HW non-identity key -> NULL");
    return NULL;
}

#include <sys/syscall.h>
int my_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    // surveillance: remember every queried name (first-seen per process)
    if (name) {
        static char seen[32][64]; static int nseen = 0;
        int known = 0;
        for (int i = 0; i < nseen; i++) if (strcmp(seen[i], name) == 0) { known = 1; break; }
        if (!known) {
            if (nseen < 32) { snprintf(seen[nseen], 64, "%s", name); nseen++; }
            char line[128]; snprintf(line, sizeof(line), "HW sysctl? %s", name);
            hwidLog(line);
        }
    }
    if (name && strcmp(name, "kern.uuid") == 0) {
        pthread_mutex_lock(&gLock);
        hwidInit();
        pthread_mutex_unlock(&gLock);
        uuid_t uu; uuid_parse(gFakeUUID, uu);
        if (!oldp || !oldlenp) { if (oldlenp) *oldlenp = sizeof(uu); return 0; }
        if (*oldlenp < sizeof(uu)) return -1;
        memcpy(oldp, uu, sizeof(uu));
        *oldlenp = sizeof(uu);
        hwidLog("HW sysctl kern.uuid FAKE");
        return 0;
    }
    if (!name) { errno = EINVAL; return -1; }
    int mib[CTL_MAXNAME]; size_t miblen = CTL_MAXNAME;
    if (sysctlnametomib(name, mib, &miblen) != 0) return -1; // errno already set
    return syscall(SYS_sysctl, mib, (u_int)miblen, oldp, oldlenp, newp, newlen);
}

INTERPOSE(IORegistryEntryCreateCFProperty, IORegistryEntryCreateCFProperty);
INTERPOSE(sysctlbyname, sysctlbyname);

// ---- device-id file redirect (covers hardcoded-path readers) ----
// lsof only shows HELD-OPEN files: a ticket file read once at startup and
// closed is invisible to it. If the SDK reads <home>/.workbuddy/device-id via
// a hardcoded getpwuid-joined path (ignoring WORKBUDDY_CONFIG_DIR and $HOME),
// neither the seed file nor the IOKit spoof matters. So: any open() whose
// path ends in "/.workbuddy/device-id" (exactly — not .workbuddy-2/3) is
// redirected to $WORKBUDDY_CONFIG_DIR/device-id. Forwarding uses the raw
// SYS_open/SYS_openat traps: calling open() normally would recurse into
// ourselves (interposition is process-global, dlsym is poisoned — see above).
// fopen() needs no hook: libc's fopen reaches the open symbol internally.
#include <fcntl.h>
#include <stdarg.h>

static int isSharedDeviceId(const char *path) {
    if (!path) return 0;
    const char *t = strstr(path, "/.workbuddy/device-id");
    if (!t) return 0;
    return strcmp(t, "/.workbuddy/device-id") == 0; // exact suffix: excludes -2/-3
}

static void redirDeviceId(char *out, size_t n) {
    const char *cd = getenv("WORKBUDDY_CONFIG_DIR");
    if (!cd || !*cd) { out[0] = 0; return; }
    snprintf(out, n, "%s/device-id", cd);
}

int my_open(const char *path, int oflag, ...) {
    mode_t mode = 0;
    if (oflag & O_CREAT) { va_list ap; va_start(ap, oflag); mode = (mode_t)va_arg(ap, int); va_end(ap); }
    if (isSharedDeviceId(path)) {
        char np[1100]; redirDeviceId(np, sizeof(np));
        if (np[0]) path = np;
        // fall through to the raw trap with the redirected path
        return syscall(SYS_open, path, oflag, mode);
    }
    return syscall(SYS_open, path, oflag, mode);
}

int my_openat(int fd, const char *path, int oflag, ...) {
    mode_t mode = 0;
    if (oflag & O_CREAT) { va_list ap; va_start(ap, oflag); mode = (mode_t)va_arg(ap, int); va_end(ap); }
    if (fd == AT_FDCWD && isSharedDeviceId(path)) {
        char np[1100]; redirDeviceId(np, sizeof(np));
        if (np[0]) path = np;
    }
    return syscall(SYS_openat, fd, path, oflag, mode);
}

INTERPOSE(open, open);
INTERPOSE(openat, openat);

// ---- MAC-address spoofing (per-clone, process-local view only) ----
// The machine's real NICs are untouched: we reimplement getifaddrs on top of
// the raw NET_RT_IFLIST sysctl and substitute only AF_LINK ether bytes with a
// stable per-clone locally-administered address (02:xx:xx:xx:xx:xx derived
// from the clone's fake UUID). IPs, names, flags are faithful copies.
// freeifaddrs frees unconditionally: post-interpose every list is ours.
#include <net/if.h>
#include <ifaddrs.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include <net/route.h>
#include <sys/socket.h>
#include <netinet/in.h>

void my_freeifaddrs(struct ifaddrs *list); // fwd: used by my_getifaddrs error path

static void fakeMac(unsigned char out[6]) {
    uuid_t uu; uuid_parse(gFakeUUID, uu);
    out[0] = 0x02;
    for (int i = 0; i < 5; i++) out[1 + i] = uu[10 + i];
}

static struct sockaddr *saCopy(struct sockaddr *sa) {
    if (!sa || sa->sa_len == 0) return NULL;
    struct sockaddr *c = malloc(sa->sa_len);
    if (c) memcpy(c, sa, sa->sa_len);
    return c;
}

#define RT_ROUNDUP(a) ((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))

int my_getifaddrs(struct ifaddrs **out) {
    pthread_mutex_lock(&gLock);
    hwidInit();
    pthread_mutex_unlock(&gLock);
    unsigned char fm[6]; fakeMac(fm);
    int mib[6] = { CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST, 0 };
    size_t len = 0;
    if (syscall(SYS_sysctl, mib, 6, NULL, &len, NULL, 0) != 0) return -1;
    char *buf = malloc(len);
    if (!buf) return -1;
    if (syscall(SYS_sysctl, mib, 6, buf, &len, NULL, 0) != 0) { free(buf); return -1; }
    struct ifaddrs *head = NULL, **tail = &head;
    struct { int idx; unsigned int flags; struct if_data data; int has; } imap[64];
    int nmap = 0;
    char *end = buf + len, *cp = buf;
    int rc = 0;
    while (cp < end) {
        struct rt_msghdr *rtm = (struct rt_msghdr *)cp;
        if (rtm->rtm_version != RTM_VERSION || rtm->rtm_msglen == 0) break;
        if (rtm->rtm_type == RTM_IFINFO) {
            struct if_msghdr *ifm = (struct if_msghdr *)cp;
            int k = -1;
            for (int i = 0; i < nmap; i++) if (imap[i].idx == ifm->ifm_index) k = i;
            if (k < 0 && nmap < 64) { k = nmap++; imap[k].idx = ifm->ifm_index; }
            if (k >= 0) { imap[k].flags = ifm->ifm_flags; imap[k].data = ifm->ifm_data; imap[k].has = 1; }
        } else if (rtm->rtm_type == RTM_NEWADDR) {
            struct ifa_msghdr *ifam = (struct ifa_msghdr *)cp;
            struct sockaddr *sa[RTAX_MAX] = { 0 };
            char *p = (char *)(ifam + 1);
            for (int i = 0; i < RTAX_MAX; i++) {
                if (ifam->ifam_addrs & (1 << i)) {
                    if (p + sizeof(struct sockaddr) > end) { rc = -1; break; }
                    sa[i] = (struct sockaddr *)p;
                    if (sa[i]->sa_len == 0 || p + RT_ROUNDUP(sa[i]->sa_len) > end) { rc = -1; break; }
                    p += RT_ROUNDUP(sa[i]->sa_len);
                }
            }
            if (rc != 0) break;
            char nm[IFNAMSIZ] = "?";
            if_indextoname(ifam->ifam_index, nm);
            int lslot = -1;
            for (int i = 0; i < nmap; i++) if (imap[i].idx == (int)ifam->ifam_index) lslot = i;
            // one node per address present (mirrors system getifaddrs)
            for (int i = 0; i < RTAX_MAX; i++) {
                if (!sa[i]) continue;
                if (i != RTA_IFA && i != RTA_IFP) continue;
                if (i == RTA_IFA && sa[i]->sa_family != AF_INET && sa[i]->sa_family != AF_INET6) continue;
                if (i == RTA_IFP && sa[i]->sa_family != AF_LINK) continue;
                struct ifaddrs *n = calloc(1, sizeof(*n));
                if (!n) { rc = -1; break; }
                n->ifa_name = strdup(nm);
                n->ifa_flags = (lslot >= 0) ? imap[lslot].flags : 0;
                if (i == RTA_IFA) {
                    n->ifa_addr = saCopy(sa[RTA_IFA]);
                    n->ifa_netmask = saCopy(sa[RTA_NETMASK]);
                    n->ifa_dstaddr = saCopy(sa[RTA_BRD]);
                } else {
                    n->ifa_addr = saCopy(sa[RTA_IFP]);
                    struct sockaddr_dl *sdl = (struct sockaddr_dl *)n->ifa_addr;
                    if (sdl && sdl->sdl_type == IFT_ETHER && sdl->sdl_alen == 6) {
                        memcpy(LLADDR(sdl), fm, 6);
                        char line[128]; snprintf(line, sizeof(line), "HW mac %s FAKE", nm);
                        hwidLog(line);
                    }
                    if (lslot >= 0 && imap[lslot].has) {
                        n->ifa_data = malloc(sizeof(struct if_data));
                        if (n->ifa_data) memcpy(n->ifa_data, &imap[lslot].data, sizeof(struct if_data));
                    }
                }
                *tail = n;
                tail = &n->ifa_next;
            }
            if (rc != 0) break;
        }
        cp += rtm->rtm_msglen;
    }
    free(buf);
    if (rc != 0) { my_freeifaddrs(head); return -1; }
    *out = head;
    return 0;
}

void my_freeifaddrs(struct ifaddrs *list) {
    while (list) {
        struct ifaddrs *nx = list->ifa_next;
        free(list->ifa_name);
        free(list->ifa_addr);
        free(list->ifa_netmask);
        free(list->ifa_dstaddr);
        free(list->ifa_data);
        free(list);
        list = nx;
    }
}

// DISABLED 2026-10-27: my RTM parser returns -1 on real dumps (breaks all
// callers) AND the OS already masks ether addresses to zeros for unentitled
// apps, so MAC is useless as a server correlator anyway. System getifaddrs
// restored by unhooking; code kept for reference.
// INTERPOSE(getifaddrs, getifaddrs);
// INTERPOSE(freeifaddrs, freeifaddrs);
