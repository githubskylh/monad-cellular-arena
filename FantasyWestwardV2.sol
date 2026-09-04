// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FantasyWestwardV2
 * @notice 全链梦幻西游 V2：多章节伏魔、神兵装备穿戴槽位与会话级聚合清算引擎 (Session Batch Settlement V2)
 * @dev 针对关卡内高频移动、连招打怪与 Boss 决战实施单笔原子化结算，结合装备穿戴系统动态加成角色战力。
 */
contract FantasyWestwardV2 {
    // 装备槽位枚举: 0: 武器 (Weapon), 1: 宝甲 (Armor), 2: 法宝 (Relic)
    enum EquipSlot { WEAPON, ARMOR, RELIC }

    struct ChapterSummary {
        uint16 chapterId;        // 关卡编号: 1: 东海沉船, 2: 江南野外, 3: 大雁塔决战
        uint32 totalDamage;      // 关卡内累计挥剑伤害
        uint16 monstersSlain;    // 击破妖魔数
        uint16 skillsUsed;       // 释放大唐门派技能次数 (横扫千军/破釜沉舟)
        uint16 stepsTaken;       // 探索移动步数
        uint32 clearTimeSeconds; // 通关耗时
        bool bossDefeated;       // 是否击破关底 Boss
    }

    struct PlayerProfile {
        uint16 level;
        uint32 totalExp;
        uint16 maxChapterUnlocked; // 最高解锁章节
        uint32 totalDamageDealt;
        uint16 totalMonstersKilled;
        uint32 totalSkillsCast;
        bool isRegistered;
    }

    struct ChapterLootNFT {
        uint256 tokenId;
        uint16 chapterId;
        uint8 itemType;    // 0: 武器, 1: 宝甲, 2: 法宝
        string name;       // 神兵名称
        string rarity;     // 稀有度
        uint32 combatPower;// 战力增幅
        uint256 mintTimestamp;
    }

    // 玩家基础档案
    mapping(address => PlayerProfile) public profiles;

    // 装备槽位账本: player => slot (0:武器, 1:宝甲, 2:法宝) => tokenId (0表示未装备)
    mapping(address => mapping(uint8 => uint256)) public equippedTokens;
    
    // 神兵 NFT 账本
    uint256 public nextTokenId = 1;
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256[]) public playerTokens;
    mapping(uint256 => ChapterLootNFT) public nftDetails;

    // 全局统计遥测
    uint256 public totalChaptersCleared;
    uint256 public totalNFTsMinted;

    // 事件定义
    event PlayerRegistered(address indexed player, uint256 timestamp);
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

    // 自定义异常
    error InvalidProof();
    error NotTokenOwner();
    error SlotMismatch();
    error ChapterLocked();

    constructor() {}

    /**
     * @notice 剑侠客初次入世登记
     */
    function registerPlayer() public {
        if (!profiles[msg.sender].isRegistered) {
            profiles[msg.sender] = PlayerProfile({
                level: 1,
                totalExp: 0,
                maxChapterUnlocked: 1,
                totalDamageDealt: 0,
                totalMonstersKilled: 0,
                totalSkillsCast: 0,
                isRegistered: true
            });
            emit PlayerRegistered(msg.sender, block.timestamp);
        }
    }

    /**
     * @notice 核心创新：多章节打怪与技能数据合并上链清算 (Session Batch Settlement)
     * @dev 一笔交易同时完成：数据校验 + 经验等级跃升 + 解锁新章节 + 铸造专属神兵 NFT
     */
    function settleChapter(ChapterSummary calldata summary) external returns (uint256 mintedTokenId) {
        PlayerProfile storage prof = profiles[msg.sender];
        if (!prof.isRegistered) {
            registerPlayer();
        }

        // 关卡准入与章节解锁核验
        if (summary.chapterId > prof.maxChapterUnlocked) {
            revert ChapterLocked();
        }

        // 防作弊数据合理性边界核验
        uint32 minExpectedDamage = uint32(summary.monstersSlain) * 40;
        if (summary.monstersSlain == 0 || summary.totalDamage < minExpectedDamage) {
            revert InvalidProof();
        }

        // 1. 批量合并角色全局成长数据 (单笔原子写入，极省 Gas)
        uint32 expGain = uint32(summary.monstersSlain) * 50 + uint32(summary.skillsUsed) * 15 + (summary.chapterId * 100);
        if (summary.bossDefeated) expGain += 200;

        prof.totalExp += expGain;
        prof.totalDamageDealt += summary.totalDamage;
        prof.totalMonstersKilled += summary.monstersSlain;
        prof.totalSkillsCast += summary.skillsUsed;
        prof.level = uint16(1 + (prof.totalExp / 250));

        // 解锁后续章节 (上限暂开放至第 3 章)
        if (summary.chapterId >= prof.maxChapterUnlocked && prof.maxChapterUnlocked < 3) {
            prof.maxChapterUnlocked = summary.chapterId + 1;
        }

        // 2. 铸造当前章节专属掉落神兵 NFT
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
     * @notice 装备穿戴功能：将所持有的 NFT 穿戴至对应槽位
     * @param tokenId 装备的 NFT TokenId
     * @param slot 槽位编号 (0: 武器, 1: 宝甲, 2: 法宝)
     */
    function equipItem(uint256 tokenId, uint8 slot) external {
        if (ownerOf[tokenId] != msg.sender) revert NotTokenOwner();
        if (slot > 2) revert SlotMismatch();

        ChapterLootNFT storage loot = nftDetails[tokenId];
        if (loot.itemType != slot) revert SlotMismatch();

        equippedTokens[msg.sender][slot] = tokenId;
        emit ItemEquipped(msg.sender, slot, tokenId, loot.name, loot.combatPower);
    }

    /**
     * @notice 卸下对应槽位的装备
     * @param slot 槽位编号 (0: 武器, 1: 宝甲, 2: 法宝)
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
     * @notice 查阅玩家当前 3 个槽位的穿戴详情与总战力加成
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

    /**
     * @dev 章节专属神兵掉落奖池
     */
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
            // 第一章：东海湾沉船掉落
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
            // 第二章：江南野外伏魔掉落
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
            // 第三章：大唐大雁塔决战掉落 (最高品阶)
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

    /**
     * @notice 查阅玩家持有的全量通关神兵 NFT
     */
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
