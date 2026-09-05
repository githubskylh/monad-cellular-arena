const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const solc = require("solc");

async function main() {
    console.log("==========================================================");
    console.log("   📜 编译并部署【全链梦幻 V5：并行原生与精密 Gas 版】...   ");
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

    // 1. 编译 V5
    console.log("🔨 正在编译 FantasyWestwardV5.sol (Parallel-Native)...");
    const src = fs.readFileSync(path.join(__dirname, "FantasyWestwardV5.sol"), "utf8");
    const input = {
        language: "Solidity",
        sources: { "FantasyWestwardV5.sol": { content: src } },
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
    const contractData = output.contracts["FantasyWestwardV5.sol"]["FantasyWestwardV5"];
    const abi = contractData.abi;
    const bytecode = contractData.evm.bytecode.object;

    fs.writeFileSync(path.join(__dirname, "v5_artifact.json"), JSON.stringify({ abi, bytecode }, null, 2));
    console.log("✅ V5 编译成功! 字节码大小:", bytecode.length / 2, "字节");

    // 2. 部署到 Monad (遵守 50 gwei 底线机制)
    console.log("🚀 正在广播 V5 部署交易至 Monad (Parallel EVM)...");
    const feeData = await provider.getFeeData();
    const minGasPrice = 52000000000n; // 52 gwei
    const gasPrice = (feeData.gasPrice && feeData.gasPrice > minGasPrice) ? feeData.gasPrice : minGasPrice;
    console.log("⛽ 设定 GasPrice:", ethers.formatUnits(gasPrice, "gwei"), "gwei (满足 >= 50 gwei 底线)");

    const factory = new ethers.ContractFactory(abi, bytecode, wallet);
    const deployTx = await factory.deploy({ type: 0, gasPrice: gasPrice });
    console.log("📡 部署交易已发送:", deployTx.deploymentTransaction().hash);

    const t0 = Date.now();
    await deployTx.waitForDeployment();
    const contractAddress = await deployTx.getAddress();
    console.log(`🎉 V5 合约上链成功! 耗时: ${Date.now() - t0}ms`);
    console.log(`📍 V5 合约地址: ${contractAddress}`);
    console.log(`🔍 区块浏览器: https://testnet.monadexplorer.com/address/${contractAddress}`);

    fs.writeFileSync(path.join(__dirname, "v5_deployed_address.txt"), contractAddress);
}

main().catch(err => {
    console.error("❌ 部署异常:", err);
    process.exit(1);
});
