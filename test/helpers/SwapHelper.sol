// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SwapHelper
 * @notice Helper contract to execute swaps on Uniswap V3 pools with proper callback handling
 */
contract SwapHelper is IUniswapV3SwapCallback {
    
    /**
     * @notice Execute a swap on a Uniswap V3 pool
     */
    function executeSwap(
        address pool,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96
    ) external returns (int256 amount0, int256 amount1) {
        return IUniswapV3Pool(pool).swap(
            msg.sender,
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            abi.encode(msg.sender)
        );
    }
    
    /**
     * @notice Uniswap V3 callback for swaps
     */
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        address sender = abi.decode(data, (address));
        address pool = msg.sender;
        
        IUniswapV3Pool v3Pool = IUniswapV3Pool(pool);
        
        // Transfer tokens from sender to pool
        if (amount0Delta > 0) {
            IERC20(v3Pool.token0()).transferFrom(sender, pool, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(v3Pool.token1()).transferFrom(sender, pool, uint256(amount1Delta));
        }
    }
}
