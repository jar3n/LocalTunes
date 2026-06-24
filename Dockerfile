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
    && find "$SDK" -name "libSystem.tbd" -exec sed -i '/liblaunch/d' {} \;

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

ENV THEOS=/opt/theos
WORKDIR /project
