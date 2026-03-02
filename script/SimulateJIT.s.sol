// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/JITLiquidityProvider.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimulateJIT
 * @notice Script to simulate JIT liquidity provision on Uniswap V3
 */
contract SimulateJIT is Script {
    
    // Mainnet addresses (these will work on Stagenet due to mainnet replay)
    address constant WETH_USDC_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // 0.05% pool
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    JITLiquidityProvider public jitProvider;
    
    function setUp() public {
        // Load deployed contract address from environment
        address jitAddress = vm.envAddress("JIT_CONTRACT_ADDRESS");
        jitProvider = JITLiquidityProvider(jitAddress);
    }
    
    /**
     * @notice Simulate adding JIT liquidity around current price
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== JIT Liquidity Simulation ===");
        console.log("Contract:", address(jitProvider));
        console.log("Pool:", WETH_USDC_POOL);
        
        // Get current pool state
        IUniswapV3Pool pool = IUniswapV3Pool(WETH_USDC_POOL);
        (uint160 sqrtPriceX96, int24 currentTick, , , , , ) = pool.slot0();
        
        console.log("Current tick:", vm.toString(currentTick));
        console.log("Current sqrtPriceX96:", sqrtPriceX96);
        
        // Calculate optimal range (±10 ticks from current)
        (int24 tickLower, int24 tickUpper) = jitProvider.calculateOptimalRange(
            WETH_USDC_POOL,
            10
        );
        
        console.log("Tick lower:", vm.toString(tickLower));
        console.log("Tick upper:", vm.toString(tickUpper));
        
        // Check balances in the CONTRACT (not deployer wallet)
        uint256 wethBalance = IERC20(WETH).balanceOf(address(jitProvider));
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(jitProvider));
        
        console.log("Contract WETH balance:", wethBalance);
        console.log("Contract USDC balance:", usdcBalance);
        
        // Use amounts based on what's in the contract
        uint256 wethAmount = 1 ether; // 1 WETH
        uint256 usdcAmount = 3000 * 1e6; // 3000 USDC (6 decimals)
        
        if (wethBalance >= wethAmount && usdcBalance >= usdcAmount) {
            console.log("Contract has sufficient balance, adding liquidity...");
            
            // Add JIT liquidity (tokens are already in contract)
            jitProvider.addJITLiquidity(
                WETH_USDC_POOL,
                tickLower,
                tickUpper,
                wethAmount,
                usdcAmount
            );
            
            console.log("JIT liquidity added successfully!");
            
            // Get position details
            JITLiquidityProvider.Position memory position = jitProvider.getPosition(WETH_USDC_POOL);
            console.log("Position liquidity:", position.liquidity);
            console.log("Position token0:", position.token0Amount);
            console.log("Position token1:", position.token1Amount);
        } else {
            console.log("Insufficient balance in contract.");
            console.log("Required: 1 WETH and 3000 USDC");
        }
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Remove JIT liquidity and collect fees
     */
    function removeLiquidity() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Removing JIT Liquidity ===");
        
        // Remove liquidity
        (uint256 amount0, uint256 amount1) = jitProvider.removeJITLiquidity(WETH_USDC_POOL);
        
        console.log("Removed liquidity");
        console.log("Collected WETH:", amount0);
        console.log("Collected USDC:", amount1);
        
        // Get total fees earned
        uint256 totalFees0 = jitProvider.totalFeesEarned0();
        uint256 totalFees1 = jitProvider.totalFeesEarned1();
        
        console.log("Total fees earned WETH:", totalFees0);
        console.log("Total fees earned USDC:", totalFees1);
        
        vm.stopBroadcast();
    }
}
