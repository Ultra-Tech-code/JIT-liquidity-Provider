// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/JITLiquidityProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/**
 * @notice Add large JIT position with 52 WETH
 */
contract AddLargePosition is Script {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    
    function run() external {
        address jitContract = vm.envAddress("JIT_CONTRACT_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        JITLiquidityProvider jit = JITLiquidityProvider(payable(jitContract));
        
        // Get current pool state
        IUniswapV3Pool pool = IUniswapV3Pool(POOL);
        (uint160 sqrtPriceX96, int24 currentTick,,,,,) = pool.slot0();
        
        console.log("Current tick:", uint256(int256(currentTick)));
        console.log("Current price:", sqrtPriceX96);
        
        // Check balances
        uint256 wethBalance = IERC20(WETH).balanceOf(jitContract);
        uint256 usdcBalance = IERC20(USDC).balanceOf(jitContract);
        
        console.log("WETH balance:", wethBalance / 1e18, "WETH");
        console.log("USDC balance:", usdcBalance / 1e6, "USDC");
        
        // Calculate tight range around current tick (±50 ticks = ±0.5%)
        int24 tickLower = (currentTick - 50) / 10 * 10; // Round down to tick spacing
        int24 tickUpper = (currentTick + 50) / 10 * 10; // Round up to tick spacing
        
        console.log("Tick range:", uint256(int256(tickLower)), "to", uint256(int256(tickUpper)));
        
        // Use maximum available capital
        // For concentrated position near current tick, we need roughly equal value in both tokens
        uint256 wethAmount = 50 ether; // Use 50 WETH
        uint256 usdcAmount = 3_800_000 * 1e6; // ~$3.8M USDC (based on ~$3800 ETH price)
        
        console.log("Adding position with:");
        console.log("  WETH:", wethAmount / 1e18);
        console.log("  USDC:", usdcAmount / 1e6);
        
        // Add large concentrated liquidity position
        jit.addJITLiquidity(
            POOL,
            tickLower,
            tickUpper,
            usdcAmount, // token0 = USDC
            wethAmount  // token1 = WETH
        );
        
        console.log("Large JIT position added successfully!");
        console.log("This position represents significant pool liquidity share");
        console.log("Will capture substantial fees from swaps in the range");
        
        vm.stopBroadcast();
    }
}
