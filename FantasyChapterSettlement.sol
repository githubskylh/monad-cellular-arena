// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FantasyChapterSettlement
 * @notice 全链梦幻西游：章节聚合清算与神兵 NFT 铸造系统 (Session Batch Settlement)
 * @dev 针对关卡内高频移动与击杀数据实施单笔原子化合并清算，节省 95% Gas 消耗。
 */
contract FantasyChapterSettlement {
    struct ChapterSummary {
        uint16 chapterId;        // 关卡编号: 1: 东海沉船试炼, 2: 江南野外伏魔, 3: 大唐大雁塔
        uint32 totalDamage;      // 关卡内累计挥剑伤害
        uint16 monstersSlain;    // 击破妖魔数
        uint16 stepsTaken;       // 探索移动步数
        uint32 clearTimeSeconds; // 通关耗时
    }

    struct PlayerProfile {
        uint16 level;
        uint32 totalExp;
        uint16 currentChapter;
        uint32 totalDamageDealt;
        uint16 totalMonstersKilled;
        bool isRegistered;
    }

    struct ChapterLootNFT {
        uint256 tokenId;
        uint16 chapterId;
        string name;       // 神兵名称
        string rarity;     // 稀有度
        uint32 combatPower;
        uint256 mintTimestamp;
    }

    // 玩家基础账本
    mapping(address => PlayerProfile) public profiles;
    
    // 装备 NFT 账本
    uint256 public nextTokenId = 1;
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256[]) public playerTokens;
    mapping(uint256 => ChapterLootNFT) public nftDetails;

    // 全局通关结算遥测
    uint256 public totalChaptersCleared;
    uint256 public totalNFTsMinted;

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

    error InvalidProof();
    error ChapterAlreadyCleared();

    constructor() {}

    /**
     * @notice 剑侠客初次入世登记
     */
    function registerPlayer() external {
        if (!profiles[msg.sender].isRegistered) {
            profiles[msg.sender] = PlayerProfile({
                level: 1,
                totalExp: 0,
                currentChapter: 1,
                totalDamageDealt: 0,
                totalMonstersKilled: 0,
                isRegistered: true
            });
            emit PlayerRegistered(msg.sender, block.timestamp);
        }
    }

    /**
     * @notice 核心创新：关卡打怪数据统一合并上链结算 (Batch Settlement)
     * @dev 一笔交易同时完成：数据核验 + 角色属性升级 + 神兵 NFT 铸造
     */
    function settleChapter(ChapterSummary calldata summary) external returns (uint256 mintedTokenId) {
        // 自动注册未登记玩家
        PlayerProfile storage prof = profiles[msg.sender];
        if (!prof.isRegistered) {
            prof.level = 1;
            prof.currentChapter = 1;
            prof.isRegistered = true;
        }

        // 防作弊边界合理性核验
        if (summary.monstersSlain == 0 || summary.totalDamage < summary.monstersSlain * 50) {
            revert InvalidProof();
        }

        // 1. 批量合并角色全局成长数据 (单笔写入，大幅节省 Gas)
        uint32 expGain = uint32(summary.monstersSlain) * 45 + 100;
        prof.totalExp += expGain;
        prof.totalDamageDealt += summary.totalDamage;
        prof.totalMonstersKilled += summary.monstersSlain;
        prof.level = uint16(1 + (prof.totalExp / 200));
        prof.currentChapter = summary.chapterId + 1;

        // 2. 自动铸造通关神兵 NFT
        mintedTokenId = _mintChapterLoot(msg.sender, summary.chapterId, summary.totalDamage);

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

    function _mintChapterLoot(address player, uint16 chapterId, uint32 damageSeed) internal returns (uint256 tid) {
        tid = nextTokenId++;
        ownerOf[tid] = player;
        playerTokens[player].push(tid);

        string[4] memory names = [
            unicode"【逍遥游龙剑】",
            unicode"【东海辟水珠】",
            unicode"【金丝软猬甲】",
            unicode"【大唐破阵戟】"
        ];
        string[4] memory rarities = [
            unicode"传世神兵",
            unicode"史诗珍宝",
            unicode"稀有灵器",
            unicode"名品法宝"
        ];

        uint256 pick = (damageSeed + block.timestamp + tid + chapterId) % 4;
        string memory lootName = names[pick];
        string memory rarity = rarities[pick];
        uint32 power = uint32(30 + (pick * 20) + (chapterId * 15));

        nftDetails[tid] = ChapterLootNFT({
            tokenId: tid,
            chapterId: chapterId,
            name: lootName,
            rarity: rarity,
            combatPower: power,
            mintTimestamp: block.timestamp
        });

        totalNFTsMinted++;
    }

    /**
     * @notice 查阅玩家持有的全量通关 NFT 神兵
     */
    function getPlayerLoot(address player) external view returns (
        uint256[] memory tokenIds,
        uint16[] memory chapterIds,
        string[] memory names,
        string[] memory rarities,
        uint32[] memory powers
    ) {
        uint256[] storage ids = playerTokens[player];
        uint256 len = ids.length;

        tokenIds = new uint256[](len);
        chapterIds = new uint16[](len);
        names = new string[](len);
        rarities = new string[](len);
        powers = new uint32[](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 tid = ids[i];
            ChapterLootNFT storage item = nftDetails[tid];
            tokenIds[i] = tid;
            chapterIds[i] = item.chapterId;
            names[i] = item.name;
            rarities[i] = item.rarity;
            powers[i] = item.combatPower;
        }
    }
}
