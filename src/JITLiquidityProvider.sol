// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title JITLiquidityProvider
 * @notice Just-In-Time Liquidity Provider for Uniswap V3
 * @dev Provides concentrated liquidity right before large swaps to capture fees
 */
contract JITLiquidityProvider is IUniswapV3MintCallback, Ownable {
    
    // ============ Structs ============
    
    struct Position {
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 feesEarned0;
        uint256 feesEarned1;
        uint256 timestamp;
    }
    
    struct SwapParams {
        address pool;
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }
    
    // ============ State Variables ============
    
    // Mapping from pool address to position
    mapping(address => Position) public positions;
    
    // Minimum swap size to trigger JIT (in USD value or token amount)
    uint256 public minSwapSize;
    
    // Tick spacing for different fee tiers
    mapping(address => int24) public poolTickSpacing;
    
    // Total fees earned per token
    uint256 public totalFeesEarned0;
    uint256 public totalFeesEarned1;
    
    // Events
    event LiquidityAdded(
        address indexed pool,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    );
    
    event LiquidityRemoved(
        address indexed pool,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    
    event FeesCollected(
        address indexed pool,
        uint256 fees0,
        uint256 fees1
    );
    
    event SwapExecuted(
        address indexed pool,
        bool zeroForOne,
        int256 amountSpecified,
        int256 amount0,
        int256 amount1
    );
    
    // ============ Constructor ============
    
    constructor(uint256 _minSwapSize) Ownable(msg.sender) {
        minSwapSize = _minSwapSize;
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Add JIT liquidity to a pool in a concentrated range
     * @param pool The Uniswap V3 pool address
     * @param tickLower The lower tick of the position
     * @param tickUpper The upper tick of the position
     * @param amount0Desired Desired amount of token0
     * @param amount1Desired Desired amount of token1
     */
    function addJITLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external onlyOwner returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        return _addJITLiquidity(pool, tickLower, tickUpper, amount0Desired, amount1Desired);
    }
    
    /**
     * @notice Internal function to add JIT liquidity
     */
    function _addJITLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        IUniswapV3Pool v3Pool = IUniswapV3Pool(pool);
        
        // Get current pool state
        (uint160 sqrtPriceX96, , , , , , ) = v3Pool.slot0();
        
        // Convert ticks to sqrtPrice values using Uniswap's TickMath library
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        
        // Calculate optimal liquidity using Uniswap's LiquidityAmounts library
        // This uses the PROPER Uniswap V3 formulas:
        // - For token0: L = amount0 * (sqrtP_upper * sqrtP_lower) / (sqrtP_upper - sqrtP_lower)
        // - For token1: L = amount1 / (sqrtP_upper - sqrtP_lower)
        // - Takes the minimum of both to ensure we don't exceed available tokens
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            amount0Desired,
            amount1Desired
        );
        
        require(liquidity > 0, "Liquidity must be > 0");
        
        // Mint liquidity - this will callback to uniswapV3MintCallback
        (amount0, amount1) = v3Pool.mint(
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(pool)
        );
        
        // Store position
        positions[pool] = Position({
            liquidity: liquidity,
            tickLower: tickLower,
            tickUpper: tickUpper,
            token0Amount: amount0,
            token1Amount: amount1,
            feesEarned0: 0,
            feesEarned1: 0,
            timestamp: block.timestamp
        });
        
        emit LiquidityAdded(pool, liquidity, tickLower, tickUpper, amount0, amount1);
    }
    
    // ============ Position Management Functions ============
    
    /**
     * @notice Remove JIT liquidity from a pool
     * @param pool The Uniswap V3 pool address
     */
    function removeJITLiquidity(address pool) external onlyOwner returns (uint256 amount0, uint256 amount1) {
        Position storage position = positions[pool];
        require(position.liquidity > 0, "No position exists");
        
        IUniswapV3Pool v3Pool = IUniswapV3Pool(pool);
        
        // Burn liquidity
        (amount0, amount1) = v3Pool.burn(
            position.tickLower,
            position.tickUpper,
            position.liquidity
        );
        
        // Collect tokens and fees
        (uint256 collected0, uint256 collected1) = v3Pool.collect(
            address(this),
            position.tickLower,
            position.tickUpper,
            uint128(amount0),
            uint128(amount1)
        );
        
        // Calculate fees (collected - original amounts)
        uint256 fees0 = collected0 > amount0 ? collected0 - amount0 : 0;
        uint256 fees1 = collected1 > amount1 ? collected1 - amount1 : 0;
        
        // Update tracking
        totalFeesEarned0 += fees0;
        totalFeesEarned1 += fees1;
        
        emit LiquidityRemoved(pool, position.liquidity, amount0, amount1);
        emit FeesCollected(pool, fees0, fees1);
        
        // Clear position
        delete positions[pool];
        
        return (collected0, collected1);
    }
    
    /**
     * @notice Add liquidity and execute swap in one transaction
     * @param pool The pool address
     * @param tickLower Lower tick
     * @param tickUpper Upper tick
     * @param amount0Desired Token0 amount for liquidity
     * @param amount1Desired Token1 amount for liquidity
     * @param swapParams Parameters for the swap
     */
    function addLiquidityAndSwap(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired,
        SwapParams calldata swapParams
    ) external onlyOwner returns (int256 amount0, int256 amount1) {
        // First, add JIT liquidity
        _addJITLiquidity(pool, tickLower, tickUpper, amount0Desired, amount1Desired);
        
        // Then execute the swap
        IUniswapV3Pool v3Pool = IUniswapV3Pool(pool);
        (amount0, amount1) = v3Pool.swap(
            address(this),
            swapParams.zeroForOne,
            swapParams.amountSpecified,
            swapParams.sqrtPriceLimitX96,
            ""
        );
        
        emit SwapExecuted(pool, swapParams.zeroForOne, swapParams.amountSpecified, amount0, amount1);
        
        return (amount0, amount1);
    }
    
    /**
     * @notice Calculate optimal tick range around current price
     * @param pool The pool address
     * @param tickRange The number of ticks on each side
     */
    function calculateOptimalRange(address pool, int24 tickRange) 
        public 
        view 
        returns (int24 tickLower, int24 tickUpper) 
    {
        IUniswapV3Pool v3Pool = IUniswapV3Pool(pool);
        (, int24 currentTick, , , , , ) = v3Pool.slot0();
        
        int24 tickSpacing = v3Pool.tickSpacing();
        
        // Round to nearest tick spacing
        int24 roundedTick = (currentTick / tickSpacing) * tickSpacing;
        
        tickLower = roundedTick - (tickRange * tickSpacing);
        tickUpper = roundedTick + (tickRange * tickSpacing);
        
        return (tickLower, tickUpper);
    }
    
    // ============ Callback Functions ============
    
    /**
     * @notice Uniswap V3 callback for minting liquidity
     */
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        address pool = abi.decode(data, (address));
        
        IUniswapV3Pool v3Pool = IUniswapV3Pool(pool);
        
        // Transfer tokens to pool
        if (amount0Owed > 0) {
            IERC20(v3Pool.token0()).transfer(msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            IERC20(v3Pool.token1()).transfer(msg.sender, amount1Owed);
        }
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update minimum swap size threshold
     */
    function setMinSwapSize(uint256 _minSwapSize) external onlyOwner {
        minSwapSize = _minSwapSize;
    }
    
    /**
     * @notice Withdraw tokens from contract
     */
    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
    
    /**
     * @notice Emergency withdraw all tokens
     */
    function emergencyWithdraw(address token0, address token1) external onlyOwner {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        
        if (balance0 > 0) {
            IERC20(token0).transfer(owner(), balance0);
        }
        if (balance1 > 0) {
            IERC20(token1).transfer(owner(), balance1);
        }
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get position details for a pool
     */
    function getPosition(address pool) external view returns (Position memory) {
        return positions[pool];
    }
    
    /**
     * @notice Get current pool price
     */
    function getCurrentPrice(address pool) external view returns (uint160 sqrtPriceX96, int24 tick) {
        IUniswapV3Pool v3Pool = IUniswapV3Pool(pool);
        (sqrtPriceX96, tick, , , , , ) = v3Pool.slot0();
        return (sqrtPriceX96, tick);
    }
}
