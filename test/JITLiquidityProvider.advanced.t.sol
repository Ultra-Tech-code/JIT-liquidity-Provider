// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/JITLiquidityProvider.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./helpers/SwapHelper.sol";

/**
 * @title JITLiquidityProvider Advanced Integration Tests
 * @notice Advanced tests covering edge cases, fee accumulation, and realistic scenarios
 */
contract JITLiquidityProviderAdvancedTest is Test {
    
    JITLiquidityProvider public jitProvider;
    SwapHelper public swapHelper;
    
    // Mainnet addresses for forking
    address constant WETH_USDC_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    address owner = address(this);
    address trader1 = address(0x1234);
    address trader2 = address(0x5678);
    
    function setUp() public {
        // Fork mainnet
        string memory alchemyKey = vm.envOr("ALCHEMY_API_KEY", string("demo"));
        string memory rpcUrl = string.concat("https://eth-mainnet.g.alchemy.com/v2/", alchemyKey);
        vm.createSelectFork(rpcUrl);
        
        // Deploy contracts
        jitProvider = new JITLiquidityProvider(1 ether);
        swapHelper = new SwapHelper();
        
        // Fund the contract with both tokens
        deal(USDC, address(jitProvider), 300000 * 1e6);
        deal(WETH, address(jitProvider), 100 ether);
        
        // Fund traders
        deal(WETH, trader1, 100 ether);
        deal(USDC, trader1, 300000 * 1e6);
        deal(WETH, trader2, 100 ether);
        deal(USDC, trader2, 300000 * 1e6);
    }
    
    // ============ Fee Accumulation Tests ============
    
    /**
     * @notice Test that fees accumulate correctly over multiple swaps
     */
    function testFeeAccumulationMultipleSwaps() public {
        console.log("=== Fee Accumulation Test ===");
        
        // Add JIT liquidity
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 10);
        (uint128 liquidity, uint256 amount0Used, uint256 amount1Used) = jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            1 ether,
            3000 * 1e6
        );
        
        console.log("Initial liquidity:", liquidity);
        console.log("WETH used:", amount0Used);
        console.log("USDC used:", amount1Used);
        
        // Record initial balances
        JITLiquidityProvider.Position memory positionBefore = jitProvider.getPosition(WETH_USDC_POOL);
        
        // Execute multiple swaps through the pool
        
        // Swap 1: Buy WETH with USDC
        vm.startPrank(trader1);
        IERC20(USDC).approve(address(swapHelper), type(uint256).max);
        swapHelper.executeSwap(
            WETH_USDC_POOL,
            false, // USDC for WETH
            int256(1000 * 1e6), // 1000 USDC
            1461446703485210103287273052203988822378723970341 // MAX_SQRT_RATIO - 1
        );
        vm.stopPrank();
        
        // Swap 2: Sell WETH for USDC
        vm.startPrank(trader2);
        IERC20(WETH).approve(address(swapHelper), type(uint256).max);
        swapHelper.executeSwap(
            WETH_USDC_POOL,
            true, // WETH for USDC
            int256(0.3 ether),
            4295128740 // MIN_SQRT_RATIO + 1
        );
        vm.stopPrank();
        
        // Swap 3: Buy WETH again
        vm.startPrank(trader1);
        swapHelper.executeSwap(
            WETH_USDC_POOL,
            false,
            int256(500 * 1e6),
            1461446703485210103287273052203988822378723970341
        );
        vm.stopPrank();
        
        // Remove liquidity and check fees
        (uint256 collected0, uint256 collected1) = jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        uint256 totalFees0 = jitProvider.totalFeesEarned0();
        uint256 totalFees1 = jitProvider.totalFeesEarned1();
        
        console.log("Tokens collected WETH:", collected0);
        console.log("Tokens collected USDC:", collected1);
        console.log("Fees earned WETH:", totalFees0);
        console.log("Fees earned USDC:", totalFees1);
        
        // Fees should be earned from swaps
        assertTrue(totalFees0 > 0 || totalFees1 > 0, "Should earn fees from swaps");
        assertTrue(collected0 >= amount0Used || collected1 >= amount1Used, "Should collect at least deposited amount");
    }
    
    /**
     * @notice Test fee calculation accuracy
     */
    function testFeeCalculationAccuracy() public {
        console.log("=== Fee Calculation Accuracy Test ===");
        
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 5);
        (uint128 liquidity, uint256 amount0, uint256 amount1) = jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            2 ether,
            6000 * 1e6
        );
        
        // Make a large swap to generate significant fees
        vm.startPrank(trader1);
        IERC20(WETH).approve(address(swapHelper), type(uint256).max);
        
        // Swap 10 WETH - should generate substantial fees (0.05% = 0.005 WETH)
        swapHelper.executeSwap(
            WETH_USDC_POOL,
            true,
            int256(10 ether),
            4295128740
        );
        vm.stopPrank();
        
        // Remove position
        (uint256 collected0, uint256 collected1) = jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        uint256 fees0 = jitProvider.totalFeesEarned0();
        uint256 fees1 = jitProvider.totalFeesEarned1();
        
        console.log("Amount0 deposited:", amount0);
        console.log("Collected0:", collected0);
        console.log("Fees0:", fees0);
        console.log("Amount1 deposited:", amount1);
        console.log("Collected1:", collected1);
        console.log("Fees1:", fees1);
        
        // Verify fee calculation
        if (collected0 > amount0) {
            assertEq(fees0, collected0 - amount0, "Fee calculation should be accurate");
        }
        if (collected1 > amount1) {
            assertEq(fees1, collected1 - amount1, "Fee calculation should be accurate");
        }
    }
    
    // ============ Price Movement Tests ============
    
    /**
     * @notice Test position rebalancing after price movement
     */
    function testPositionAfterPriceMovement() public {
        console.log("=== Price Movement Test ===");
        
        // Get initial price
        (uint160 initialPrice, int24 initialTick) = jitProvider.getCurrentPrice(WETH_USDC_POOL);
        console.log("Initial tick:", initialTick);
        console.log("Initial sqrt price:", initialPrice);
        
        // Add liquidity
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 10);
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            1 ether,
            3000 * 1e6
        );
        
        // Execute large swap to move price
        vm.startPrank(trader1);
        IERC20(WETH).approve(address(swapHelper), type(uint256).max);
        
        // Large swap to move price significantly
        swapHelper.executeSwap(
            WETH_USDC_POOL,
            true,
            int256(50 ether), // Large swap
            4295128740
        );
        vm.stopPrank();
        
        // Check new price
        (uint160 newPrice, int24 newTick) = jitProvider.getCurrentPrice(WETH_USDC_POOL);
        console.log("New tick:", newTick);
        console.log("New sqrt price:", newPrice);
        console.log("Tick movement:", newTick - initialTick);
        
        // Price should have moved
        assertNotEq(newTick, initialTick, "Price should have moved");
        
        // Should still be able to remove liquidity
        (uint256 collected0, uint256 collected1) = jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        console.log("Collected WETH:", collected0);
        console.log("Collected USDC:", collected1);
        
        assertTrue(collected0 > 0 || collected1 > 0, "Should collect tokens after price movement");
    }
    
    /**
     * @notice Test adding liquidity at different tick ranges
     */
    function testMultipleTickRanges() public {
        console.log("=== Multiple Tick Ranges Test ===");
        
        // Add first position - wide range
        (int24 tick1Lower, int24 tick1Upper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 20);
        (uint128 liq1, ,) = jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tick1Lower,
            tick1Upper,
            1 ether,
            3000 * 1e6
        );
        console.log("Wide range liquidity:", liq1);
        console.log("Wide range tick lower:", tick1Lower);
        console.log("Wide range tick upper:", tick1Upper);
        
        // Remove and add narrow range
        jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        (int24 tick2Lower, int24 tick2Upper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 5);
        (uint128 liq2, ,) = jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tick2Lower,
            tick2Upper,
            1 ether,
            3000 * 1e6
        );
        console.log("Narrow range liquidity:", liq2);
        console.log("Narrow range tick lower:", tick2Lower);
        console.log("Narrow range tick upper:", tick2Upper);
        
        // Narrow range should create more liquidity for same amounts
        assertTrue(liq2 > liq1, "Narrow range should have higher liquidity");
        
        jitProvider.removeJITLiquidity(WETH_USDC_POOL);
    }
    
    // ============ Realistic Trading Scenarios ============
    
    /**
     * @notice Simulate JIT strategy: Add liquidity before large swap, remove after
     */
    function testJITStrategySimulation() public {
        console.log("=== JIT Strategy Simulation ===");
        
        uint256 contractWETHBefore = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 contractUSDCBefore = IERC20(USDC).balanceOf(address(jitProvider));
        
        console.log("Contract WETH before:", contractWETHBefore);
        console.log("Contract USDC before:", contractUSDCBefore);
        
        // Step 1: Detect incoming large swap (simulated - in reality would use mempool monitoring)
        uint256 incomingSwapSize = 20 ether;
        console.log("Detected incoming swap:", incomingSwapSize);
        
        // Step 2: Add JIT liquidity
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 10);
        (uint128 liquidity, uint256 amount0, uint256 amount1) = jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            3 ether,
            9000 * 1e6
        );
        console.log("JIT liquidity added:", liquidity);
        
        // Step 3: Large swap executes
        vm.startPrank(trader1);
        IERC20(WETH).approve(address(swapHelper), type(uint256).max);
        
        swapHelper.executeSwap(
            WETH_USDC_POOL,
            true,
            int256(incomingSwapSize),
            4295128740
        );
        vm.stopPrank();
        console.log("Large swap executed");
        
        // Step 4: Remove liquidity immediately to capture fees
        (uint256 collected0, uint256 collected1) = jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        uint256 contractWETHAfter = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 contractUSDCAfter = IERC20(USDC).balanceOf(address(jitProvider));
        
        console.log("Contract WETH after:", contractWETHAfter);
        console.log("Contract USDC after:", contractUSDCAfter);
        
        uint256 netProfitWETH = contractWETHAfter > contractWETHBefore ? contractWETHAfter - contractWETHBefore : 0;
        uint256 netProfitUSDC = contractUSDCAfter > contractUSDCBefore ? contractUSDCAfter - contractUSDCBefore : 0;
        
        console.log("Net profit WETH:", netProfitWETH);
        console.log("Net profit USDC:", netProfitUSDC);
        console.log("Fees earned WETH:", jitProvider.totalFeesEarned0());
        console.log("Fees earned USDC:", jitProvider.totalFeesEarned1());
        
        // Should earn fees from the swap
        assertTrue(
            jitProvider.totalFeesEarned0() > 0 || jitProvider.totalFeesEarned1() > 0,
            "JIT strategy should earn fees"
        );
    }
    
    /**
     * @notice Test multiple concurrent traders
     */
    function testMultipleConcurrentTraders() public {
        console.log("=== Multiple Concurrent Traders Test ===");
        
        // Add liquidity
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 15);
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            5 ether,
            15000 * 1e6
        );
        
        // Trader 1: Multiple small swaps
        vm.startPrank(trader1);
        IERC20(WETH).approve(address(swapHelper), type(uint256).max);
        IERC20(USDC).approve(address(swapHelper), type(uint256).max);
        
        for (uint i = 0; i < 5; i++) {
            swapHelper.executeSwap(WETH_USDC_POOL, true, int256(0.5 ether), 4295128740);
            console.log("Trader1 swap", i + 1);
        }
        vm.stopPrank();
        
        // Trader 2: Large swaps
        vm.startPrank(trader2);
        IERC20(WETH).approve(address(swapHelper), type(uint256).max);
        IERC20(USDC).approve(address(swapHelper), type(uint256).max);
        
        swapHelper.executeSwap(WETH_USDC_POOL, false, int256(5000 * 1e6), 1461446703485210103287273052203988822378723970341);
        console.log("Trader2 large swap executed");
        
        swapHelper.executeSwap(WETH_USDC_POOL, true, int256(2 ether), 4295128740);
        console.log("Trader2 reverse swap executed");
        vm.stopPrank();
        
        // Check accumulated fees
        (uint256 collected0, uint256 collected1) = jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        console.log("Total fees WETH:", jitProvider.totalFeesEarned0());
        console.log("Total fees USDC:", jitProvider.totalFeesEarned1());
        
        assertTrue(
            jitProvider.totalFeesEarned0() > 0 || jitProvider.totalFeesEarned1() > 0,
            "Should earn fees from multiple traders"
        );
    }
    
    /**
     * @notice Test position profitability calculation
     */
    function testPositionProfitability() public {
        console.log("=== Position Profitability Test ===");
        
        uint256 initialWETH = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 initialUSDC = IERC20(USDC).balanceOf(address(jitProvider));
        
        // Add position
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 10);
        (uint128 liquidity, uint256 deposited0, uint256 deposited1) = jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            2 ether,
            6000 * 1e6
        );
        
        console.log("Deposited WETH:", deposited0);
        console.log("Deposited USDC:", deposited1);
        
        // Simulate trading activity
        vm.startPrank(trader1);
        IERC20(WETH).approve(address(swapHelper), type(uint256).max);
        
        // Execute swap
        swapHelper.executeSwap(WETH_USDC_POOL, true, int256(15 ether), 4295128740);
        vm.stopPrank();
        
        // Remove position
        (uint256 collected0, uint256 collected1) = jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        uint256 finalWETH = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 finalUSDC = IERC20(USDC).balanceOf(address(jitProvider));
        
        // Calculate P&L
        int256 pnlWETH = int256(finalWETH) - int256(initialWETH);
        int256 pnlUSDC = int256(finalUSDC) - int256(initialUSDC);
        
        console.log("P&L WETH:", pnlWETH >= 0 ? uint256(pnlWETH) : uint256(-pnlWETH));
        console.log("WETH positive:", pnlWETH >= 0);
        console.log("P&L USDC:", pnlUSDC >= 0 ? uint256(pnlUSDC) : uint256(-pnlUSDC));
        console.log("USDC positive:", pnlUSDC >= 0);
        console.log("Fees WETH:", jitProvider.totalFeesEarned0());
        console.log("Fees USDC:", jitProvider.totalFeesEarned1());
        
        // Position may have impermanent loss, but should collect fees
        assertTrue(collected0 > 0 || collected1 > 0, "Should collect tokens");
    }
    
    /**
     * @notice Test gas efficiency of JIT operations
     */
    function testGasEfficiency() public {
        console.log("=== Gas Efficiency Test ===");
        
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 10);
        
        // Measure gas for adding liquidity
        uint256 gasBefore = gasleft();
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            1 ether,
            3000 * 1e6
        );
        uint256 addGasUsed = gasBefore - gasleft();
        console.log("Gas for addJITLiquidity:", addGasUsed);
        
        // Measure gas for removing liquidity
        gasBefore = gasleft();
        jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        uint256 removeGasUsed = gasBefore - gasleft();
        console.log("Gas for removeJITLiquidity:", removeGasUsed);
        
        // Gas should be reasonable (< 500k for each operation)
        assertTrue(addGasUsed < 500000, "Add liquidity should be gas efficient");
        assertTrue(removeGasUsed < 500000, "Remove liquidity should be gas efficient");
    }
    
    // ============ Edge Cases ============
    
    /**
     * @notice Test with very small amounts
     */
    function testSmallAmounts() public {
        console.log("=== Small Amounts Test ===");
        
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 10);
        
        // Try with very small amounts
        (uint128 liquidity, uint256 amount0, uint256 amount1) = jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            0.001 ether, // Very small
            3 * 1e6      // Very small
        );
        
        console.log("Liquidity from small amounts:", liquidity);
        console.log("WETH used:", amount0);
        console.log("USDC used:", amount1);
        
        assertTrue(liquidity > 0, "Should create liquidity even with small amounts");
        
        jitProvider.removeJITLiquidity(WETH_USDC_POOL);
    }
    
    /**
     * @notice Test with large amounts
     */
    function testLargeAmounts() public {
        console.log("=== Large Amounts Test ===");
        
        // Fund contract with large amounts
        deal(WETH, address(jitProvider), 100 ether);
        deal(USDC, address(jitProvider), 300000 * 1e6);
        
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 10);
        
        (uint128 liquidity, uint256 amount0, uint256 amount1) = jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            50 ether,
            150000 * 1e6
        );
        
        console.log("Liquidity from large amounts:", liquidity);
        console.log("WETH used:", amount0);
        console.log("USDC used:", amount1);
        
        assertTrue(liquidity > 0, "Should create liquidity with large amounts");
        
        (uint256 collected0, uint256 collected1) = jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        console.log("Collected WETH:", collected0);
        console.log("Collected USDC:", collected1);
    }
    
    /**
     * @notice Test position during extreme volatility
     */
    function testExtremeVolatility() public {
        console.log("=== Extreme Volatility Test ===");
        
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(WETH_USDC_POOL, 10);
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            3 ether,
            9000 * 1e6
        );
        
        // Extreme price movement - multiple large swaps in both directions
        vm.startPrank(trader1);
        IERC20(WETH).approve(address(swapHelper), type(uint256).max);
        IERC20(USDC).approve(address(swapHelper), type(uint256).max);
        
        // Crash: Large sells
        swapHelper.executeSwap(WETH_USDC_POOL, true, int256(30 ether), 4295128740);
        console.log("Price crashed");
        
        // Bounce: Large buys
        swapHelper.executeSwap(WETH_USDC_POOL, false, int256(50000 * 1e6), 1461446703485210103287273052203988822378723970341);
        console.log("Price bounced");
        
        // Another crash
        swapHelper.executeSwap(WETH_USDC_POOL, true, int256(40 ether), 4295128740);
        console.log("Price crashed again");
        
        vm.stopPrank();
        
        // Should still be able to remove position
        (uint256 collected0, uint256 collected1) = jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        console.log("Collected after volatility WETH:", collected0);
        console.log("Collected after volatility USDC:", collected1);
        console.log("Fees earned WETH:", jitProvider.totalFeesEarned0());
        console.log("Fees earned USDC:", jitProvider.totalFeesEarned1());
        
        // Despite impermanent loss, should earn significant fees
        assertTrue(
            jitProvider.totalFeesEarned0() > 0 || jitProvider.totalFeesEarned1() > 0,
            "Should earn fees during high volatility"
        );
    }
}
