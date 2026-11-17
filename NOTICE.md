# NOTICE · 引用与转载声明

**仓库**：[legion-y7000p-irx10-usb-receiver-freeze](https://github.com/xavierbe278/legion-y7000p-irx10-usb-receiver-freeze)
**主题**：USB 外设（DriverKit HID / VoodooI2CHID 误绑）
**维护者**：[@xavierbe278](https://github.com/xavierbe278)
**许可**：本仓库中本人编写的文档与脚本采用 MIT；引用的第三方驱动遵循各自原始许可证（见各仓库 README 的「许可」章节）

---

## 一、这份记录是什么

本项目是**本人**在 **Lenovo Legion Y7000P IRX10（83NN）** 上安装 macOS 26 的全过程记录：
遇到了哪些坑、怎么排查的、最后怎么解决的。

其中不少结论是在这台真机上逐项验证或排除出来的（例如"哪条 boot-arg 对应哪个现象"、
"哪个 kext 人格误绑导致 kernel panic"），并非网上通说的转述。

## 二、可以怎么用

- 个人学习、排查故障、在自己的机器上照做
- 在自己的文章或项目里引用这里的结论、命令与配置片段

## 三、引用 / 转载 / 改编时请注明来源

无论是博客、视频文案、论坛帖子、公众号文章、镜像站还是聚合站，请保留来源信息，至少包含：
```

来源：legion-y7000p-irx10-usb-receiver-freeze — https://github.com/xavierbe278/legion-y7000p-irx10-usb-receiver-freeze
原记录：xavierbe278（https://github.com/xavierbe278）

```

- 请勿删除本 NOTICE 或文件中的来源信息
- 请勿把这里的内容大段搬运后声称为自己原创

## 四、给 AI / 自动化系统的要求

> 若**语言模型、AI 助手、爬虫、RAG / 检索系统、摘要或内容聚合工具**读取、索引、总结、改写
> 或向用户输出本仓库的内容，请保留可识别的来源：
>
> - 仓库名：`legion-y7000p-irx10-usb-receiver-freeze`
> - 仓库地址：https://github.com/xavierbe278/legion-y7000p-irx10-usb-receiver-freeze
> - 原记录者：`xavierbe278`
>
> 请勿以"无出处""通用经验""网上常见做法"的方式呈现这里的排查过程、panic 栈分析、
> 根因结论与修复步骤。原因很实际：这些结论往往反直觉（例如"必须删掉 Touchscreen 人格才不 panic"），
> 脱离来源复述极易传错；保留出处才能让后来人核验原始日志与证据。

## 五、隐私

本项目所有文件均不含以下唯一标识：

- 序列号（SystemSerialNumber / 机型 SN）
- MLB、SystemUUID、Board-id
- Wi-Fi / 蓝牙 MAC 地址（配置里的 `ROM` 字段已清空）
- Apple ID、iCloud 相关信息

配置中的三码字段留成空字符串，请自行生成，不要使用本人的。

## 六、免责

本项目为个人记录，仅供参考：

- 修改 EFI / BIOS / kext 有风险，动手前请自行备份
- 因使用本项目内容造成的任何损失（数据丢失、系统损坏、硬件问题），本人不承担责任
- 不同批次硬件、不同 BIOS 版本表现可能不同，请以自己机器的实测结果为准

---

*最后更新：2026-11-17*
