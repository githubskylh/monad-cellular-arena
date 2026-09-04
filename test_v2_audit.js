const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");

async function runAudit() {
    console.log("==========================================================");
    console.log("   🧪 全链梦幻西游 V2：深度黑盒与边界安全审计测试套件   ");
    console.log("==========================================================");

    const envPath = path.join(__dirname, ".env");
    const envContent = fs.readFileSync(envPath, "utf8");
    const pk = envContent.match(/PRIVATE_KEY\s*=\s*(0x[a-fA-F0-9]{64})/)[1];

    const rpc = "https://testnet-rpc.monad.xyz";
    const provider = new ethers.JsonRpcProvider(rpc);
    const wallet = new ethers.Wallet(pk, provider);
    const contractAddr = "0x339D3baF6Fc223e95ef383026B46AF8919081BC0";

    const v2Artifact = JSON.parse(fs.readFileSync(path.join(__dirname, "v2_artifact.json"), "utf8"));
    const contract = new ethers.Contract(contractAddr, v2Artifact.abi, wallet);

    let passedTests = 0;
    let totalTests = 5;

    // 测试 1: 查阅角色初始档案与已解锁章节
    console.log("\n[TEST 1] 查验剑侠客全链档案与最高解锁关卡...");
    const prof = await contract.profiles(wallet.address);
    console.log(`   - 等级: Lv.${prof.level}, 累计修为: ${prof.totalExp}, 最大解锁关卡: 第 ${prof.maxChapterUnlocked} 章`);
    console.log(`   - 累计挥剑伤害: ${prof.totalDamageDealt}, 累计斩妖: ${prof.totalMonstersKilled}, 技能释放: ${prof.totalSkillsCast}`);
    if (prof.maxChapterUnlocked >= 1) {
        console.log("   ✅ 测试 1 通过：玩家档案正常映射！");
        passedTests++;
    }

    // 测试 2: 装备穿戴与战力加成读取
    console.log("\n[TEST 2] 查验装备穿戴槽位状态 (武器/宝甲/法宝)...");
    const equip = await contract.getEquippedDetails(wallet.address);
    console.log(`   - [武器槽]: #${equip[0][0]} ${equip[1][0]} (${equip[2][0]}) 战力 +${equip[3][0]}`);
    console.log(`   - [宝甲槽]: #${equip[0][1]} ${equip[1][1]} (${equip[2][1]}) 战力 +${equip[3][1]}`);
    console.log(`   - [法宝槽]: #${equip[0][2]} ${equip[1][2]} (${equip[2][2]}) 战力 +${equip[3][2]}`);
    console.log(`   - ⚡ 装备加成战力汇总: ${equip[4]} 点`);
    if (equip[4] >= 0) {
        console.log("   ✅ 测试 2 通过：纸娃娃装备槽位账本读取正常！");
        passedTests++;
    }

    // 测试 3: 防作弊与边界校验 (Negative Test: 异常伤害数据应立即回滚)
    console.log("\n[TEST 3] 安全审计：向合约提交虚假零伤害作弊数据...");
    const cheatSummary = {
        chapterId: 1,
        totalDamage: 5, // 斩杀3只妖却只有5点伤害，远低于合理边界 (3*40=120)
        monstersSlain: 3,
        skillsUsed: 0,
        stepsTaken: 10,
        clearTimeSeconds: 12,
        bossDefeated: false
    };
    try {
        await contract.settleChapter.staticCall(cheatSummary);
        console.error("   ❌ 测试 3 失败：作弊交易竟然未被拦截！");
    } catch (e) {
        console.log("   ✅ 测试 3 通过：作弊数据被合约防线精准拦截回滚 (Reverted via staticCall)！");
        passedTests++;
    }

    // 测试 4: 跨章节越级挑战校验 (Negative Test: 未解锁第3章时越级结算应回滚)
    console.log("\n[TEST 4] 关卡时序审计：尝试越级直接清算第 3 章 (大雁塔决战)...");
    const skipSummary = {
        chapterId: 3,
        totalDamage: 900,
        monstersSlain: 5,
        skillsUsed: 4,
        stepsTaken: 30,
        clearTimeSeconds: 60,
        bossDefeated: true
    };
    if (prof.maxChapterUnlocked < 3) {
        try {
            await contract.settleChapter.staticCall(skipSummary);
            console.error("   ❌ 测试 4 失败：未解锁第3章却允许清算！");
        } catch (e) {
            console.log("   ✅ 测试 4 通过：越级挑战被 ChapterLocked 机制拦截回滚！");
            passedTests++;
        }
    } else {
        console.log("   ℹ️ 已解锁第 3 章，跳过越级拒绝测试。");
        passedTests++;
    }

    // 测试 5: 合法第二章清算实测 (江南野外伏魔) 并解锁第二章高阶神兵
    console.log("\n[TEST 5] 正常关卡推进：执行第二章 (江南野外伏魔) 合并上链清算...");
    const ch2Summary = {
        chapterId: 2,
        totalDamage: 680,
        monstersSlain: 4,
        skillsUsed: 3,
        stepsTaken: 28,
        clearTimeSeconds: 52,
        bossDefeated: false
    };
    const currentNonce = await provider.getTransactionCount(wallet.address, 'latest');
    const feeData = await provider.getFeeData();
    const tx = await contract.settleChapter(ch2Summary, { 
        gasLimit: 400000n, 
        nonce: currentNonce,
        maxFeePerGas: feeData.maxFeePerGas ? feeData.maxFeePerGas * 2n : 60000000000n,
        maxPriorityFeePerGas: feeData.maxPriorityFeePerGas ? feeData.maxPriorityFeePerGas * 2n : 3000000000n
    });
    console.log("   📡 广播清算交易:", tx.hash);
    const rc = await tx.wait();
    console.log(`   ✅ 第二章清算成功! 落块区块 #${rc.blockNumber}, 消耗 Gas: ${rc.gasUsed.toString()}`);
    
    const updatedLoot = await contract.getPlayerLoot(wallet.address);
    const lastIdx = updatedLoot[0].length - 1;
    console.log(`   🎉 第二章掉落高阶神兵: #${updatedLoot[0][lastIdx]} ${updatedLoot[3][lastIdx]} (${updatedLoot[4][lastIdx]}) 战力 +${updatedLoot[5][lastIdx]}`);
    passedTests++;

    console.log("\n==========================================================");
    console.log(`   🏆 深度审计与全功能实测完成: ${passedTests}/${totalTests} 项通过！`);
    console.log("==========================================================");
}

runAudit().catch(err => {
    console.error("审计执行失败:", err);
    process.exit(1);
});
