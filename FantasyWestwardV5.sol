// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FantasyWestwardV5
 * @notice 全链梦幻西游 V5 并行原生版 (Parallel-Native Edition)
 * @dev 针对 Monad 并行 EVM (10,000 TPS) 与 Monad Blitz 竞赛规约极致重构：
 * 1. 彻底斩断全局锁变量 (Zero Global Serializing Storage Counters)：
 *    - 废除 nextTokenId++，改用确定性无碰撞哈希派生 TokenID；
 *    - 废除 totalChaptersCleared 等高频竞争累加器，改由事件流驱动，实现 100% 真正的并行零冲突执行。
 * 2. 精算 Gas 机制：适配 Monad 按 gas_limit 全额扣费的底层特性，大幅精简状态写入开销。
 * 3. 完整保留 V4 全部核心系统：
 *    - 三宗自由转职 (Sect Switching)
 *    - 会话防重放凭证 (Session Nonce Commitment)
 *    - 纸娃娃装备槽位账本 (Paper Doll Slots)
 *    - 藏宝阁天机玄炉全链升星 (On-Chain Forging & Star Progression)
 *    - 藏宝阁全链 C2C 去中心化寄售行 (Bazaar Marketplace)
 *    - 长安城擂台战神榜 (Chang'an Arena Duels)
 */
contract FantasyWestwardV5 {
    enum Sect { DATANG, LONGGONG, SHITUOLING }
    enum EquipSlot { WEAPON, ARMOR, RELIC }

    struct ChapterSummary {
        uint16 chapterId;        // 关卡编号: 1: 东海沉船, 2: 江南野外, 3: 大雁塔决战
        uint32 totalDamage;      // 累计伤害
        uint16 monstersSlain;    // 斩杀妖兽数
        uint16 skillsUsed;       // 技能释放数
        uint16 stepsTaken;       // 探索步数
        uint32 clearTimeSeconds; // 通关耗时
        bool bossDefeated;       // 是否击破关底 Boss
    }

    struct PlayerProfile {
        uint8 sect;              // 所属门派 (0:大唐, 1:龙宫, 2:狮驼岭)
        uint16 level;            // 角色等级
        uint32 totalExp;         // 累计修为
        uint16 maxChapterUnlocked; // 最高解锁章节
        uint32 totalDamageDealt; // 累计输出伤害
        uint16 totalMonstersKilled; // 累计斩妖除魔
        uint32 totalSkillsCast;  // 累计施法次数
        uint32 arenaWins;        // 擂台切磋胜场
        uint32 totalForges;      // 累计锻造升星次数
        bool isRegistered;
    }

    struct ChapterLootNFT {
        uint256 tokenId;
        uint16 chapterId;
        uint8 itemType;          // 0: 武器, 1: 宝甲, 2: 法宝
        uint8 starLevel;         // 锻造星级 (0 ~ 5 星)
        uint8 affix;             // 特有词缀 (0: 破阵, 1: 疾风, 2: 护体, 3: 归元)
        string name;             // 神兵名称
        string rarity;           // 稀有度
        uint32 combatPower;      // 战力加成
        uint256 mintTimestamp;
    }

    struct Listing {
        uint256 tokenId;
        address payable seller;
        uint256 price;           // 挂单价格 (wei)
        bool active;
    }

    // 玩家基础档案 (纯隔离地址槽位)
    mapping(address => PlayerProfile) public profiles;

    // 装备槽位账本: player => slot => tokenId
    mapping(address => mapping(uint8 => uint256)) public equippedTokens;
    
    // 神兵 NFT 资产账本
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256[]) public playerTokens;
    mapping(uint256 => ChapterLootNFT) public nftDetails;

    // 会话凭证防重放集合: sessionId => consumed
    mapping(bytes32 => bool) public consumedSessions;

    // 藏宝阁全链 C2C 寄售行
    mapping(uint256 => Listing) public listings;
    uint256[] public activeListingIds;

    // =========================================================================
    // 丰富事件流 (为 Envio Indexer 与 Monad 链下轻节点提供极致零 Gas 统计)
    // =========================================================================
    event PlayerRegistered(address indexed player, uint8 sect, uint256 timestamp);
    event SectSwitched(address indexed player, uint8 oldSect, uint8 newSect);
    event ChapterCleared(
        address indexed player,
        uint16 indexed chapterId,
        uint32 expGained,
        uint256 indexed lootTokenId,
        string lootName,
        string rarity,
        uint32 combatPower,
        bytes32 sessionId,
        uint256 blockNum
    );
    event ItemEquipped(address indexed player, uint8 indexed slot, uint256 indexed tokenId, string itemName, uint32 combatPower);
    event ItemUnequipped(address indexed player, uint8 indexed slot, uint256 indexed tokenId);
    event ItemForged(uint256 indexed tokenId, uint8 newStarLevel, uint32 newCombatPower);
    event ItemListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ItemListingCancelled(uint256 indexed tokenId, address indexed seller);
    event ItemSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event ArenaVictoryRecorded(address indexed winner, address indexed opponent, uint32 points);

    // 异常定义 (自定义 Error 节省部署与执行 Gas)
    error InvalidProof();
    error NotTokenOwner();
    error SlotMismatch();
    error ChapterLocked();
    error ItemCurrentlyEquipped();
    error InvalidPrice();
    error NotListedForSale();
    error CannotBuyOwnListing();
    error InsufficientPayment();
    error SessionAlreadyConsumed();
    error MaxStarReached();

    constructor() {}

    /**
     * @notice 拜入宗门初次入世
     */
    function registerPlayer(uint8 sect) public {
        if (!profiles[msg.sender].isRegistered) {
            profiles[msg.sender] = PlayerProfile({
                sect: sect > 2 ? 0 : sect,
                level: 1,
                totalExp: 0,
                maxChapterUnlocked: 1,
                totalDamageDealt: 0,
                totalMonstersKilled: 0,
                totalSkillsCast: 0,
                arenaWins: 0,
                totalForges: 0,
                isRegistered: true
            });
            emit PlayerRegistered(msg.sender, sect, block.timestamp);
        }
    }

    /**
     * @notice 随时切换修行门派
     */
    function switchSect(uint8 newSect) external {
        if (!profiles[msg.sender].isRegistered) {
            registerPlayer(newSect);
            return;
        }
        if (newSect > 2) revert SlotMismatch();
        uint8 old = profiles[msg.sender].sect;
        profiles[msg.sender].sect = newSect;
        emit SectSwitched(msg.sender, old, newSect);
    }

    /**
     * @notice 核心突破：无全局锁会话单笔合并清算与自动 Mint
     * @dev 彻底移除 nextTokenId++ 与 totalChaptersCleared++ 全局存储冲突，支持百人同屏并发通关
     */
    function settleChapter(ChapterSummary calldata summary, bytes32 sessionId) external returns (uint256 mintedTokenId) {
        if (consumedSessions[sessionId]) {
            revert SessionAlreadyConsumed();
        }
        consumedSessions[sessionId] = true;

        PlayerProfile storage prof = profiles[msg.sender];
        if (!prof.isRegistered) {
            registerPlayer(0);
        }

        if (summary.chapterId > prof.maxChapterUnlocked) {
            revert ChapterLocked();
        }

        uint32 minExpectedDamage = uint32(summary.monstersSlain) * 35;
        if (summary.monstersSlain == 0 || summary.totalDamage < minExpectedDamage) {
            revert InvalidProof();
        }

        // 1. 批量合并玩家个人成长 (纯局部状态读写)
        uint32 expGain = uint32(summary.monstersSlain) * 50 + uint32(summary.skillsUsed) * 15 + (summary.chapterId * 100);
        if (summary.bossDefeated) expGain += 200;

        prof.totalExp += expGain;
        prof.totalDamageDealt += summary.totalDamage;
        prof.totalMonstersKilled += summary.monstersSlain;
        prof.totalSkillsCast += summary.skillsUsed;
        prof.level = uint16(1 + (prof.totalExp / 250));

        if (summary.chapterId >= prof.maxChapterUnlocked && prof.maxChapterUnlocked < 3) {
            prof.maxChapterUnlocked = summary.chapterId + 1;
        }

        // 2. 自动铸造专属神兵 NFT (确定性零冲突哈希 TokenID)
        mintedTokenId = _mintChapterLoot(msg.sender, summary.chapterId, summary.totalDamage + summary.skillsUsed, sessionId);

        ChapterLootNFT storage loot = nftDetails[mintedTokenId];
        emit ChapterCleared(
            msg.sender,
            summary.chapterId,
            expGain,
            mintedTokenId,
            loot.name,
            loot.rarity,
            loot.combatPower,
            sessionId,
            block.number
        );
    }

    /**
     * @notice 装备锻造升星与词缀强化系统 (On-Chain Forging)
     * @param tokenId 装备编号
     */
    function forgeUpgradeItem(uint256 tokenId) external {
        if (ownerOf[tokenId] != msg.sender) revert NotTokenOwner();
        if (listings[tokenId].active) revert ItemCurrentlyEquipped();

        ChapterLootNFT storage loot = nftDetails[tokenId];
        if (loot.starLevel >= 5) revert MaxStarReached();

        loot.starLevel++;
        loot.combatPower += 25; // 每次锻造战力稳固跃升 +25
        profiles[msg.sender].totalForges++;

        emit ItemForged(tokenId, loot.starLevel, loot.combatPower);

        // 若当前正处于穿戴状态，更新穿戴中通知
        if (equippedTokens[msg.sender][loot.itemType] == tokenId) {
            emit ItemEquipped(msg.sender, loot.itemType, tokenId, loot.name, loot.combatPower);
        }
    }

    /**
     * @notice 装备穿戴功能
     */
    function equipItem(uint256 tokenId, uint8 slot) external {
        if (ownerOf[tokenId] != msg.sender) revert NotTokenOwner();
        if (slot > 2) revert SlotMismatch();
        if (listings[tokenId].active) revert ItemCurrentlyEquipped();

        ChapterLootNFT storage loot = nftDetails[tokenId];
        if (loot.itemType != slot) revert SlotMismatch();

        equippedTokens[msg.sender][slot] = tokenId;
        emit ItemEquipped(msg.sender, slot, tokenId, loot.name, loot.combatPower);
    }

    /**
     * @notice 卸下装备
     */
    function unequipItem(uint8 slot) external {
        if (slot > 2) revert SlotMismatch();
        uint256 curToken = equippedTokens[msg.sender][slot];
        if (curToken != 0) {
            equippedTokens[msg.sender][slot] = 0;
            emit ItemUnequipped(msg.sender, slot, curToken);
        }
    }

    /**
     * @notice 查阅装备穿戴详情与星级加成
     */
    function getEquippedDetails(address player) external view returns (
        uint256[3] memory tokenIds,
        string[3] memory names,
        string[3] memory rarities,
        uint32[3] memory powers,
        uint8[3] memory starLevels,
        uint32 totalEquipPower
    ) {
        for (uint8 s = 0; s < 3; s++) {
            uint256 tid = equippedTokens[player][s];
            tokenIds[s] = tid;
            if (tid != 0) {
                ChapterLootNFT storage itm = nftDetails[tid];
                names[s] = itm.name;
                rarities[s] = itm.rarity;
                powers[s] = itm.combatPower;
                starLevels[s] = itm.starLevel;
                totalEquipPower += itm.combatPower;
            } else {
                names[s] = unicode"【虚位以待】";
                rarities[s] = unicode"无";
                powers[s] = 0;
                starLevels[s] = 0;
            }
        }
    }

    // =========================================================================
    // 藏宝阁全链去中心化 C2C 寄售行
    // =========================================================================
    function listLoot(uint256 tokenId, uint256 price) external {
        if (ownerOf[tokenId] != msg.sender) revert NotTokenOwner();
        if (price == 0) revert InvalidPrice();

        ChapterLootNFT storage loot = nftDetails[tokenId];
        if (equippedTokens[msg.sender][loot.itemType] == tokenId) {
            revert ItemCurrentlyEquipped();
        }

        listings[tokenId] = Listing({
            tokenId: tokenId,
            seller: payable(msg.sender),
            price: price,
            active: true
        });

        bool found = false;
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            if (activeListingIds[i] == tokenId) {
                found = true;
                break;
            }
        }
        if (!found) {
            activeListingIds.push(tokenId);
        }

        emit ItemListed(tokenId, msg.sender, price);
    }

    function cancelListing(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        if (!listing.active) revert NotListedForSale();
        if (listing.seller != msg.sender) revert NotTokenOwner();

        listing.active = false;
        _removeActiveListingId(tokenId);

        emit ItemListingCancelled(tokenId, msg.sender);
    }

    function buyLoot(uint256 tokenId) external payable {
        Listing storage listing = listings[tokenId];
        if (!listing.active) revert NotListedForSale();
        if (listing.seller == msg.sender) revert CannotBuyOwnListing();
        if (msg.value < listing.price) revert InsufficientPayment();

        address payable seller = listing.seller;
        uint256 price = listing.price;

        listing.active = false;
        _removeActiveListingId(tokenId);

        _transferLoot(seller, msg.sender, tokenId);

        seller.transfer(price);

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        emit ItemSold(tokenId, seller, msg.sender, price);
    }

    function getActiveListings() external view returns (
        uint256[] memory tokenIds,
        address[] memory sellers,
        uint256[] memory prices,
        string[] memory names,
        string[] memory rarities,
        uint32[] memory powers,
        uint8[] memory itemTypes,
        uint8[] memory starLevels
    ) {
        uint256 count = 0;
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            if (listings[activeListingIds[i]].active) count++;
        }

        tokenIds = new uint256[](count);
        sellers = new address[](count);
        prices = new uint256[](count);
        names = new string[](count);
        rarities = new string[](count);
        powers = new uint32[](count);
        itemTypes = new uint8[](count);
        starLevels = new uint8[](count);

        uint256 idx = 0;
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            uint256 tid = activeListingIds[i];
            Listing storage l = listings[tid];
            if (l.active) {
                ChapterLootNFT storage nft = nftDetails[tid];
                tokenIds[idx] = tid;
                sellers[idx] = l.seller;
                prices[idx] = l.price;
                names[idx] = nft.name;
                rarities[idx] = nft.rarity;
                powers[idx] = nft.combatPower;
                itemTypes[idx] = nft.itemType;
                starLevels[idx] = nft.starLevel;
                idx++;
            }
        }
    }

    function _removeActiveListingId(uint256 tokenId) internal {
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            if (activeListingIds[i] == tokenId) {
                activeListingIds[i] = activeListingIds[activeListingIds.length - 1];
                activeListingIds.pop();
                break;
            }
        }
    }

    function _transferLoot(address from, address to, uint256 tokenId) internal {
        ownerOf[tokenId] = to;

        uint256[] storage fromTokens = playerTokens[from];
        for (uint256 i = 0; i < fromTokens.length; i++) {
            if (fromTokens[i] == tokenId) {
                fromTokens[i] = fromTokens[fromTokens.length - 1];
                fromTokens.pop();
                break;
            }
        }

        playerTokens[to].push(tokenId);
    }

    // =========================================================================
    // 长安擂台切磋 (Arena Duels)
    // =========================================================================
    function recordArenaVictory(address opponent, uint32 points) external {
        PlayerProfile storage prof = profiles[msg.sender];
        if (!prof.isRegistered) registerPlayer(0);
        prof.arenaWins++;
        prof.totalExp += points;
        emit ArenaVictoryRecorded(msg.sender, opponent, points);
    }

    // =========================================================================
    // 并行原生神兵生成 (零全局存储冲突 TokenID 算法)
    // =========================================================================
    function _mintChapterLoot(address player, uint16 chapterId, uint32 seed, bytes32 sessionId) internal returns (uint256 tid) {
        // 基于玩家地址、会话随机凭据与区块时间确定性派生 8-9 位可读唯一神兵编号，彻底消除 nextTokenId++ 冲突
        uint256 derivedId = (uint256(keccak256(abi.encodePacked(player, sessionId, block.timestamp))) % 900000000) + 100000000;
        while (ownerOf[derivedId] != address(0)) {
            derivedId += 1;
        }
        tid = derivedId;

        ownerOf[tid] = player;
        playerTokens[player].push(tid);

        string memory lootName;
        string memory rarity;
        uint8 itemType; // 0: 武器, 1: 宝甲, 2: 法宝
        uint32 power;
        uint8 affix = uint8((seed + tid) % 4);

        uint256 roll = (seed + block.timestamp + tid) % 3;
        itemType = uint8(roll);

        if (chapterId == 1) {
            if (roll == 0) {
                lootName = unicode"【大唐青锋剑】";
                rarity = unicode"名品法宝";
                power = 65;
            } else if (roll == 1) {
                lootName = unicode"【金丝软猬甲】";
                rarity = unicode"稀有灵宝";
                power = 85;
            } else {
                lootName = unicode"【东海辟水珠】";
                rarity = unicode"史诗神品";
                power = 110;
            }
        } else if (chapterId == 2) {
            if (roll == 0) {
                lootName = unicode"【玄铁重剑】";
                rarity = unicode"史诗神品";
                power = 160;
            } else if (roll == 1) {
                lootName = unicode"【锁子黄金甲】";
                rarity = unicode"传世孤品";
                power = 195;
            } else {
                lootName = unicode"【定风辟邪珠】";
                rarity = unicode"史诗神品";
                power = 175;
            }
        } else {
            if (roll == 0) {
                lootName = unicode"【逍遥游龙剑】";
                rarity = unicode"传世无双";
                power = 280;
            } else if (roll == 1) {
                lootName = unicode"【九霄天仙铠】";
                rarity = unicode"造化圣物";
                power = 320;
            } else {
                lootName = unicode"【七宝玲珑塔】";
                rarity = unicode"通天灵宝";
                power = 350;
            }
        }

        nftDetails[tid] = ChapterLootNFT({
            tokenId: tid,
            chapterId: chapterId,
            itemType: itemType,
            starLevel: 0,
            affix: affix,
            name: lootName,
            rarity: rarity,
            combatPower: power,
            mintTimestamp: block.timestamp
        });
    }

    function getPlayerLoot(address player) external view returns (
        uint256[] memory tokenIds,
        uint16[] memory chapterIds,
        uint8[] memory itemTypes,
        uint8[] memory starLevels,
        string[] memory names,
        string[] memory rarities,
        uint32[] memory powers
    ) {
        uint256[] storage ids = playerTokens[player];
        uint256 len = ids.length;

        tokenIds = new uint256[](len);
        chapterIds = new uint16[](len);
        itemTypes = new uint8[](len);
        starLevels = new uint8[](len);
        names = new string[](len);
        rarities = new string[](len);
        powers = new uint32[](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 tid = ids[i];
            ChapterLootNFT storage item = nftDetails[tid];
            tokenIds[i] = tid;
            chapterIds[i] = item.chapterId;
            itemTypes[i] = item.itemType;
            starLevels[i] = item.starLevel;
            names[i] = item.name;
            rarities[i] = item.rarity;
            powers[i] = item.combatPower;
        }
    }
}
