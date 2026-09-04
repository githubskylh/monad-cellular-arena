// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FantasyWestwardV3
 * @notice 全链梦幻西游 V3 旗舰合约：三界三宗多门派、藏宝阁全链去中心化寄售行与长安擂台切磋系统
 * @dev 在高吞吐、低延迟 Monad 链上实现：门派修行、关卡会话聚合清算、神兵槽位穿戴、C2C 全链交易与战神榜。
 */
contract FantasyWestwardV3 {
    // 门派枚举: 0: 大唐官府 (人族爆发), 1: 龙宫 (仙族法术), 2: 狮驼岭 (魔族暴击)
    enum Sect { DATANG, LONGGONG, SHITUOLING }

    // 装备槽位: 0: 武器 (Weapon), 1: 宝甲 (Armor), 2: 法宝 (Relic)
    enum EquipSlot { WEAPON, ARMOR, RELIC }

    struct ChapterSummary {
        uint16 chapterId;        // 关卡: 1: 东海沉船, 2: 江南野外, 3: 大雁塔决战
        uint32 totalDamage;      // 累计挥剑/法术伤害
        uint16 monstersSlain;    // 击破妖魔数
        uint16 skillsUsed;       // 释放门派技能次数
        uint16 stepsTaken;       // 探索步数
        uint32 clearTimeSeconds; // 通关耗时
        bool bossDefeated;       // 是否伏诛关底 Boss
    }

    struct PlayerProfile {
        uint8 sect;              // 所属门派 (0:大唐, 1:龙宫, 2:狮驼岭)
        uint16 level;            // 等级
        uint32 totalExp;         // 累计修为
        uint16 maxChapterUnlocked; // 最高解锁章节
        uint32 totalDamageDealt; // 累计输出伤害
        uint16 totalMonstersKilled; // 累计斩妖除魔
        uint32 totalSkillsCast;  // 累计施法次数
        uint32 arenaWins;        // 擂台切磋胜场
        bool isRegistered;
    }

    struct ChapterLootNFT {
        uint256 tokenId;
        uint16 chapterId;
        uint8 itemType;          // 0: 武器, 1: 宝甲, 2: 法宝
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

    // 玩家基础档案
    mapping(address => PlayerProfile) public profiles;

    // 装备槽位账本: player => slot (0:武器, 1:宝甲, 2:法宝) => tokenId
    mapping(address => mapping(uint8 => uint256)) public equippedTokens;
    
    // 神兵 NFT 资产账本
    uint256 public nextTokenId = 1;
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256[]) public playerTokens;
    mapping(uint256 => ChapterLootNFT) public nftDetails;

    // 藏宝阁全链 C2C 交易市场
    mapping(uint256 => Listing) public listings;
    uint256[] public activeListingIds;

    // 全局统计遥测
    uint256 public totalChaptersCleared;
    uint256 public totalNFTsMinted;
    uint256 public totalMarketTrades;
    uint256 public totalTradeVolumeWei;

    // 事件
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
        uint256 blockNum
    );
    event ItemEquipped(address indexed player, uint8 indexed slot, uint256 indexed tokenId, string itemName, uint32 combatPower);
    event ItemUnequipped(address indexed player, uint8 indexed slot, uint256 indexed tokenId);
    event ItemListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ItemListingCancelled(uint256 indexed tokenId, address indexed seller);
    event ItemSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event ArenaVictoryRecorded(address indexed winner, address indexed opponent, uint32 points);

    // 异常定义
    error InvalidProof();
    error NotTokenOwner();
    error SlotMismatch();
    error ChapterLocked();
    error ItemCurrentlyEquipped();
    error InvalidPrice();
    error NotListedForSale();
    error CannotBuyOwnListing();
    error InsufficientPayment();

    constructor() {}

    /**
     * @notice 剑侠客/仙客初次入世并拜入宗门
     * @param sect 0: 大唐官府, 1: 龙宫, 2: 狮驼岭
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
                isRegistered: true
            });
            emit PlayerRegistered(msg.sender, sect, block.timestamp);
        }
    }

    /**
     * @notice 宗门转换：随时更换拜入之仙家门派
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
     * @notice 核心清算：章节会话级批量合并上链
     */
    function settleChapter(ChapterSummary calldata summary) external returns (uint256 mintedTokenId) {
        PlayerProfile storage prof = profiles[msg.sender];
        if (!prof.isRegistered) {
            registerPlayer(0);
        }

        if (summary.chapterId > prof.maxChapterUnlocked) {
            revert ChapterLocked();
        }

        uint32 minExpectedDamage = uint32(summary.monstersSlain) * 40;
        if (summary.monstersSlain == 0 || summary.totalDamage < minExpectedDamage) {
            revert InvalidProof();
        }

        // 1. 批量合并成长
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

        // 2. 铸造当前章节专属神兵 NFT
        mintedTokenId = _mintChapterLoot(msg.sender, summary.chapterId, summary.totalDamage + summary.skillsUsed);

        totalChaptersCleared++;

        ChapterLootNFT storage loot = nftDetails[mintedTokenId];
        emit ChapterCleared(
            msg.sender,
            summary.chapterId,
            expGain,
            mintedTokenId,
            loot.name,
            loot.rarity,
            loot.combatPower,
            block.number
        );
    }

    /**
     * @notice 装备穿戴功能
     */
    function equipItem(uint256 tokenId, uint8 slot) external {
        if (ownerOf[tokenId] != msg.sender) revert NotTokenOwner();
        if (slot > 2) revert SlotMismatch();
        if (listings[tokenId].active) revert ItemCurrentlyEquipped(); // 寄售中的物品不可穿戴

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
     * @notice 查阅玩家装备槽位详情
     */
    function getEquippedDetails(address player) external view returns (
        uint256[3] memory tokenIds,
        string[3] memory names,
        string[3] memory rarities,
        uint32[3] memory powers,
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
                totalEquipPower += itm.combatPower;
            } else {
                names[s] = unicode"【虚位以待】";
                rarities[s] = unicode"无";
                powers[s] = 0;
            }
        }
    }

    // =========================================================================
    // 藏宝阁全链去中心化 C2C 寄售行 (On-Chain Bazaar Marketplace)
    // =========================================================================

    /**
     * @notice 将神兵挂单至藏宝阁寄售
     * @param tokenId 所持神兵编号
     * @param price 挂单价格 (wei)
     */
    function listLoot(uint256 tokenId, uint256 price) external {
        if (ownerOf[tokenId] != msg.sender) revert NotTokenOwner();
        if (price == 0) revert InvalidPrice();

        // 检查是否正在穿戴中 (穿戴中的装备必须先卸下才能挂牌寄售)
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

        // 避免重复推入数组
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

    /**
     * @notice 取消藏宝阁寄售
     */
    function cancelListing(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        if (!listing.active) revert NotListedForSale();
        if (listing.seller != msg.sender) revert NotTokenOwner();

        listing.active = false;
        _removeActiveListingId(tokenId);

        emit ItemListingCancelled(tokenId, msg.sender);
    }

    /**
     * @notice 在藏宝阁出资购买其他少侠寄售的神兵
     */
    function buyLoot(uint256 tokenId) external payable {
        Listing storage listing = listings[tokenId];
        if (!listing.active) revert NotListedForSale();
        if (listing.seller == msg.sender) revert CannotBuyOwnListing();
        if (msg.value < listing.price) revert InsufficientPayment();

        address payable seller = listing.seller;
        uint256 price = listing.price;

        listing.active = false;
        _removeActiveListingId(tokenId);

        // 转移所有权账本
        _transferLoot(seller, msg.sender, tokenId);

        // 原生 MON 即刻清算给卖家 (0 手续费良心直达)
        seller.transfer(price);

        // 若多付了多余金额则原路退还
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        totalMarketTrades++;
        totalTradeVolumeWei += price;

        emit ItemSold(tokenId, seller, msg.sender, price);
    }

    /**
     * @notice 获取藏宝阁全量在售寄售品
     */
    function getActiveListings() external view returns (
        uint256[] memory tokenIds,
        address[] memory sellers,
        uint256[] memory prices,
        string[] memory names,
        string[] memory rarities,
        uint32[] memory powers,
        uint8[] memory itemTypes
    ) {
        // 先统计有效数目
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

        // 从原拥有者数组中移除
        uint256[] storage fromTokens = playerTokens[from];
        for (uint256 i = 0; i < fromTokens.length; i++) {
            if (fromTokens[i] == tokenId) {
                fromTokens[i] = fromTokens[fromTokens.length - 1];
                fromTokens.pop();
                break;
            }
        }

        // 推入新拥有者数组
        playerTokens[to].push(tokenId);
    }

    // =========================================================================
    // 长安擂台榜与比武记录 (Arena Duels)
    // =========================================================================
    function recordArenaVictory(address opponent, uint32 points) external {
        PlayerProfile storage prof = profiles[msg.sender];
        if (!prof.isRegistered) registerPlayer(0);
        prof.arenaWins++;
        prof.totalExp += points;
        emit ArenaVictoryRecorded(msg.sender, opponent, points);
    }

    // =========================================================================
    // 章节神兵奖池与信息查阅
    // =========================================================================
    function _mintChapterLoot(address player, uint16 chapterId, uint32 seed) internal returns (uint256 tid) {
        tid = nextTokenId++;
        ownerOf[tid] = player;
        playerTokens[player].push(tid);

        string memory lootName;
        string memory rarity;
        uint8 itemType; // 0: 武器, 1: 宝甲, 2: 法宝
        uint32 power;

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
            name: lootName,
            rarity: rarity,
            combatPower: power,
            mintTimestamp: block.timestamp
        });

        totalNFTsMinted++;
    }

    function getPlayerLoot(address player) external view returns (
        uint256[] memory tokenIds,
        uint16[] memory chapterIds,
        uint8[] memory itemTypes,
        string[] memory names,
        string[] memory rarities,
        uint32[] memory powers
    ) {
        uint256[] storage ids = playerTokens[player];
        uint256 len = ids.length;

        tokenIds = new uint256[](len);
        chapterIds = new uint16[](len);
        itemTypes = new uint8[](len);
        names = new string[](len);
        rarities = new string[](len);
        powers = new uint32[](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 tid = ids[i];
            ChapterLootNFT storage item = nftDetails[tid];
            tokenIds[i] = tid;
            chapterIds[i] = item.chapterId;
            itemTypes[i] = item.itemType;
            names[i] = item.name;
            rarities[i] = item.rarity;
            powers[i] = item.combatPower;
        }
    }
}
