# XShark（小鲨鱼）

**XShark**（中文名：**小鲨鱼**）是基于 [Wireshark](https://www.wireshark.org/) 的开源网络协议分析定制版，面向**国密 TLCP（GM/T 0024）**与密评场景。

- **产品版本**：V1.0.0  
- **定位**：国密协议版（独立 `tlcp` 过滤，不与普通 TLS 混筛）  
- **开源许可**：**GNU General Public License v2 or later**（与上游 Wireshark 一致，见根目录 [`COPYING`](COPYING)）  
- **项目主页**：https://github.com/c01djc/xshark  

> 本项目是 Wireshark 的衍生作品（fork / derived work），**不是** Wireshark Foundation 官方产品。  
> Upstream：https://www.wireshark.org / https://gitlab.com/wireshark/wireshark

## 开源协议（必读）

本仓库按 **GPL-2.0-or-later** 发布：

1. 你可以自由使用、修改、再分发（含商业使用），但衍生作品须继续以 GPL 兼容方式授权  
2. 分发二进制时，须同时提供对应源码或书面的源码获取方式  
3. 须保留原作者版权声明、本仓库的 `COPYING`，以及改动说明  
4. 产品对外名称请使用 **XShark / 小鲨鱼**；文档中注明基于 Wireshark，**勿冒充官方 Wireshark**

详细功能与相对上游的改动见 [`docs/XSHARK.CHANGES.md`](docs/XSHARK.CHANGES.md)。

## 为什么做小鲨鱼？

上游 Wireshark 虽能解析 TLCP，但流量通常挂在通用 **TLS** 协议树下，密评与国密联调时往往要用 `tls` 再人工筛，**容易和普通 HTTPS/TLS 混在一起**。

小鲨鱼针对这一痛点：

| 能力 | 说明 |
|------|------|
| 独立显示过滤器 `tlcp` | TLCP 作为可单独筛选的对象，不必与普通 TLS 混筛 |
| 协议列 / 分析路径更清晰 | 仅在确认 TLCP 记录时标记，避免 TCP 重组碎片误匹配 |
| **TLCP 配置 Profile** | 打开含 TLCP 的抓包可自动切换；工具栏、着色、Cipher/SNI/证书列等预置 |
| 密评友好默认项 | 欢迎页去推广侧栏、国密主题、更大抓包缓冲、虚拟网卡默认隐藏等 |

## 与上游的关系

- 代码基础：Wireshark（GPL-2.0-or-later）  
- 产品名：**XShark / 小鲨鱼 · 国密协议版**  
- 界面产品版本：**V1.0.0**（与上游工程版本号可不同；底层仍基于 Wireshark 源码树）  
- 可执行文件名可能仍为构建系统默认的 `Wireshark.exe`；界面与配置展示为 XShark

## 快速使用（Windows 自编译）

```bat
F:\wireshark\run-wireshark.bat
```

建议：

1. **配置 → 配置文件 → TLCP**  
2. 显示过滤器：`tlcp`  
3. 外观主题：**XShark**

解密：在 TLCP Profile 中配置 `tls.keylog_file`，或设置客户端 `SSLKEYLOGFILE`。

## 构建说明

与上游 Wireshark 基本相同；根目录 `.gm_build` 启用小鲨鱼选项（`GM_WIRESHARK_BUILD`）。

```bat
build-wireshark-gm.bat
```

官方构建文档：https://www.wireshark.org/docs/wsdg_html_chunked/

## 贡献

欢迎 Issue / PR。提交代码即表示同意以 **GPL-2.0-or-later** 贡献。

## 致谢

感谢 Wireshark 全体贡献者与 Wireshark Foundation。
