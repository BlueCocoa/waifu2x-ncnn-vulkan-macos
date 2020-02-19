# waifu2x-ncnn-vulkan-macos
As its long long name suggested.

### Acknowledgement
- [waifu2x-ncnn-vulkan](https://github.com/nihui/waifu2x-ncnn-vulkan)
- [ncnn](https://github.com/Tencent/ncnn)
- [Vulkan SDK](https://vulkan.lunarg.com/sdk/home)

### Build Instructions
Download lastest Vulkan SDK at [https://vulkan.lunarg.com/sdk/home](https://vulkan.lunarg.com/sdk/home).

At the time of this README.md wrote, 1.2.131.2 was the newest version for macOS.

```bash
brew install swig protobuf libomp

# remove all OpenMP lib but libomp.a to force a static link
export OPENMP_VER=9.0.0
rm -f /usr/local/Cellar/libomp/${OPENMP_VER}/lib/libgomp.dylib
rm -f /usr/local/Cellar/libomp/${OPENMP_VER}/lib/libgomp.a
rm -f /usr/local/Cellar/libomp/${OPENMP_VER}/lib/libiomp5.dylib
rm -f /usr/local/Cellar/libomp/${OPENMP_VER}/lib/libiomp5.a
rm -f /usr/local/Cellar/libomp/${OPENMP_VER}/lib/libomp.dylib

# build Xcode Toolchain with OpenMP support
export LLVM_VER=9.0.1
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/llvm-${LLVM_VER}.src.tar.xz"
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/clang-${LLVM_VER}.src.tar.xz"
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/compiler-rt-${LLVM_VER}.src.tar.xz"
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/libcxx-${LLVM_VER}.src.tar.xz"
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/libcxxabi-${LLVM_VER}.src.tar.xz"
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/libunwind-${LLVM_VER}.src.tar.xz"
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/lld-${LLVM_VER}.src.tar.xz"
# the debugserver requires code sign
# skip lldb if you wanna do that
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/lldb-${LLVM_VER}.src.tar.xz"
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/openmp-${LLVM_VER}.src.tar.xz"
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/polly-${LLVM_VER}.src.tar.xz"
wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/clang-tools-extra-${LLVM_VER}.src.tar.xz"

tar xf llvm-${LLVM_VER}.src.tar.xz
tar xf clang-${LLVM_VER}.src.tar.xz && mv clang-${LLVM_VER}.src "llvm-${LLVM_VER}.src/projects/clang"
tar xf compiler-rt-${LLVM_VER}.src.tar.xz && mv compiler-rt-${LLVM_VER}.src "llvm-${LLVM_VER}.src/projects/compiler-rt"
tar xf libcxx-${LLVM_VER}.src.tar.xz && mv libcxx-${LLVM_VER}.src "llvm-${LLVM_VER}.src/projects/libcxx"
tar xf libcxxabi-${LLVM_VER}.src.tar.xz && mv libcxxabi-${LLVM_VER}.src "llvm-${LLVM_VER}.src/projects/libcxxabi"
tar xf lld-${LLVM_VER}.src.tar.xz && mv lld-${LLVM_VER}.src "llvm-${LLVM_VER}.src/projects/lld"
tar xf lldb-${LLVM_VER}.src.tar.xz && mv lldb-${LLVM_VER}.src "llvm-${LLVM_VER}.src/projects/lldb"
tar xf openmp-${LLVM_VER}.src.tar.xz && mv openmp-${LLVM_VER}.src "llvm-${LLVM_VER}.src/projects/openmp"
tar xf polly-${LLVM_VER}.src.tar.xz && mv polly-${LLVM_VER}.src "llvm-${LLVM_VER}.src/projects/polly"
tar xf clang-tools-extra-${LLVM_VER}.src.tar.xz && mv clang-tools-extra-${LLVM_VER}.src "llvm-${LLVM_VER}.src/projects/clang-tools-extra"

cd "llvm-${LLVM_VER}.src" && mkdir -p build && cd build

# ninja is recommended to build LLVM
# get the latest ninja here
# https://github.com/ninja-build/ninja/releases/latest

cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_FFI=ON -DLLVM_CREATE_XCODE_TOOLCHAIN=ON -DLLVM_ENABLE_PROJECTS="clang;compiler-rt;libcxx;libcxxabi;lld;lldb;openmp;polly;clang-tools-extra;" ..

# caffee time / compile time
ninja

# we will only install the Xcode Toolchain 
sudo mkdir -p /usr/local/Toolchains
sudo chmod a+w /usr/local/Toolchains
ninja install-xcode-toolchain
sudo ln -s /usr/local/Toolchains/LLVM${LLVM_VER}.xctoolchain /Applications/Xcode.app/Contents/Developer/Toolchains

# copy arc related libraries from default toolchain to ours
sudo cp -rf /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/arc /Applications/Xcode.app/Contents/Developer/Toolchains/LLVM${LLVM_VER}.xctoolchain/usr/lib/

# clone this repo first
git clone --depth=1 https://github.com/BlueCocoa/waifu2x-ncnn-vulkan-macos

# download lastest Vulkan SDK
export VULKAN_SDK_VER="1.2.131.2"
wget https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VER}/mac/vulkansdk-macos-${VULKAN_SDK_VER}.tar.gz?Human=true -O vulkansdk-macos-${VULKAN_SDK_VER}.tar.gz
tar xf vulkansdk-macos-${VULKAN_SDK_VER}.tar.gz
rm -rf waifu2x-ncnn-vulkan-macos/waifu2x/VulkanSDK
mv vulkansdk-macos-${VULKAN_SDK_VER} waifu2x-ncnn-vulkan-macos/waifu2x/VulkanSDK

# clone Tencent/ncnn
# (At the time of writing this) https://github.com/Tencent/ncnn/tree/4fead31beabf96c375741bd12672ca616d535322
git clone --depth=1 https://github.com/Tencent/ncnn ncnn
cp -rf ncnn/* waifu2x-ncnn-vulkan-macos/waifu2x/ncnn

# clone nihui/waifu2x-ncnn-vulkan
# (At the time of writing this) https://github.com/nihui/waifu2x-ncnn-vulkan/commit/ff7bc433612f4daf6a9fefcaa867b992b5c60196
git clone --depth=1 https://github.com/nihui/waifu2x-ncnn-vulkan waifu2x-ncnn-vulkan
cp -rf waifu2x-ncnn-vulkan/* waifu2x-ncnn-vulkan-macos/waifu2x/waifu2x-ncnn-vulkan

# check your cmake installation
which cmake
# if it goes with /Applications/CMake.app/Contents/bin/cmake
# then you need to install it in /usr/local/bin via follow command
sudo "/Applications/CMake.app/Contents/bin/cmake-gui" --install

# then change these paths at the first a few lines in `CMakeLists-ncnn-omp.txt` and `CMakeLists-waifu2x-ncnn-vulkan.txt` accordingly
set(CMAKE_C_COMPILER "/Applications/Xcode.app/Contents/Developer/Toolchains/LLVM9.0.1.xctoolchain/usr/bin/clang")
set(CMAKE_CXX_COMPILER "/Applications/Xcode.app/Contents/Developer/Toolchains/LLVM9.0.1.xctoolchain/usr/bin/clang++")
set(OPENMP_LIBRARIES "/usr/local/Cellar/libomp/9.0.0/lib")
set(OPENMP_INCLUDES "/usr/local/Cellar/libomp/9.0.0/include")
include_directories("/usr/local/Cellar/libomp/9.0.0/include")
link_directories("/usr/local/Cellar/libomp/9.0.0/lib")

# and change the paths in the last a few lines in `CMakeLists-waifu2x-ncnn-vulkan.txt` based on your own configurations
include_directories("/usr/local/Cellar/libomp/9.0.0/include")
link_directories("/usr/local/Cellar/libomp/9.0.0/lib")

# also change the libomp's include path and library path in `waifu2x.xcodeproj/project.pbxproj` based on your own configurations
1.
CCA6DCA623FD0B4D0097C7B1 /* libomp.a */ = {isa = PBXFileReference; lastKnownFileType = archive.ar; name = libomp.a; path = ../../../../usr/local/Cellar/libomp/9.0.0/lib/libomp.a; sourceTree = "<group>"; };

2.
HEADER_SEARCH_PATHS = (
    /usr/local/Cellar/libomp/9.0.0/include,
    "$(SRCROOT)/waifu2x/VulkanSDK/macOS/include",
    "$(SRCROOT)/waifu2x/ncnn/src/**",
);

3.
LIBRARY_SEARCH_PATHS = (
    "$(SRCROOT)/waifu2x/VulkanSDK/macOS/lib",
    /usr/local/Cellar/libomp/9.0.0/lib,
    "$(PROJECT_DIR)/waifu2x/VulkanSDK/MoltenVK/macOS/dynamic",
);

# compile waifu2x-ncnn-vulkan-macos
# and the compiled application will be placed at `build/Release/waifu2x-gui.app`
cd waifu2x-ncnn-vulkan-macos
# you may need to open this project with Xcode in GUI mode to initialize Code Sign to your Apple ID
# and then you could continue with terminal
# using the toolchain we just built
export TOOLCHAINS=org.llvm.${LLVM_VER}
xcodebuild
```

### Notice
After the first compilation, if you want to modify this project only, you may set those flags in `Build Phases -> Run Script` to `false` to avoid recompile ncnn and regenerate shader.

![regenerate_shader](regenerate_shader.png)

![recompile_ncnn](recompile_ncnn.png)

### Screenshot

![screenshot](screenshot.png)
