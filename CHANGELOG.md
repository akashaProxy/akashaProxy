# akashaProxy — 更新日志

本分支基于上游 [akashaProxy/akashaProxy](https://github.com/akashaProxy/akashaProxy) 的 `c2489d6`，
围绕**开箱可用的默认配置**做了一轮重写，并修掉了模块脚本里的一个热重载缺陷。
内核仍是 **mihomo 原生内核**（不含、也不使用任何 Smart 内核特性）。

安装方式与上游一致：Magisk / KernelSU 刷入本页附带的 zip，首次使用把
`/data/adb/akashaProxy/config.example.yaml` 重命名为 `config.yaml`，
**填写里面 `proxy-providers` 的机场订阅链接**（模板中唯一必填项，有 `####` 横幅标注）。

---

## 一、默认配置模板重写（`module/src/config.example.yaml`）

254 行 → 449 行；**51 个策略组 / 40 个规则集 / 60 条规则**，全部使用 mihomo 原生组类型。

### 策略组

- **主策略**：全局代理、兜底流量、国内直连、故障转移、手动选择、广告拦截、直接连接（隐藏）
- **细分策略**：
  - 人工智能 —— ChatGPT / Claude / Gemini / Grok / Copilot / Perplexity
  - 海外社交 —— Telegram / X / Facebook / Instagram / Discord / Reddit / WhatsApp
  - 国内社交 —— 小红书、小黑盒、抖音（按 **App 包名** 分流，见下）
  - 国际媒体 —— YouTube / Netflix / Disney+ / Spotify 等
  - 谷歌服务、微软服务
  - 金融平台 —— PayPal / Visa / Mastercard / Wise / Stripe / IBKR / 富途 / 老虎 +
    加密货币（Binance / OKX / Coinbase / Trust Wallet）；geosite 里没有条目的
    Neverless、Revolut 用 `DOMAIN-SUFFIX` 单独补齐
  - 游戏平台 —— Steam / Epic / Xbox（国服游戏与平台下载 CDN 走直连，跑满带宽）
- **地区策略** 9 组（香港 / 台湾 / 日本 / 韩国 / 新加坡 / 美国 / 英国 / 欧洲 / 其他地区），
  每组内置三个隐藏子组，可按需切换：
  - `自动`（`url-test`，选延迟最低）
  - `负载均衡-散列`（`load-balance` + `consistent-hashing`，同一目标站点固定走同一节点，登录态不易掉）
  - `负载均衡-轮询`（`load-balance` + `round-robin`，多节点叠加带宽）

  全部 `lazy: true`，不选中就不测速，省电。

### 节点筛选（`filter`）

按 flag emoji + 国名 + 常见中转命名归类，两条硬规矩：

- **不使用裸的单字中文地区词**（`日` `美` `港` `台` …）。机场用
  `override.additional-prefix` 加前缀时，前缀会出现在每个节点名里，单字词会造成整机场误判。
- **拉丁字母国家代码一律带零宽边界** `(?<![a-z])xx(?![a-z])`，
  避免 `Russia`→us、`No.1`→no、`10Gb`→gb、`Digital`→it 这类误命中。

回归基线（120 个真实节点、两个带前缀的机场）：
香港 36 / 台湾 18 / 日本 16 / 韩国 2 / 新加坡 6 / 美国 8 / 英国 2 / 欧洲 6 / 其他地区 26，
20 种 flag 全部归类正确，`手动选择` 收录 120/120，无节点失去归属。

### 分流数据

- `GEOSITE` / `GEOIP` 用模块内置的 `GeoSite.dat` / `GeoIP.dat`，**离线可用**，负责
  `cn` / `private` / `geolocation-!cn` 等大类
- `RULE-SET` 用 MetaCubeX/meta-rules-dat 的 `.mrs`（二进制格式，体积小解析快）负责细分类
- **广告拦截换用 [秋风广告规则 AWAvenue Ads Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule)** 的
  `.mrs`（约 900 条），并配套屏蔽 HTTPDNS、禁止非内核进程访问 DoT(853)，防止 App 绕过分流

### 国内社交按 App 包名分流

Android 上内核把 `metadata.process` 上报为**应用包名**，因此用 `PROCESS-NAME` 整体归类，
能连带该 App 调用的三方 CDN / 统计 / 风控域名一起兜住，比纯域名规则彻底：

```yaml
- PROCESS-NAME,com.xingin.xhs,国内社交               # 小红书
- PROCESS-NAME,com.max.xiaoheihe,国内社交            # 小黑盒
- PROCESS-NAME,com.ss.android.ugc.aweme,国内社交     # 抖音
- PROCESS-NAME,com.ss.android.ugc.livelite,国内社交  # 抖音极速版
```

依赖 `find-process-mode: strict`。要加自己的 App：`adb shell pm list packages -3`
查包名，照上面的格式加一行即可。广告拦截规则在本节之前，App 内广告照样被拦。

### 顺手修正的内核兼容问题

- 移除 `global-client-fingerprint` —— mihomo 1.19 已删除该选项，保留会打 error 日志
- 增加 `geodata-mode: true` —— 直接使用内置 `GeoIP.dat`，不再在首次启动时联网下载 `Country.mmdb`
- 运营商 IMS（`pub.3gppnetwork.org`）明确走直连，避免 VoLTE / VoWiFi 被代理打断
- DNS 保持 `redir-host`（兼容性最好）；想切 `fake-ip` 改一行即可，模块脚本两种都支持

---

## 二、修复 `clash.tool` 热重载失效（`module/src/scripts/clash.tool`）

原 `reload()` 有三个问题：

1. `-H 'Authorization: Bearer ${secret}'` 用单引号导致变量不展开，且变量名有误
   （`clash.env` 中实际为 `kernel_ui_secret`）→ **配置了 `secret` 的用户必然 401**
2. 请求体 `{"configs": [...]}` 不是 mihomo 的 API schema（正确的是
   `{"path": "<绝对路径>", "payload": "..."}`）。错误字段被解码成空结构体后
   `Path == ""`，内核回退到默认配置路径 —— 属于依赖未定义行为
3. 无任何校验与反馈：坏配置会被直接推进正在运行的内核，用户看不到失败原因

现在：重载前依次检查「配置文件存在 → 内核在运行 → `mihomo -t` 语法校验通过」，
不通过就中止并输出错误摘要；使用正确的请求体；仅在配置了 `secret` 时附带
`Authorization`；按 HTTP 状态码分别写日志，成功时输出 `info: 配置已热重载.`。

---

## 三、构建与发布

- 产物命名改为 **`akashaProxy-<YYYYMMDD>-<7位 commit>.zip`**（日期为 UTC+8），
  Actions artifact 与 Release 资产同名，便于区分版本
- Release tag 改为 `<YYYYMMDD>-<7位 commit>`，说明正文取自本文件
- 内核只构建 `android/arm64-v8a`（与 `Makefile` 实际行为一致，readme 中的
  armeabi-v7a 描述已更正）

---

## 四、已知事项

- 首次启动需联网下载 `rule-providers`（约 40 个 `.mrs`）；单个下载失败只打 error 日志，
  不影响内核启动，下次 `interval` 到期会自动重试
- 策略组数量偏多（9 地区 × 3 变体），如需精简，直接删掉不用的地区组及其三个子组即可
