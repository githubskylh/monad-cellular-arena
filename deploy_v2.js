const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const solc = require("solc");

async function main() {
    console.log("==========================================================");
    console.log("   📜 编译并部署【梦幻西游 V2：多章节与装备穿戴清算系统】...   ");
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

    // 1. 编译
    console.log("🔨 正在编译 FantasyWestwardV2.sol...");
    const src = fs.readFileSync(path.join(__dirname, "FantasyWestwardV2.sol"), "utf8");
    const input = {
        language: "Solidity",
        sources: { "FantasyWestwardV2.sol": { content: src } },
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
    const contractData = output.contracts["FantasyWestwardV2.sol"]["FantasyWestwardV2"];
    const abi = contractData.abi;
    const bytecode = contractData.evm.bytecode.object;

    fs.writeFileSync(path.join(__dirname, "v2_artifact.json"), JSON.stringify({ abi, bytecode }, null, 2));
    console.log("✅ 编译成功! 字节码大小:", bytecode.length / 2, "字节");

    // 2. 部署到 Monad
    console.log("🚀 正在广播上链部署交易至 Monad...");
    const factory = new ethers.ContractFactory(abi, bytecode, wallet);
    const deployTx = await factory.deploy();
    console.log("📡 部署交易已发送:", deployTx.deploymentTransaction().hash);

    const t0 = Date.now();
    await deployTx.waitForDeployment();
    const contractAddress = await deployTx.getAddress();
    console.log(`🎉 梦幻西游 V2 合约部署成功! 耗时: ${Date.now() - t0}ms`);
    console.log("📍 V2 合约地址:", contractAddress);

    // 3. 执行实测：第一章 (东海沉船试炼) 聚合清算与神兵铸造
    console.log("🌱 正在执行第一章聚合清算实测 (含大唐技能统计)...");
    const settlement = new ethers.Contract(contractAddress, abi, wallet);
    const summary = {
        chapterId: 1,
        totalDamage: 450,
        monstersSlain: 3,
        skillsUsed: 2, // 释放了2次大唐横扫千军
        stepsTaken: 22,
        clearTimeSeconds: 40,
        bossDefeated: false
    };
    const tx = await settlement.settleChapter(summary, { gasLimit: 400000n });
    console.log("📡 章节清算交易已广播:", tx.hash);
    const rc = await tx.wait();
    console.log(`✅ 章节结算落块成功! 区块 #${rc.blockNumber}, 消耗 Gas: ${rc.gasUsed.toString()}`);

    const loot = await settlement.getPlayerLoot(wallet.address);
    const mintedTid = loot[0][0];
    const mintedType = loot[2][0];
    const mintedName = loot[3][0];
    const mintedRarity = loot[4][0];
    const mintedPower = loot[5][0];
    console.log(`🏆 铸造神兵: #${mintedTid} ${mintedName} (${mintedRarity}) 类型:${mintedType} 战力 +${mintedPower}`);

    // 4. 执行穿戴测试：将铸造的神兵穿戴至对应槽位
    console.log(`🛡️ 正在测试将 #${mintedTid} 穿戴至槽位 ${mintedType}...`);
    const equipTx = await settlement.equipItem(mintedTid, mintedType, { gasLimit: 200000n });
    await equipTx.wait();
    console.log("✅ 装备穿戴上链成功! Tx:", equipTx.hash);

    // 5. 查阅穿戴属性
    const equipInfo = await settlement.getEquippedDetails(wallet.address);
    console.log("✨ 当前剑侠客全身装备详情:");
    console.log("   - 武器槽 [0]:", equipInfo[1][0], "战力 +" + equipInfo[3][0]);
    console.log("   - 宝甲槽 [1]:", equipInfo[1][1], "战力 +" + equipInfo[3][1]);
    console.log("   - 法宝槽 [2]:", equipInfo[1][2], "战力 +" + equipInfo[3][2]);
    console.log("   ⚡ 装备总战力加成:", equipInfo[4].toString(), "点！");

    console.log("\n==========================================================");
    console.log("   🏆 梦幻西游 V2 全链核心在 Monad 官方测试网部署且全流程闭环验证成功！");
    console.log("==========================================================");
    console.log("FANTASY_V2_CONTRACT=" + contractAddress);
}

main().catch(err => {
    console.error("部署与测试失败:", err);
    process.exit(1);
});
