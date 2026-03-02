// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/JITLiquidityProvider.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract JITLiquidityProviderTest is Test {
    
    JITLiquidityProvider public jitProvider;
    
    // Mainnet addresses for forking
    address constant WETH_USDC_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    address owner = address(this);
    
    function setUp() public {
        // Fork mainnet at a recent block using Alchemy API key from env
        string memory alchemyKey = vm.envOr("ALCHEMY_API_KEY", string("demo"));
        string memory rpcUrl = string.concat("https://eth-mainnet.g.alchemy.com/v2/", alchemyKey);
        vm.createSelectFork(rpcUrl);
        
        // Deploy contract
        jitProvider = new JITLiquidityProvider(1 ether);
    }
    
    function testDeployment() public {
        assertEq(jitProvider.owner(), owner);
        assertEq(jitProvider.minSwapSize(), 1 ether);
    }
    
    function testCalculateOptimalRange() public {
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        // Verify ticks are valid
        assertTrue(tickLower < tickUpper);
        
        // Get pool tick spacing
        IUniswapV3Pool pool = IUniswapV3Pool(WETH_USDC_POOL);
        int24 tickSpacing = pool.tickSpacing();
        
        // Verify ticks are properly spaced
        assertTrue((tickUpper - tickLower) % tickSpacing == 0);
    }
    
    function testGetCurrentPrice() public {
        (uint160 sqrtPriceX96, int24 tick) = jitProvider.getCurrentPrice(WETH_USDC_POOL);
        
        // Verify we got valid data
        assertTrue(sqrtPriceX96 > 0);
        assertTrue(tick != 0);
    }
    
    function testAddJITLiquidity() public {
        // This would require funding the contract with tokens
        // For now, we just test that the function exists and has proper access control
        
        vm.expectRevert();
        vm.prank(address(0x123)); // Random address
        jitProvider.addJITLiquidity(
            WETH_USDC_POOL,
            -887220,
            887220,
            1 ether,
            3000 * 1e6
        );
    }
    
    function testSetMinSwapSize() public {
        jitProvider.setMinSwapSize(2 ether);
        assertEq(jitProvider.minSwapSize(), 2 ether);
        
        // Test access control
        vm.expectRevert();
        vm.prank(address(0x123));
        jitProvider.setMinSwapSize(3 ether);
    }
    
    function testWithdrawTokens() public {
        // Deal some WETH to the contract
        deal(WETH, address(jitProvider), 10 ether);
        
        uint256 balanceBefore = IERC20(WETH).balanceOf(owner);
        jitProvider.withdrawTokens(WETH, 5 ether);
        uint256 balanceAfter = IERC20(WETH).balanceOf(owner);
        
        assertEq(balanceAfter - balanceBefore, 5 ether);
    }
}
