### SAN_QAQ的坦克世界闪击战国服模组整合包

<img src="https://avatars.githubusercontent.com/u/88847568?v=4" alt="SAN_QAQ" style="zoom: 50%;" />

------

一款针对国服适配的整合很多优质模组的整合包。

**使用本整合包前请注意，本整合包可能带来卡顿或恶性bug**

### ✅主要功能
- [x] **玩梗文本** - 加入了很多梗的文本包，修改了几乎所有文本
- [x] **UI模糊** - 对很多UI界面添加了毛玻璃模糊化效果
- [x] **画质修改** - 重新调色，为移动端带来桌面级别的渲染(~~压力~~)
- [x] **更多设置** - 解锁了电影画质选项(~~不建议开启~~)
- [x] **图标修改** - 修改了炮弹和点亮等图标(~~加入二次元~~)
- [x] **反和谐** - 旗帜反和谐
- [x] **完整科技树** - 显示完整的科技树，包含大部分金币载具和绝版载具
- [x] **闪电系语音包** - 对闪电系部分车辆添加玩梗语音包
- [x] **旧版聊天框** - 更改车库聊天框位置到旧版本
- [x] **地图修改** - 修改部分地图的色调
- [x] **车辆模型修改** - 修改尾气，弹痕和履带印等
- [x] **炮弹着色** - 使炮弹非常显眼
- [x] **二次元背景** - 加载图修改为二次元背景
- [ ] **性能优化** - 咕咕咕
- [ ] ~~**更多模糊和调色** - SAN_QAQ喜欢模糊~~

### 🛠️使用方法
#### 快速安装
前往[**releases**](https://github.com/SAN-QAQ/WoT-Blitz-ModPack/releases)下载发布版本(如果遇到热更新可能需要手动安装修复包)和`data.zip`(可能没有)
<details>
<summary>什么是热更新?</summary>
如果不需要下载新版本安装包，只需要进入游戏后下载资源的版本就是热更新
</details>

##### 第一次安装

1. 准备一个[mt管理器](https://mt2.cn/download/)或其他文件管理工具以访问`/storage/emulated/0/Android/data/`目录(有关该目录无法访问的问题请自行搜索)
2. 如果需要保留游戏数据(如回放和已安装的模组)，请备份`/storage/emulated/0/Android/data/com.netease.wotb/`目录内的文件
3. 卸载原先的游戏
4. 安装模组版本的游戏
5. 将`data.zip`的内容放入 `/storage/emulated/0/Android/data/com.netease.wotb/files/packs/`目录内(`data.zip`其实就是`./Objects/SAN_QAQ/DATA`目录内的文件)
6. 启动游戏检查模组是否生效

##### 安装更新

1. 直接安装模组版本
2. 将`data.zip`的内容放入 `/storage/emulated/0/Android/data/com.netease.wotb/files/packs/`目录内

#### 手动修改安装包并安装

1. 下载存储库，准备一个[mt管理器](https://mt2.cn/download/)
2. 准备好当前版本的官方安装包
3. 将`./ModPack`目录内的文件放入官方安装包的`./assets/Data/`目录内
4. 将`./Objects/SAN_QAQ/APK`目录内的文件放入官方安装包的`./assets/Data/`目录内
5. 签名修改好后的安装包
6. (可选但推荐)使用mt的`注入文件提供器`功能，这样未root的设备也可以直接访问游戏在`/data/`目录内存放的数据
7. 此时已修改完成，可以参考上面的方法进行后续安装

### ⚠️ 注意事项

1. 整合包内容较多，可能需要较高配置的设备
2. 整合包bug较多，有bug可以提交issue
3. 如果新版本已经更新但整合包没有更新，可以先安装官方安装包并删除`/storage/emulated/0/Android/data/com.netease.wotb/files/packs/`目录中的`XML`文件夹，就可以先游玩官方版本

### 📜 版权说明

此整合包内的模组大部分来自国外模组作者，SAN_QAQ进行了汉化和适配工作，如有侵权请联系删除
