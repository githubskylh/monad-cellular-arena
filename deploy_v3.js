const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const solc = require("solc");

async function main() {
    console.log("==========================================================");
    console.log("   📜 编译并部署【梦幻西游 V3 旗舰版：多宗门与全链寄售行】...   ");
    console.log("==========================================================");

    const envPath = path.join(__dirname, ".env");
    const envContent = fs.readFileSync(envPath, "utf8");
    const pk = envContent.match(/PRIVATE_KEY\s*=\s*(0x[a-fA-F0-9]{64})/)[1];

    const rpc = "https://testnet-rpc.monad.xyz";
    const provider = new ethers.JsonRpcProvider(rpc);
    const wallet = new ethers.Wallet(pk, provider);
    console.log("🔑 部署钱包:", wallet.address);

    const bal = await provider.getBalance(wallet.address);
    console.log("💰 当前储备余额:", ethers.formatEther(bal), "MON");

    // 1. 编译 V3
    console.log("🔨 正在编译 FantasyWestwardV3.sol...");
    const src = fs.readFileSync(path.join(__dirname, "FantasyWestwardV3.sol"), "utf8");
    const input = {
        language: "Solidity",
        sources: { "FantasyWestwardV3.sol": { content: src } },
        settings: {
            optimizer: { enabled: true, runs: 200 },
            outputSelection: { "*": { "*": ["abi", "evm.bytecode"] } }
        }
    };
    const output = JSON.parse(solc.compile(JSON.stringify(input)));
    if (output.errors) {
        for (const e of output.errors) {
            if (e.severity === "error") {
                console.error(e.formattedMessage);
                process.exit(1);
            }
        }
    }
    const contractData = output.contracts["FantasyWestwardV3.sol"]["FantasyWestwardV3"];
    const abi = contractData.abi;
    const bytecode = contractData.evm.bytecode.object;

    fs.writeFileSync(path.join(__dirname, "v3_artifact.json"), JSON.stringify({ abi, bytecode }, null, 2));
    console.log("✅ V3 编译成功! 字节码大小:", bytecode.length / 2, "字节");

    // 2. 部署到 Monad
    console.log("🚀 正在广播 V3 部署交易至 Monad...");
    const factory = new ethers.ContractFactory(abi, bytecode, wallet);
    const deployTx = await factory.deploy();
    console.log("📡 部署交易已发送:", deployTx.deploymentTransaction().hash);

    const t0 = Date.now();
    await deployTx.waitForDeployment();
    const contractAddress = await deployTx.getAddress();
    console.log(`🎉 梦幻西游 V3 旗舰合约部署成功! 耗时: ${Date.now() - t0}ms`);
    console.log("📍 V3 合约地址:", contractAddress);

    // 3. 实测 1: 拜入宗门 (大唐官府)
    console.log("🌱 实测 1: 拜入宗门【大唐官府】...");
    const settlement = new ethers.Contract(contractAddress, abi, wallet);
    const regTx = await settlement.registerPlayer(0, { gasLimit: 200000n });
    await regTx.wait();
    console.log("✅ 宗门拜谒成功! Tx:", regTx.hash);

    // 4. 实测 2: 第一章通关清算并铸造神兵
    console.log("🌱 实测 2: 第一章 (东海沉船) 合并清算...");
    const summary1 = {
        chapterId: 1,
        totalDamage: 420,
        monstersSlain: 3,
        skillsUsed: 2,
        stepsTaken: 20,
        clearTimeSeconds: 38,
        bossDefeated: false
    };
    const tx1 = await settlement.settleChapter(summary1, { gasLimit: 400000n });
    await tx1.wait();
    console.log("✅ 第一章清算落块完毕!");

    // 5. 实测 3: 装备第一件神兵
    const loot1 = await settlement.getPlayerLoot(wallet.address);
    const tid1 = loot1[0][0];
    const type1 = loot1[2][0];
    const name1 = loot1[3][0];
    console.log(`🏆 铸造获得: #${tid1} ${name1} (类型:${type1})`);
    const eqTx = await settlement.equipItem(tid1, type1, { gasLimit: 200000n });
    await eqTx.wait();
    console.log(`✅ 已穿戴至槽位 ${type1}!`);

    // 6. 实测 4: 再次通关清算获得第二件神兵，并将其挂牌至【藏宝阁寄售行】
    console.log("🌱 实测 3: 再次通关第 1 章获得多余神兵，测试【藏宝阁挂单寄售】...");
    const tx2 = await settlement.settleChapter(summary1, { gasLimit: 400000n });
    await tx2.wait();
    const loot2 = await settlement.getPlayerLoot(wallet.address);
    const tid2 = loot2[0][1];
    const name2 = loot2[3][1];
    console.log(`🏆 再次获得神兵: #${tid2} ${name2}`);

    // 挂单 0.01 MON 寄售
    const listPrice = ethers.parseEther("0.01");
    console.log(`🏷️ 将 #${tid2} 挂单至全链藏宝阁，售价 0.01 MON...`);
    const listTx = await settlement.listLoot(tid2, listPrice, { gasLimit: 250000n });
    await listTx.wait();
    console.log("✅ 挂单上链成功! Tx:", listTx.hash);

    // 7. 查阅藏宝阁当前寄售列表
    const market = await settlement.getActiveListings();
    console.log("🛒 当前全链藏宝阁寄售行市场列表:");
    console.log(`   - 寄售中数量: ${market[0].length} 件`);
    console.log(`   - 挂牌 #${market[0][0]}: ${market[3][0]} (${market[4][0]}) 战力 +${market[5][0]} 售价: ${ethers.formatEther(market[2][0])} MON`);

    console.log("\n==========================================================");
    console.log("   🏆 梦幻西游 V3 旗舰合约在 Monad 官方测试网全功能点火成功！");
    console.log("==========================================================");
    console.log("FANTASY_V3_CONTRACT=" + contractAddress);
}

main().catch(err => {
    console.error("V3 部署失败:", err);
    process.exit(1);
});
