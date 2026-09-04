# 🗡️ 全链梦幻西游：东海湾 (Monad Fantasy Westward Journey)
> **Fully On-Chain RPG Adventure & Instant Auto-Minting Loot NFT on Monad Parallel EVM**

[![Monad Testnet](https://img.shields.io/badge/Monad-Testnet%20(ChainID%2010143)-8A2BE2?style=flat-square&logo=ethereum)](https://testnet.monadexplorer.com)
[![Contract](https://img.shields.io/badge/Contract-0x76A9...6875-00f0ff?style=flat-square)](https://testnet.monadexplorer.com/address/0x76A95df7bF134e0B51f9a1f5130DD7db82aE6875)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-363636?style=flat-square&logo=solidity)](https://soliditylang.org/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

*经典回合与即时伏魔世界观重铸 • 单刀挥剑伤害实时上链 • 降妖伏魔自动铸造神兵 NFT*

---

## 🎯 1. 故事背景与黑客松核心命题 (Lore & Vision)

> **“二十年梦幻情怀，今朝全链重生！”**

在以太坊与传统 Rollup 上，“全链游戏”连一次走格子都舍不得上链，更妄谈将**每一刀挥剑造成的物理伤害、每一处山体古木碰撞与每一次击败野怪爆出的神兵利器**完全写在区块链上。

**全链梦幻西游（Monad Edition）** 依托 Monad 10,000 TPS 与 1.0 秒即时终局性，彻底打破了这一桎梏：
* 🧑‍🎤 **经典主角：大唐官府 • 剑侠客**：蓝发束冠、蓝白锦袍、仗剑天涯，自由行走于东海湾。
* 🌲 **合理微观环境与碰撞体积**：古桃树、太湖石、草丛与海湾沙滩，具备严密的位置碰撞检测。
* ⚔️ **单刀伤害实时上链（Combat Damage on-chain）**：按空格挥剑斩击大海龟与珊瑚巨蛙，每一笔造成的暴击伤害（-65 ~ -90）实时广播至 Monad。
* 🏆 **击败怪物自动空投神兵 NFT（Auto-Minted Loot NFT）**：野怪击破瞬间，智能合约自动在链上铸造 ERC721 神兵（如【逍遥游龙剑】、【东海定海珠】），即刻沉淀进玩家的「藏宝阁」背包！

---

## ⚡ 2. 为什么非 Monad 不可？(The "Why Monad" Architecture)

```
[ 剑侠客移动 / 遭遇野怪 ] 
            │
            ▼
[ 按下空格: 逍遥剑气斩击 ] ──► 即时物理剑光特效 + 伤害跳字
            │
            ▼ (并行上链)
[ Monad Testnet: attackMonster(id, dmg) ] ──► 1.0 秒即时打包伤害交易
            │
            ├──► 怪物血量归零 (Victory)
            ▼
[ 合约自动触发: _mintLootNFT(...) ] ──► 自动铸造神兵 ERC-721
            │
            ▼
[ 藏宝阁背包实时入库: 【东海定海珠】(Token #1) ]
```

---

## 📜 3. 官方测试网实测链上凭证 (Verified On-Chain Proofs)

| 链上实体 | 详情与区块链浏览器哈希 | 状态 / 指标 |
| :--- | :--- | :--- |
| **梦幻西游主合约** | [`0x76A95df7bF134e0B51f9a1f5130DD7db82aE6875`](https://testnet.monadexplorer.com/address/0x76A95df7bF134e0B51f9a1f5130DD7db82aE6875) | ✅ 已部署验证 |
| **剑侠客入界降生** | [`0xb0bd809d...3d491551de72dc32169d63`](https://testnet.monadexplorer.com/tx/0xb0bd809dffadec20cc3d491551de72dc32169d63d44194580d31822aeb9c5899) | 坐标 (15, 15) |
| **单刀伤害与伏魔** | [`0x0687c321...7573e7a329deabd64ede25`](https://testnet.monadexplorer.com/tx/0x0687c3216f879de3cf4c0596a0cb3d7573e7a329deabd64ede25771e854d499b) | 暴击 -150 伤害 |
| **神兵 NFT 自动铸造** | Token #1 【东海定海珠】(史诗珍宝 • 战力 +35) | ✅ 自动铸造入库 |

---

## 🕹️ 4. 键盘操作说明 (Controls)
* **行走探险**: `W`（上）、`S`（下）、`A`（左）、`D`（右）
* **拔剑斩击**: `Space`（空格键）或点击右上方「⚔️ 挥剑斩击」
* **神兵背包**: 右侧「藏宝阁」实时展示当前地址拥有的链上装备 NFT

---

## 📄 开源许可 (License)
本项目采用 [MIT License](LICENSE) 开源。
