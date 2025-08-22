## akashaProxy

中文 | [English](./readme.md)

### 使用须知

1. 拥有自主判断/分析能力
2. 知道如何使用搜索引擎
3. 拥有阅读官方文档的能力
4. 拥有基础的Linux知识
4. 乐于折腾

> 否则不建议您使用本模块


akashaProxy 是 mihomo 衍生的Magisk/KernelSU模块

名字来源于[mihomo文档](https://wiki.metacubex.one)的虚空终端修改而来

~~中文名应该叫`虚空代理`~~

---

**此模块99%的问题基本上都来自clash配置错误或插件配置错误**

**请善用搜索引擎和日志**

## 配置：

**工作路径：/data/clash/**

`clash.config` : 模块启动配置

`config.yaml.` ：clash配置文件

`packages.list` : 进行代理的黑/白名单列表

yacd管理面板：127.0.0.1:9090/ui（默认）

>将config.yaml.example重命名为config.yaml后填写配置文件，或者使用你自己的配置文件

clash教程：
https://wiki.metacubex.one
https://clash-meta.wiki

## 启动和停止

开始：
````
/data/clash/scripts/clash.service -s && /data/clash/scripts/clash.iptables -s
````

停止：
````
/data/clash/scripts/clash.service -k && /data/clash/scripts/clash.iptables -k
````

您还可以使用[dashboard](https://t.me/MagiskChangeKing)管理启停或者使用KernelSU webUI

## 编译

执行 `make` 编译并打包模块
````
make
````
> 默认构建android平台下armeabi-v7a架构和arm64-v8a架构

## 发布

[Telegram](https://t.me/akashaProxy)
[Github工作流(需要解压)](https://github.com/ModuleList/akashaProxy/actions)
