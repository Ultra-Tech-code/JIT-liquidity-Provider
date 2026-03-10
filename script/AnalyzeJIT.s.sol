// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/JITLiquidityProvider.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/**
 * @title AnalyzeJIT
 * @notice Analyzes historical swap data to calculate theoretical JIT profits
 * @dev Queries Uniswap pool events and simulates what JIT positions would have earned
 */
contract AnalyzeJIT is Script {
    
    address constant WETH_USDC_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    JITLiquidityProvider public jitContract;
    IUniswapV3Pool public pool;
    
    struct SwapData {
        uint256 blockNumber;
        int256 amount0;
        int256 amount1;
        uint160 sqrtPriceX96;
        uint128 liquidity;
        int24 tick;
        uint256 usdValue;
    }
    
    function setUp() public {
        jitContract = JITLiquidityProvider(vm.envAddress("JIT_CONTRACT_ADDRESS"));
        pool = IUniswapV3Pool(WETH_USDC_POOL);
    }
    
    function run() public view {
        console.log("=== JIT Liquidity Analysis Tool ===");
        console.log("Pool:", WETH_USDC_POOL);
        console.log("");
        
        // Get current pool state
        (uint160 sqrtPriceX96, int24 currentTick,,,,,) = pool.slot0();
        uint128 liquidity = pool.liquidity();
        
        console.log("Current Pool State:");
        console.log("- Current Tick:", vm.toString(currentTick));
        console.log("- Total Liquidity:", liquidity);
        console.log("- Sqrt Price X96:", sqrtPriceX96);
        console.log("");
        
        // Calculate theoretical swap analysis
        console.log("=== Theoretical JIT Analysis ===");
        console.log("");
        
        // Simulate different swap sizes
        uint256[] memory swapSizes = new uint256[](5);
        swapSizes[0] = 1 ether;      // 1 WETH
        swapSizes[1] = 10 ether;     // 10 WETH  
        swapSizes[2] = 50 ether;     // 50 WETH
        swapSizes[3] = 100 ether;    // 100 WETH
        swapSizes[4] = 500 ether;    // 500 WETH
        
        for (uint256 i = 0; i < swapSizes.length; i++) {
            analyzeTheoreticalSwap(swapSizes[i], currentTick, liquidity);
        }
        
        // Check our current position
        console.log("");
        console.log("=== Our Active Position ===");
        JITLiquidityProvider.Position memory pos = jitContract.getPosition(WETH_USDC_POOL);
        
        if (pos.liquidity > 0) {
            console.log("Active Position Found:");
            console.log("- Liquidity:", pos.liquidity);
            console.log("- Tick Range:", vm.toString(pos.tickLower), "to", vm.toString(pos.tickUpper));
            console.log("- Token0 Amount:", pos.token0Amount);
            console.log("- Token1 Amount:", pos.token1Amount);
            console.log("- Fees Earned (Token0):", pos.feesEarned0);
            console.log("- Fees Earned (Token1):", pos.feesEarned1);
            console.log("- Timestamp:", pos.timestamp);
            
            // Check if position is in range
            if (currentTick >= pos.tickLower && currentTick <= pos.tickUpper) {
                console.log("- Status: IN RANGE (actively earning fees)");
            } else {
                console.log("- Status: OUT OF RANGE (not earning fees)");
            }
        } else {
            console.log("No active position found");
        }
        
        console.log("");
        console.log("=== Fee Tracking ===");
        console.log("Total Fees Earned (Token0/USDC):", jitContract.totalFeesEarned0());
        console.log("Total Fees Earned (Token1/WETH):", jitContract.totalFeesEarned1());
    }
    
    function analyzeTheoreticalSwap(
        uint256 swapAmount,
        int24 currentTick,
        uint128 poolLiquidity
    ) internal pure {
        console.log("--- Swap Size: %s WETH ---", swapAmount / 1e18);
        
        // Estimate fees (0.05% fee tier)
        uint256 estimatedFees = (swapAmount * 500) / 1_000_000; // 0.05% = 500/1000000
        
        console.log("Estimated fees from swap: %s WETH", estimatedFees / 1e15, "milli");
        
        // Calculate optimal JIT strategy
        // For max fee capture, we want to provide significant portion of liquidity
        // Let's say we target 20% of pool liquidity
        uint256 targetLiquidityShare = 20; // 20%
        uint128 ourLiquidity = (poolLiquidity * uint128(targetLiquidityShare)) / 100;
        
        // Our share of fees
        uint256 ourFees = (estimatedFees * targetLiquidityShare) / 100;
        
        console.log("If we provide %s%% of liquidity:", targetLiquidityShare);
        console.log("- Our liquidity needed: ~%s", ourLiquidity);
        console.log("- Our estimated fee capture: %s WETH", ourFees / 1e15, "milli");
        
        // Calculate tick range (±100 ticks around current for concentrated position)
        int24 tickLower = currentTick - 100;
        int24 tickUpper = currentTick + 100;
        console.log("- Optimal tick range: %s to %s", vm.toString(tickLower), vm.toString(tickUpper));
        console.log("");
    }
}
