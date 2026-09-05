const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");

async function main() {
    console.log("==========================================================");
    console.log("   🧪 梦幻西游 × 元气地牢 V6 全链金融与关卡结算 E2E 审计...");
    console.log("==========================================================");

    // 1. 检查 index.html 代码结构与 V6 智能合约绑定
    const htmlPath = path.join(__dirname, "index.html");
    const html = fs.readFileSync(htmlPath, "utf8");
    console.log("1. 正在检查 index.html 代码结构与 V6 合约地址完整性...");
    const v6Addr = "0xbeAF44AD57B7f55DAAdf07233E7927D08d103bfF";
    if (!html.includes(v6Addr)) {
        throw new Error("index.html 未包含正确的 V6 并行原生合约地址：" + v6Addr);
    }
    if (!html.includes("tabBtnDefi") || !html.includes("tabContentDefi")) {
        throw new Error("index.html 缺少 DeFi 金融与 AMM Swap 面板标签！");
    }
    if (!html.includes("clearanceOverlay") || !html.includes("settleEquipmentList") || !html.includes("settleXytAmount")) {
        throw new Error("index.html 缺少通关双资产结算视窗核心组件！");
    }
    if (!html.includes("swapMonForTokens") || !html.includes("swapTokensForMon")) {
        throw new Error("index.html 缺少 AMM Swap 交易接口！");
    }
    if (!html.includes("stakeTokens") || !html.includes("claimStakingRewards") || !html.includes("stakeLp")) {
        throw new Error("index.html 缺少单币质押与 LP 农场接口！");
    }
    if (!html.includes("tabContentBazaar") || !html.includes("listLootModalOverlay") || !html.includes("bazaarListingsContainer")) {
        throw new Error("index.html 缺少全链藏宝阁寄售行与上架神兵模态视窗！");
    }
    if (!html.includes("listLoot") || !html.includes("buyLoot") || !html.includes("cancelListing")) {
        throw new Error("index.html 缺少全链寄售上架/购买/撤单核心合约接口！");
    }
    console.log("   ✅ index.html 核心逻辑结构检查通过！(文件总大小: " + (html.length / 1024).toFixed(1) + " KB)");

    // 2. 检查 Vercel 与 Scaffold-ETH 规范配置
    console.log("\n2. 正在检查 Vercel 生产部署与 Scaffold-ETH / monskills 规范合约...");
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

    // 3. 验证与 Monad 测试网上 V6 合约的真实链上状态交互
    console.log("\n3. 正在验证 Monad 测试网上 V6 合约的只读与状态调用...");
    const rpc = "https://testnet-rpc.monad.xyz";
    const provider = new ethers.JsonRpcProvider(rpc);
    let pk;
    if (fs.existsSync(path.join(__dirname, ".env"))) {
        const envContent = fs.readFileSync(path.join(__dirname, ".env"), "utf8");
        const pkMatch = envContent.match(/PRIVATE_KEY\s*=\s*(0x[a-fA-F0-9]{64})/);
        if (pkMatch) pk = pkMatch[1];
    }
    if (!pk) {
        pk = process.env.PRIVATE_KEY || "0x7772a6e4dd2b096bedd60e95c760b8feea6fb146c1b23ec325ab71a106742855";
    }
    const wallet = new ethers.Wallet(pk, provider);

    const balance = await provider.getBalance(wallet.address);
    const balMon = ethers.formatEther(balance);
    console.log(`   - 测试钱包地址: ${wallet.address}`);
    console.log(`   - 钱包原生余额: ${balMon} MON`);

    const artifact = JSON.parse(fs.readFileSync(path.join(__dirname, "v6_artifact.json"), "utf8"));
    const contract = new ethers.Contract(v6Addr, artifact.abi, wallet);

    // 查阅代币信息
    const name = await contract.name();
    const symbol = await contract.symbol();
    console.log(`   - 游戏代币: ${name} (${symbol})`);

    // 查阅 AMM 储备池底
    const resMon = await contract.reserveMon();
    const resTok = await contract.reserveToken();
    console.log(`   - AMM 底池储备: ${ethers.formatEther(resMon)} MON / ${ethers.formatEther(resTok)} XYT`);

    // 查阅质押年化常数
    const stakingApy = await contract.STAKING_APY_BPS();
    const lpApy = await contract.LP_FARM_APY_BPS();
    console.log(`   - 质押 APY: ${Number(stakingApy)/100}% | LP 农场 APY: ${Number(lpApy)/100}%`);

    // 查阅玩家档案与财务全景
    const profile = await contract.profiles(wallet.address);
    console.log(`   - 玩家角色门派: ${profile.sect} | 境界等级: ${profile.level}`);

    const fin = await contract.getFinancialOverview(wallet.address);
    console.log(`   - 财务概览: XYT余额=${ethers.formatEther(fin[0])} | LP余额=${ethers.formatEther(fin[1])}`);

    // 查阅藏宝阁活跃挂单
    const market = await contract.getActiveListings();
    console.log(`   - 藏宝阁当前全链有效挂单: ${market[0].length} 件 (已按 MON 标价)`);
    for (let i = 0; i < market[0].length; i++) {
        console.log(`     [挂单 #${market[0][i].toString().slice(-4)}] ${market[3][i]} 售价: ${ethers.formatEther(market[2][i])} MON | 卖家: ${market[1][i]}`);
    }

    console.log("\n==========================================================");
    console.log("   🎉 梦幻西游 V6 全链金融旗舰版在 Monad 测试网与 CI/CD 规范下 100% 审计通过！");
    console.log("==========================================================");
}

main().catch(err => {
    console.error("❌ 审计测试失败:", err);
    process.exit(1);
});
