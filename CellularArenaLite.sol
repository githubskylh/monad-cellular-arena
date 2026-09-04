// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CellularArenaLite
 * @notice High-concurrency on-chain cellular survival benchmark designed for Monad Parallel EVM.
 * @dev Spatial slots are decoupled into distinct storage keys (gridKey) to maximize Monad's OCC parallel throughput.
 */
contract CellularArenaLite {
    uint16 public constant GRID_SIZE = 50; // 50x50 grid = 2500 independent spatial slots

    struct Cell {
        uint16 x;
        uint16 y;
        uint32 score;
        bool alive;
    }

    // Grid mapping: gridKey(x, y) => occupant player address.
    // Under Monad's Parallel EVM, disjoint keys incur zero lock contention and execute concurrently!
    mapping(uint256 => address) public grid;
    
    // Player cell state mapping: player address => Cell state
    mapping(address => Cell) public cells;

    // Telemetry & Benchmark counters for live Hackathon HUD
    uint256 public totalMoves;
    uint256 public totalDevours;
    uint256 public totalSpawns;

    // Global registry for frontend live polling
    address[] public playerList;
    mapping(address => bool) private hasRegistered;

    event Spawned(address indexed player, uint16 x, uint16 y, uint256 timestamp);
    event Moved(address indexed player, uint16 fromX, uint16 fromY, uint16 toX, uint16 toY, bool devoured, uint256 blockNum);
    event Devoured(address indexed predator, address indexed prey, uint16 x, uint16 y, uint32 newScore);

    error OutOfBounds();
    error CellAlreadyAlive();
    error CellNotAlive();
    error SlotOccupied();
    error InvalidMoveDistance();
    error CannotEatSelf();

    function gridKey(uint16 x, uint16 y) public pure returns (uint256) {
        return (uint256(x) << 16) | uint256(y);
    }

    /**
     * @notice Spawn a cell at designated coordinates
     */
    function spawn(uint16 x, uint16 y) external {
        if (x >= GRID_SIZE || y >= GRID_SIZE) revert OutOfBounds();
        if (cells[msg.sender].alive) revert CellAlreadyAlive();

        uint256 key = gridKey(x, y);
        if (grid[key] != address(0)) revert SlotOccupied();

        grid[key] = msg.sender;
        cells[msg.sender] = Cell({
            x: x,
            y: y,
            score: 10,
            alive: true
        });

        if (!hasRegistered[msg.sender]) {
            playerList.push(msg.sender);
            hasRegistered[msg.sender] = true;
        }

        totalSpawns++;
        emit Spawned(msg.sender, x, y, block.timestamp);
    }

    /**
     * @notice Move cell 1 step (up, down, left, right, or diagonal)
     * @param toX Destination X (0..49)
     * @param toY Destination Y (0..49)
     */
    function move(uint16 toX, uint16 toY) external {
        Cell storage cell = cells[msg.sender];
        if (!cell.alive) revert CellNotAlive();
        if (toX >= GRID_SIZE || toY >= GRID_SIZE) revert OutOfBounds();

        uint16 fromX = cell.x;
        uint16 fromY = cell.y;

        // Verify distance is exactly 1 step (Chebyshev distance)
        uint16 dx = toX > fromX ? toX - fromX : fromX - toX;
        uint16 dy = toY > fromY ? toY - fromY : fromY - toY;
        if ((dx == 0 && dy == 0) || dx > 1 || dy > 1) revert InvalidMoveDistance();

        uint256 oldKey = gridKey(fromX, fromY);
        uint256 newKey = gridKey(toX, toY);

        address occupant = grid[newKey];
        bool devoured = false;

        if (occupant != address(0)) {
            if (occupant == msg.sender) revert CannotEatSelf();
            
            // Devour prey
            Cell storage prey = cells[occupant];
            prey.alive = false;
            uint32 preyScore = prey.score;
            prey.score = 0;

            cell.score += (preyScore > 0 ? preyScore : 10);
            totalDevours++;
            devoured = true;
            emit Devoured(msg.sender, occupant, toX, toY, cell.score);
        }

        // Parallel storage update:
        // Updating oldKey and newKey touches distinct slots from other players in different grid locations
        grid[oldKey] = address(0);
        grid[newKey] = msg.sender;
        cell.x = toX;
        cell.y = toY;
        totalMoves++;

        emit Moved(msg.sender, fromX, fromY, toX, toY, devoured, block.number);
    }

    /**
     * @notice Batch fetch all active players and their coordinates for lightweight frontend polling
     */
    function getActivePlayers() external view returns (
        address[] memory activeAddrs,
        uint16[] memory xs,
        uint16[] memory ys,
        uint32[] memory scores
    ) {
        uint256 count = 0;
        for (uint256 i = 0; i < playerList.length; i++) {
            if (cells[playerList[i]].alive) {
                count++;
            }
        }

        activeAddrs = new address[](count);
        xs = new uint16[](count);
        ys = new uint16[](count);
        scores = new uint32[](count);

        uint256 idx = 0;
        for (uint256 i = 0; i < playerList.length; i++) {
            address p = playerList[i];
            if (cells[p].alive) {
                activeAddrs[idx] = p;
                xs[idx] = cells[p].x;
                ys[idx] = cells[p].y;
                scores[idx] = cells[p].score;
                idx++;
            }
        }
    }
}
