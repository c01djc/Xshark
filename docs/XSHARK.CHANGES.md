# XShark（小鲨鱼）改动说明

**产品**：XShark / 小鲨鱼 · 国密协议版  
**产品版本**：V1.0.0  
**项目主页**：https://github.com/c01djc/xshark  
**开源许可**：**GNU GPL v2 or later**（与上游 Wireshark 相同，见仓库根目录 `COPYING`）  
**性质**：基于 Wireshark 的衍生作品（derived work），非官方发行版

---

## 开源与版权说明

| 项 | 内容 |
|----|------|
| 上游许可 | Wireshark：GPL-2.0-or-later |
| 本仓库 | 继续以 **GPL-2.0-or-later** 开源；修改部分同样适用 GPL |
| 版权归属 | 上游代码版权归原作者 / Wireshark 贡献者；本仓库定制改动按 GPL 贡献 |
| 商标 | 请使用 **XShark / 小鲨鱼**；勿将本产品宣传为官方 Wireshark |
| 分发义务 | 提供二进制时须提供对应源码（或符合 GPL 的书面要约） |

按 GPL 公开发布 **不构成对上游源码的侵权**；须保留版权声明与本说明，并注明基于 Wireshark。

---

## 1. 国密 TLCP：独立过滤，不与普通 TLS 混筛

### 背景

上游对 TLCP（GM/T 0024，版本 `0x0101`）的解析复用 TLS 解剖器，用户侧常用 `tls` 才能看到相关流量，与普通 TLS/HTTPS **混在同一过滤口径**，密评筛选成本高。

### 本版本做法

- 注册独立助手协议 **`tlcp`**，可用：
  - `tlcp` — 仅国密 TLCP 相关帧
  - `tls and not tlcp` — 排除 TLCP 后的普通 TLS
- **仅在确认 TLCP 记录时**打标，避免 TCP 重组片段误匹配
- 全局 **TLCP Profile**（`resources/share/wireshark/profiles/TLCP/`）：
  - `auto_switch_filter: tlcp`
  - 打开文件后默认应用 `tlcp`（小鲨鱼构建）
  - 工具栏：TLCP / TLS only / Handshake / App Data
  - 着色、Cipher / SNI / Cert CN 列、密钥日志预设项

### 对密评人员

过滤口径独立、配置一键就绪；需要对比时仍可用 `tls and not tlcp`。

> 底层仍共享 TLS 解剖框架（与协议族现实一致）；产品体验上把 TLCP 作为可独立过滤与独立配置的分析对象。

---

## 2. 界面与品牌（V1.0.0）

| 项 | 内容 |
|----|------|
| 窗口标题 | `XShark（小鲨鱼）· 国密协议版` |
| 欢迎页版本行 | **V1.0.0**（产品版本，独立于上游工程号） |
| 右侧标签 | Wireshark 国密专版 |
| 横幅文案 | Wireshark 国密专版 · XShark（小鲨鱼）｜独立 tlcp …｜国密密评专用 |
| 主题 | XShark（深红） |
| 欢迎页 | 默认关闭 Tips/Learn/Donate 侧栏 |
| 图标 | 鲨鱼鳍换为红色（`tools/recolor_gm_icons.py`） |
| 自动更新 | 关闭官方更新通道 |
| 配置目录 | 小鲨鱼构建下使用 `xshark` |

---

## 3. 抓包与性能默认

- 默认捕获缓冲：**8 MiB**
- 虚拟网卡名默认隐藏（VMware、Bluetooth、本地连接*、VirtualBox、Hyper-V 等）
- 捕获过滤器预设：`tcp port 443`、`8443`、TLCP 常用端口组合

---

## 4. 主要涉及文件（摘要）

- `epan/dissectors/packet-tls.c` — `tlcp` 协议注册与打标  
- `app/wireshark_flavor.c` / `ui/qt/wireshark_application.cpp` / `ui/qt/main_window.cpp` — 品牌与窗口标题  
- `ui/qt/widgets/welcome_header_widget.cpp` — V1.0.0 与国密横幅  
- `resources/share/wireshark/profiles/TLCP/` — TLCP Profile  
- `resources/themes/gm-wireshark/` — XShark 主题  
- `ui/capture_opts.h`、`ui/qt/manager/interface_list_manager.cpp`、`ui/recent.c`、`ui/qt/welcome_page.cpp`  
- `tools/recolor_gm_icons.py`、`.gm_build`  

---

## 5. 版本说明

- **产品版本 V1.0.0**：面向用户的小鲨鱼发行标记  
- **上游工程版本**（如 4.7.x）：构建树来源；帮助/协议兼容性仍以该基础为准  
