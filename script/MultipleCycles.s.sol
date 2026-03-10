// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/JITLiquidityProvider.sol";

/**
 * @title Multiple JIT Cycles
 * @notice Run multiple add/remove cycles to demonstrate the strategy
 */
contract MultipleCycles is Script {
    
    address constant WETH_USDC_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    
    function run() external {
        // Load contract address and private key from env
        address contractAddress = vm.envAddress("JIT_CONTRACT_ADDRESS");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        JITLiquidityProvider jit = JITLiquidityProvider(contractAddress);
        
        vm.startBroadcast(privateKey);
        
        console.log("=== Running Multiple JIT Cycles ===");
        console.log("Contract:", contractAddress);
        
        // Run 5 cycles
        for (uint i = 0; i < 5; i++) {
            console.log("\n--- Cycle", i + 1, "---");
            
            // Calculate optimal range
            (int24 tickLower, int24 tickUpper) = jit.calculateOptimalRange(WETH_USDC_POOL, 10);
            console.log("Tick lower:", tickLower);
            console.log("Tick upper:", tickUpper);
            
            // Add liquidity
            (uint128 liquidity, uint256 amount0, uint256 amount1) = jit.addJITLiquidity(
                WETH_USDC_POOL,
                tickLower,
                tickUpper,
                1 ether,
                3000 * 1e6
            );
            console.log("Added liquidity:", liquidity);
            console.log("Used USDC:", amount0);
            console.log("Used WETH:", amount1);
            
            // Remove liquidity immediately
            (uint256 collected0, uint256 collected1) = jit.removeJITLiquidity(WETH_USDC_POOL);
            console.log("Collected USDC:", collected0);
            console.log("Collected WETH:", collected1);
            
            // Check total fees
            uint256 fees0 = jit.totalFeesEarned0();
            uint256 fees1 = jit.totalFeesEarned1();
            console.log("Total fees USDC:", fees0);
            console.log("Total fees WETH:", fees1);
        }
        
        console.log("\n=== All Cycles Complete ===");
        console.log("Final total fees USDC:", jit.totalFeesEarned0());
        console.log("Final total fees WETH:", jit.totalFeesEarned1());
        
        vm.stopBroadcast();
    }
}
