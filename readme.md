## akashaProxy

English | [中文](./readme_zh.md)

A Magisk / KernelSU transparent proxy module built on the **native mihomo kernel**,
supporting tproxy / tun / redirect modes.

The name is modified from the void terminal of [clashMeta document](https://wiki.metacubex.one)

~~The Chinese name should be called `Void Agent`~~

### Instructions for use

1. Possess independent judgment/analysis ability.
2. Know how to use a search engine.
3. Ability to read official documents.
4. Have basic knowledge of Linux.
5. Willing to tinker.

> Otherwise, we do not recommend using this module

**99% of the problems with this module basically come from clash configuration errors or plug-in configuration errors**

**Please make good use of search engines and logs**

---

## Configuration

**Working path: `/data/adb/akashaProxy/`**

| File | Description |
|---|---|
| `clash.config` | module startup configuration (auto start, proxy mode, plugins, ghproxy ...) |
| `config.yaml` | mihomo configuration file |
| `config.example.yaml` | default configuration template, see below |
| `packages.list` | black/white list for proxying |
| `run/run.logs` | module log |
| `run/kernel.log` | kernel log (check rule matching here) |

Dashboard (zashboard): `http://127.0.0.1:9090/ui` — KernelSU users can also use the bundled WebUI.

> Rename `config.example.yaml` to `config.yaml` and fill it in, or use your own configuration file

clash tutorial:
https://wiki.metacubex.one
https://clash-meta.wiki

### Default configuration template

The template works out of the box. **The only field you must fill in is the subscription
URL under `proxy-providers`** (marked with a `####` banner in the file). It ships with:

- 51 proxy groups / 40 rule sets / 60 rules, using native mihomo group types only
- Dedicated policies for AI, overseas social, domestic social, streaming, Google, Microsoft,
  finance & crypto, and gaming platforms
- 9 region policies (HK / TW / JP / KR / SG / US / UK / EU / Others), each with
  `url-test`, `load-balance (consistent-hashing)` and `load-balance (round-robin)`
  sub-groups so you can aggregate bandwidth across nodes
- Ad blocking via [AWAvenue Ads Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule)
- Coarse routing from the bundled `GeoSite.dat` / `GeoIP.dat` (works offline),
  fine-grained routing from `.mrs` rule sets
- Domestic apps routed by **Android package name** (`PROCESS-NAME`), which also captures
  the third-party CDN / analytics / anti-fraud domains those apps call

See [CHANGELOG.md](./CHANGELOG.md) for details.

> If you bring your own config, keep the keys the module parses: top-level `redir-port` /
> `tproxy-port` / `mixed-port`, `dns.listen` and `external-controller` in `ip:port` form,
> plus `tun.enable` / `tun.auto-route` / `tun.device`.

---

## Start and stop

start:
````
/data/adb/akashaProxy/scripts/clash.service -s && /data/adb/akashaProxy/scripts/clash.iptables -s
````

stop:
````
/data/adb/akashaProxy/scripts/clash.service -k && /data/adb/akashaProxy/scripts/clash.iptables -k
````

hot reload the config (validated with `mihomo -t` first, invalid configs are rejected):
````
/data/adb/akashaProxy/scripts/clash.tool -s
````

You can also use [dashboard](https://t.me/MagiskChangeKing) to manage startup and shutdown or KernelSU webUI control

## module

[module wiki](./docs/module.md)

## Compile

Execute `make` to compile and package the module
````
make
````
> Requires `curl unzip pnpm go upx zip`; only the arm64-v8a architecture is built for android

## Publish

Artifact name: `akashaProxy-<YYYYMMDD>-<7-char commit>.zip` (date in UTC+8)

[Releases](https://github.com/TG-Twilight/akashaProxy/releases)

[Github action (requires decompression)](https://github.com/TG-Twilight/akashaProxy/actions)

Upstream: [akashaProxy/akashaProxy](https://github.com/akashaProxy/akashaProxy) ·
[Telegram](https://t.me/akashaProxyci)
