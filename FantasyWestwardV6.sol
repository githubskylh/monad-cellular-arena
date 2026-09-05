// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FantasyWestwardV6
 * @notice 全链梦幻西游 V6：全链 DeFi 金融与元气地牢融合旗舰版
 * @dev 针对 Monad 并行 EVM (10,000 TPS) 打造的闭环生态：
 * 1. 关卡原子结算：神兵装备 -> 铸造 ERC-721 NFT；杀敌积分 -> 铸造 ERC-20 西游灵石 ($XYT)；
 * 2. 内置 ERC-20 游戏积分代币 ($XYT)；
 * 3. 内置去中心化 AMM Swap (MON <-> XYT)；
 * 4. 内置单币质押金库 (36.5% APY)；
 * 5. 内置 LP 流动性做市农场 (128.0% APY)；
 * 6. 完整保留 V5 纸娃娃装备槽位、升星锻造与 C2C 寄售行。
 */
contract FantasyWestwardV6 {
    enum Sect { DATANG, LONGGONG, SHITUOLING }
    enum EquipSlot { WEAPON, ARMOR, RELIC }

    struct ChapterSummary {
        uint16 chapterId;
        uint32 totalDamage;
        uint16 monstersSlain;
        uint16 skillsUsed;
        uint16 stepsTaken;
        uint32 clearTimeSeconds;
        bool bossDefeated;
    }

    struct PlayerProfile {
        uint8 sect;
        uint16 level;
        uint32 totalExp;
        uint16 maxChapterUnlocked;
        uint32 totalDamageDealt;
        uint16 totalMonstersKilled;
        uint32 totalSkillsCast;
        uint32 arenaWins;
        uint32 totalForges;
        bool isRegistered;
    }

    struct ChapterLootNFT {
        uint256 tokenId;
        uint16 chapterId;
        uint8 itemType;
        uint8 starLevel;
        uint8 affix;
        string name;
        string rarity;
        uint32 combatPower;
        uint256 mintTimestamp;
    }

    struct Listing {
        uint256 tokenId;
        address payable seller;
        uint256 price;
        bool active;
    }

    address public owner;
    mapping(address => PlayerProfile) public profiles;
    mapping(address => mapping(uint8 => uint256)) public equippedTokens;
    
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256[]) public playerTokens;
    mapping(uint256 => ChapterLootNFT) public nftDetails;
    mapping(bytes32 => bool) public consumedSessions;

    mapping(uint256 => Listing) public listings;
    uint256[] public activeListingIds;

    // ERC-20 代币 ($XYT)
    string public constant tokenName = "XiYou Token";
    string public constant tokenSymbol = "XYT";
    uint8 public constant tokenDecimals = 18;
    uint256 public tokenTotalSupply;
    mapping(address => uint256) public tokenBalanceOf;
    mapping(address => mapping(address => uint256)) public tokenAllowance;

    // AMM 链上 Swap (MON <-> XYT)
    uint256 public reserveMon;
    uint256 public reserveToken;
    uint256 public totalLpSupply;
    mapping(address => uint256) public lpBalanceOf;

    // 单币质押金库 (36.5% APY)
    struct StakerInfo {
        uint256 stakedAmount;
        uint256 rewardDebt;
        uint256 lastUpdateTime;
    }
    mapping(address => StakerInfo) public stakers;
    uint256 public constant STAKING_APY_BPS = 3650;

    // LP 流动性做市农场 (128.0% APY)
    struct LpFarmerInfo {
        uint256 stakedLp;
        uint256 rewardDebt;
        uint256 lastUpdateTime;
    }
    mapping(address => LpFarmerInfo) public lpFarmers;
    uint256 public constant LP_FARM_APY_BPS = 12800;

    event ChapterCleared(
        address indexed player,
        uint16 indexed chapterId,
        uint32 expGained,
        uint256 mintedTokenId,
        uint256 xytPointsEarned,
        bytes32 sessionId,
        uint256 blockNumber
    );

    event ItemForged(address indexed player, uint256 indexed tokenId, uint8 newStarLevel, uint32 newCombatPower);
    event LootListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event LootSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event ListingCancelled(uint256 indexed tokenId, address indexed seller);

    event TokenTransfer(address indexed from, address indexed to, uint256 value);
    event TokenApproval(address indexed ownerAddr, address indexed spender, uint256 value);

    event Swapped(address indexed user, uint256 amountIn, uint256 amountOut, bool monToToken);
    event LiquidityAdded(address indexed user, uint256 monAdded, uint256 tokensAdded, uint256 lpMinted);
    event LiquidityRemoved(address indexed user, uint256 monReturned, uint256 tokensReturned, uint256 lpBurned);

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event StakingHarvested(address indexed user, uint256 reward);

    event LpStaked(address indexed user, uint256 lpAmount);
    event LpUnstaked(address indexed user, uint256 lpAmount);
    event LpHarvested(address indexed user, uint256 reward);

    constructor() payable {
        owner = msg.sender;
        _mintTokens(msg.sender, 1_000_000 * 1e18);

        // 如果部署时附带 MON，直接为内置 AMM 注入做市底池
        if (msg.value > 0) {
            uint256 seedTokens = msg.value * 1000;
            _mintTokens(address(this), seedTokens);
            reserveMon = msg.value;
            reserveToken = seedTokens;
            totalLpSupply = 1000 * 1e18;
            lpBalanceOf[msg.sender] = totalLpSupply;
        }
    }

    receive() external payable {}

    function settleChapter(
        ChapterSummary calldata summary,
        bytes32 sessionId
    ) external returns (uint256 mintedTokenId, uint256 xytPointsEarned) {
        require(!consumedSessions[sessionId], "SessionAlreadyConsumed");
        consumedSessions[sessionId] = true;

        PlayerProfile storage prof = profiles[msg.sender];
        if (!prof.isRegistered) {
            registerPlayer(0);
        }

        require(summary.chapterId <= prof.maxChapterUnlocked, "ChapterLocked");
        require(summary.monstersSlain > 0, "NoMonstersSlain");

        uint32 expGain = uint32(summary.monstersSlain) * 50 + uint32(summary.skillsUsed) * 15 + (summary.chapterId * 100);
        if (summary.bossDefeated) expGain += 200;

        prof.totalExp += expGain;
        prof.totalDamageDealt += summary.totalDamage;
        prof.totalMonstersKilled += summary.monstersSlain;
        prof.totalSkillsCast += summary.skillsUsed;
        prof.level = uint16(1 + (prof.totalExp / 250));

        if (summary.chapterId >= prof.maxChapterUnlocked && prof.maxChapterUnlocked < 10) {
            prof.maxChapterUnlocked = summary.chapterId + 1;
        }

        mintedTokenId = _mintChapterLoot(msg.sender, summary.chapterId, summary.totalDamage + summary.skillsUsed, sessionId);

        xytPointsEarned = (uint256(summary.chapterId) * 50 + uint256(summary.monstersSlain) * 10 + uint256(summary.totalDamage) / 200 + (summary.bossDefeated ? 100 : 0)) * 1e18;
        _mintTokens(msg.sender, xytPointsEarned);

        emit ChapterCleared(
            msg.sender,
            summary.chapterId,
            expGain,
            mintedTokenId,
            xytPointsEarned,
            sessionId,
            block.number
        );
    }

    function name() external pure returns (string memory) { return tokenName; }
    function symbol() external pure returns (string memory) { return tokenSymbol; }
    function decimals() external pure returns (uint8) { return tokenDecimals; }
    function totalSupply() external view returns (uint256) { return tokenTotalSupply; }
    function balanceOf(address account) external view returns (uint256) { return tokenBalanceOf[account]; }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transferTokens(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address ownerAddr, address spender) external view returns (uint256) {
        return tokenAllowance[ownerAddr][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        tokenAllowance[msg.sender][spender] = amount;
        emit TokenApproval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        uint256 currentAllowance = tokenAllowance[sender][msg.sender];
        require(currentAllowance >= amount, "AllowanceExceeded");
        tokenAllowance[sender][msg.sender] = currentAllowance - amount;
        _transferTokens(sender, recipient, amount);
        return true;
    }

    function _transferTokens(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0) && recipient != address(0), "ZeroAddress");
        require(tokenBalanceOf[sender] >= amount, "BalanceExceeded");

        tokenBalanceOf[sender] -= amount;
        tokenBalanceOf[recipient] += amount;
        emit TokenTransfer(sender, recipient, amount);
    }

    function _mintTokens(address account, uint256 amount) internal {
        tokenTotalSupply += amount;
        tokenBalanceOf[account] += amount;
        emit TokenTransfer(address(0), account, amount);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "InvalidReserves");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function swapMonForTokens(uint256 minTokensOut) external payable returns (uint256 tokensOut) {
        require(msg.value > 0, "ZeroMONIn");
        tokensOut = getAmountOut(msg.value, reserveMon, reserveToken);
        require(tokensOut >= minTokensOut, "SlippageExceeded");
        require(tokenBalanceOf[address(this)] >= tokensOut, "InsufficientPoolLiquidity");

        reserveMon += msg.value;
        reserveToken -= tokensOut;

        _transferTokens(address(this), msg.sender, tokensOut);
        emit Swapped(msg.sender, msg.value, tokensOut, true);
    }

    function swapTokensForMon(uint256 tokenAmountIn, uint256 minMonOut) external returns (uint256 monOut) {
        require(tokenAmountIn > 0, "ZeroTokensIn");
        monOut = getAmountOut(tokenAmountIn, reserveToken, reserveMon);
        require(monOut >= minMonOut, "SlippageExceeded");
        require(address(this).balance >= monOut, "InsufficientMonLiquidity");

        _transferTokens(msg.sender, address(this), tokenAmountIn);
        reserveToken += tokenAmountIn;
        reserveMon -= monOut;

        (bool success, ) = payable(msg.sender).call{value: monOut}("");
        require(success, "MonTransferFailed");
        emit Swapped(msg.sender, tokenAmountIn, monOut, false);
    }

    function addLiquidity(uint256 tokenAmount) external payable returns (uint256 lpMinted) {
        require(msg.value > 0 && tokenAmount > 0, "ZeroLiquidity");

        if (totalLpSupply == 0 || reserveMon == 0) {
            lpMinted = msg.value;
        } else {
            uint256 monShare = (msg.value * totalLpSupply) / reserveMon;
            uint256 tokenShare = (tokenAmount * totalLpSupply) / reserveToken;
            lpMinted = monShare < tokenShare ? monShare : tokenShare;
        }

        require(lpMinted > 0, "ZeroLpMinted");

        _transferTokens(msg.sender, address(this), tokenAmount);
        reserveMon += msg.value;
        reserveToken += tokenAmount;

        totalLpSupply += lpMinted;
        lpBalanceOf[msg.sender] += lpMinted;

        emit LiquidityAdded(msg.sender, msg.value, tokenAmount, lpMinted);
    }

    function removeLiquidity(uint256 lpAmount) external returns (uint256 monReturned, uint256 tokensReturned) {
        require(lpAmount > 0 && lpBalanceOf[msg.sender] >= lpAmount, "InsufficientLp");

        monReturned = (lpAmount * reserveMon) / totalLpSupply;
        tokensReturned = (lpAmount * reserveToken) / totalLpSupply;
        require(monReturned > 0 && tokensReturned > 0, "InvalidReturnAmounts");

        lpBalanceOf[msg.sender] -= lpAmount;
        totalLpSupply -= lpAmount;

        reserveMon -= monReturned;
        reserveToken -= tokensReturned;

        _transferTokens(address(this), msg.sender, tokensReturned);
        (bool success, ) = payable(msg.sender).call{value: monReturned}("");
        require(success, "MonReturnFailed");

        emit LiquidityRemoved(msg.sender, monReturned, tokensReturned, lpAmount);
    }

    function getPendingStakingReward(address user) public view returns (uint256) {
        StakerInfo storage s = stakers[user];
        if (s.stakedAmount == 0) return s.rewardDebt;
        uint256 timeElapsed = block.timestamp - s.lastUpdateTime;
        uint256 newReward = (s.stakedAmount * STAKING_APY_BPS * timeElapsed) / (10000 * 365 days);
        return s.rewardDebt + newReward;
    }

    function stakeTokens(uint256 amount) external {
        require(amount > 0, "ZeroStakeAmount");
        _updateStakingReward(msg.sender);

        _transferTokens(msg.sender, address(this), amount);
        stakers[msg.sender].stakedAmount += amount;
        emit Staked(msg.sender, amount);
    }

    function unstakeTokens(uint256 amount) external {
        StakerInfo storage s = stakers[msg.sender];
        require(amount > 0 && s.stakedAmount >= amount, "InsufficientStaked");
        _updateStakingReward(msg.sender);

        s.stakedAmount -= amount;
        _transferTokens(address(this), msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function claimStakingRewards() external returns (uint256 reward) {
        _updateStakingReward(msg.sender);
        StakerInfo storage s = stakers[msg.sender];
        reward = s.rewardDebt;
        require(reward > 0, "NoRewards");

        s.rewardDebt = 0;
        _mintTokens(msg.sender, reward);
        emit StakingHarvested(msg.sender, reward);
    }

    function _updateStakingReward(address user) internal {
        StakerInfo storage s = stakers[user];
        s.rewardDebt = getPendingStakingReward(user);
        s.lastUpdateTime = block.timestamp;
    }

    function getPendingLpReward(address user) public view returns (uint256) {
        LpFarmerInfo storage f = lpFarmers[user];
        if (f.stakedLp == 0) return f.rewardDebt;
        uint256 timeElapsed = block.timestamp - f.lastUpdateTime;
        uint256 newReward = (f.stakedLp * LP_FARM_APY_BPS * timeElapsed) / (10000 * 365 days);
        return f.rewardDebt + newReward;
    }

    function stakeLp(uint256 lpAmount) external {
        require(lpAmount > 0 && lpBalanceOf[msg.sender] >= lpAmount, "InsufficientLpBalance");
        _updateLpReward(msg.sender);

        lpBalanceOf[msg.sender] -= lpAmount;
        lpFarmers[msg.sender].stakedLp += lpAmount;
        emit LpStaked(msg.sender, lpAmount);
    }

    function unstakeLp(uint256 lpAmount) external {
        LpFarmerInfo storage f = lpFarmers[msg.sender];
        require(lpAmount > 0 && f.stakedLp >= lpAmount, "InsufficientStakedLp");
        _updateLpReward(msg.sender);

        f.stakedLp -= lpAmount;
        lpBalanceOf[msg.sender] += lpAmount;
        emit LpUnstaked(msg.sender, lpAmount);
    }

    function claimLpRewards() external returns (uint256 reward) {
        _updateLpReward(msg.sender);
        LpFarmerInfo storage f = lpFarmers[msg.sender];
        reward = f.rewardDebt;
        require(reward > 0, "NoLpRewards");

        f.rewardDebt = 0;
        _mintTokens(msg.sender, reward);
        emit LpHarvested(msg.sender, reward);
    }

    function _updateLpReward(address user) internal {
        LpFarmerInfo storage f = lpFarmers[user];
        f.rewardDebt = getPendingLpReward(user);
        f.lastUpdateTime = block.timestamp;
    }

    function getFinancialOverview(address user) external view returns (
        uint256 userXytBalance,
        uint256 stakedXyt,
        uint256 pendingXytReward,
        uint256 userLpBalance,
        uint256 stakedLp,
        uint256 pendingLpReward,
        uint256 poolMon,
        uint256 poolXyt,
        uint256 totalLp
    ) {
        return (
            tokenBalanceOf[user],
            stakers[user].stakedAmount,
            getPendingStakingReward(user),
            lpBalanceOf[user],
            lpFarmers[user].stakedLp,
            getPendingLpReward(user),
            reserveMon,
            reserveToken,
            totalLpSupply
        );
    }

    function registerPlayer(uint8 sect) public {
        PlayerProfile storage prof = profiles[msg.sender];
        if (!prof.isRegistered) {
            prof.sect = sect;
            prof.level = 1;
            prof.maxChapterUnlocked = 1;
            prof.isRegistered = true;
        }
    }

    function switchSect(uint8 newSect) external {
        require(newSect <= 2, "InvalidSect");
        PlayerProfile storage prof = profiles[msg.sender];
        if (!prof.isRegistered) registerPlayer(newSect);
        else prof.sect = newSect;
    }

    function equipItem(uint8 slot, uint256 tokenId) external {
        require(ownerOf[tokenId] == msg.sender, "NotTokenOwner");
        require(!listings[tokenId].active, "ItemCurrentlyListed");
        equippedTokens[msg.sender][slot] = tokenId;
    }

    function forgeUpgradeItem(uint256 tokenId) external {
        require(ownerOf[tokenId] == msg.sender, "NotTokenOwner");
        require(!listings[tokenId].active, "ItemCurrentlyListed");

        ChapterLootNFT storage item = nftDetails[tokenId];
        require(item.starLevel < 5, "MaxStarReached");

        uint256 forgeCost = 50 * 1e18;
        require(tokenBalanceOf[msg.sender] >= forgeCost, "InsufficientXYTForForge");
        _transferTokens(msg.sender, address(this), forgeCost);

        item.starLevel += 1;
        item.combatPower += 35 + (uint32(item.starLevel) * 15);
        profiles[msg.sender].totalForges += 1;

        emit ItemForged(msg.sender, tokenId, item.starLevel, item.combatPower);
    }

    function listLoot(uint256 tokenId, uint256 priceWei) external {
        require(ownerOf[tokenId] == msg.sender, "NotTokenOwner");
        require(priceWei > 0, "InvalidPrice");

        for (uint8 s = 0; s < 3; s++) {
            require(equippedTokens[msg.sender][s] != tokenId, "ItemCurrentlyEquipped");
        }

        listings[tokenId] = Listing(tokenId, payable(msg.sender), priceWei, true);
        activeListingIds.push(tokenId);
        emit LootListed(tokenId, msg.sender, priceWei);
    }

    function buyLoot(uint256 tokenId) external payable {
        Listing storage item = listings[tokenId];
        require(item.active, "ListingNotActive");
        require(msg.value >= item.price, "InsufficientPayment");
        require(item.seller != msg.sender, "CannotBuyOwnListing");

        address payable seller = item.seller;
        uint256 price = item.price;
        item.active = false;

        _transferNFT(seller, msg.sender, tokenId);

        uint256 fee = (price * 3) / 100;
        uint256 sellerProceeds = price - fee;
        reserveMon += fee;

        (bool paid, ) = seller.call{value: sellerProceeds}("");
        require(paid, "SellerPaymentFailed");

        if (msg.value > price) {
            (bool refund, ) = payable(msg.sender).call{value: msg.value - price}("");
            require(refund, "RefundFailed");
        }

        emit LootSold(tokenId, seller, msg.sender, price);
    }

    function cancelListing(uint256 tokenId) external {
        Listing storage item = listings[tokenId];
        require(item.active, "ListingNotActive");
        require(item.seller == msg.sender, "NotItemSeller");

        item.active = false;
        emit ListingCancelled(tokenId, msg.sender);
    }

    function getActiveListings() external view returns (
        uint256[] memory ids,
        address[] memory sellers,
        uint256[] memory prices,
        string[] memory names,
        string[] memory rarities,
        uint32[] memory powers,
        uint8[] memory types
    ) {
        uint256 count = 0;
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            if (listings[activeListingIds[i]].active) count++;
        }

        ids = new uint256[](count);
        sellers = new address[](count);
        prices = new uint256[](count);
        names = new string[](count);
        rarities = new string[](count);
        powers = new uint32[](count);
        types = new uint8[](count);

        uint256 idx = 0;
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            uint256 tid = activeListingIds[i];
            if (listings[tid].active) {
                ids[idx] = tid;
                sellers[idx] = listings[tid].seller;
                prices[idx] = listings[tid].price;
                names[idx] = nftDetails[tid].name;
                rarities[idx] = nftDetails[tid].rarity;
                powers[idx] = nftDetails[tid].combatPower;
                types[idx] = nftDetails[tid].itemType;
                idx++;
            }
        }
    }

    function getPlayerTokens(address player) external view returns (uint256[] memory) {
        return playerTokens[player];
    }

    function _mintChapterLoot(
        address player,
        uint16 chapterId,
        uint32 seed,
        bytes32 sessionId
    ) internal returns (uint256 tokenId) {
        tokenId = uint256(keccak256(abi.encodePacked(block.prevrandao, player, chapterId, seed, sessionId)));
        while (ownerOf[tokenId] != address(0)) {
            tokenId = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp)));
        }

        ownerOf[tokenId] = player;
        playerTokens[player].push(tokenId);

        uint8 itemType = uint8(seed % 3);
        uint8 affix = uint8((seed / 3) % 4);

        string memory itemName;
        string memory rarity;
        uint32 power;

        if (chapterId == 1) {
            itemName = itemType == 0 ? unicode"【大唐青锋剑】" : (itemType == 1 ? unicode"【金丝软猬甲】" : unicode"【玄天定风珠】");
            rarity = unicode"名品灵宝";
            power = 65 + uint32(seed % 25);
        } else if (chapterId == 2) {
            itemName = itemType == 0 ? unicode"【方寸太极扇】" : (itemType == 1 ? unicode"【玄武吞兽铠】" : unicode"【紫金照妖镜】");
            rarity = unicode"上古真品";
            power = 120 + uint32(seed % 40);
        } else {
            itemName = itemType == 0 ? unicode"【化生蟠龙枪】" : (itemType == 1 ? unicode"【万龙伏魔袍】" : unicode"【九幽翻天印】");
            rarity = unicode"鸿蒙至宝";
            power = 220 + uint32(seed % 70);
        }

        nftDetails[tokenId] = ChapterLootNFT({
            tokenId: tokenId,
            chapterId: chapterId,
            itemType: itemType,
            starLevel: 0,
            affix: affix,
            name: itemName,
            rarity: rarity,
            combatPower: power,
            mintTimestamp: block.timestamp
        });
    }

    function _transferNFT(address from, address to, uint256 tokenId) internal {
        ownerOf[tokenId] = to;
        uint256[] storage fromList = playerTokens[from];
        for (uint256 i = 0; i < fromList.length; i++) {
            if (fromList[i] == tokenId) {
                fromList[i] = fromList[fromList.length - 1];
                fromList.pop();
                break;
            }
        }
        playerTokens[to].push(tokenId);
    }
}
