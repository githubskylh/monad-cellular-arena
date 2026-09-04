const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const solc = require("solc");

async function main() {
    console.log("==========================================================");
    console.log("   🐉 正在编译并部署【全链梦幻西游：东海湾】智能合约...     ");
    console.log("==========================================================");

    const envPath = path.join(__dirname, ".env");
    const envContent = fs.readFileSync(envPath, "utf8");
    const pk = envContent.match(/PRIVATE_KEY\s*=\s*(0x[a-fA-F0-9]{64})/)[1];

    const rpc = "https://testnet-rpc.monad.xyz";
    const provider = new ethers.JsonRpcProvider(rpc);
    const wallet = new ethers.Wallet(pk, provider);
    console.log("🔑 部署钱包:", wallet.address);

    const bal = await provider.getBalance(wallet.address);
    console.log("💰 当前余额:", ethers.formatEther(bal), "MON");

    // 1. 编译合约
    console.log("🔨 编译 FantasyWestwardMonad.sol...");
    const src = fs.readFileSync(path.join(__dirname, "FantasyWestwardMonad.sol"), "utf8");
    const input = {
        language: "Solidity",
        sources: { "FantasyWestwardMonad.sol": { content: src } },
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
    const contractData = output.contracts["FantasyWestwardMonad.sol"]["FantasyWestwardMonad"];
    const abi = contractData.abi;
    const bytecode = contractData.evm.bytecode.object;

    fs.writeFileSync(path.join(__dirname, "fantasy_artifact.json"), JSON.stringify({ abi, bytecode }, null, 2));
    console.log("✅ 编译成功! 字节码大小:", bytecode.length / 2, "字节");

    // 2. 部署到 Monad
    console.log("🚀 正在广播上链交易...");
    const factory = new ethers.ContractFactory(abi, bytecode, wallet);
    const deployTx = await factory.deploy();
    console.log("📡 部署交易已发送:", deployTx.deploymentTransaction().hash);

    const t0 = Date.now();
    await deployTx.waitForDeployment();
    const contractAddress = await deployTx.getAddress();
    console.log(`🎉 梦幻西游全链合约已部署成功! 耗时: ${Date.now() - t0}ms`);
    console.log("📍 新合约地址:", contractAddress);

    // 3. 进入世界：初始剑侠客降生在 (15, 15)
    console.log("🌱 正在为剑侠客执行初始入界交易 (15, 15)...");
    const game = new ethers.Contract(contractAddress, abi, wallet);
    const enterTx = await game.enterWorld(15, 15, { gasLimit: 200000n });
    await enterTx.wait();
    console.log("✅ 剑侠客已进入东海湾 (坐标: 15, 15)!");

    console.log("\n==========================================================");
    console.log("   🏆 部署全部完毕！已为前端生成专属配置！");
    console.log("==========================================================");
    console.log("FANTASY_CONTRACT=" + contractAddress);
}

main().catch(err => {
    console.error("部署失败:", err);
    process.exit(1);
});
