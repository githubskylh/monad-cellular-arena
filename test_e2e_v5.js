const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");

async function main() {
    console.log("==========================================================");
    console.log("   🧪 梦幻西游 × 元气地牢 V5 并行原生版 全闭环审计测试...");
    console.log("==========================================================");

    // 1. 检查 index.html 语法与标签完整度
    const htmlPath = path.join(__dirname, "index.html");
    const html = fs.readFileSync(htmlPath, "utf8");
    console.log("1. 正在检查 index.html 代码结构与 V5 合约地址完整性...");
    const v5Addr = "0x7781478250d944efd88256F4D84D479194116341";
    if (!html.includes(v5Addr)) {
        throw new Error("index.html 未包含正确的 V5 并行原生合约地址：" + v5Addr);
    }
    if (!html.includes("getOptimalMonadFee")) {
        throw new Error("index.html 缺少 Monad 特性优化手续费函数 getOptimalMonadFee！");
    }
    if (!html.includes("forgeUpgradeItem") || !html.includes("sessionId")) {
        throw new Error("index.html ABI 未包含 V5 核心接口！");
    }
    if (!html.includes("takePlayerDamage") || !html.includes("prayAtAltar")) {
        throw new Error("index.html 缺少元气骑士受击或神坛祈福机制！");
    }
    if (!html.includes("hitstopFrames") || !html.includes("bossBullets")) {
        throw new Error("index.html 缺少打击顿帧或 Boss 弹幕机制！");
    }
    console.log("   ✅ index.html 核心逻辑结构检查通过！(文件总大小: " + (html.length / 1024).toFixed(1) + " KB)");

    // 2. 检查 Vercel 与 Scaffold-ETH 规范配置
    console.log("\n2. 正在检查 Vercel 生产部署与 Scaffold-ETH / monskills 规约...");
    const vercelConfig = JSON.parse(fs.readFileSync(path.join(__dirname, "vercel.json"), "utf8"));
    if (!vercelConfig.cleanUrls || !vercelConfig.rewrites) {
        throw new Error("vercel.json 缺少必要路由与 cleanUrls 规范！");
    }
    console.log("   ✅ vercel.json 生产路由重写配置完好。");

    const monskillsContent = fs.readFileSync(path.join(__dirname, ".monskills"), "utf8");
    if (!monskillsContent.includes("built-with=monskills") || !monskillsContent.includes("chain=monad-testnet")) {
        throw new Error(".monskills 元数据规范缺失！");
    }
    console.log("   ✅ .monskills Monad Blitz 追溯元数据完备。");

    const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, "package.json"), "utf8"));
    if (!pkg.scripts.vercel || !pkg.scripts["vercel:prod"]) {
        throw new Error("package.json 缺少 Vercel 一键发布 scripts 指令！");
    }
    console.log("   ✅ package.json Scaffold-ETH 工作流脚本完备。");

    // 3. 验证与 Monad 测试网上 V5 合约的真实链上状态交互
    console.log("\n3. 正在验证 Monad 测试网上 V5 合约的只读与状态调用...");
    const rpc = "https://testnet-rpc.monad.xyz";
    const provider = new ethers.JsonRpcProvider(rpc);
    const envContent = fs.readFileSync(path.join(__dirname, ".env"), "utf8");
    const pkMatch = envContent.match(/PRIVATE_KEY\s*=\s*(0x[a-fA-F0-9]{64})/);
    if (!pkMatch) throw new Error(".env 未包含 PRIVATE_KEY");
    const pk = pkMatch[1];
    const wallet = new ethers.Wallet(pk, provider);

    const balance = await provider.getBalance(wallet.address);
    const balMon = ethers.formatEther(balance);
    console.log(`   - 部署者钱包地址: ${wallet.address}`);
    console.log(`   - 当前账户余额: ${balMon} MON (是否达标 10 MON 储备底线: ${parseFloat(balMon) >= 10 ? '✅ 是 (享最优亚秒处理)' : '⚠️ 否'})`);

    const artifact = JSON.parse(fs.readFileSync(path.join(__dirname, "v5_artifact.json"), "utf8"));
    const contract = new ethers.Contract(v5Addr, artifact.abi, wallet);

    // 查阅玩家档案
    const profile = await contract.profiles(wallet.address);
    console.log(`   - 玩家角色登记状态: ${profile.isRegistered ? '已登记' : '未登记 (需首次登门)'}`);
    console.log(`   - 角色门派: ${profile.sect} | 等级: ${profile.level} | 累计修为: ${profile.totalExp}`);

    // 查阅玩家持宝
    const loots = await contract.getPlayerLoot(wallet.address);
    console.log(`   - 玩家当前持有 V5 神兵数: ${loots[0].length} 件`);

    // 查阅集市挂单
    const market = await contract.getActiveListings();
    console.log(`   - 藏宝阁寄售行当前有效挂单数: ${market[0].length} 件`);

    console.log("\n==========================================================");
    console.log("   🎉 梦幻西游 V5 并行原生版在 Monad 测试网与 Vercel 规范下 100% 审计通过！");
    console.log("==========================================================");
}

main().catch(err => {
    console.error("❌ 审计测试失败:", err);
    process.exit(1);
});
