# waifu2x-ncnn-vulkan-macos
As its long long name suggested.

### Acknowledgement
- [waifu2x-ncnn-vulkan](https://github.com/nihui/waifu2x-ncnn-vulkan)
- [ncnn](https://github.com/Tencent/ncnn)
- [Vulkan SDK](https://vulkan.lunarg.com/sdk/home)

### Thanks
Thanks to [@shincurry](https://github.com/shincurry) for contributing to the UI of this project.

### Build Instructions
Download lastest Vulkan SDK at [https://vulkan.lunarg.com/sdk/home](https://vulkan.lunarg.com/sdk/home).

At the time of this README.md wrote, 1.2.131.2 was the newest version for macOS.

```bash
brew install protobuf

# clone this repo first
git clone --depth=1 https://github.com/BlueCocoa/waifu2x-ncnn-vulkan-macos

# download lastest Vulkan SDK
export VULKAN_SDK_VER="1.2.131.2"
wget https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VER}/mac/vulkansdk-macos-${VULKAN_SDK_VER}.tar.gz?Human=true -O vulkansdk-macos-${VULKAN_SDK_VER}.tar.gz
tar xf vulkansdk-macos-${VULKAN_SDK_VER}.tar.gz
rm -rf waifu2x-ncnn-vulkan-macos/waifu2x/VulkanSDK
mv vulkansdk-macos-${VULKAN_SDK_VER} waifu2x-ncnn-vulkan-macos/waifu2x/VulkanSDK

# clone Tencent/ncnn
git clone --depth=1 https://github.com/Tencent/ncnn ncnn

# clone nihui/waifu2x-ncnn-vulkan
# (At the time of writing) https://github.com/nihui/waifu2x-ncnn-vulkan/commit/ff7bc433612f4daf6a9fefcaa867b992b5c60196
rm -rf waifu2x-ncnn-vulkan-macos/waifu2x/waifu2x-ncnn-vulkan
git clone --depth=1 https://github.com/nihui/waifu2x-ncnn-vulkan waifu2x-ncnn-vulkan-macos/waifu2x/waifu2x-ncnn-vulkan

# check your cmake installation
which cmake
# if it goes with /Applications/CMake.app/Contents/bin/cmake
# then you need to install it in /usr/local/bin via follow command
sudo "/Applications/CMake.app/Contents/bin/cmake-gui" --install

# build ncnn
cp -f waifu2x-ncnn-vulkan-macos/waifu2x/CMakeLists-waifu2x-ncnn-vulkan.txt ncnn/CMakeLists.txt
rm -rf ncnn/build && mkdir -p ncnn/build && pushd ncnn/build
cmake -DNCNN_VULKAN=ON -D CMAKE_BUILD_TYPE=Release ..
make -j`sysctl -n hw.ncpu` && make install
cp -rf install/* ../../waifu2x-ncnn-vulkan-macos/waifu2x/ncnn

# compile waifu2x-ncnn-vulkan-macos
# and the compiled application will be placed at `build/Release/waifu2x-gui.app`
cd waifu2x-ncnn-vulkan-macos
xcodebuild
```

### Notice
After the first compilation, if you want to modify this project only, you may set those flags in `Build Phases -> Run Script` to `false` to avoid recompile ncnn and regenerate shader.

![regenerate_shader](regenerate_shader.png)

### Screenshot

#### Single Mode
![screenshot](screenshot-v1.3-single-image.png)

#### Multiple Mode
![screenshot](screenshot-v1.3-multiple-images.png)

## Speed Comparison (not really) with waifu2x-caffe-cui & waifu2x-ncnn-vulkan

### Environment (waifu2x-caffe-cui & waifu2x-ncnn-vulkan)

- Windows 10 1809
- AMD R7-1700
- Nvidia GTX-1070
- Nvidia driver 419.67
- CUDA 10.1.105
- cuDNN 10.1

### Environment (waifu2x-ncnn-vulkan-macos)

- macOS 10.14.6 (18G103)
- Intel Core i9 8890HK
- AMD Radeon Pro Vega 20

### cunet

||Image Size|Target Size|Block Size|Total Time(s)|GPU Memory(MB)|
|---|---|---|---|---|---|
|waifu2x-ncnn-vulkan-macOS|200x200|400x400|400/200/100|0.46/0.44/0.43|621/621/180|
|waifu2x-ncnn-vulkan|200x200|400x400|400/200/100|0.86/0.86/0.82|638/638/197|
|waifu2x-caffe-cui|200x200|400x400|400/200/100|2.54/2.39/2.36|3017/936/843|
|waifu2x-ncnn-vulkan-macOS|400x400|800x800|400/200/100|0.91/0.84/0.92|2415/621/180|
|waifu2x-ncnn-vulkan|400x400|800x800|400/200/100|1.17/1.04/1.02|2430/638/197|
|waifu2x-caffe-cui|400x400|800x800|400/200/100|2.91/2.43/2.7|3202/1389/1178|
|waifu2x-ncnn-vulkan-macOS|1000x1000|2000x2000|400/200/100|3.54/3.58/4.18|2422/624/182|
|waifu2x-ncnn-vulkan|1000x1000|2000x2000|400/200/100|2.35/2.26/2.46|2430/638/197|
|waifu2x-caffe-cui|1000x1000|2000x2000|400/200/100|4.04/3.79/4.35|3258/1582/1175|
|waifu2x-ncnn-vulkan-macOS|2000x2000|4000x4000|400/200/100|12.83/13.25/15.44|2426/676/200|
|waifu2x-ncnn-vulkan|2000x2000|4000x4000|400/200/100|6.46/6.59/7.49|2430/686/213|
|waifu2x-caffe-cui|2000x2000|4000x4000|400/200/100|7.01/7.54/10.11|3258/1499/1200|
|waifu2x-ncnn-vulkan-macOS|4000x4000|8000x8000|400/200/100|49.56/51.44/60.56|2459/651/203|
|waifu2x-ncnn-vulkan|4000x4000|8000x8000|400/200/100|22.78/23.78/27.61|2448/654/213|
|waifu2x-caffe-cui|4000x4000|8000x8000|400/200/100|18.45/21.85/31.82|3325/1652/1236|

### upconv_7_anime_style_art_rgb

||Image Size|Target Size|Block Size|Total Time(s)|GPU Memory(MB)|
|---|---|---|---|---|---|
|waifu2x-ncnn-vulkan-macOS|200x200|400x400|400/200/100|0.23/0.20/0.22|465/465/125|
|waifu2x-ncnn-vulkan|200x200|400x400|400/200/100|0.74/0.75/0.72|482/482/142|
|waifu2x-caffe-cui|200x200|400x400|400/200/100|2.04/1.99/1.99|995/546/459|
|waifu2x-ncnn-vulkan-macOS|400x400|800x800|400/200/100|0.49/0.42/0.41|1747/466/125|
|waifu2x-ncnn-vulkan|400x400|800x800|400/200/100|0.95/0.83/0.81|1762/482/142|
|waifu2x-caffe-cui|400x400|800x800|400/200/100|2.08/2.12/2.11|995/546/459|
|waifu2x-ncnn-vulkan-macOS|1000x1000|2000x2000|400/200/100|1.67/1.60/1.68|1770/468/127|
|waifu2x-ncnn-vulkan|1000x1000|2000x2000|400/200/100|1.52/1.41/1.44|1778/482/142|
|waifu2x-caffe-cui|1000x1000|2000x2000|400/200/100|2.72/2.60/2.68|1015/570/459|
|waifu2x-ncnn-vulkan-macOS|2000x2000|4000x4000|400/200/100|6.11/5.89/6.18|1774/472/128|
|waifu2x-ncnn-vulkan|2000x2000|4000x4000|400/200/100|3.45/3.42/3.63|1778/482/142|
|waifu2x-caffe-cui|2000x2000|4000x4000|400/200/100|3.90/4.01/4.35|1015/521/462|
|waifu2x-ncnn-vulkan-macOS|4000x4000|8000x8000|400/200/100|22.92/22.70/24.16|1806/495/147|
|waifu2x-ncnn-vulkan|4000x4000|8000x8000|400/200/100|11.16/11.29/12.07|1796/498/158|
|waifu2x-caffe-cui|4000x4000|8000x8000|400/200/100|9.24/9.81/11.16|995/546/436|
