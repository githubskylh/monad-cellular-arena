// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FantasyWestwardMonad
 * @notice 全链梦幻西游：东海湾微观演化与自动化装备 NFT 铸造系统
 * @dev Designed for Monad Parallel EVM. Records every hit of combat damage, settles loot, and auto-mints on-chain NFTs.
 */
contract FantasyWestwardMonad {
    // 经典西游角色与地图常量
    uint16 public constant MAP_WIDTH = 30;
    uint16 public constant MAP_HEIGHT = 30;

    struct Player {
        uint16 x;
        uint16 y;
        uint32 hp;
        uint32 maxHp;
        uint32 attack;
        uint32 exp;
        uint16 level;
        bool isAlive;
    }

    struct Monster {
        uint256 id;
        string name; // "大海龟", "巨蛙", "野猪", "强盗"
        uint16 x;
        uint16 y;
        uint32 hp;
        uint32 maxHp;
        uint32 attack;
        bool isAlive;
    }

    struct LootNFT {
        uint256 tokenId;
        string name;       // e.g. "逍遥游龙剑", "避水定海珠", "乾坤护腕", "九转金丹"
        string rarity;     // "普通", "稀有", "史诗", "传世神兵"
        uint32 powerBonus;
        uint256 mintTimestamp;
    }

    // 状态映射
    mapping(address => Player) public players;
    mapping(uint256 => Monster) public monsters;
    mapping(uint256 => bool) public isObstacle; // 树木与巨石碰撞阻挡: key = (x << 16) | y

    // 装备 NFT 账本 (轻量化嵌入式 ERC721 机制)
    uint256 public nextTokenId = 1;
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256[]) public playerTokens;
    mapping(uint256 => LootNFT) public nftDetails;

    // 全局遥测计数
    uint256 public totalStrikes;
    uint256 public totalMonstersDefeated;
    uint256 public totalNFTsMinted;

    // 经典事件
    event PlayerSpawned(address indexed player, uint16 x, uint16 y, string characterName);
    event PlayerMoved(address indexed player, uint16 fromX, uint16 fromY, uint16 toX, uint16 toY);
    event StrikeDealt(address indexed player, uint256 indexed monsterId, uint32 damage, uint32 remainingHp, uint256 blockNum);
    event MonsterDefeated(address indexed player, uint256 indexed monsterId, string monsterName, uint32 expGained);
    event LootNFTMinted(address indexed player, uint256 indexed tokenId, string lootName, string rarity, uint32 powerBonus);

    constructor() {
        // 初始化经典阻挡物 (东海湾顽石与古桃树坐标)
        _setObstacle(5, 5);
        _setObstacle(5, 6);
        _setObstacle(12, 10);
        _setObstacle(12, 11);
        _setObstacle(18, 15);
        _setObstacle(20, 20);
        _setObstacle(20, 21);
        _setObstacle(8, 22);
        _setObstacle(25, 8);
    }

    function _setObstacle(uint16 x, uint16 y) internal {
        isObstacle[(uint256(x) << 16) | y] = true;
    }

    function coordKey(uint16 x, uint16 y) public pure returns (uint256) {
        return (uint256(x) << 16) | uint256(y);
    }

    /**
     * @notice 剑侠客降生进入东海湾
     */
    function enterWorld(uint16 x, uint16 y) external {
        require(x < MAP_WIDTH && y < MAP_HEIGHT, "Out of bounds");
        require(!isObstacle[coordKey(x, y)], "Collision with rock/tree");

        players[msg.sender] = Player({
            x: x,
            y: y,
            hp: 250,
            maxHp: 250,
            attack: 45,
            exp: 0,
            level: 1,
            isAlive: true
        });

        emit PlayerSpawned(msg.sender, x, y, unicode"剑侠客");
    }

    /**
     * @notice 剑侠客移动与障碍碰撞仲裁
     */
    function move(uint16 toX, uint16 toY) external {
        Player storage p = players[msg.sender];
        require(p.isAlive, "Player not alive");
        require(toX < MAP_WIDTH && toY < MAP_HEIGHT, "Out of bounds");
        require(!isObstacle[coordKey(toX, toY)], "Blocked by mountain/tree");

        uint16 fromX = p.x;
        uint16 fromY = p.y;
        p.x = toX;
        p.y = toY;

        emit PlayerMoved(msg.sender, fromX, fromY, toX, toY);
    }

    /**
     * @notice 每一笔战斗挥剑伤害实时上链
     */
    function attackMonster(uint256 monsterId, uint32 damage) external returns (bool defeated) {
        Player storage p = players[msg.sender];
        require(p.isAlive, "Player not alive");

        totalStrikes++;

        Monster storage m = monsters[monsterId];
        if (m.maxHp == 0) {
            m.id = monsterId;
            m.name = monsterId % 2 == 0 ? unicode"东海大海龟" : unicode"珊瑚巨蛙";
            m.maxHp = 120;
            m.hp = 120;
            m.isAlive = true;
        }

        if (damage >= m.hp) {
            m.hp = 0;
            m.isAlive = false;
            defeated = true;
            emit StrikeDealt(msg.sender, monsterId, damage, 0, block.number);
            _resolveVictory(msg.sender, monsterId, m.name);
        } else {
            m.hp -= damage;
            defeated = false;
            emit StrikeDealt(msg.sender, monsterId, damage, m.hp, block.number);
        }
    }

    /**
     * @notice 战斗胜利结算与自动 NFT 铸造
     */
    function _resolveVictory(address player, uint256 monsterId, string memory monsterName) internal {
        Player storage p = players[player];
        uint32 expGained = 35;
        p.exp += expGained;
        totalMonstersDefeated++;

        emit MonsterDefeated(player, monsterId, monsterName, expGained);

        _mintLootNFT(player, monsterId);
    }

    function _mintLootNFT(address player, uint256 seed) internal {
        uint256 tid = nextTokenId++;
        ownerOf[tid] = player;
        playerTokens[player].push(tid);

        string[4] memory itemNames = [unicode"【逍遥游龙剑】", unicode"【东海定海珠】", unicode"【金丝软猬甲】", unicode"【九转乾坤履】"];
        string[4] memory rarities = [unicode"传世神兵", unicode"史诗珍宝", unicode"稀有灵器", unicode"名品法宝"];
        
        uint256 pick = (seed + block.timestamp + tid) % 4;
        string memory lootName = itemNames[pick];
        string memory rarity = rarities[pick];
        uint32 bonus = uint32(20 + (pick * 15));

        nftDetails[tid] = LootNFT({
            tokenId: tid,
            name: lootName,
            rarity: rarity,
            powerBonus: bonus,
            mintTimestamp: block.timestamp
        });

        totalNFTsMinted++;
        emit LootNFTMinted(player, tid, lootName, rarity, bonus);
    }

    /**
     * @notice 查阅玩家的藏宝阁 NFT 战利品背包
     */
    function getPlayerLoot(address player) external view returns (
        uint256[] memory tokenIds,
        string[] memory names,
        string[] memory rarities,
        uint32[] memory bonuses
    ) {
        uint256[] storage ids = playerTokens[player];
        uint256 len = ids.length;

        tokenIds = new uint256[](len);
        names = new string[](len);
        rarities = new string[](len);
        bonuses = new uint32[](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 tid = ids[i];
            LootNFT storage item = nftDetails[tid];
            tokenIds[i] = tid;
            names[i] = item.name;
            rarities[i] = item.rarity;
            bonuses[i] = item.powerBonus;
        }
    }
}
