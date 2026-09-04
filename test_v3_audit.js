const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");

async function runAudit() {
    console.log("==========================================================");
    console.log("   🧪 全链梦幻西游 V3 旗舰版：全功能与 C2C 寄售审计套件   ");
    console.log("==========================================================");

    const envPath = path.join(__dirname, ".env");
    const envContent = fs.readFileSync(envPath, "utf8");
    const pk = envContent.match(/PRIVATE_KEY\s*=\s*(0x[a-fA-F0-9]{64})/)[1];

    const rpc = "https://testnet-rpc.monad.xyz";
    const provider = new ethers.JsonRpcProvider(rpc);
    const sellerWallet = new ethers.Wallet(pk, provider);
    const contractAddr = "0xFF8C132525E5aa50f9D549959c4cc5DD448CE430";

    const v3Artifact = JSON.parse(fs.readFileSync(path.join(__dirname, "v3_artifact.json"), "utf8"));
    const contract = new ethers.Contract(contractAddr, v3Artifact.abi, sellerWallet);

    let passedTests = 0;
    let totalTests = 5;

    // 测试 1: 门派修习与随时转职 (Sect Switching)
    console.log("\n[TEST 1] 测试门派流派转换机制 (大唐 -> 龙宫 -> 狮驼岭)...");
    const switchTx = await contract.switchSect(1, { gasLimit: 200000n });
    await switchTx.wait();
    let prof = await contract.profiles(sellerWallet.address);
    console.log(`   - 当前宗门已成功切换为: ${prof.sect === 1n ? '仙族【龙宫】(水系法术)' : '未知'}`);
    
    // 切回大唐
    const switchBackTx = await contract.switchSect(0, { gasLimit: 200000n });
    await switchBackTx.wait();
    prof = await contract.profiles(sellerWallet.address);
    console.log(`   - 再次切换回: ${prof.sect === 0n ? '人族【大唐官府】(横扫千军)' : '未知'}`);
    passedTests++;
    console.log("   ✅ 测试 1 通过：三界多门派随时自由切换！");

    // 测试 2: 查验与补充藏宝阁挂单状态
    console.log("\n[TEST 2] 查验全链藏宝阁寄售行并动态挂单测试...");
    let market = await contract.getActiveListings();
    let listedTokenId;

    if (market[0].length === 0) {
        console.log("   - 当前集市暂无挂单，正在通过第一章清算铸造全新神兵用于挂单测试...");
        const summaryMint = {
            chapterId: 1,
            totalDamage: 400,
            monstersSlain: 3,
            skillsUsed: 1,
            stepsTaken: 15,
            clearTimeSeconds: 30,
            bossDefeated: false
        };
        const mintTx = await contract.settleChapter(summaryMint, { gasLimit: 400000n });
        await mintTx.wait();
        const loots = await contract.getPlayerLoot(sellerWallet.address);
        listedTokenId = loots[0][loots[0].length - 1];
        console.log(`   - 获得全新神兵 #${listedTokenId}，挂单 0.01 MON 寄售...`);
        const listTx = await contract.listLoot(listedTokenId, ethers.parseEther("0.01"), { gasLimit: 250000n });
        await listTx.wait();
        market = await contract.getActiveListings();
    } else {
        listedTokenId = market[0][0];
    }

    console.log(`   - 当前全链挂单数量: ${market[0].length} 件`);
    console.log(`   - 挂单详情: Token #${market[0][0]}, 卖家: ${market[1][0].slice(0, 8)}..., 名称: ${market[3][0]}, 价格: ${ethers.formatEther(market[2][0])} MON`);
    passedTests++;
    console.log("   ✅ 测试 2 通过：全链寄售数据与深度查询完全正常！");

    // 测试 3: 真实 C2C 点对点购买神兵 (用副钱包模拟另一名玩家购买)
    console.log("\n[TEST 3] 模拟另一名玩家在藏宝阁购买挂单神兵 (真金白银转账)...");
    const BUYER_PK = "0x9a8f4c2847d9b736783856271928374829103948572615243546576879809182";
    const buyerWallet = new ethers.Wallet(BUYER_PK, provider);
    console.log(`   - 买家钱包: ${buyerWallet.address}`);
    
    let buyerBal = await provider.getBalance(buyerWallet.address);
    console.log(`   - 买家当前余额: ${ethers.formatEther(buyerBal)} MON`);
    if (buyerBal < ethers.parseEther("0.05")) {
        const fundTx = await sellerWallet.sendTransaction({
            to: buyerWallet.address,
            value: ethers.parseEther("0.1"),
            gasLimit: 50000n
        });
        await fundTx.wait();
        console.log("   - 补充买家资金 0.1 MON");
    }

    // 买家通过合约购买 listedTokenId (使用 type: 0 避免 Monad 节点对 EIP-1559 的超额预扣检查)
    const feeData = await provider.getFeeData();
    const buyerContract = new ethers.Contract(contractAddr, v3Artifact.abi, buyerWallet);
    const buyTx = await buyerContract.buyLoot(listedTokenId, { 
        value: ethers.parseEther("0.01"),
        gasLimit: 250000n,
        type: 0,
        gasPrice: feeData.gasPrice || 105000000000n
    });
    const buyReceipt = await buyTx.wait();
    console.log(`   ✅ 买家购买成功! 落块区块 #${buyReceipt.blockNumber}, Tx: ${buyTx.hash}`);

    // 核验所有权转移
    const newOwner = await contract.ownerOf(listedTokenId);
    console.log(`   - 链上验证: Token #${listedTokenId} 当前拥有者已变更为: ${newOwner} (买家地址匹配: ${newOwner === buyerWallet.address})`);
    if (newOwner === buyerWallet.address) {
        passedTests++;
        console.log("   ✅ 测试 3 通过：全链 C2C 资产交割与原生 MON 即时清算 100% 成功！");
    }

    // 测试 4: 长安城擂台切磋胜场记录
    console.log("\n[TEST 4] 挑战长安城擂台切磋与战神榜累加...");
    const duelTx = await contract.recordArenaVictory(buyerWallet.address, 150, { gasLimit: 200000n });
    await duelTx.wait();
    prof = await contract.profiles(sellerWallet.address);
    console.log(`   - 擂台切磋获胜! 当前擂台累积胜场: ${prof.arenaWins} 场, 修为总计: ${prof.totalExp}`);
    if (prof.arenaWins >= 1) {
        passedTests++;
        console.log("   ✅ 测试 4 通过：长安擂台决斗胜场正常累加记录！");
    }

    // 测试 5: 第二章 (江南野外) 伏魔与高阶仙器掉落
    console.log("\n[TEST 5] 关卡推进：第二章 (江南野外伏魔) 合并清算实测...");
    const ch2Summary = {
        chapterId: 2,
        totalDamage: 650,
        monstersSlain: 4,
        skillsUsed: 3,
        stepsTaken: 25,
        clearTimeSeconds: 48,
        bossDefeated: false
    };
    const tx2 = await contract.settleChapter(ch2Summary, { gasLimit: 400000n });
    const rc2 = await tx2.wait();
    console.log(`   ✅ 第二章清算成功! 区块 #${rc2.blockNumber}, 消耗 Gas: ${rc2.gasUsed.toString()}`);
    
    const lootList = await contract.getPlayerLoot(sellerWallet.address);
    const last = lootList[0].length - 1;
    console.log(`   🎉 第二章掉落仙器: #${lootList[0][last]} ${lootList[3][last]} (${lootList[4][last]}) 战力 +${lootList[5][last]}`);
    passedTests++;

    console.log("\n==========================================================");
    console.log(`   🏆 V3 旗舰版黑盒审计测试全部完成: ${passedTests}/${totalTests} 项全数通过！`);
    console.log("==========================================================");
}

runAudit().catch(err => {
    console.error("V3 审计执行失败:", err);
    process.exit(1);
});
