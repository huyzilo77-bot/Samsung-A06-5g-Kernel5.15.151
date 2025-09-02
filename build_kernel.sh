#!/bin/bash
set -e

echo -e "\n[INFO] BẮT ĐẦU BUILD KERNEL SAMSUNG A06B...\n"

# ====== Thiết lập biến môi trường ======
export KERNEL_ROOT="$(pwd)"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="github"
export KBUILD_BUILD_HOST="actions"

# Output
mkdir -p out build

# ====== Toolchains ======
TOOLCHAIN_DIR="$HOME/toolchains"
CLANG_DIR="$TOOLCHAIN_DIR/clang-r450784e"
GCC_DIR="$TOOLCHAIN_DIR/arm-gnu-toolchain-14.2"

mkdir -p "$TOOLCHAIN_DIR"

if [ ! -d "$CLANG_DIR" ]; then
    echo "[INFO] Tải Clang..."
    mkdir -p "$CLANG_DIR"
    wget -q https://github.com/ravindu644/Android-Kernel-Tutorials/releases/download/toolchains/clang-r450784e.tar.gz -O clang.tar.gz
    tar -xzf clang.tar.gz -C "$CLANG_DIR"
    rm clang.tar.gz
fi

if [ ! -d "$GCC_DIR" ]; then
    echo "[INFO] Tải ARM GNU Toolchain..."
    mkdir -p "$GCC_DIR"
    wget -q https://github.com/ravindu644/Android-Kernel-Tutorials/releases/download/toolchains/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz -O gcc.tar.xz
    tar -xf gcc.tar.xz -C "$GCC_DIR" --strip-components=1
    rm gcc.tar.xz
fi

export PATH="$CLANG_DIR/bin:$GCC_DIR/bin:$PATH"
export CROSS_COMPILE=aarch64-none-linux-gnu-
export CC=clang
export CLANG_TRIPLE=aarch64-linux-gnu-

# ====== Thêm KernelSU Next + SUSFS ======
if [ ! -d "KernelSU-Next" ]; then
    echo "[INFO] Clone KernelSU Next..."
    git clone https://github.com/KernelSU-Next/KernelSU-Next.git
    cp -r KernelSU-Next/kernel/* drivers/kernelsu/ || true
fi

if [ ! -d "susfs4ksu" ]; then
    echo "[INFO] Clone SUSFS patches..."
    git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android13-5.15
    cp susfs4ksu/kernel_patches/fs/* fs/ || true
    cp susfs4ksu/kernel_patches/include/linux/* include/linux/ || true
    patch -p1 < susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch || true
fi

# ====== Build kernel ======
DEFCONFIG="a06x_00_defconfig"

echo "[INFO] Dùng defconfig: $DEFCONFIG"
make O=out $DEFCONFIG
make -j$(nproc) O=out \
    ARCH=$ARCH SUBARCH=$SUBARCH \
    CC=$CC CROSS_COMPILE=$CROSS_COMPILE \
    CLANG_TRIPLE=$CLANG_TRIPLE LLVM=1 LLVM_IAS=1 \
    Image.gz

# Copy kết quả
cp out/arch/arm64/boot/Image* build/ || true
cp out/arch/arm64/boot/dts/*.dtb build/ 2>/dev/null || true
cp out/arch/arm64/boot/dts/*.dtbo build/ 2>/dev/null || true

echo -e "\n[INFO] BUILD HOÀN TẤT, file kernel ở thư mục build/\n"
