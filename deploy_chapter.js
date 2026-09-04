const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const solc = require("solc");

async function main() {
    console.log("==========================================================");
    console.log("   📜 编译并部署【梦幻西游：章节结算与神兵铸造系统】...   ");
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
    console.log("🔨 正在编译 FantasyChapterSettlement.sol...");
    const src = fs.readFileSync(path.join(__dirname, "FantasyChapterSettlement.sol"), "utf8");
    const input = {
        language: "Solidity",
        sources: { "FantasyChapterSettlement.sol": { content: src } },
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
    const contractData = output.contracts["FantasyChapterSettlement.sol"]["FantasyChapterSettlement"];
    const abi = contractData.abi;
    const bytecode = contractData.evm.bytecode.object;

    fs.writeFileSync(path.join(__dirname, "chapter_artifact.json"), JSON.stringify({ abi, bytecode }, null, 2));
    console.log("✅ 编译成功! 字节码大小:", bytecode.length / 2, "字节");

    // 2. 部署到 Monad
    console.log("🚀 正在广播上链交易...");
    const factory = new ethers.ContractFactory(abi, bytecode, wallet);
    const deployTx = await factory.deploy();
    console.log("📡 部署交易已发送:", deployTx.deploymentTransaction().hash);

    const t0 = Date.now();
    await deployTx.waitForDeployment();
    const contractAddress = await deployTx.getAddress();
    console.log(`🎉 章节结算合约已部署成功! 耗时: ${Date.now() - t0}ms`);
    console.log("📍 结算合约地址:", contractAddress);

    // 3. 执行第一次章节结算实测：第一章 (东海沉船大捷) 结算
    console.log("🌱 正在执行第一章通关合并结算与神兵铸造实测...");
    const settlement = new ethers.Contract(contractAddress, abi, wallet);
    const summary = {
        chapterId: 1,
        totalDamage: 380,
        monstersSlain: 3,
        stepsTaken: 18,
        clearTimeSeconds: 45
    };
    const tx = await settlement.settleChapter(summary, { gasLimit: 350000n });
    console.log("📡 章节清算交易已广播:", tx.hash);
    const rc = await tx.wait();
    console.log(`✅ 章节结算落块成功! 区块 #${rc.blockNumber}, 消耗 Gas: ${rc.gasUsed.toString()}`);

    const loot = await settlement.getPlayerLoot(wallet.address);
    console.log("🏆 获得第一章通关神兵:", loot[2][0], loot[3][0], "战力 +" + loot[4][0]);

    console.log("\n==========================================================");
    console.log("   🏆 章节结算引擎已在 Monad 官方测试网点火成功！");
    console.log("==========================================================");
    console.log("CHAPTER_SETTLEMENT_CONTRACT=" + contractAddress);
}

main().catch(err => {
    console.error("部署失败:", err);
    process.exit(1);
});
