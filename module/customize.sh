MIN_KSU_VERSION=11563
MIN_KSUD_VERSION=11563
MIN_MAGISK_VERSION=26402

if [ ! $KSU ];then
    ui_print "- Magisk ver: $MAGISK_VER"
    ui_print "- Magisk version: $MAGISK_VER_CODE"
    if [ "$MAGISK_VER_CODE" -lt $MIN_MAGISK_VERSION ]; then
        ui_print "*********************************************************"
        ui_print "! 请使用 Magisk alpha 26301+"
        abort "*********************************************************"
    fi
elif [ $KSU ];then
    ui_print "- KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
    if ! [ "$KSU_KERNEL_VER_CODE" ] || [ "$KSU_KERNEL_VER_CODE" -lt $MIN_KSU_VERSION ] || [ "$KSU_VER_CODE" -lt $MIN_KSUD_VERSION ]; then
        ui_print "*********************************************************"
        ui_print "! KernelSU 版本太旧!"
        ui_print "! 请将 KernelSU 更新到最新版本"
        abort "*********************************************************"
    fi
else
    ui_print "! 未知的模块管理器"
    ui_print "$(set)"
    abort
fi


system_gid="1000"
system_uid="1000"
clash_data_dir="/data/clash"
case $(getprop ro.product.cpu.abi) in
    "arm64-v8a")
        ABI="arm64-v8"
        ;;
    "armeabi-v7a")
        ABI="armv7"
        ;;
    "x86")
        ABI="386"
        ;;
    "x86_64")
        ABI="amd64"
        ;;
    "")
        ABI="unknown"
        ;;
esac
mkdir -p ${clash_data_dir}/run
mkdir -p ${clash_data_dir}/clashkernel

[ -f ${clash_data_dir}/clashkernel/clashMeta ] && mv ${clash_data_dir}/clashkernel/clashMeta ${clash_data_dir}/clashkernel/mihomo
if [ ! -f ${clash_data_dir}/clashkernel/mihomo ];then
    unzip -o "$ZIPFILE" 'bin/*' -d "$TMPDIR" >&2
    if [ -f "${MODPATH}/bin/mihomo-android-${ABI}.gz" ];then
        ui_print "- 正在解压 mihomo 内核..."
        gunzip -f ${MODPATH}/bin/mihomo-android-${ABI}.gz
        mv -f ${MODPATH}/bin/mihomo-android-${ABI} ${clash_data_dir}/clashkernel/mihomo
    else
        abort "未找到架构: ${ABI} 请自行前往 GitHub 项目地址下载 → https://github.com/MetaCubeX/mihomo/releases"
    fi
fi

unzip -o "${ZIPFILE}" -x 'META-INF/*' -d ${MODPATH} >&2
unzip -o "${ZIPFILE}" -x 'clash/*' -d ${MODPATH} >&2

if [ -d "${clash_data_dir}" ];then
    rm -rf ${MODPATH}/clash/config.yaml.example
fi

if [ -f "${clash_data_dir}/packages.list" ];then
        ui_print "- packages.list 文件已存在 跳过覆盖."
        rm -rf ${MODPATH}/clash/packages.list
fi

if [ -f "${clash_data_dir}/clash.config" ];then
    mode=$(grep -i "^mode" ${clash_data_dir}/clash.config | awk -F '=' '{print $2}' | sed "s/\"//g")
    oldVersion=$(grep -i "version" ${clash_data_dir}/clash.config | awk -F '=' '{print $2}' | sed "s/\"//g")
    newVersion=$(grep -i "version" ${MODPATH}/clash/clash.config | awk -F '=' '{print $2}' | sed "s/\"//g")
    if [[ "${oldVersion}" >= "${newVersion}" ]] && [ ! "${oldVersion}" == "" ];then
        ui_print "- clash.config 文件已存在 跳过覆盖."
        rm -rf ${MODPATH}/clash/clash.config
    else
        sed -i "s/global/${mode}/g" ${MODPATH}/clash/clash.config
        cp -Rvf ${clash_data_dir}/clash.config ${clash_data_dir}/clash.config.old
    fi
fi

if [ "$(pm list packages | grep com.dashboard.kotlin)" == ""];then
    pm install -r ${MODPATH}/apk/DashBoard.apk
fi

cp -Rvf ${MODPATH}/clash/* ${clash_data_dir}/
rm -rf ${MODPATH}/clash
rm -rf ${MODPATH}/apk
rm -rf ${MODPATH}/bin
rm -rf ${MODPATH}/clashkernel

ui_print "- 开始设置权限."
set_perm_recursive ${MODPATH} 0 0 0770 0770
set_perm_recursive ${clash_data_dir} ${system_uid} ${system_gid} 0770 0770
set_perm_recursive ${clash_data_dir}/scripts ${system_uid} ${system_gid} 0770 0770
set_perm_recursive ${clash_data_dir}/mosdns ${system_uid} ${system_gid} 0770 0770
set_perm_recursive ${clash_data_dir}/adguard ${system_uid} ${system_gid} 0770 0770
set_perm_recursive ${clash_data_dir}/tools ${system_uid} ${system_gid} 0770 0770
set_perm_recursive ${clash_data_dir}/clashkernel ${system_uid} ${system_gid} 6770 6770
set_perm  ${clash_data_dir}/mosdns/mosdns  ${system_uid}  ${system_gid}  6770
set_perm  ${clash_data_dir}/adguard/AdGuardHome  ${system_uid}  ${system_gid}  6770
set_perm  ${clash_data_dir}/clashkernel/mihomo  ${system_uid}  ${system_gid}  6770
set_perm  ${clash_data_dir}/clash.config ${system_uid} ${system_gid} 0770
set_perm  ${clash_data_dir}/packages.list ${system_uid} ${system_gid} 0770


ui_print "
************************************************
使用须知:
1. 拥有自主判断/分析能力
2. 知道如何使用搜索引擎
3. 拥有阅读官方文档的能力
4. 拥有基础的Linux知识
4. 乐于折腾

> 否则不建议您使用本模块

如何使用本模块清查阅→https://github.com/ModuleList/akashaProxy
如何使用mihomo以及配置文件文档清查阅→https://wiki.metacubex.one/config
预设配置文件在 /data/clash/config.yaml.example
请重命名为 config.yaml 后使用DashBoard启动/停止 或者使用tools文件夹下的start.sh/stop.sh
************************************************
Telegram Channel: https://t.me/akashaProxy
"
