# 🗡️ 全链梦幻：元气地牢伏魔录 (Monad Soul Knight Edition - V5 Parallel-Native)
> **Full-chain Roguelike Dungeon • Parallel-Native EVM Architecture • On-Chain Star Forging & C2C Bazaar • Scaffold-ETH & Vercel One-Click Production**

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fgithubskylh%2Fmonad-cellular-arena)
[![CI / CD](https://github.com/githubskylh/monad-cellular-arena/actions/workflows/deploy.yml/badge.svg)](https://github.com/githubskylh/monad-cellular-arena/actions)
[![Live Demo (GitHub Pages)](https://img.shields.io/badge/Live%20Demo-GitHub%20Pages-2ea44f?style=flat-square&logo=github)](https://githubskylh.github.io/monad-cellular-arena/)
[![Monad Testnet](https://img.shields.io/badge/Monad-Testnet%20(ChainID%2010143)-8A2BE2?style=flat-square&logo=ethereum)](https://testnet.monadexplorer.com)
[![V5 Contract](https://img.shields.io/badge/V5%20Contract-0x7781...6341-00f0ff?style=flat-square)](https://testnet.monadexplorer.com/address/0x7781478250d944efd88256F4D84D479194116341)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-363636?style=flat-square&logo=solidity)](https://soliditylang.org/)
[![Scaffold-ETH](https://img.shields.io/badge/Built%20With-Scaffold--ETH%20%26%20Monskills-blueviolet?style=flat-square)](https://scaffoldeth.io/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

*《元气骑士》街机手感重铸 • 踏入传送门 100% 自动 Mint • 掉落非线性磁吸吸附 • 藏宝阁天机玄炉全链升星 • 三宗玄坛祈福受印 • 关底狂暴环形弹幕 • 彻底斩断全局串行累加器，实现 100% 并行零冲突状态提交*

---

## ⚡ 1. Monad 并行 EVM 与 Scaffold-ETH 规范架构 (V5 Parallel-Native)

```
                     ┌────────────────────────────────────────────────────────┐
                     │   全链梦幻 × 元气地牢 V5 并行原生架构 (Monad 10,000 TPS) │
                     └──────────────────────────┬─────────────────────────────┘
                                                │
         ┌──────────────────────┬───────────────┼───────────────┬──────────────────────┐
         ▼                      ▼               ▼               ▼                      ▼
┌──────────────────┐  ┌──────────────────┐┌──────────────────┐┌──────────────────┐┌──────────────────┐
│  元气骑士动作手感  │  │  零全局冲突并行状态  ││  单笔清算自动Mint ││  全链神兵锻造升星  ││  藏宝阁 C2C 寄售 │
│  (Soul Knight E) │  │  (Parallel-Native)││ (Auto-Mint Claim)││(On-Chain Forging)││ (Bazaar Market)  │
├──────────────────┤  ├──────────────────┤├──────────────────┤├──────────────────┤├──────────────────┤
│• 打击顿帧 (2~5帧) │  │• 废除 nextTokenId ││• 踏入传送阵(14,14)││• 0~5 星级全链存证 ││• 玩家自主上架挂单 │
│• 紧缩 Hurtbox 70%│  │• 确定性哈希派生ID ││• 会话凭据防重放  ││• 每次锻造战力+25  ││• 原生 MON 实时结算│
│• 宽容 Hitbox 115%│  │• 废除全局累加器   ││• 关卡成长+NFT合一 ││• 纸娃娃槽位即时联动││• 零中间商与 0 手续费│
│• 受击18帧无敌闪烁│  │• 事件驱动链下统计 ││• 紧凑 GasLimit 扣费││• 背包一键消耗Gas  ││• 撤单与所有权转移 │
│• 脱战3.5s护甲自愈│  │• 100% 真正并行零争用││• 极速 1.0 秒落块  ││• 突破战力天花板   ││• 杜绝虚假交易挂单 │
└──────────────────┘  └──────────────────┘└──────────────────┘└──────────────────┘└──────────────────┘
```

---

## 🚀 2. Vercel 一键部署与生产运行指南 (Scaffold-ETH Specification)

本项目已完全遵循 **Scaffold-ETH 2** 与 **Monad Blitz** 竞赛规约进行工程化配置，支持多种途径一键上线公网：

### 方式 A：点击上方「Deploy with Vercel」徽章（最快 30 秒上线）
1. 点击项目顶部的 [![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fgithubskylh%2Fmonad-cellular-arena) 按钮。
2. 登录 Vercel 并选择导入个人 GitHub 账号。
3. Vercel 将基于内置的 `vercel.json` 自动完成零配置秒级构建并分发至全球 CDN 边缘节点。

### 方式 B：本地命令行一键发布（Scaffold-ETH 推荐）
```bash
# 1. 安装依赖
yarn install

# 2. 运行自动化全闭环测试（语法、ABI、Monad 测试网链上只读验证）
yarn test

# 3. 一键发布至 Vercel 生产环境
yarn vercel:prod
```

### 方式 C：GitHub 仓库无缝联动
本项目已托管至公开 GitHub 仓库：[githubskylh/monad-cellular-arena](https://github.com/githubskylh/monad-cellular-arena)。在 Vercel 控制台关联此仓库后，每次 `git push` 均会自动触发自动化 CI/CD 生产构建与预览。

---

## 🎯 3. 核心系统机制与创新突破

### ⚡ 一、并行原生状态架构 (Parallel-Native Zero-Storage Collision)
* **彻底斩断全局串行计数器**：传统 Solidity 合约依赖 `nextTokenId++` 或 `totalPlayers++` 等全局存储槽位，在 Monad 并行 EVM 高并发执行时会导致多个独立交易因争用同一存储槽而产生冲突并强制回退串行。V5 合约通过 `keccak256(abi.encodePacked(msg.sender, summary.chapterId, sessionId, block.prevrandao))` 确定性派生无碰撞 Token ID，使得所有玩家的清算交易能在底层并行管道中 100% 并发执行。
* **精算 Gas 规约**：针对 Monad 底层「按 `gas_limit` 全额扣除」的特性，前端精简了各操作的 Gas Limit，配合 EIP-1559 动态基础费，大幅降低手续费开销。

### 🔮 二、踏入传送门 100% 自动认领 Mint (Zero-Friction Auto-Mint)
* **妖兽掉落神兵光球**：地牢斩灭妖兽后爆出悬浮神兵光球，通过非线性 Ease-Out 重力加速度平滑吸入玩家背包。
* **传送阵单笔落块**：房间全歼后中央传送门激发，玩家踏入光圈自动向 Monad 广播单笔包含 `sessionId` 防重放凭证的合并清算交易，自动认领并铸造专属 ERC721 神兵 NFT，无需关内频繁弹窗打断游戏体验。

### 🔨 三、藏宝阁天机玄炉全链升星 (On-Chain Forging & Star Progression)
* **神兵星级存证**：每件掉落的神兵初始为 0 星，最高可锻造至 5 星。
* **全链属性跃迁**：玩家在背包中点击【⭐ 升星】，直连 Monad 测试网执行 `forgeUpgradeItem`，每次升星稳固提升 +25 战力，全身装备槽位即刻联动同步。

### 🎮 四、元气骑士手感宽容度体系 (Paradigm E Game Feel)
* **打击卡肉感（Hitstop）**：普攻命中顿帧 2 帧，门派大招与暴击命中顿帧 5 帧，打击反馈扎实生动。
* **非对称碰撞判定**：玩家 Hurtbox 紧缩至 0.75 格（灵活规避伤害），斩击 Hitbox 宽容扩展至 2.3~2.8 格（爽快横扫群怪与木箱）。
* **受击缓冲保护（i-frames）**：受击后获得 18 帧无敌闪烁，护甲优先抵扣伤害；脱战 3.5 秒后护甲自然自愈充能。
* **输入缓冲队列（Input Buffering）**：8-tick 动作队列，连招平滑不卡手。

### 🏛️ 五、地牢 Roguelike 动态生态与 Boss 弹幕
* **可破坏障碍物**：散落在地牢角落的古旧木箱与陶罐可被剑气斩碎，掉落恢复气血（HP +35）与聚气法力（MP +45）的灵丹。
* **三宗玄坛神像**：第二、三层地牢设立神坛，靠近即可祈福受印，随机获取 🩸【嗜血玄印】（20%吸血）、⚡【疾风破影】（移速大幅跃升）或 🛡️【金刚法相】（40%减伤且护甲全满）。
* **镇塔妖王二阶段狂暴**：关底 Boss 血量低于 50% 时进入狂暴，周期性发射八荒魔火 8 向环形扩散弹幕。

---

## 📜 4. Monad 官方测试网实测认证凭证 (Verified On-Chain Proofs)

| 链上实体 / 核心操作 | 详情与区块链浏览器链接 | 状态与验证指标 |
| :--- | :--- | :--- |
| **V5 并行原生主合约** | [`0x7781478250d944efd88256F4D84D479194116341`](https://testnet.monadexplorer.com/address/0x7781478250d944efd88256F4D84D479194116341) | ✅ 全链 V5 并行版本部署完成 |
| **部署交易** | [`0xec4b4e44...`](https://testnet.monadexplorer.com/tx/0xec4b4e441fad6d388c6dd1cdf7ccfc6307424c170806ebfca90a36ac29b8feb7) | 字节码 14,377 字节 |
| **V4 殿堂版本合约** | [`0xFD83796156D677B83266Ba7CD86a077040a0166c`](https://testnet.monadexplorer.com/address/0xFD83796156D677B83266Ba7CD86a077040a0166c) | 历史版本可回溯验证 |
| **天机玄炉锻造升星** | 链上交易落块确认 | 0~5 星属性跃升，战力实时全链存证 |
| **已升星神兵穿戴** | 链上槽位永久铭刻 | 全身装备战力稳固生效 |

---

## 🕹️ 5. 键盘操作指南 (Keybindings)

| 按键 / 快捷方式 | 动作说明 |
| :--- | :--- |
| **W / A / S / D 或 方向键** | 连贯平滑走位 (微秒级响应，疾风印记下 CD 缩短至 75ms) |
| **按键 1 或 空格 (Space)** | 普攻斩击（挥砍击破周边木箱、陶罐与妖兽，顿帧 2 帧） |
| **按键 2 或 Q** | 门派招牌技能（单体爆发斩杀，顿帧 5 帧） |
| **按键 3 或 E** | 门派终极必杀（全屏群攻，击碎大范围障碍与群怪） |
| **靠近三宗玄坛** | 自动祈福，获取嗜血/疾风/金刚强力 Buff |
| **踏入中央传送阵 (14, 14)** | 全歼妖兽后开启，踏入触发 100% 自动 Mint 神兵落块 |
| **点击右侧「升星」** | 在藏宝阁背包中将神兵送入天机玄炉锻造升星（最高 5 星） |
| **点击右侧「寄售 / 购买」** | 在藏宝阁全链寄售行以原生 MON 进行点对点 C2C 买卖 |

---

## 📄 开源许可 (License)
本项目采用 [MIT License](LICENSE) 开源。
