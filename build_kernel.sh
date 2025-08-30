#!/bin/bash
set -e  # 出错时终止脚本

# 输出编译信息
echo "===== 开始编译安卓内核 ====="
echo "内核源码: ${KERNEL_SOURCE}"
echo "分支: ${KERNEL_BRANCH}"
echo "架构: ${ARCH}"
echo "配置文件: ${KERNEL_CONFIG}"
echo "KernelSU类型: ${KERNEL_SU}"
echo "启用LXC支持: ${ENABLE_LXC}"
echo "工具链: ${TOOLCHAIN}"
echo "工具链分支: ${CLANG_BRANCH}"
echo "工具链版本: ${CLANG_VERSION}"
echo "额外附加编译命令: ${EXTRA_CMDS}"

# 进入内核目录
cd ${KERNEL_DIR}

#启用LXC-Docker支持
if [ "${ENABLE_LXC}" = "true" ]; then
	echo "启用LXC-Docker支持"
        git clone https://github.com/tomxi1997/lxc-docker-support-for-android.git utils
        echo 'source "utils/Kconfig"' >> "Kconfig"

        # 添加LXC配置
        echo "CONFIG_DOCKER=y" >> "arch/${ARCH}/configs/${KERNEL_CONFIG}"
        echo "CONFIG_BINFMT_MISC=y" >> "arch/${ARCH}/configs/${KERNEL_CONFIG}"
        sed -i '/CONFIG_ANDROID_PARANOID_NETWORK/d' "arch/${ARCH}/configs/${KERNEL_CONFIG}"
        echo "# CONFIG_ANDROID_PARANOID_NETWORK is not set" >> "arch/${ARCH}/configs/${KERNEL_CONFIG}"

        # 应用补丁
        chmod +x utils/runcpatch.sh
        for cgroup_file in "kernel/cgroup/cgroup.c" "kernel/cgroup.c"; do
          if [ -f "$cgroup_file" ]; then
            sh utils/runcpatch.sh "$cgroup_file"
            break
          fi
        done

        if [ -f "net/netfilter/xt_qtaguid.c" ]; then
          patch -p0 < utils/xt_qtaguid.patch
        fi   
fi

#设置kernel版本
if [ "${KERNEL_SU}" = "kernelsu" ]; then
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -   
fi

if [ "${KERNEL_SU}" = "kernelsu-next" ]; then
     curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -
fi

if [ "${KERNEL_SU}" = "suki-su" ]; then
     curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s main
fi

exxport TOOLCHAIN_DIR=/root
export PATH="${TOOLCHAIN_DIR}/clang/bin:${TOOLCHAIN_DIR}/gcc64/aarch64-linux-android-4.9/bin:${TOOLCHAIN_DIR}/gcc32/arm-linux-androideabi-4.9/bin:${PATH}"
# 设置编译参数
MAKE_OPTS="\
    O=${OUTPUT_DIR} \
    ARCH=${ARCH} \
    -j$(nproc) \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
"
if [ "${TOOLCHAIN}" = "clang" ]; then
    MAKE_OPTS+=" CC=clang CLANG_TRIPLE=aarch64-linux-gnu- LD=ld.lld ${EXTRA_CMDS}"
fi

# 生成配置文件
make ${MAKE_OPTS} ${KERNEL_CONFIG}

# 编译内核
echo "===== 编译内核中....... ====="
echo $PATH && clang -v
echo "=====....... ====="
make ${MAKE_OPTS}

# 复制输出文件到 OUTPUT_DIR
echo "===== 编译完成，输出文件如下 ====="
ls -l ${OUTPUT_DIR}/arch/${ARCH}/boot/

echo "===== 使用Anykernel3打包内核中，输出如下 ====="
git clone --depth=1 https://github.com/tomxi1997/AnyKernel3.git AnyKernel3
rm -rf AnyKernel3/.git* AnyKernel3/README.md
cp ${OUTPUT_DIR}/arch/${ARCH}/boot/Image ./AnyKernel3/Image
cp -R AnyKernel3 ${OUTPUT_DIR}/



if [ "${USE_MAGISKBOOT}" = "true" ]; then
     echo "===== 使用'magiskboot打包内核中，输出如下 ====="
     cp ${OUTPUT_DIR}/arch/${ARCH}/boot/Image ${TMP_DIR}/kernel0
     cd ${TMP_DIR}
     ./magiskboot unpack boot.img 
     rm kernel && mv kernel0 kernel
     ./magiskboot repack boot.img
     cp new-boot.img  ${OUTPUT_DIR}/boot.img
fi

# 保留容器运行（可选，用于调试）
# tail -f /dev/null
