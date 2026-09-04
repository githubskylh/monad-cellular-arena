/**
 * Monad Cellular Arena - Automated Deployment Script
 * 
 * Usage:
 *   node deploy.js <PRIVATE_KEY> [RPC_URL]
 * 
 * Examples:
 *   node deploy.js 0xYOUR_PRIVATE_KEY
 *   node deploy.js 0xYOUR_PRIVATE_KEY http://127.0.0.1:8545
 */

const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");

async function main() {
    console.log("==========================================================");
    console.log("   🚀 MONAD CELLULAR ARENA: 自动化一键部署系统            ");
    console.log("==========================================================");

    const privateKey = process.argv[2] || process.env.PRIVATE_KEY;
    const rpcUrl = process.argv[3] || process.env.MONAD_RPC || "https://testnet-rpc.monad.xyz";

    if (!privateKey) {
        console.error("❌ 提示: 请输入部署私钥！");
        console.log("\n使用方法:");
        console.log("  node deploy.js <0x你的私钥> [RPC节点地址]");
        console.log("\n示例 1 (部署到 Monad 官方测试网):");
        console.log("  node deploy.js 0x4f3edf983ac636a65a842ce7c78d5aa706d401cdc7b83d3493729ee574f... ");
        console.log("\n示例 2 (部署到本地 8545 极速测试节点，免水龙头即刻开跑):");
        console.log("  node deploy.js 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 http://127.0.0.1:8545\n");
        return;
    }

    console.log(`📡 正在连接目标节点: ${rpcUrl}`);
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    
    let blockNumber;
    try {
        blockNumber = await provider.getBlockNumber();
        console.log(`📦 当前区块高度: #${blockNumber}`);
    } catch (err) {
        console.error(`❌ 连接 RPC 节点失败: ${err.message}`);
        return;
    }

    const wallet = new ethers.Wallet(privateKey, provider);
    console.log(`🔑 部署者账户地址: ${wallet.address}`);

    const balance = await provider.getBalance(wallet.address);
    const balanceEth = ethers.formatEther(balance);
    console.log(`💰 账户当前余额: ${balanceEth} 代币`);

    if (balance === 0n) {
        console.error("\n❌ 提示: 当前账户余额为 0！无法支付链上 Gas 费用。");
        console.log("👉 解决路径:");
        console.log("   1. 前往 Monad 测试网水龙头为地址 " + wallet.address + " 领取代币。");
        console.log("   2. 或者启动本地 Hardhat/Anvil 节点秒级测试 (初始赠送 10,000 ETH)。\n");
        return;
    }

    // 1. 读取编译产物
    const artifactPath = path.join(__dirname, "contract_artifact.json");
    let abi, bytecode;

    if (fs.existsSync(artifactPath)) {
        console.log("\n⚡ 载入预编译合约产物 (contract_artifact.json)...");
        const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
        abi = artifact.abi;
        bytecode = artifact.evm ? artifact.evm.bytecode.object : artifact.bytecode;
    } else {
        console.log("\n🔨 正在编译 CellularArenaLite.sol...");
        const solc = require("solc");
        const sourceCode = fs.readFileSync(path.join(__dirname, "CellularArenaLite.sol"), "utf8");
        const input = {
            language: "Solidity",
            sources: { "CellularArenaLite.sol": { content: sourceCode } },
            settings: { outputSelection: { "*": { "*": ["abi", "evm.bytecode"] } } }
        };
        const output = JSON.parse(solc.compile(JSON.stringify(input)));
        const compiledContract = output.contracts["CellularArenaLite.sol"]["CellularArenaLite"];
        abi = compiledContract.abi;
        bytecode = compiledContract.evm.bytecode.object;
        fs.writeFileSync(artifactPath, JSON.stringify({ abi, bytecode }, null, 2));
    }
    console.log("✅ 编译产物就绪! 字节码大小:", bytecode.length / 2, "字节");

    // 2. 部署到链上
    console.log("\n🚀 正在广播部署交易到链上...");
    const factory = new ethers.ContractFactory(abi, bytecode, wallet);

    const deployTx = await factory.deploy();
    console.log(`📡 部署交易已发送! Tx Hash: ${deployTx.deploymentTransaction().hash}`);
    console.log("⏳ 等待区块确认中 (Monad 约为 1.0 秒)...");

    const t0 = Date.now();
    await deployTx.waitForDeployment();
    const elapsed = Date.now() - t0;
    const contractAddress = await deployTx.getAddress();

    console.log("\n🎉 ========================================================");
    console.log(`🎉 合约部署成功! 耗时: ${elapsed} ms`);
    console.log(`📍 合约地址 (Contract Address): ${contractAddress}`);
    console.log(`🔍 区块浏览器查看: https://testnet.monadexplorer.com/address/${contractAddress}`);
    console.log("==========================================================");

    console.log("\n👉 下一步操作建议:");
    console.log(`1. 双击打开 index.html，在右侧「智能合约地址」填入: ${contractAddress}`);
    console.log(`2. 运行蜂群并发测试脚本: node swarm.js ${contractAddress}`);
}

main().catch((err) => {
    console.error("❌ 部署脚本执行异常:", err);
});
