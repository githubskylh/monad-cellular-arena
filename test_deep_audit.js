/**
 * Deep Self-Audit & Automated Verification Test Suite
 * Tests FantasyWestwardMonad against the live Monad Testnet contract:
 * 0x76A95df7bF134e0B51f9a1f5130DD7db82aE6875
 */

const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");

const CONTRACT_ADDR = "0x76A95df7bF134e0B51f9a1f5130DD7db82aE6875";
const RPC_URL = "https://testnet-rpc.monad.xyz";

async function runDeepAudit() {
    console.log("==========================================================");
    console.log("   🧪 开始全链梦幻西游智能合约深度自测与审计实验...       ");
    console.log("==========================================================");

    const envPath = path.join(__dirname, ".env");
    const envContent = fs.readFileSync(envPath, "utf8");
    const pk = envContent.match(/PRIVATE_KEY\s*=\s*(0x[a-fA-F0-9]{64})/)[1];

    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(pk, provider);
    const artifact = JSON.parse(fs.readFileSync(path.join(__dirname, "fantasy_artifact.json"), "utf8"));
    const contract = new ethers.Contract(CONTRACT_ADDR, artifact.abi, wallet);

    console.log(`📡 节点: ${RPC_URL}`);
    console.log(`🔑 审计执行地址: ${wallet.address}`);
    const balance = await provider.getBalance(wallet.address);
    console.log(`💰 当前储备余额: ${ethers.formatEther(balance)} MON\n`);

    const results = {
        movement: false,
        obstacleCollision: false,
        strikeDamage: false,
        defeatAndMint: false,
        lootInventorySync: false
    };

    // -------------------------------------------------------------
    // 测试 1: 玩家合法坐标移动验证
    // -------------------------------------------------------------
    console.log("▶ [测试 1/5] 验证合规移动指令上链 (15, 15) -> (15, 16)...");
    try {
        const tx1 = await contract.move(15, 16, { gasLimit: 120000n });
        const rc1 = await tx1.wait();
        const p1 = await contract.players(wallet.address);
        console.log(`   ✅ 移动成功落块 (区块 #${rc1.blockNumber}, 耗时: ${rc1.gasUsed} gas)`);
        console.log(`   📍 链上新坐标确认: (${p1.x}, ${p1.y})`);
        results.movement = (Number(p1.x) === 15 && Number(p1.y) === 16);
    } catch (e) {
        console.error("   ❌ 移动测试失败:", e.message);
    }

    // -------------------------------------------------------------
    // 测试 2: 树木与太湖石物理碰撞阻挡测试 (边界违规防御)
    // -------------------------------------------------------------
    console.log("\n▶ [测试 2/5] 验证障碍物碰撞拦截 (尝试强行移入太湖顽石坐标 (12, 10))...");
    try {
        // (12, 10) 是构造函数设置的 isObstacle 坐标
        await contract.move.estimateGas(12, 10);
        console.error("   ❌ 致命缺陷: 障碍物坐标未被拦截！");
    } catch (e) {
        console.log("   ✅ 成功拦截! 合约如预期拒绝穿模:", e.shortMessage || "Blocked by mountain/tree");
        results.obstacleCollision = true;
    }

    // -------------------------------------------------------------
    // 测试 3: 每一笔挥剑物理伤害实时上链结算
    // -------------------------------------------------------------
    console.log("\n▶ [测试 3/5] 验证非致命挥剑物理伤害实时结算 (对野怪 201 造成 50 点暴击)...");
    try {
        const tx3 = await contract.attackMonster(201, 50, { gasLimit: 300000n });
        const rc3 = await tx3.wait();
        console.log(`   ✅ 伤害成功落块 (区块 #${rc3.blockNumber}, 消耗: ${rc3.gasUsed} gas)`);
        console.log(`   📡 交易哈希: ${tx3.hash}`);
        results.strikeDamage = true;
    } catch (e) {
        console.error("   ❌ 伤害上链失败:", e.message);
    }

    // -------------------------------------------------------------
    // 测试 4: 致命一击与全自动神兵 NFT 铸造管线
    // -------------------------------------------------------------
    console.log("\n▶ [测试 4/5] 验证斩杀终局判定与神兵 ERC-721 自动空投铸造...");
    try {
        // 野怪初始 120 血，此前打了 50 血，再施加 100 点致命伤害必定击杀
        const tx4 = await contract.attackMonster(201, 100, { gasLimit: 500000n });
        const rc4 = await tx4.wait();
        console.log(`   ✅ 斩杀落块成功 (区块 #${rc4.blockNumber}, 消耗: ${rc4.gasUsed} gas)`);
        
        // 检查事件日志
        let mintedEventFound = false;
        for (const log of rc4.logs) {
            try {
                const parsed = contract.interface.parseLog(log);
                if (parsed && parsed.name === "LootNFTMinted") {
                    console.log(`   🎉 捕获链上 NFT 铸造事件: Token #${parsed.args.tokenId}【${parsed.args.lootName}】(${parsed.args.rarity}, 战力 +${parsed.args.powerBonus})`);
                    mintedEventFound = true;
                }
            } catch (ignore) {}
        }
        results.defeatAndMint = mintedEventFound;
    } catch (e) {
        console.error("   ❌ 斩杀与铸造测试失败:", e.message);
    }

    // -------------------------------------------------------------
    // 测试 5: 藏宝阁背包账本一致性读取
    // -------------------------------------------------------------
    console.log("\n▶ [测试 5/5] 验证藏宝阁全量 NFT 背包数据同步性...");
    try {
        const loot = await contract.getPlayerLoot(wallet.address);
        const ids = loot[0];
        const names = loot[1];
        const rarities = loot[2];
        const bonuses = loot[3];
        console.log(`   📦 当前地址共计持有 ${ids.length} 件神兵利器:`);
        for (let i = 0; i < ids.length; i++) {
            console.log(`      [#${ids[i]}] ${names[i]} - ${rarities[i]} (战力 +${bonuses[i]})`);
        }
        results.lootInventorySync = (ids.length >= 2);
    } catch (e) {
        console.error("   ❌ 背包查询失败:", e.message);
    }

    console.log("\n==========================================================");
    console.log("   📊 深度自测实验总结报告 (Empirical Audit Summary)       ");
    console.log("==========================================================");
    console.log(`1. 自由移动上链与坐标更新:     ${results.movement ? "【通过 PASS】" : "【未通过 FAIL】"}`);
    console.log(`2. 山体岩石碰撞防穿模拦截:     ${results.obstacleCollision ? "【通过 PASS】" : "【未通过 FAIL】"}`);
    console.log(`3. 单刀伤害实时上链结算:       ${results.strikeDamage ? "【通过 PASS】" : "【未通过 FAIL】"}`);
    console.log(`4. 致命斩杀与自动 NFT 铸造:    ${results.defeatAndMint ? "【通过 PASS】" : "【未通过 FAIL】"}`);
    console.log(`5. 藏宝阁多维战利品账本同步:   ${results.lootInventorySync ? "【通过 PASS】" : "【未通过 FAIL】"}`);
    console.log("==========================================================\n");
}

runDeepAudit().catch(console.error);
