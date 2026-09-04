# 🧬 Monad Cellular Arena (Lite)
> **High-Concurrency Autonomous World & Parallel On-Chain Survival Benchmark on Monad**

[![Monad Testnet](https://img.shields.io/badge/Monad-Testnet%20(ChainID%2010143)-8A2BE2?style=flat-square&logo=ethereum)](https://testnet.monadexplorer.com)
[![Contract](https://img.shields.io/badge/Contract-0xCa78403Bc...724C-00f0ff?style=flat-square)](https://testnet.monadexplorer.com/address/0xCa78403Bc03AfC5A3ca56192a135B9Be7ea1724C)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-363636?style=flat-square&logo=solidity)](https://soliditylang.org/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

*专为 Monad 并行 EVM 量身定制的亚秒级、高并发全链生存沙盘与性能基准测试系统*

---

## 🎯 1. 项目愿景与黑客松定位 (Vision & Problem Solved)

长期以来，“全链游戏（Fully On-Chain Game, FOCG）”受限于以太坊及主流 L2 的高时延与串行状态锁死，几乎只能妥协为“回合制慢棋”。任何高频微交互或多人空间竞争，都会瞬间导致交易拥堵与 Gas 暴涨。

**Monad Cellular Arena** 专为打破这一范式而生：
* **2,500 个独立空间状态槽（Spatial Slots）**：我们将 $50 \times 50$ 的离散生存竞技网格解耦为独立的 Storage Key，彻底消灭不必要的单点全局写锁。
* **Monad 并行执行（OCC）的最佳实战载体**：玩家在不同网格的移动与吞噬在底层触碰完全不相交的存储槽，Monad 并行流水线能够以纳秒级零冲突同时执行。
* **零弹窗体验（Ephemeral Burner Wallet）**：借助前端临时会话私钥，玩家敲击 `WASD` 即可发起静默秒级上链，实现与 Web2 联机游戏无异的流畅操控。

---

## ⚡ 2. 为什么非 Monad 不可？(The "Why Monad" Architecture)

```
       [ Client Browser (WASD) ] ──── Zero-Popup Silent Signature
                   │
                   ▼
  [ Monad Testnet Node (ChainID 10143) ]
                   │
    ┌──────────────┴──────────────┐
    ▼ (OCC Parallel Pipeline)     ▼
[ Tx 1: Move (10,10) -> (10,11) ] [ Tx 2: Move (40,40) -> (40,41) ]
         │                                   │
         ▼                                   ▼
 [ Slot: 0x000a000b ]               [ Slot: 0x00280029 ]
    └──────────────┬─────────────────────────┘
                   │
                   ▼
   [ Finalized in SAME 1-Sec Block! ] (Zero State Contention)
```

1. **状态槽解耦公式**：
   ```solidity
   function gridKey(uint16 x, uint16 y) public pure returns (uint256) {
       return (uint256(x) << 16) | uint256(y);
   }
   ```
2. **冲突局域化（Localized Arbitration）**：
   只有当两名玩家进入同一个网格发生碰撞（吞噬）时，才会触发局部的读写冲突重排；在广阔的沙盘中，99% 的操作均以完全并行形态执行。

---

## 📜 3. 官方测试网实测链上证据 (Verified On-Chain Proofs)

| 链上实体 | 详情与区块链浏览器哈希 | 状态 / 指标 |
| :--- | :--- | :--- |
| **测试网合约** | [`0xCa78403Bc03AfC5A3ca56192a135B9Be7ea1724C`](https://testnet.monadexplorer.com/address/0xCa78403Bc03AfC5A3ca56192a135B9Be7ea1724C) | ✅ 已部署验证 |
| **部署交易** | [`0x9ad7eb8c...64d7549ecd6846bf4f668`](https://testnet.monadexplorer.com/tx/0x9ad7eb8c2b96bbe9231287e92115ba54ec6854590e964d7549ecd6846bf4f668) | 单区块确认 |
| **降生交易** | [`0x7e7df429...51a5f2416f4eb0db4eeef`](https://testnet.monadexplorer.com/tx/0x7e7df429e4eb4776c37f8650533f65e51a5f2416f4eb0db4eeef6ce0adbd82fe) | 坐标 (25, 25) |
| **链上单步移动** | [`0xf490b20e...09de12f362f8500705322`](https://testnet.monadexplorer.com/tx/0xf490b20edd8a320e02ec1e0e7154d70941f109de12f362f850070532250fdbb3) | 耗时 ~1050ms |

---

## 🛠️ 4. 极简技术栈与工程结构 (Repository Structure)

本项目坚持**“扁平零冗余”**的工程哲学，完全杜绝沉重的构建工具链，双击即玩，极速上链：

```
monad-cellular-arena/
├── CellularArenaLite.sol    # 核心智能合约 (空间解耦、移动校验、碰撞吞噬)
├── contract_artifact.json   # 预编译合约 ABI 与 EVM 字节码 (极速部署依赖)
├── index.html               # 赛博朋克极简终端前端 (50x50 Canvas + Ethers.js v6)
├── deploy.js                # Node.js 极速自动化部署脚本
├── launch.js                # 一键全自动编译、部署、热装配与唤醒浏览器流水线
├── swarm.js                 # 评委路演专属：并发打压与并行基准测试脚本
├── .env.example             # 环境变量配置模版 (防泄露范本)
├── .gitignore               # 严格的私钥与依赖隔离规则
├── LICENSE                  # MIT 开源许可证
└── README.md                # 完整技术架构说明与路演指南
```

---

## 🚀 5. 本地快速运行 (Quickstart in 1 Minute)

### 环境要求
* [Node.js](https://nodejs.org/) v18+ 

### 运行步骤
1. **克隆仓库**：
   ```bash
   git clone https://github.com/YOUR_USERNAME/monad-cellular-arena.git
   cd monad-cellular-arena
   ```
2. **安装轻量依赖**：
   ```bash
   npm install
   ```
3. **启动前端沙盘**：
   直接在浏览器中双击打开 `index.html`（或使用任意本地静态服务器）。
   页面预填了官方测试网已部署的合约地址 `0xCa78403Bc03AfC5A3ca56192a135B9Be7ea1724C`。
4. **键盘操作**：
   为页面的临时钱包充入少量测试币后，按键盘 `W / A / S / D` 即可实时操控细胞在 Monad 链上对局！

### 并发压测演示 (Swarm Influx Benchmark)
向 Monad 节点发起多账户并发移动请求，测试吞吐性能：
```bash
node swarm.js 0xCa78403Bc03AfC5A3ca56192a135B9Be7ea1724C
```

---

## 📄 开源许可 (License)
本项目采用 [MIT License](LICENSE) 开源。
