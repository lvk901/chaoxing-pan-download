# 超星网盘文件下载 / Chaoxing Pan Download

把超星学习通 / 超星网盘的**在线预览链接**转换成**真实下载**。附带一个可被 AI Agent 直接加载的 Skill。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

---

## 这是什么

超星网盘分享出来的链接长这样，它只能"看"，不能直接"存"：

```
https://pan-yz.chaoxing.com/screen/v2/file_9d31b8b92e668a63629730400c878dc6?ext=...&appid=...&signature=...
```

本仓库提供把这种预览链接变成可下载文件的方法，包含三部分：

| 内容 | 路径 | 用途 |
|------|------|------|
| 🧠 Skill | [`skills/chaoxing-pan-download/SKILL.md`](./skills/chaoxing-pan-download/SKILL.md) | 给 AI Agent（Claude Code / pi 等）自动加载 |
| ⚙️ 一键脚本 | [`skills/chaoxing-pan-download/chaoxing-download.sh`](./skills/chaoxing-pan-download/chaoxing-download.sh) | 命令行直接下载 |
| 📖 本文档 | `README.md` | 给人看的完整教程 |

---

## 快速开始

### 方法一：一键脚本（推荐）

```bash
bash skills/chaoxing-pan-download/chaoxing-download.sh "<预览链接>"
```

输出示例：

```
[1/3] 抓取预览页...
[2/3] 找到直链
[3/3] 下载 -> 2.3浮点数的表示（1）2025.pptx
完成: 2.3浮点数的表示（1）2025.pptx (1477272 bytes)
```

### 方法二：浏览器 F12（不用命令行）

1. 浏览器打开预览链接，等页面加载出来
2. `F12` → **Network（网络）** 面板 → 刷新
3. 筛选框输入 `cldisk.com/download`
4. 复制那条请求的 URL（Copy link address）
5. 粘贴进地址栏回车，即弹出下载

> 或 `Ctrl+U` 看源码，搜 `download`，找 `'download': 'https://d0.cldisk.com/download/...'`。

### 方法三：手动 curl（三步）

```bash
# 1. 抓预览页（注意：不能用 HEAD，会 405）
curl -sS -L -A "Mozilla/5.0 ... Chrome/120.0 Safari/537.36" "<预览链接>" -o preview.html

# 2. 提取真实直链
grep -oE "'download':[[:space:]]*'https?://[^']+'" preview.html

# 3. 带 Referer 头下载（关键！不带必 403）
curl -sS -L -A "Mozilla/5.0 ... Chrome/120.0 Safari/537.36" \
  -e "https://pan-yz.chaoxing.com/" \
  "<直链>" -o "文件名.pptx"
```

---

## 安装 Skill

把 skill 目录复制到你的 Agent skills 库即可（以本机为例）：

```bash
# 全局 skills 库（如 Claude Code / pi）
cp -r skills/chaoxing-pan-download ~/.agents/skills/
```

之后只要贴一个 `pan-yz.chaoxing.com/...` 链接或问"这个超星文件怎么下载"，Agent 就会自动触发。

---

## 原理速览

- 预览页（`screen/v2/file_xxx`）返回的 HTML 把文件每页渲染成缩略图。
- 源码里内嵌 JS 对象 `fileinfo`，其 `download` 字段才是**真实直链**：
  `https://d0.cldisk.com/download/{文件ID}?at_=时间戳&ak_=签名&ad_=签名&fn=文件名`
- `at_` / `ak_` / `ad_` 是**时效签名**，几分钟即过期 —— 每次下载都要重新抓最新值。
- 下载服务器做了**防盗链**：请求头必须带 `Referer: https://pan-yz.chaoxing.com/`，否则 `403 Forbidden / Invalid Request`。

---

## 常见报错排查

| 现象 | 原因 | 解决办法 |
|------|------|----------|
| `403 Forbidden / Invalid Request` | 缺 Referer 头，或签名过期 | 补 `-e "https://pan-yz.chaoxing.com/"`；过期则重新抓预览页 |
| `405 Method Not Allowed` | 用了 HEAD 请求 | 改用 GET |
| 页面里搜不到 `download` 字段 | 链接失效 / 需登录 / 文件已删 | 让对方重新发链接；确认有访问权限 |
| 下载下来是一堆 HTML | 复制错 URL 或漏了 Referer | 确认复制的是 `cldisk.com/download/...` 直链 |

---

## 相关端点备忘

| 用途 | 地址 |
|------|------|
| 预览页 | `https://pan-yz.chaoxing.com/screen/v2/file_{objectId}?...` |
| 直链 | `https://d0.cldisk.com/download/{objectId}?at_=&ak_=&ad_=&fn=` |
| 缩略图 | `https://s3.cldisk.com/sv-w9/doc/{a}/{b}/{c}/{objectId}/thumb/{n}.png` |
| WPS 在线预览（非下载） | `preview/v2/objectshowpreview.html?objectid=...&puid=...&enc=...&wps=...` |

---

## ⚠️ 免责声明

- 本项目仅供**技术学习与个人备份**使用，请只下载你**有合法访问权限**（被分享、被授权）的文件。
- 不绕过登录、不破解 DRM、不用于传播盗版或侵犯版权的内容。
- 若文件要求登录后才能看到（页面无 `download` 字段），本方法不适用。
- 使用本项目产生的一切后果由使用者自行承担。

## License

[MIT](./LICENSE)
