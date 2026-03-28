# EbixExtractiOS
**本项目依然处于实验阶段，用户交互几乎没有**

## 功能
* 导出EBookJapan专有格式Ebix中的图像
  * 对于加密/封装JPEG，直接导出JPEG
  * 对于专有格式，输出BMP后重新编码为PNG导出

## 原理
* 直接调用EBIWrapperKit

## 使用方法
* 注入EbookJapan IPA