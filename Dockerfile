FROM fedora:latest

# Build dependencies (based on Theos install script for redhat)
RUN dnf group install -y "c-development" --refresh \
    && dnf install -y \
        fakeroot \
        lzma \
        libbsd \
        rsync \
        curl \
        perl \
        git \
        zip \
        libxml2 \
        ncurses-libs \
        xz \
        findutils \
        dpkg \
        dpkg-devel \
        openssl-devel \
        libplist-devel \
    && dnf clean all

# Favor fakeroot sysv backend (circumvents TCP restrictions on Fedora 41+)
RUN update-alternatives --set fakeroot /usr/bin/fakeroot-sysv

WORKDIR /opt

# 1. Theos itself
RUN git clone --recursive --depth 1 https://github.com/theos/theos.git /opt/theos

# 2. iOS SDKs (both 9.3 and 10.3 so main and update-ui branches both work)
RUN git clone --depth 1 https://github.com/theos/sdks.git /tmp/sdks \
    && mkdir -p /opt/theos/sdks \
    && cp -RL /tmp/sdks/iPhoneOS9.3.sdk /opt/theos/sdks/ \
    && cp -RL /tmp/sdks/iPhoneOS10.3.sdk /opt/theos/sdks/ \
    && rm -rf /tmp/sdks

# 3. Fix module.map → module.modulemap (needed for modern clang)
RUN find /opt/theos/sdks -name "module.map" | while read f; do \
        mv "$f" "$(dirname "$f")/module.modulemap"; \
    done

# 4. Patch 9.3 SDK .tbd stubs so the linker works on main branch
RUN SDK=/opt/theos/sdks/iPhoneOS9.3.sdk \
    && find "$SDK" -name "*.tbd" -exec sed -i 's/, i386//g' {} \; \
    && find "$SDK" -name "*.tbd" -exec sed -i 's/i386, //g' {} \; \
    && find "$SDK" -name "*.tbd" -exec sed -i 's/, x86_64//g' {} \; \
    && find "$SDK" -name "*.tbd" -exec sed -i 's/x86_64, //g' {} \; \
    && find "$SDK" -name "*.tbd" -exec sed -i 's/platform: ios-simulator/platform: ios/g' {} \; \
    && find "$SDK" -name "*.tbd" -exec sed -i 's/i386-ios-simulator/armv7-ios/g' {} \; \
    && find "$SDK" -name "*.tbd" -exec sed -i 's/x86_64-ios-simulator/arm64-ios/g' {} \; \
    && find "$SDK" -name "*.tbd" -exec sed -i 's/armv7-apple-ios-simulator/armv7-apple-ios/g' {} \; \
    && find "$SDK" -name "*.tbd" -exec sed -i '/liblaunch/d' {} \; \
    # Add missing libc symbols (memcpy etc.) to libsystem_c.tbd \
    && MISSING_SYMS="_memcpy _memmove _memset _memcmp _memchr _memset_pattern16 _strdup _strndup _strtok_r _strcasestr _strncasecmp _strcasecmp" \
    && for sym in \$MISSING_SYMS; do \
        if ! grep -Eq "\\b\${sym}\\b" "$SDK/usr/lib/system/libsystem_c.tbd" 2>/dev/null; then \
            sed -i "s/_wcscasecmp_l/&, \$sym/" "$SDK/usr/lib/system/libsystem_c.tbd"; \
        fi \
    done

# 5. Download the pre-built Theos iOS toolchain for Linux
RUN curl -sL https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-x86_64.tar.xz \
    | tar -xJvf - -C /opt/theos/toolchain/

# 6. Build ldid for Linux
RUN git clone --depth 1 https://github.com/ProcursusTeam/ldid.git /tmp/ldid \
    && make -C /tmp/ldid -j$(nproc) \
    && install -m 755 /tmp/ldid/ldid /usr/local/bin/ldid \
    && rm -rf /tmp/ldid

# 7. Permissions
RUN chown -R root:root /opt/theos

# 8a. Symlink OGG/Vorbis headers into Theos include path (so -fmodules doesn't override -I)
RUN ln -sf /opt/local/include/ogg /opt/theos/include/ogg \
    && ln -sf /opt/local/include/vorbis /opt/theos/include/vorbis

# 8b. Build libogg (armv7) for OGG Vorbis support
RUN set -e; \
    CC=/opt/theos/toolchain/linux/iphone/bin/clang; \
    LIBTOOL=/opt/theos/toolchain/linux/iphone/bin/libtool; \
    SDK=/opt/theos/sdks/iPhoneOS9.3.sdk; \
    CFLAGS="-target armv7-apple-ios6.0 -isysroot $SDK -O2 -I/tmp/libogg-1.3.5/include"; \
    mkdir -p /opt/local/include/ogg /opt/local/lib; \
    curl -sL https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz \
        | tar xz -C /tmp; \
    cd /tmp/libogg-1.3.5; \
    $CC $CFLAGS -c src/framing.c -o /tmp/framing.o; \
    $CC $CFLAGS -c src/bitwise.c -o /tmp/bitwise.o; \
    $LIBTOOL -static -o /opt/local/lib/libogg.a /tmp/framing.o /tmp/bitwise.o; \
    cp include/ogg/*.h /opt/local/include/ogg/; \
    rm -rf /tmp/libogg-1.3.5 /tmp/framing.o /tmp/bitwise.o

# 9. Build libvorbis (armv7)
RUN set -e; \
    CC=/opt/theos/toolchain/linux/iphone/bin/clang; \
    LIBTOOL=/opt/theos/toolchain/linux/iphone/bin/libtool; \
    SDK=/opt/theos/sdks/iPhoneOS9.3.sdk; \
    CFLAGS="-target armv7-apple-ios6.0 -isysroot $SDK -O2 -I/opt/local/include -I/tmp/libvorbis-1.3.7/include -I/tmp/libvorbis-1.3.7/lib"; \
    mkdir -p /opt/local/include/vorbis; \
    curl -sL https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz \
        | tar xz -C /tmp; \
    cd /tmp/libvorbis-1.3.7; \
    ODIR=/tmp/vorbis_objs; mkdir -p "$ODIR"; \
    for src in lib/analysis.c lib/bitrate.c lib/block.c lib/codebook.c \
               lib/envelope.c lib/floor0.c lib/floor1.c lib/info.c \
               lib/lookup.c lib/lpc.c lib/lsp.c lib/mapping0.c \
               lib/mdct.c lib/psy.c lib/registry.c lib/res0.c \
               lib/sharedbook.c lib/smallft.c lib/synthesis.c \
               lib/window.c lib/vorbisfile.c; do \
        $CC $CFLAGS -c "$src" -o "$ODIR/$(basename $src .c).o"; \
    done; \
    $LIBTOOL -static -o /opt/local/lib/libvorbis.a "$ODIR"/analysis.o "$ODIR"/bitrate.o \
        "$ODIR"/block.o "$ODIR"/codebook.o "$ODIR"/envelope.o "$ODIR"/floor0.o \
        "$ODIR"/floor1.o "$ODIR"/info.o "$ODIR"/lookup.o "$ODIR"/lpc.o \
        "$ODIR"/lsp.o "$ODIR"/mapping0.o "$ODIR"/mdct.o "$ODIR"/psy.o \
        "$ODIR"/registry.o "$ODIR"/res0.o "$ODIR"/sharedbook.o \
        "$ODIR"/smallft.o "$ODIR"/synthesis.o "$ODIR"/window.o; \
    $LIBTOOL -static -o /opt/local/lib/libvorbisfile.a "$ODIR"/vorbisfile.o; \
    cp /tmp/libvorbis-1.3.7/include/vorbis/*.h /opt/local/include/vorbis/; \
    rm -rf /tmp/libvorbis-1.3.7 "$ODIR"

ENV THEOS=/opt/theos
WORKDIR /project
