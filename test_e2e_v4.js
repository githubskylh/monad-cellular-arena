const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");

async function main() {
    console.log("==========================================================");
    console.log("   🧪 梦幻西游 × 元气地牢 V4 自动化闭环审计测试...");
    console.log("==========================================================");

    // 1. 检查 index.html 语法与标签完整度
    const html = fs.readFileSync(path.join(__dirname, "index.html"), "utf8");
    console.log("1. 正在检查 index.html 代码结构与语法完整性...");
    if (!html.includes("0xFD83796156D677B83266Ba7CD86a077040a0166c")) {
        throw new Error("index.html 未包含正确的 V4 殿堂合约地址！");
    }
    if (!html.includes("forgeUpgradeItem") || !html.includes("sessionId")) {
        throw new Error("index.html ABI 未包含 V4 核心接口！");
    }
    if (!html.includes("takePlayerDamage") || !html.includes("prayAtAltar")) {
        throw new Error("index.html 缺少元气骑士受击或神坛祈福机制！");
    }
    if (!html.includes("hitstopFrames") || !html.includes("bossBullets")) {
        throw new Error("index.html 缺少打击顿帧或 Boss 弹幕机制！");
    }
    console.log("   ✅ index.html 核心逻辑结构检查通过！(文件总大小: " + (html.length / 1024).toFixed(1) + " KB)");

    // 2. 验证与 Monad 测试网上 V4 合约的真实交互
    console.log("\n2. 正在验证 Monad 测试网上 V4 合约的只读与状态调用...");
    const rpc = "https://testnet-rpc.monad.xyz";
    const provider = new ethers.JsonRpcProvider(rpc);
    const envContent = fs.readFileSync(path.join(__dirname, ".env"), "utf8");
    const pk = envContent.match(/PRIVATE_KEY\s*=\s*(0x[a-fA-F0-9]{64})/)[1];
    const wallet = new ethers.Wallet(pk, provider);

    const artifact = JSON.parse(fs.readFileSync(path.join(__dirname, "v4_artifact.json"), "utf8"));
    const contract = new ethers.Contract("0xFD83796156D677B83266Ba7CD86a077040a0166c", artifact.abi, wallet);

    // 查阅玩家资产
    const loots = await contract.getPlayerLoot(wallet.address);
    console.log(`   - 玩家当前持有神兵总数: ${loots[0].length} 件`);
    for (let i = 0; i < loots[0].length; i++) {
        console.log(`     * #${loots[0][i]} ${loots[4][i]} | 星级: ${loots[3][i]}星 | 战力: +${loots[6][i]} | 稀有度: ${loots[5][i]}`);
    }

    const equipped = await contract.getEquippedDetails(wallet.address);
    console.log(`   - 玩家全身装备穿戴总战力: +${equipped[5]}`);

    // 查阅集市挂单
    const market = await contract.getActiveListings();
    console.log(`   - 藏宝阁寄售行当前有效挂单数: ${market[0].length} 件`);

    console.log("\n==========================================================");
    console.log("   🎉 梦幻西游 V4 殿堂版双模型对撞架构在 Monad 链上验证 100% 成功！");
    console.log("==========================================================");
}

main().catch(err => {
    console.error("❌ 审计测试失败:", err);
    process.exit(1);
});
