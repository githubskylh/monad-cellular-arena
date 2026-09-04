const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const solc = require("solc");

async function main() {
    console.log("==========================================================");
    console.log("   📜 编译并部署【梦幻西游 V4 殿堂版：会话防重放与神兵锻造】...   ");
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

    // 1. 编译 V4
    console.log("🔨 正在编译 FantasyWestwardV4.sol...");
    const src = fs.readFileSync(path.join(__dirname, "FantasyWestwardV4.sol"), "utf8");
    const input = {
        language: "Solidity",
        sources: { "FantasyWestwardV4.sol": { content: src } },
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
    const contractData = output.contracts["FantasyWestwardV4.sol"]["FantasyWestwardV4"];
    const abi = contractData.abi;
    const bytecode = contractData.evm.bytecode.object;

    fs.writeFileSync(path.join(__dirname, "v4_artifact.json"), JSON.stringify({ abi, bytecode }, null, 2));
    console.log("✅ V4 编译成功! 字节码大小:", bytecode.length / 2, "字节");

    // 2. 部署到 Monad
    console.log("🚀 正在广播 V4 部署交易至 Monad...");
    const feeData = await provider.getFeeData();
    console.log("⛽ 当前 GasPrice:", ethers.formatUnits(feeData.gasPrice, "gwei"), "gwei");
    const factory = new ethers.ContractFactory(abi, bytecode, wallet);
    const deployTx = await factory.deploy({ type: 0, gasPrice: feeData.gasPrice });
    console.log("📡 部署交易已发送:", deployTx.deploymentTransaction().hash);

    const t0 = Date.now();
    await deployTx.waitForDeployment();
    const contractAddress = await deployTx.getAddress();
    console.log(`🎉 梦幻西游 V4 殿堂合约部署成功! 耗时: ${Date.now() - t0}ms`);
    console.log("📍 V4 合约地址:", contractAddress);

    // 3. 实测 1: 拜入大唐官府
    const contract = new ethers.Contract(contractAddress, abi, wallet);
    const regTx = await contract.registerPlayer(0, { type: 0, gasPrice: feeData.gasPrice, gasLimit: 200000n });
    await regTx.wait();
    console.log("✅ 宗门登记成功!");

    // 4. 实测 2: 带唯一 SessionId 的第一章清算与自动 Mint
    const sessionId = ethers.keccak256(ethers.toUtf8Bytes("dungeon_session_" + Date.now()));
    console.log("🌱 实测 2: 第一章带会话凭据清算, SessionId:", sessionId.slice(0, 16) + "...");
    const summary1 = {
        chapterId: 1,
        totalDamage: 430,
        monstersSlain: 3,
        skillsUsed: 2,
        stepsTaken: 22,
        clearTimeSeconds: 40,
        bossDefeated: false
    };
    const tx1 = await contract.settleChapter(summary1, sessionId, { type: 0, gasPrice: feeData.gasPrice, gasLimit: 400000n });
    await tx1.wait();
    console.log("✅ 第一章清算落块完毕！");

    // 5. 实测 3: 锻造升星实测 (从 0 星升至 1 星，战力 +25)
    console.log("🌱 实测 3: 全链神兵锻造升星...");
    const loots = await contract.getPlayerLoot(wallet.address);
    const tid = loots[0][0];
    const oldPower = loots[6][0];
    console.log(`   - 锻造前: #${tid} ${loots[4][0]} 星级:${loots[3][0]}星 战力:${oldPower}`);
    
    const forgeTx = await contract.forgeUpgradeItem(tid, { type: 0, gasPrice: feeData.gasPrice, gasLimit: 200000n });
    await forgeTx.wait();
    const updatedLoots = await contract.getPlayerLoot(wallet.address);
    console.log(`   ✅ 锻造升星成功! #${tid} 星级提升至: ${updatedLoots[3][0]} 星, 战力升至: ${updatedLoots[6][0]} (+25 点)`);

    // 6. 实测 4: 穿戴已升星的神兵
    const eqTx = await contract.equipItem(tid, updatedLoots[2][0], { type: 0, gasPrice: feeData.gasPrice, gasLimit: 200000n });
    await eqTx.wait();
    const eq = await contract.getEquippedDetails(wallet.address);
    console.log(`✅ 穿戴已升星神兵成功! 全身装备战力: ${eq[5]}`);

    console.log("\n==========================================================");
    console.log("   🏆 梦幻西游 V4 殿堂合约在 Monad 官方测试网点火验证全闭环成功！");
    console.log("==========================================================");
    console.log("FANTASY_V4_CONTRACT=" + contractAddress);
}

main().catch(err => {
    console.error("V4 部署测试失败:", err);
    process.exit(1);
});
