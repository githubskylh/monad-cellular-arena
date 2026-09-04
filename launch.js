/**
 * Monad Cellular Arena - Full Autonomous Pipeline Launcher
 * 
 * Takes a private key, deploys the contract to Monad Testnet,
 * automatically bakes the contract address into index.html,
 * spawns the initial cell, and opens the game in the browser!
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const { ethers } = require("ethers");

const RPC_URL = process.env.MONAD_RPC || "https://testnet-rpc.monad.xyz";

async function main() {
    console.log("==========================================================");
    console.log("   ⚡ MONAD CELLULAR ARENA: 全自动一键点火与装配启动器    ");
    console.log("==========================================================");

    // Read private key from argument or .env file
    let privateKey = process.argv[2];
    const envFile = path.join(__dirname, ".env");
    if (!privateKey && fs.existsSync(envFile)) {
        const envContent = fs.readFileSync(envFile, "utf8");
        const match = envContent.match(/PRIVATE_KEY\s*=\s*(0x[a-fA-F0-9]{64})/);
        if (match) privateKey = match[1];
    }

    if (!privateKey) {
        console.error("❌ 错误: 未提供私钥。请提供私钥或在 .env 中设置 PRIVATE_KEY=0x...");
        process.exit(1);
    }

    console.log(`📡 1/4 正在连接 Monad 官方测试网: ${RPC_URL}`);
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(privateKey, provider);
    console.log(`🔑 钱包地址: ${wallet.address}`);

    const balance = await provider.getBalance(wallet.address);
    console.log(`💰 当前测试币余额: ${ethers.formatEther(balance)} MON`);
    if (balance === 0n) {
        console.error("❌ 错误: 该钱包余额为 0，请先领水后再执行！");
        process.exit(1);
    }

    // 1. 部署合约
    console.log("\n🚀 2/4 正在自动化广播部署智能合约...");
    const artifactPath = path.join(__dirname, "contract_artifact.json");
    const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
    const abi = artifact.abi;
    const bytecode = artifact.evm ? artifact.evm.bytecode.object : artifact.bytecode;

    const factory = new ethers.ContractFactory(abi, bytecode, wallet);
    const deployTx = await factory.deploy();
    console.log(`📡 部署交易广播成功: ${deployTx.deploymentTransaction().hash}`);
    console.log("⏳ 等待 Monad 1秒即时终局确认中...");

    const t0 = Date.now();
    await deployTx.waitForDeployment();
    const contractAddress = await deployTx.getAddress();
    console.log(`🎉 合约上链成功! 耗时: ${Date.now() - t0}ms`);
    console.log(`📍 合约地址: ${contractAddress}`);

    // 2. 自动注入 index.html
    console.log("\n⚙️ 3/4 正在将合约地址与私钥自动装配到前端页面...");
    const htmlPath = path.join(__dirname, "index.html");
    let htmlContent = fs.readFileSync(htmlPath, "utf8");

    // Replace contract address placeholder
    htmlContent = htmlContent.replace(
        /placeholder="0x\.\.\. \(部署后粘贴在此\)"(\s+value="[^"]*")?/,
        `value="${contractAddress}" placeholder="${contractAddress}"`
    );

    // Save patched HTML
    fs.writeFileSync(htmlPath, htmlContent, "utf8");
    console.log("✅ 前端配置自动热装配完成，用户无需手动复制粘贴！");

    // 3. 在链上自动执行第一笔 Spawn 交易
    console.log("\n🌱 4/4 正在自动为您在链上降生初始细胞...");
    const arena = new ethers.Contract(contractAddress, abi, wallet);
    try {
        const spawnTx = await arena.spawn(25, 25);
        console.log(`📡 初始细胞降生交易已广播: ${spawnTx.hash}`);
        await spawnTx.wait();
        console.log("🎉 初始细胞在坐标 (25, 25) 降生成功！");
    } catch (e) {
        console.log("ℹ️ 初始细胞状态已初始化或跳过:", e.shortMessage || e.message);
    }

    console.log("\n==========================================================");
    console.log("   🏆 恭喜主人！全链沙盘已 100% 部署并点火完毕！          ");
    console.log(`   📍 链上合约: ${contractAddress}`);
    console.log(`   🔍 区块浏览器: https://testnet.monadexplorer.com/address/${contractAddress}`);
    console.log("==========================================================");

    // 4. 打开浏览器页面
    try {
        console.log("\n🖥️ 正在自动为您唤醒浏览器打开全链沙盘界面...");
        execSync(`start "" "${htmlPath}"`);
    } catch (e) {
        console.log("请在文件管理器中双击 index.html 即可直接游玩。");
    }
}

main().catch(err => {
    console.error("❌ 自动化启动流程异常:", err);
    process.exit(1);
});
