const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');

async function main() {
    console.log('==========================================================');
    console.log('   🚀 编译并部署【全链梦幻 V6：DeFi 金融与关卡结算旗舰版】...   ');
    console.log('==========================================================');

    const envPath = path.join(__dirname, '.env');
    const envContent = fs.readFileSync(envPath, 'utf8');
    const pk = envContent.match(/PRIVATE_KEY\s*=\s*(0x[a-fA-F0-9]{64})/)[1];

    const rpc = 'https://testnet-rpc.monad.xyz';
    const provider = new ethers.JsonRpcProvider(rpc);
    const wallet = new ethers.Wallet(pk, provider);
    console.log('Deployer address:', wallet.address);

    const bal = await provider.getBalance(wallet.address);
    console.log('Current balance:', ethers.formatEther(bal), 'MON');

    const artifact = JSON.parse(fs.readFileSync(path.join(__dirname, 'v6_artifact.json'), 'utf8'));
    const abi = artifact.abi;
    const bytecode = artifact.bytecode;

    const feeData = await provider.getFeeData();
    const minGasPrice = 52000000000n; // 52 gwei
    const gasPrice = (feeData.gasPrice && feeData.gasPrice > minGasPrice) ? feeData.gasPrice : minGasPrice;
    console.log('GasPrice:', ethers.formatUnits(gasPrice, 'gwei'), 'gwei');

    const seedMon = ethers.parseEther('0.2');
    console.log('Seed AMM liquidity:', ethers.formatEther(seedMon), 'MON');

    const factory = new ethers.ContractFactory(abi, bytecode, wallet);
    const deployTx = await factory.deploy({
        value: seedMon,
        type: 0,
        gasPrice: gasPrice
    });
    console.log('Deployment tx sent:', deployTx.deploymentTransaction().hash);

    const t0 = Date.now();
    await deployTx.waitForDeployment();
    const contractAddress = await deployTx.getAddress();
    console.log('V6 deployed successfully in ' + (Date.now() - t0) + 'ms');
    console.log('V6 contract address: ' + contractAddress);
    console.log('Explorer: https://testnet.monadexplorer.com/address/' + contractAddress);

    fs.writeFileSync(path.join(__dirname, 'v6_deployed_address.txt'), contractAddress);
}

main().catch(err => {
    console.error('Deployment error:', err);
    process.exit(1);
});
