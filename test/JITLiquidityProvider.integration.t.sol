// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/JITLiquidityProvider.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title JITLiquidityProvider Integration Tests
 * @notice Comprehensive tests that actually interact with Uniswap V3 pool
 * These tests catch real issues like liquidity calculation bugs
 */
contract JITLiquidityProviderIntegrationTest is Test {
    
    JITLiquidityProvider public jitProvider;
    
    // Mainnet addresses for forking
    address constant WETH_USDC_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    // Whale addresses for getting tokens
    address constant WETH_WHALE = 0x8EB8a3b98659Cce290402893d0123abb75E3ab28; // Has lots of WETH
    address constant USDC_WHALE = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503; // Has lots of USDC
    
    address owner = address(this);
    
    // Test amounts - similar to what we'll use in production
    uint256 constant WETH_AMOUNT = 1 ether;
    uint256 constant USDC_AMOUNT = 3000 * 1e6; // 3000 USDC
    
    function setUp() public {
        // Fork mainnet at a recent block
        string memory alchemyKey = vm.envOr("ALCHEMY_API_KEY", string("demo"));
        string memory rpcUrl = string.concat("https://eth-mainnet.g.alchemy.com/v2/", alchemyKey);
        vm.createSelectFork(rpcUrl);
        
        // Deploy contract
        jitProvider = new JITLiquidityProvider(1 ether);
        
        // Fund the contract with WETH and USDC from whales
        _fundContract();
    }
    
    /**
     * @dev Helper function to fund the contract with tokens
     * Using deal() for more reliable testing
     */
    function _fundContract() internal {
        // Use Forge's deal function to give tokens directly to the contract
        deal(WETH, address(jitProvider), WETH_AMOUNT * 5); // 5 WETH for multiple tests
        deal(USDC, address(jitProvider), USDC_AMOUNT * 5); // 15000 USDC for multiple tests
        
        // Verify balances
        assertGe(IERC20(WETH).balanceOf(address(jitProvider)), WETH_AMOUNT);
        assertGe(IERC20(USDC).balanceOf(address(jitProvider)), USDC_AMOUNT);
    }
    
    /**
     * @notice Test adding JIT liquidity with real amounts
     * This is the critical test that would have caught the liquidity calculation bug
     */
    function testAddJITLiquidityWithRealAmounts() public {
        // Calculate optimal range
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        // Get initial balances
        uint256 wethBefore = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 usdcBefore = IERC20(USDC).balanceOf(address(jitProvider));
        
        // Add liquidity - THIS SHOULD NOT REVERT
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            WETH_AMOUNT,
            USDC_AMOUNT
        );
        
        // Get final balances
        uint256 wethAfter = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(jitProvider));
        
        // Verify tokens were used (some amount should have been spent)
        assertTrue(wethBefore > wethAfter, "WETH should have been used");
        assertTrue(usdcBefore > usdcAfter, "USDC should have been used");
        
        // Verify position was created
        JITLiquidityProvider.Position memory position = jitProvider.getPosition(WETH_USDC_POOL);
        
        assertTrue(position.liquidity > 0, "Liquidity should be greater than 0");
        
        console.log("=== Add Liquidity Test Results ===");
        console.log("WETH used:", wethBefore - wethAfter);
        console.log("USDC used:", usdcBefore - usdcAfter);
        console.log("Liquidity created:", position.liquidity);
    }
    
    /**
     * @notice Test removing JIT liquidity
     * Note: Depending on current price, you may get back mostly one token
     */
    function testRemoveJITLiquidity() public {
        // First add liquidity
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            WETH_AMOUNT,
            USDC_AMOUNT
        );
        
        // Get position info
        JITLiquidityProvider.Position memory positionBefore = jitProvider.getPosition(WETH_USDC_POOL);
        assertTrue(positionBefore.liquidity > 0, "Should have liquidity before removal");
        
        // Get balances before removal
        uint256 wethBefore = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 usdcBefore = IERC20(USDC).balanceOf(address(jitProvider));
        
        // Remove liquidity
        jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        // Get balances after removal
        uint256 wethAfter = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(jitProvider));
        
        // Verify at least some tokens were returned
        // Note: Depending on price range, might get mostly one token or the other
        assertTrue(
            (wethAfter > wethBefore) || (usdcAfter > usdcBefore), 
            "At least one token should be returned"
        );
        
        // Verify position was removed
        JITLiquidityProvider.Position memory positionAfter = jitProvider.getPosition(WETH_USDC_POOL);
        assertEq(positionAfter.liquidity, 0, "Liquidity should be 0 after removal");
        
        console.log("=== Remove Liquidity Test Results ===");
        console.log("WETH returned:", wethAfter > wethBefore ? wethAfter - wethBefore : 0);
        console.log("USDC returned:", usdcAfter > usdcBefore ? usdcAfter - usdcBefore : 0);
    }
    
    /**
     * @notice Test the full cycle: add → remove → verify
     */
    function testFullLiquidityCycle() public {
        uint256 initialWETH = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 initialUSDC = IERC20(USDC).balanceOf(address(jitProvider));
        
        // Calculate optimal range
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        // Add liquidity
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            WETH_AMOUNT,
            USDC_AMOUNT
        );
        
        // Verify position exists
        JITLiquidityProvider.Position memory position = jitProvider.getPosition(WETH_USDC_POOL);
        assertTrue(position.liquidity > 0, "Should have active position");
        
        // Remove liquidity
        jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        // Verify position is gone
        JITLiquidityProvider.Position memory positionAfterRemove = jitProvider.getPosition(WETH_USDC_POOL);
        assertEq(positionAfterRemove.liquidity, 0, "Position should be removed");
        
        // Check final balances (should be close to initial, might have small fees)
        uint256 finalWETH = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 finalUSDC = IERC20(USDC).balanceOf(address(jitProvider));
        
        // Allow for small rounding differences (0.1%)
        assertApproxEqRel(finalWETH, initialWETH, 0.001e18, "WETH should be approximately returned");
        assertApproxEqRel(finalUSDC, initialUSDC, 0.001e18, "USDC should be approximately returned");
        
        console.log("=== Full Cycle Test Results ===");
        console.log("Initial WETH:", initialWETH);
        console.log("Final WETH:", finalWETH);
        console.log("Initial USDC:", initialUSDC);
        console.log("Final USDC:", finalUSDC);
    }
    
    /**
     * @notice Test adding liquidity with insufficient balance
     * This ensures proper error handling
     */
    function testAddLiquidityInsufficientBalance() public {
        // Deploy a new contract with no funds
        JITLiquidityProvider emptyProvider = new JITLiquidityProvider(1 ether);
        
        (int24 tickLower, int24 tickUpper) = emptyProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        // Try to add liquidity without funds - should revert
        vm.expectRevert();
        emptyProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            WETH_AMOUNT,
            USDC_AMOUNT
        );
    }
    
    /**
     * @notice Test multiple positions can be added and removed
     */
    function testMultiplePositions() public {
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        // Add first position
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            WETH_AMOUNT / 2,
            USDC_AMOUNT / 2
        );
        
        JITLiquidityProvider.Position memory position1 = jitProvider.getPosition(WETH_USDC_POOL);
        assertTrue(position1.liquidity > 0, "First position should exist");
        
        // Remove first position
        jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        // Add second position
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            WETH_AMOUNT / 2,
            USDC_AMOUNT / 2
        );
        
        JITLiquidityProvider.Position memory position2 = jitProvider.getPosition(WETH_USDC_POOL);
        assertTrue(position2.liquidity > 0, "Second position should exist");
        
        // Clean up
        jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        console.log("=== Multiple Positions Test ===");
        console.log("First position liquidity:", position1.liquidity);
        console.log("Second position liquidity:", position2.liquidity);
    }
    
    /**
     * @notice Test that access control works for adding liquidity
     */
    function testAddLiquidityAccessControl() public {
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        // Try to add liquidity from non-owner - should revert
        vm.expectRevert();
        vm.prank(address(0x123));
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            WETH_AMOUNT,
            USDC_AMOUNT
        );
    }
    
    /**
     * @notice Test that access control works for removing liquidity
     */
    function testRemoveLiquidityAccessControl() public {
        // First add liquidity as owner
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            tickLower,
            tickUpper,
            WETH_AMOUNT,
            USDC_AMOUNT
        );
        
        // Try to remove liquidity from non-owner - should revert
        vm.expectRevert();
        vm.prank(address(0x456));
        jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        // Clean up as owner
        jitProvider.removeJITLiquidity(WETH_USDC_POOL);
    }
    
    /**
     * @notice Test tick calculation is within valid range
     */
    function testTickCalculationValid() public {
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        IUniswapV3Pool pool = IUniswapV3Pool(WETH_USDC_POOL);
        int24 tickSpacing = pool.tickSpacing();
        
        // Verify tick properties
        assertTrue(tickLower < tickUpper, "Lower tick should be less than upper tick");
        assertEq((tickLower % tickSpacing), 0, "Lower tick should be multiple of spacing");
        assertEq((tickUpper % tickSpacing), 0, "Upper tick should be multiple of spacing");
        
        // Verify ticks are not at extremes
        assertTrue(tickLower > -887272, "Lower tick should not be at minimum");
        assertTrue(tickUpper < 887272, "Upper tick should not be at maximum");
        
        console.log("=== Tick Calculation Test ===");
        console.log("Tick lower:", vm.toString(tickLower));
        console.log("Tick upper:", vm.toString(tickUpper));
        console.log("Tick spacing:", vm.toString(tickSpacing));
    }
    
    /**
     * @notice Test emergency withdraw functionality
     */
    function testEmergencyWithdraw() public {
        uint256 wethBalance = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(jitProvider));
        
        assertTrue(wethBalance > 0, "Contract should have WETH");
        assertTrue(usdcBalance > 0, "Contract should have USDC");
        
        // Withdraw WETH
        jitProvider.withdrawTokens(WETH, wethBalance);
        assertEq(IERC20(WETH).balanceOf(address(jitProvider)), 0, "All WETH should be withdrawn");
        
        // Withdraw USDC
        jitProvider.withdrawTokens(USDC, usdcBalance);
        assertEq(IERC20(USDC).balanceOf(address(jitProvider)), 0, "All USDC should be withdrawn");
        
        console.log("=== Emergency Withdraw Test ===");
        console.log("WETH withdrawn:", wethBalance);
        console.log("USDC withdrawn:", usdcBalance);
    }
    
    /**
     * @notice Test getCurrentPrice returns valid data
     */
    function testGetCurrentPrice() public {
        (uint160 sqrtPriceX96, int24 tick) = jitProvider.getCurrentPrice(WETH_USDC_POOL);
        
        assertTrue(sqrtPriceX96 > 0, "Price should be greater than 0");
        assertTrue(tick != 0, "Tick should not be 0");
        
        // Verify we can use this price to calculate ticks
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        // Current tick should be between calculated range
        assertTrue(tick >= tickLower - 100 && tick <= tickUpper + 100, "Current tick should be near calculated range");
        
        console.log("=== Current Price Test ===");
        console.log("Sqrt price X96:", sqrtPriceX96);
        console.log("Current tick:", vm.toString(tick));
    }
}
