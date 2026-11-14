# AncientBuilding 参数参考（自动生成）

> 由 `AncientBuilding CLI params` 生成，不要手工编辑；改 schema 后重跑生成命令。
> 生成器 v14；模块 72 项，程序网格 47 项。
> 默认列：民居（house）；殿阁/门楼（hall）的差异见对应列。

## 生成命令

```bash
bash Tools/AncientBuilding/generate_param_reference.sh
```

## 建筑与部件参数

| 参数 | 标签 | 取值 | 默认（民居） | 默认（殿阁） | 种子幅度 | 固定默认 | 适用模式 | 说明 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| junction_height_tolerance | 接头高差容差 (m) | 0.005–0.15（步长 0.005） | 0.03 | 0.03 | 0 | 否 | compound | 檐口与正脊均在此容差内时统一到共同标高。明显高差应保留为高低连接。 |
| junction_clearance | 接头结构净距 (m) | 0.03–0.25（步长 0.01） | 0.08 | 0.08 | 0 | 否 | compound | 高低连接时为柱梁外缘和低屋顶保留净距；增大可能要求更长的低段。 |
| junction_gutter_width | 出水沟宽 (0=自动) | 0–0.6（步长 0.01） | 0 | 0 | 0 | 否 | compound | 0 按瓦垄间距自动确定。手动值至少 0.12 m 且不小于瓦垄间距的 55%。 |
| awning_style | 临街棚架 | 枚举：关闭 / 席棚 / 木板棚 / 开敞骨架 | 关闭 | 关闭 | 0 | 是 | rect | — |
| awning_projection | 棚面出挑 (m) | 0.6–2.8（步长 0.05） | 1.3 | 1.3 | 0.12 | 否 | rect | — |
| awning_height | 棚后缘离台高 (m) | 1.9–3.3（步长 0.05） | 2.5 | 2.5 | 0.05 | 否 | rect | — |
| awning_drop | 棚前缘降高 (m) | 0.1–0.6（步长 0.01） | 0.25 | 0.25 | 0.12 | 否 | rect | — |
| awning_sag | 席面下垂 (m) | 0–0.2（步长 0.01） | 0.06 | 0.06 | 0.25 | 否 | rect | — |
| awning_edge | 席面自由挑边 (m) | 0–0.18（步长 0.01） | 0 | 0 | 0.1 | 否 | rect | — |
| awning_bays | 棚覆盖开间 (0=全部) | 0–9（步长 1） | 0 | 0 | 0 | 否 | rect | — |
| awning_support | 棚架承托 | 枚举：落地立杆 / 墙侧斜撑 | 落地立杆 | 落地立杆 | 0 | 是 | rect | — |
| awning_pattern | 席面纹路 | 枚举：顺排苇席 / 经纬编织 / 斜编席 | 顺排苇席 | 顺排苇席 | 0 | 否 | rect | — |
| upper_porch_depth | 楼上退墙 (m) | 0–1.8（步长 0.05） | 0.92 | 0.92 | 0 | 否 | rect | — |
| beam_pattern | 梁枋线饰 | 枚举：素木 / 细线饰 / 几何菱带 | 素木 | 素木 | 0 | 是 | 全部 | — |
| bracket_style | 檐下承托 | 枚举：层叠铺作 / 简支梁枋 | 层叠铺作 | 层叠铺作 | 0 | 是 | rect | — |
| bracket_projection | 铺作出跳 (m) | 0.24–0.6（步长 0.01） | 0.36 | 0.36 | 0.1 | 否 | rect / tower | — |
| bracket_density | 补间铺作 | 枚举：仅柱头与转角 / 开间增加一攒 | 仅柱头与转角 | 开间增加一攒 | 0 | 是 | rect | — |
| joinery_bevel | 木件倒角 (m) | 0–0.012（步长 0.001） | 0.004 | 0.004 | 0 | 否 | 全部 | — |
| column_entasis | 柱身梭度 | 0–0.06（步长 0.005） | 0.015 | 0.015 | 0 | 否 | 全部 | — |
| column_taper | 柱头收分 | 0–0.14（步长 0.005） | 0.09 | 0.09 | 0 | 否 | 全部 | — |
| column_base | 柱础轮廓 | 枚举：阶叠柱础 / 覆盆柱础 / 素石墩 | 阶叠柱础 | 阶叠柱础 | 0 | 是 | rect / tower | — |
| column_base_height | 首层柱础高 (m) | 0.08–0.4（步长 0.01） | 0.34 | 0.34 | 0 | 否 | rect | — |
| platform_margin | 台沿外扩 (m) | 0.2–0.85（步长 0.01） | 0.62 | 0.62 | 0 | 否 | rect | — |
| surface_palette | 材作配色 | 枚举：原材作 / 街屋柔和材作 | 原材作 | 原材作 | 0 | 是 | rect | — |
| eave_style | 檐口做法 | 枚举：装饰檐口 / 素檐口 | 装饰檐口 | 装饰檐口 | 0 | 是 | rect | — |
| porch_depth | 前廊退墙 (m) | 0–1.8（步长 0.05） | 0.84 | 0.84 | 0 | 否 | rect | — |
| facade_style | 前脸围护 | 枚举：传统格扇 / 窗墙与中门 / 满开间落地格扇 / 敞铺门面 | 传统格扇 | 传统格扇 | 0 | 是 | rect | — |
| shop_opening | 铺面板扇开启 | 0–1（步长 0.05） | 1 | 1 | 0 | 否 | rect | — |
| counter_height | 铺窗柜台高 (m) | 0.6–1.1（步长 0.01） | 0.84 | 0.84 | 0 | 否 | rect | — |
| side_windows | 侧墙开窗 | 枚举：封墙 / 格窗 | 封墙 | 封墙 | 0 | 是 | rect | — |
| gable_finish | 山墙封护 | 枚举：木板 / 灰泥 | 木板 | 木板 | 0 | 是 | rect | — |
| gable_rafter_setback | 山墙椽列内退 (m) | 0–0.3（步长 0.01） | 0.02 | 0.02 | 0 | 否 | rect | 檐椽和飞椽收在封闭山墙内侧的额外净距；0 仍避免构件穿墙。正背檐头保持。 |
| window_backing | 格心背衬 | 枚举：通透 / 纸绢 | 通透 | 通透 | 0 | 是 | rect / tower | — |
| railing_style | 栏杆样式 | 枚举：关闭 / 木栏 / 石栏 | 关闭 | 关闭 | 0 | 是 | rect / tower | — |
| railing_height | 栏杆高度 (m) | 0.55–1.15（步长 0.01） | 0.88 | 0.88 | 0.08 | 否 | rect / tower | — |
| balcony_depth | 塔挑台宽 (m) | 0–1.2（步长 0.05） | 0.65 | 0.65 | 0 | 否 | tower | — |
| bracket_spacing | 塔补间铺作间距 (m) | 0.65–2（步长 0.05） | 1.2 | 1.2 | 0.08 | 否 | tower | — |
| finial_height | 塔刹高度 (m) | 0.4–3.5（步长 0.05） | 1.8 | 1.8 | 0.1 | 否 | tower | — |
| ridge_profile | 脊身样式 | 枚举：圆盖素脊 / 薄压脊 / 高身灰脊 / 连弧花脊 | 圆盖素脊 | 圆盖素脊 | 0 | 是 | rect | — |
| ridge_ornament | 脊端装饰 | 枚举：随等级 / 素脊 / 兽饰 / 扇形鸱尾 | 随等级 | 随等级 | 0 | 是 | rect | — |
| ridge_height | 正脊高度 (m) | 0.1–0.6（步长 0.01） | 0.28 | 0.28 | 0.1 | 否 | rect | — |
| ridge_width | 正脊宽度 (m) | 0.14–0.46（步长 0.01） | 0.29 | 0.29 | 0.08 | 否 | rect | — |
| ridge_end_lift | 脊端生起 (m) | 0–0.35（步长 0.01） | 0 | 0 | 0.1 | 否 | rect | — |
| verge_width | 垂戗脊宽 (m) | 0.1–0.32（步长 0.01） | 0.19 | 0.19 | 0.1 | 否 | rect | — |
| ridge_joint_spacing | 正脊分节间距 (m) | 0–0.8（步长 0.02） | 0.4 | 0.4 | 0.1 | 否 | rect | — |
| ornament_scale | 脊端尺度 | 0.5–1.5（步长 0.05） | 1 | 1 | 0.1 | 否 | rect | — |
| ornament_relief | 脊饰浮雕强度 | 0–1（步长 0.05） | 0.6 | 0.6 | 0 | 否 | rect | — |
| ornament_curl | 脊饰卷尾程度 | 0.65–1.25（步长 0.05） | 1 | 1 | 0.08 | 否 | rect | — |
| roof_palette | 瓦作表面 | 枚举：灰陶瓦 / 青绿釉瓦 / 灰釉瓦 | 灰陶瓦 | 灰陶瓦 | 0 | 是 | 全部 | — |
| platform_paving | 独立石板铺地 | 枚举：关闭 / 开启 | 关闭 | 关闭 | 0 | 是 | rect / tower | — |
| paving_size | 石板边长 (m) | 0.4–1.2（步长 0.05） | 0.75 | 0.75 | 0.1 | 否 | rect / tower | — |
| entry_roof | 中央抱厦屋顶 | 枚举：关闭 / 开启 | 关闭 | 关闭 | 0 | 是 | rect | — |
| entry_projection | 抱厦出挑 (m) | 0.3–1.4（步长 0.05） | 0.8 | 0.8 | 0 | 否 | rect | — |
| entry_rise | 抱厦举高 (m) | 0.35–1.1（步长 0.05） | 0.65 | 0.65 | 0 | 否 | rect | — |
| roof_curve | 屋面凹曲程度 | 0–0.85（步长 0.05） | 0.52 | 0.52 | 0.1 | 否 | rect / tower | — |
| thatch_thickness | 茅束厚度 (m) | 0.12–0.45（步长 0.01） | 0.24 | 0.24 | 0.15 | 否 | rect | — |
| thatch_bundle | 茅束宽度 (m) | 0.08–0.3（步长 0.01） | 0.16 | 0.16 | 0.12 | 否 | rect | — |
| thatch_raggedness | 草梢参差 | 0–1（步长 0.05） | 0.6 | 0.6 | 0.2 | 否 | rect | — |
| thatch_rods | 压草杆 | 枚举：关闭 / 开启 | 开启 | 开启 | 0 | 是 | rect | — |
| damage | 几何破损强度 | 0–1（步长 0.05） | 0 | 0 | 0 | 否 | 全部 | — |
| damage_wood | 木件破损倍率 | 0–1（步长 0.05） | 1 | 1 | 0 | 否 | 全部 | — |
| damage_wall | 墙体破损倍率 | 0–1（步长 0.05） | 1 | 1 | 0 | 否 | 全部 | — |
| damage_roof | 瓦件破损倍率 | 0–1（步长 0.05） | 1 | 1 | 0 | 否 | 全部 | — |
| damage_stone | 石作破损倍率 | 0–1（步长 0.05） | 1 | 1 | 0 | 否 | 全部 | — |
| damage_depth | 缺口深度 (m) | 0.005–0.15（步长 0.005） | 0.06 | 0.06 | 0 | 否 | 全部 | — |
| damage_density | 受损密度 | 0–1（步长 0.05） | 0.7 | 0.7 | 0 | 否 | 全部 | — |
| wall_thickness | 围护厚度 (m) | 0.12–0.6（步长 0.01） | 0.32 | 0.32 | 0 | 否 | 全部 | — |
| board_width | 墙板宽度 (m) | 0.1–0.4（步长 0.01） | 0.18 | 0.18 | 0.1 | 否 | 全部 | — |
| log_diameter | 垒木层高 (m) | 0.12–0.4（步长 0.01） | 0.22 | 0.22 | 0.1 | 否 | 全部 | — |
| base_height | 台基高度 (m) | 0.12–1.2（步长 0.01） | 0.45 | 0.72 | 0.16 | 否 | 全部 | — |
| floor_height | 柱层高度 (m) | 2.7–3.9（步长 0.01） | 3.05 | 3.6 | 0.1 | 否 | 全部 | — |
| column_radius | 主柱半径 (m) | 0.1–0.25（步长 0.005） | 0.145 | 0.19 | 0.13 | 否 | 全部 | — |
| eave_depth | 檐口挑出 (m) | 0.45–1.2（步长 0.01） | 0.67 | 0.86 | 0.18 | 否 | 全部 | — |
| roof_rise_ratio | 屋顶高深比 | 0.2–0.4（步长 0.01） | 0.29 | 0.33 | 0.14 | 否 | 全部 | — |
| corner_lift | 翼角抬升 (m) | 0–0.6（步长 0.01） | 0.47 | 0.47 | 0.2 | 否 | 全部 | — |
| tile_pattern | 铺瓦纹路 | 枚举：筒板瓦 / 错缝板瓦 / 鳞叠板瓦 | 筒板瓦 | 筒板瓦 | 0 | 是 | rect | — |
| tile_pitch | 瓦垄间距 (m) | 0.22–0.38（步长 0.005） | 0.285 | 0.285 | 0.14 | 否 | 全部 | — |
| rafter_spacing | 檐椽间距 (m) | 0.24–0.45（步长 0.01） | 0.32 | 0.32 | 0.16 | 否 | 全部 | — |
| rafter_radius | 檐椽半径 (m) | 0.045–0.09（步长 0.001） | 0.068 | 0.068 | 0.12 | 否 | 全部 | — |
| lattice_style | 格心样式 | 枚举：传统格心 / 疏横格心 / 菱形格心 / 方格格心 | 传统格心 | 传统格心 | 0 | 否 | 全部 | — |
| lattice_bars | 格心竖棂数 | 3–9（步长 1） | 5 | 5 | 0.35 | 否 | 全部 | — |
| lattice_bar | 棂条宽度 (m) | 0.012–0.035（步长 0.001） | 0.021 | 0.021 | 0.2 | 否 | 全部 | — |
| hanging_style | 挂落样式 | 枚举：卷草挂落 / 菱格挂落 / 素牙挂落 | 卷草挂落 | 卷草挂落 | 0 | 否 | 全部 | — |
| hanging_height | 挂落高度 (m) | 0.2–0.48（步长 0.01） | 0.36 | 0.36 | 0.18 | 否 | 全部 | — |
| cap_pattern | 瓦当纹样 | 枚举：卷纹 / 花瓣 / 素环 | 卷纹 | 卷纹 | 0 | 否 | 全部 | — |
| lanterns | 灯笼 | 枚举：关闭 / 开启 | 关闭 | 开启 | 0 | 是 | 全部 | — |
| hangings | 挂落 | 枚举：关闭 / 开启 | 关闭 | 开启 | 0 | 是 | 全部 | — |

## 模块参数

模块参数写入 `modules[].params`；`unit`/`max_stretch`/`repeat_unit` 用于 S/R/P 求解。

### Base

| ID | 模块 | 策略 | 实现 | unit | max_stretch | repeat_unit | 参数（类型/默认/范围） |
| --- | --- | --- | --- | ---: | ---: | ---: | --- |
| B01 | 台明 | S | 是 | 1 | 1.2 | 1 | height：length，默认 0.45，范围 0.05–3；depth：length，默认 2，范围 0.2–20；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| B02 | 阶条石 | R | 是 | 0.6 | 1 | 0.6 | height：length，默认 0.18，范围 0.05–0.4；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| B03 | 台面铺地 | R | 占位 | 0.4 | 1 | 0.4 | — |
| B04 | 踏跺 | P | 是 | 1 | 1 | 0 | height：length，默认 0.45，范围 0.1–1.5；depth：length，默认 0.6，范围 0.2–3；steps：int，默认 3，范围 1–12；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| B05 | 踏步 | R | 是 | 0.3 | 1 | 0.3 | height：length，默认 0.15，范围 0.05–0.5；depth：length，默认 0.3，范围 0.1–1；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| B06 | 垂带 | S | 占位 | 1 | 1.2 | 1 | — |
| B07 | 御路 | P | 占位 | 1 | 1 | 0 | — |
| B08 | 栏杆 | P | 占位 | 1 | 1 | 0 | — |
| B09 | 望柱 | R | 是 | 0.6 | 1 | 0.6 | height：length，默认 0.71，范围 0.3–1.35；style：int，默认 0，范围 0–1 |
| B10 | 栏板 | R | 是 | 0.9 | 1 | 0.9 | width：length，默认 0.8，范围 0.28–1.2；height：length，默认 0.66，范围 0.28–1.2；style：int，默认 0，范围 0–1 |
| B11 | 须弥座 | P | 占位 | 1 | 1 | 0 | — |
| B12 | 柱础 | R | 是 | 0.5 | 1 | 0.5 | radius：length，默认 0.29，范围 0.1–0.8；height：length，默认 0.26，范围 0.08–0.6；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；style：int，默认 0，范围 0–2 |
| B13 | 铺地 | S | 占位 | 1 | 1.2 | 1 | — |
| B14 | 砖缝 | R | 占位 | 0.4 | 1 | 0.4 | — |

### Frame

| ID | 模块 | 策略 | 实现 | unit | max_stretch | repeat_unit | 参数（类型/默认/范围） |
| --- | --- | --- | --- | ---: | ---: | ---: | --- |
| F01 | 柱 | S | 是 | 1 | 1.2 | 1 | radius：length，默认 0.12，范围 0.025–0.5；height：length，默认 3，范围 0.5–15；sides：int，默认 12，范围 3–32；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；taper：ratio，默认 0.09，范围 0–0.14；entasis：ratio，默认 0.015，范围 0–0.06 |
| F02 | 额枋 | S | 是 | 1 | 1.2 | 1 | height：length，默认 0.28，范围 0.05–1.1；depth：length，默认 0.22，范围 0.08–0.6；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；bevel：length，默认 0.004，范围 0–0.012 |
| F03 | 穿插枋 | S | 占位 | 1 | 1.2 | 1 | — |
| F04 | 梁 | P | 是 | 1 | 1 | 0 | height：length，默认 0.28，范围 0.05–1.1；depth：length，默认 0.22，范围 0.08–0.6；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；bevel：length，默认 0.004，范围 0–0.012 |
| F05 | 檩 | S | 是 | 1 | 1.2 | 1 | radius：length，默认 0.09，范围 0.02–0.3；sides：int，默认 8，范围 3–16；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| F06 | 瓜柱 | A | 占位 | 1 | 1 | 0 | — |
| F07 | 斗栱 | R | 是 | 0.5 | 1 | 0.5 | height：length，默认 0.3，范围 0.15–0.8；depth：length，默认 0.35，范围 0.15–1 |
| F08 | 斗 | R | 是 | 0.3 | 1 | 0.3 | width：length，默认 0.3，范围 0.1–0.7；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；bevel：length，默认 0.004，范围 0–0.012；slot：length，默认 0.16，范围 0.03–0.4 |
| F09 | 栱 | R | 是 | 0.4 | 1 | 0.4 | width：length，默认 0.85，范围 0.24–1.8；height：length，默认 0.19，范围 0.08–0.6；depth：length，默认 0.16，范围 0.08–0.6；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；bevel：length，默认 0.004，范围 0–0.012；fork：int，默认 0，范围 0–1；fork_angle：int，默认 90，范围 45–135 |
| F10 | 昂 | A | 是 | 1 | 1 | 0 | length：length，默认 0.8，范围 0.2–2；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；bevel：length，默认 0.004，范围 0–0.012 |
| F11 | 檐椽 | R | 是 | 0.24 | 1 | 0.24 | radius：length，默认 0.06，范围 0.02–0.2；length：length，默认 1.2，范围 0.05–4；sides：int，默认 8，范围 3–16；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| F12 | 飞椽 | R | 是 | 0.24 | 1 | 0.24 | length：length，默认 0.76，范围 0.05–3；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；width：length，默认 0.094，范围 0.04–0.16；height：length，默认 0.082，范围 0.035–0.16 |
| F13 | 望板 | S | 是 | 1 | 1.2 | 1 | thickness：length，默认 0.03，范围 0.01–0.3；length：length，默认 1.2，范围 0.2–12；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| F14 | 连檐 | S | 是 | 1 | 1.2 | 1 | length：length，默认 0.45，范围 0.09–1.2；height：length，默认 0.115，范围 0.04–0.26；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| F15 | 瓦口 | R | 占位 | 0.3 | 1 | 0.3 | — |

### Wall

| ID | 模块 | 策略 | 实现 | unit | max_stretch | repeat_unit | 参数（类型/默认/范围） |
| --- | --- | --- | --- | ---: | ---: | ---: | --- |
| W01 | 墙身 | S | 是 | 1 | 1.2 | 1 | thickness：length，默认 0.2，范围 0.05–1；height：length，默认 2.6，范围 0.3–12；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；wall_kind：int，默认 0，范围 0–3；board_width：length，默认 0.18，范围 0.1–0.4；log_diameter：length，默认 0.22，范围 0.12–0.4 |
| W02 | 下碱 | S | 是 | 1 | 1.2 | 1 | height：length，默认 0.55，范围 0.05–2.5；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| W03 | 墙帽 | S | 是 | 1 | 1.2 | 1 | height：length，默认 0.18，范围 0.05–0.5；depth：length，默认 0.32，范围 0.1–0.8 |
| W04 | 砖 | R | 占位 | 0.24 | 1 | 0.24 | — |
| W05 | 砖缝 | R | 占位 | 0.24 | 1 | 0.24 | — |
| W06 | 山墙 | P | 是 | 1 | 1 | 0 | rise：length，默认 1.2，范围 0.05–6；thickness：length，默认 0.11，范围 0.05–0.5；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；curve：ratio，默认 0.52，范围 0–0.85 |
| W07 | 墀头 | A | 占位 | 1 | 1 | 0 | — |
| W08 | 博风板 | P | 占位 | 1 | 1 | 0 | — |
| W09 | 山花板 | P | 占位 | 1 | 1 | 0 | — |

### Opening

| ID | 模块 | 策略 | 实现 | unit | max_stretch | repeat_unit | 参数（类型/默认/范围） |
| --- | --- | --- | --- | ---: | ---: | ---: | --- |
| O01 | 门框 | A | 是 | 1 | 1 | 0 | width：length，默认 1.2，范围 0.6–4；height：length，默认 2.2，范围 1.4–3.2；frame：length，默认 0.08，范围 0.03–0.2；depth：length，默认 0.15，范围 0.06–0.4 |
| O02 | 门扇 | R | 是 | 0.55 | 1 | 0.55 | height：length，默认 2.1，范围 0.6–4；thickness：length，默认 0.05，范围 0.02–0.15；width：length，默认 0.55，范围 0.22–1.1；pattern：int，默认 0，范围 0–3；bars：int，默认 5，范围 3–9；bar：length，默认 0.021，范围 0.012–0.035；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；window：int，默认 0，范围 0–1 |
| O03 | 门钉 | R | 占位 | 0.12 | 1 | 0.12 | — |
| O04 | 铺首 | A | 是 | 1 | 1 | 0 | radius：length，默认 0.052，范围 0.025–0.1 |
| O05 | 门槛 | S | 是 | 1 | 1.2 | 1 | height：length，默认 0.12，范围 0.05–0.4；depth：length，默认 0.28，范围 0.1–0.8；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| O06 | 窗框 | S | 是 | 1 | 1.2 | 1 | width：length，默认 1.2，范围 0.5–3；height：length，默认 1.2，范围 0.5–4；frame：length，默认 0.06，范围 0.02–0.15；depth：length，默认 0.12，范围 0.05–0.3 |
| O07 | 棂条 | R | 是 | 0.12 | 1 | 0.12 | height：length，默认 1.1，范围 0.4–2.4；bar：length，默认 0.02，范围 0.01–0.06；depth：length，默认 0.04，范围 0.01–0.12 |
| O08 | 窗纸 | S | 是 | 1 | 1.2 | 1 | height：length，默认 1，范围 0.1–4 |
| O09 | 槛墙 | S | 占位 | 1 | 1.2 | 1 | — |
| O10 | 横披 | S | 占位 | 1 | 1.2 | 1 | — |
| O11 | 挂落 | P | 是 | 1 | 1 | 0 | height：length，默认 0.36，范围 0.16–0.8；pattern：int，默认 0，范围 0–2；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| O12 | 花罩 | P | 占位 | 1 | 1 | 0 | — |

### Roof

| ID | 模块 | 策略 | 实现 | unit | max_stretch | repeat_unit | 参数（类型/默认/范围） |
| --- | --- | --- | --- | ---: | ---: | ---: | --- |
| R01 | 屋面 | P | 是 | 1 | 1 | 0 | depth：length，默认 6，范围 0.15–40；rise：length，默认 1.5，范围 0.05–10；overhang：length，默认 0.4，范围 0–2；patch：int，默认 0，范围 0–1；inset：length，默认 0，范围 0–10；lift：length，默认 0，范围 0–1.5；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；covering：int，默认 0，范围 0–1；curve：ratio，默认 0.52，范围 0–0.85；straw_depth：length，默认 0.24，范围 0.12–0.45；bundle：length，默认 0.16，范围 0.08–0.3；ragged：ratio，默认 0.6，范围 0–1；straw_seed：int，默认 0，范围 0–2147483646 |
| R02 | 瓦面 | R | 是 | 0.3 | 1 | 0.3 | length：length，默认 1.2，范围 0.1–5；thickness：length，默认 0.03，范围 0.005–0.2 |
| R03 | 瓦垄 | R | 是 | 0.3 | 1 | 0.3 | pattern：int，默认 0，范围 0–2；radius：length，默认 0.08，范围 0.03–0.2；length：length，默认 1，范围 0.1–12；sides：int，默认 8，范围 3–16；pitch：length，默认 0.3，范围 0.12–0.6；rise：length，默认 0，范围 0–10；lift：length，默认 0，范围 0–1.5；inset：length，默认 0，范围 0–10；left：length，默认 12，范围 0–40；right：length，默认 12，范围 0–40；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；curve：ratio，默认 0.52，范围 0–0.85 |
| R04 | 滴水 | R | 是 | 0.3 | 1 | 0.3 | width：length，默认 0.26，范围 0.1–0.6；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；pattern：int，默认 0，范围 0–1 |
| R05 | 瓦当 | R | 是 | 0.3 | 1 | 0.3 | radius：length，默认 0.085，范围 0.03–0.22；pattern：int，默认 0，范围 0–2；neck_length：length，默认 0，范围 0–0.4；neck_radius：length，默认 0，范围 0–0.22；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7 |
| R06 | 正脊 | P | 是 | 1 | 1 | 0 | profile：int，默认 0，范围 0–3；end_lift：length，默认 0，范围 0–0.35；foot_width：length，默认 0，范围 0–1；joint_spacing：length，默认 0.4，范围 0–0.8；height：length，默认 0.35，范围 0.05–1.5；thickness：length，默认 0.3，范围 0.05–1；overhang：length，默认 0.4，范围 0–2；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；covering：int，默认 0，范围 0–1 |
| R07 | 垂脊 | P | 是 | 1 | 1 | 0 | profile：int，默认 0，范围 0–3；height：length，默认 0，范围 0–1；foot_width：length，默认 0，范围 0–1；run：length，默认 1.8，范围 0.2–10；rise：length，默认 1.2，范围 0.2–8；thickness：length，默认 0.22，范围 0.05–0.8；inset：length，默认 0，范围 0–10；lift：length，默认 0，范围 0–1.5；paired：int，默认 0，范围 0–1；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；curve：ratio，默认 0.52，范围 0–0.85 |
| R08 | 戗脊 | P | 是 | 1 | 1 | 0 | profile：int，默认 0，范围 0–3；height：length，默认 0，范围 0–1；foot_width：length，默认 0，范围 0–1；run：length，默认 1.8，范围 0.2–10；rise：length，默认 1.2，范围 0.2–8；thickness：length，默认 0.22，范围 0.05–0.8；inset：length，默认 0，范围 0–10；lift：length，默认 0，范围 0–1.5；paired：int，默认 0，范围 0–1；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；curve：ratio，默认 0.52，范围 0–0.85 |
| R09 | 博脊 | P | 是 | 1 | 1 | 0 | width：length，默认 1，范围 0.05–30 |
| R10 | 脊筒 | R | 占位 | 0.4 | 1 | 0.4 | — |
| R11 | 吻兽 | A | 是 | 1 | 1 | 0 | height：length，默认 0.6，范围 0.1–2；width：length，默认 0.3，范围 0.05–1.5；depth：length，默认 0.25，范围 0.05–1.5；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；style：int，默认 0，范围 0–1；relief：ratio，默认 0.6，范围 0–1；curl：ratio，默认 1，范围 0.65–1.25 |
| R12 | 垂兽 | A | 是 | 1 | 1 | 0 | height：length，默认 0.4，范围 0.1–1.5；width：length，默认 0.2，范围 0.05–1；depth：length，默认 0.18，范围 0.05–1；damage：ratio，默认 0，范围 0–1；damage_depth：length，默认 0.06，范围 0.005–0.15；damage_density：ratio，默认 0.7，范围 0–1；damage_seed：int，默认 0，范围 0–7；style：int，默认 0，范围 0–1；relief：ratio，默认 0.6，范围 0–1；curl：ratio，默认 1，范围 0.65–1.25 |
| R13 | 套兽 | A | 占位 | 1 | 1 | 0 | — |
| R14 | 宝顶 | A | 是 | 1 | 1 | 0 | height：length，默认 0.8，范围 0.2–3.5；radius：length，默认 0.25，范围 0.1–0.7；style：int，默认 0，范围 0–1 |
| R15 | 悬鱼 | A | 是 | 1 | 1 | 0 | height：length，默认 0.6，范围 0.25–1.2 |
| R16 | 翼角 | P | 占位 | 1 | 1 | 0 | — |
| R17 | 望板（屋面） | S | 占位 | 1 | 1.2 | 1 | — |
| R18 | 翼角椽 | P | 占位 | 1 | 1 | 0 | — |
| R19 | 棚面 | P | 是 | 1 | 1 | 0 | depth：length，默认 1.3，范围 0.6–2.8；drop：length，默认 0.25，范围 0.1–0.6；sag：length，默认 0.06，范围 0–0.2；covering：int，默认 0，范围 0–1；pattern：int，默认 0，范围 0–2；seed：int，默认 0，范围 0–2147483646；edge：length，默认 0，范围 0–0.18 |

### Ornament

| ID | 模块 | 策略 | 实现 | unit | max_stretch | repeat_unit | 参数（类型/默认/范围） |
| --- | --- | --- | --- | ---: | ---: | ---: | --- |
| D01 | 匾额 | A | 是 | 1 | 1 | 0 | width：length，默认 1.2，范围 0.3–3；height：length，默认 0.5，范围 0.2–1.2；depth：length，默认 0.08，范围 0.03–0.3；frame：length，默认 0.05，范围 0.01–0.15 |
| D02 | 楹联 | A | 占位 | 1 | 1 | 0 | — |
| D03 | 灯笼 | A | 是 | 1 | 1 | 0 | height：length，默认 0.65，范围 0.25–1.5 |

## 备注

- `S`/`R`/`A`/`P` 策略与尺寸身份见 008 §4.3；
- 选择型字段的默认值是索引，生成器按 `choices` 取标签；
- 种子只改变非固定项，固定值优先（008 §5.9）；
- 未实现模块仍可手动摆放，但会退化为 unit box，面板显示“占位”。
