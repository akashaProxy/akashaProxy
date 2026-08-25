## akashaProxy

中文 | [English](./readme.md)

基于 **mihomo 原生内核**的 Magisk / KernelSU 透明代理模块，支持 tproxy / tun / redirect 三种代理模式。

名字来源于 [clashMeta 文档](https://wiki.metacubex.one)的虚空终端修改而来

~~中文名应该叫 `虚空代理`~~

### 使用须知

1. 拥有自主判断/分析能力
2. 知道如何使用搜索引擎
3. 拥有阅读官方文档的能力
4. 拥有基础的 Linux 知识
5. 乐于折腾

> 否则不建议您使用本模块

**此模块 99% 的问题基本上都来自 clash 配置错误或插件配置错误**

**请善用搜索引擎和日志**

---

## 配置

**工作路径：`/data/adb/akashaProxy/`**

| 文件 | 说明 |
|---|---|
| `clash.config` | 模块启动配置（开机自启、代理模式、插件、ghproxy 等） |
| `config.yaml` | mihomo 配置文件 |
| `config.example.yaml` | 默认配置模板，见下 |
| `packages.list` | 进行代理的黑/白名单列表 |
| `run/run.logs` | 模块日志 |
| `run/kernel.log` | 内核日志（看规则命中看这个） |

管理面板（zashboard）：`http://127.0.0.1:9090/ui`，KernelSU 用户也可直接使用模块自带的 WebUI。

> 将 `config.example.yaml` 重命名为 `config.yaml` 后填写，或者使用你自己的配置文件

clash 教程：
https://wiki.metacubex.one
https://clash-meta.wiki

### 默认配置模板

模板开箱即用，**唯一必填项是 `proxy-providers` 里的机场订阅链接**（文件中有 `####` 横幅标注）。
内容概览：

- 51 个策略组 / 40 个规则集 / 60 条分流规则，全部使用 mihomo 原生组类型
- 细分策略：人工智能、海外社交、国内社交、国际媒体、谷歌服务、微软服务、金融平台、游戏平台
- 地区策略 9 组（香港/台湾/日本/韩国/新加坡/美国/英国/欧洲/其他地区），每组内置
  `自动(url-test)`、`负载均衡-散列`、`负载均衡-轮询` 三个子组，可多节点叠加带宽
- 广告拦截使用[秋风广告规则 AWAvenue Ads Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule)
- 大类分流走模块内置的 `GeoSite.dat` / `GeoIP.dat`（离线可用），细分类走 `.mrs` 规则集
- 国内社交按 **App 包名**（`PROCESS-NAME`）分流，可连带 App 调用的三方 CDN / 统计 / 风控一起归类

改动详情见 [CHANGELOG.md](./CHANGELOG.md)。

> 若使用自己的配置文件，请保留模块要读取的字段：顶层 `redir-port` / `tproxy-port` / `mixed-port`，
> `ip:port` 格式的 `dns.listen` 与 `external-controller`，以及 `tun.enable` / `tun.auto-route` / `tun.device`。

---

## 启动和停止

开始：
````
/data/adb/akashaProxy/scripts/clash.service -s && /data/adb/akashaProxy/scripts/clash.iptables -s
````

停止：
````
/data/adb/akashaProxy/scripts/clash.service -k && /data/adb/akashaProxy/scripts/clash.iptables -k
````

热重载配置（会先做 `mihomo -t` 校验，不通过不生效）：
````
/data/adb/akashaProxy/scripts/clash.tool -s
````

您还可以使用 [dashboard](https://t.me/MagiskChangeKing) 管理启停或者使用 KernelSU webUI

## 模块

[模块文档](./docs/zh/module-zh.md)

## 编译

执行 `make` 编译并打包模块
````
make
````
> 需要 `curl unzip pnpm go upx zip`；默认只构建 android 平台下的 arm64-v8a 架构

## 发布

产物命名：`akashaProxy-<YYYYMMDD>-<7 位 commit>.zip`（日期为 UTC+8）

[本仓库 Releases](https://github.com/TG-Twilight/akashaProxy/releases)

[Github 工作流(需要解压)](https://github.com/TG-Twilight/akashaProxy/actions)

上游项目：[akashaProxy/akashaProxy](https://github.com/akashaProxy/akashaProxy) ·
[Telegram](https://t.me/akashaProxyci)
