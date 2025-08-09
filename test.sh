#!/bin/bash
#set -e  # 启用错误立即退出

#ubuntu版本,可选值18.04 20.04 22.04 24.04 
UBUNTU_VERSION=22.04

#内核源码
KERNEL_SOURCE=https://github.com/LineageOS/android_kernel_xiaomi_msm8998
#分支
KERNEL_BRANCH=lineage-22.2
#内核配置文件
KERNEL_CONFIG=chiron_defconfig
#架构
ARCH=arm64

#KernelSU可选的值 kernelsu kernelsu-next suki-su
KERNEL_SU=kernelsu-next

#启用LXC-Docker支持
ENABLE_LXC=true

#额外附加的编译命令(传递到make)
EXTRA_CMDS="LLVM=1 LLVM_IAS=1 AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf OBJSIZE=llvm-size STRIP=llvm-strip"

#使用magiskboot打包内核
USE_MAGISKBOOT=true

# 编译工具链
TOOLCHAIN=clang
CLANG_BRANCH=android3-release
CLANG_VERSION=r450784d
GCC_VERSION=

# 提前创建输出目录并设置权限
mkdir -p $GITHUB_WORKSPACE/kernel_workspace
sudo chmod 777 $GITHUB_WORKSPACE/kernel_workspace

# 构建Docker镜像
sudo docker build . --file Dockerfile \
             --tag android-kernel-builder:latest \
             --build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
             --build-arg KERNEL_SOURCE=${KERNEL_SOURCE} \
             --build-arg KERNEL_BRANCH=${KERNEL_BRANCH} \
             --build-arg KERNEL_CONFIG=${KERNEL_CONFIG} \
	     --build-arg ARCH=${ARCH}  \
             --build-arg KERNEL_SU=${KERNEL_SU} \
             --build-arg ENABLE_LXC=${ENABLE_LXC} \
             --build-arg TOOLCHAIN=${TOOLCHAIN} \
	     --build-arg CLANG_BRANCH=${CLANG_BRANCH} \
	     --build-arg CLANG_VERSION=${CLANG_VERSION} \
             --build-arg GCC_VERSION=${GCC_VERSION} \
             --build-arg USE_MAGISKBOOT=${USE_MAGISKBOOT} \
	     --build-arg EXTRA_CMDS="${EXTRA_CMDS}"

# 运行容器（指定用户ID避免权限问题）
sudo docker run -u 1001:1001 \
  -v $GITHUB_WORKSPACE/kernel_workspace:/root/output \
  android-kernel-builder:latest
