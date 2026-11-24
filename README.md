# 建材套餐计数（PackageCounter）

记录 Hay Day 货仓建材套餐每天发货次数的小工具：多账号、30 天格子日历、今日已发货 / 撤销、套餐设置，数据保存在手机本地。

## 安装

到本仓库的 Releases 下载最新的 `PackageCounter.ipa`，用 SideStore / AltStore 在 iPhone 上安装即可（未签名包，需通过 SideStore/AltStore 自签）。

## 构建

GitHub Actions（`.github/workflows/build.yml`）在 macos-15 上用 XcodeGen 生成工程并打包未签名 IPA，同时上传 artifact 并发布到 Release。图标在构建前由 `icon-1024.b64` 解码生成。
