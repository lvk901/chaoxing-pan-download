---
name: chaoxing-pan-download
description: >-
  下载超星网盘（超星学习通 / chaoxing.com / cldisk.com）的在线预览文件。当用户给出 pan-yz.chaoxing.com、pan.chaoxing.com 的 screen/v2 或 preview 链接，或问「这个超星/学习通/网盘文件怎么下载」「帮我下载这个超星文件」时使用。核心方法：GET 抓取预览页，从 HTML 里的 fileinfo.download 字段提取真实直链，再带 Referer 请求头（值为预览页域名）下载，否则会 403。
---

# 超星网盘文件下载（Chaoxing Pan Download）

把超星网盘的「在线预览链接」转换成「真实下载」，核心是抓出页面里埋的直链并带上防盗链 Referer 头。

## 何时使用

- 用户粘贴一个 `pan-yz.chaoxing.com/screen/v2/file_xxxx` 或 `pan.chaoxing.com` 链接，想下载其中的文件
- 用户问「超星网盘的文件怎么下载」「学习通里的 PPT/文档怎么保存下来」
- 链接域名含 `chaoxing.com` 或 `cldisk.com`

## 关键原理（已验证）

1. 预览链接本身**不是**下载地址，它返回一个 HTML 预览页（`<title>文档</title>`），把文件每页渲染成缩略图。
2. 预览页 HTML 里内嵌一个 JS 对象 `fileinfo`，其中 `'download'` 字段才是真实直链：
   ```
   'download': 'https://d0.cldisk.com/download/{objectId}?at_={时间戳ms}&ak_={签名}&ad_={签名}&fn={urlencoded文件名}'
   ```
3. 直链里的 `at_` / `ak_` / `ad_` 是**时效性签名**，几分钟后失效，必须用最新抓到的。
4. 直链下载**必须带 `Referer: https://pan-yz.chaoxing.com/`**（防盗链），否则返回 `403 Forbidden / Invalid Request`。
5. 用 `HEAD` 请求预览页会 `405`，要用 `GET`。

## 工作流

### 第 1 步：GET 抓取预览页

```bash
curl -sS -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" \
  "<预览链接>" -o /tmp/cx_preview.html
```

> 注意：不能加 `-I`/`HEAD`，会 405。

### 第 2 步：提取真实直链

```bash
grep -oE "'download':[[:space:]]*'https?://[^']+'" /tmp/cx_preview.html
```

或直接在预览页里搜 `cldisk.com/download`。文件名可从以下任一来源取：

- 直链里的 `fn=` 参数（URL 编码）
- 页面里的 `<input type="hidden" id="fileInfoNameInput" value="文件名">`
- 下载响应头 `Content-Disposition`

### 第 3 步：带 Referer 头下载

```bash
curl -sS -L -A "Mozilla/5.0 ... Chrome/120.0 Safari/537.36" \
  -e "https://pan-yz.chaoxing.com/" \
  "<直链>" -o "文件名.pptx"
```

> `-e` 即 `Referer`，缺了必 403。也可用 `-OJ` 让 curl 按 `Content-Disposition` 自动命名。

### 一键脚本

skill 目录下自带 `chaoxing-download.sh`：

```bash
bash <skill目录>/chaoxing-download.sh "<预览链接>"
```

## 常见问题排查

| 现象 | 原因 | 处理 |
|------|------|------|
| `403 Forbidden / Invalid Request` | 缺 Referer 头，或 `at_/ak_/ad_` 签名过期 | 补 `-e "https://pan-yz.chaoxing.com/"`；过期则重新抓预览页拿新直链 |
| `405 Method Not Allowed` | 用了 HEAD | 改用 GET |
| 页面里找不到 `download` 字段 | 链接已失效 / 需登录 / 文件被删 | 让用户重新打开原分享链接生成新链接；确认有访问权限 |
| 直链下载下来是 HTML | 拿错了 URL 或没带 Referer | 检查是否提取到了 `cldisk.com/download/...` 而非预览页地址 |

## 相关端点备忘

- 预览页：`https://pan-yz.chaoxing.com/screen/v2/file_{objectId}?...`
- 直链：`https://d0.cldisk.com/download/{objectId}?at_=&ak_=&ad_=&fn=`（`d0` 可能为 `d1` 等）
- 缩略图：`https://s3.cldisk.com/sv-w9/doc/{a}/{b}/{c}/{objectId}/thumb/{n}.png`（多页文档逐页）
- WPS 在线预览（非下载）：页面里 `switchPreviewMode()` 跳转的 `preview/v2/objectshowpreview.html?objectid=...&puid=...&enc=...&wps=...`

## 注意事项

- 只下载用户有合法访问权限（拿到分享/预览链接）的文件，不绕过登录、不破解 DRM，尊重版权。
- 签名直链时效短，拿到的 URL 不要长期保存复用。
- 若文件需要登录态（`p_auth_token` 非空、页面无 `download` 字段），本方法不适用，需用户在浏览器登录后用 F12 抓带 Cookie 的请求。
