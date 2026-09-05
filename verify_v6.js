const fs = require('fs');
const path = require('path');
const solc = require('solc');

async function main() {
    console.log('==========================================================');
    console.log('   🔍 正在验证【全链梦幻 V6 主合约】至 Sourcify / Blockvision...');
    console.log('==========================================================');

    const contractAddress = '0xbeAF44AD57B7f55DAAdf07233E7927D08d103bfF';
    const chainId = '10143';
    const sourcifyUrl = 'https://sourcify-api-monad.blockvision.org';

    // 1. 检查当前验证状态
    const checkRes = await fetch(`${sourcifyUrl}/check-by-addresses?addresses=${contractAddress}&chainIds=${chainId}`);
    const checkData = await checkRes.json();
    console.log('当前验证状态:', checkData);
    if (checkData && checkData[0] && (checkData[0].status === 'perfect' || checkData[0].status === 'partial')) {
        console.log(`✅ 合约已在 Sourcify / Blockvision 完成验证！状态: ${checkData[0].status}`);
        return;
    }

    // 2. 编译并提取精准元数据
    console.log('正在重新编译以生成精准 metadata.json...');
    const src = fs.readFileSync(path.join(__dirname, 'FantasyWestwardV6.sol'), 'utf8');
    const input = {
        language: 'Solidity',
        sources: { 'FantasyWestwardV6.sol': { content: src } },
        settings: {
            optimizer: { enabled: true, runs: 200 },
            outputSelection: { '*': { '*': ['*'] } }
        }
    };
    const output = JSON.parse(solc.compile(JSON.stringify(input)));
    const meta = output.contracts['FantasyWestwardV6.sol']['FantasyWestwardV6'].metadata;

    // 3. 提交至 Sourcify API
    console.log('正在向 Sourcify API 提交源码与元数据...');
    const payload = {
        address: contractAddress,
        chain: chainId,
        files: {
            'metadata.json': meta,
            'FantasyWestwardV6.sol': src
        }
    };

    const verifyRes = await fetch(`${sourcifyUrl}/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    });
    const verifyResult = await verifyRes.json();
    console.log('🎉 验证响应结果:', verifyResult);
}

main().catch(err => {
    console.error('❌ 验证失败:', err);
    process.exit(1);
});
