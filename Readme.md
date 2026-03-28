# iOSEbixImgExtract

本模块仅供编程技术交流学习使用，请勿用于其他用途。

* 导出EBookJapan专有格式Ebix中的图像
  * 对于加密/封装JPEG，直接导出JPEG
  * 对于专有格式，输出BMP后重新编码为PNG导出
  * 集成SSZipArchive流式封装CBZ
* 通过UIDocumentPickerViewController可将输出文件移动到Sandbox外

## 原理
* 注入到IPA后，直接使用EBIWrapperKit原始逻辑实现图像抽取

## 环境要求
* iOS 14.0+
* MSHookMessageEx
  * 即同时注入 Substitute, ElleKit 或其现代化替代
  * LiveContainer环境自带ElleKit

## 使用
每次打开应用时，会扫描Library路径检查是否有Ebix文件存在，如果有则弹窗询问用户是否抽取

目前只支持全部抽取，不想抽取的书请手动从本地移除

去壳可以使用 **TrollDecrypt** 或 **frida-ios-dump**
## 安装
### LiveContainer (推荐)
* 安装去壳的EbookJapan IPA
* 在模块页面新建文件夹，进入文件夹后，在右上角加号选择导入模块，导入本dylib
### Sideloadly
* 拖入去壳的EbookJapan IPA
* 点击Advanced Options，勾选inject dylibs/frameworks
* 添加本dylib，勾选Substitute（或拖入ElleKit）
* 安装到设备，或导出未签名的完成注入的IPA（可在vphone-cli上安装运行，也是一样的）

## Q&A
* 为什么不制作一个iOS应用或魔改链接库使其在macOS (Apple Silicon)上运行？
  1. 我水平不行
  2. 解密过程需要使用一个存储在Keychain中的值，获取较为困难
  3. 解密参数很有可能与设备信息相关联

## ToDo
- [ ] 可中途终止抽取
- [ ] 有没有可能支持小说？

## 致谢
* [SSZipArchive](https://github.com/ZipArchive/ZipArchive)

## 许可证
MIT