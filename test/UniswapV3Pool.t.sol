// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

//forge test --match-contract UniswapV3PoolTest -vv         
//forge script scripts/DeployDevelopment.s.sol --broadcast --fork-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
//cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "allowance(address,address)" "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9" --rpc-url http://localhost:8545
//cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "totalSupply()(uint256)" --rpc-url http://localhost:8545
//cast balance 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
//cast chain-id
//forge inspect UniswapV3Pool abi
//cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "slot0()" | ForEach-Object { cast --abi-decode "a()(uint160,int24)" $_ }
import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";
import "./TestUtils.sol";
// import "./FullMath.sol";

contract UniswapV3PoolTest is Test, TestUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiqudity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 expectedAmount0 = 0.998976618347425280 ether;
        uint256 expectedAmount1 = 5000 ether;
        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect token0 deposited amount"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect token1 deposited amount"
        );
        assertEq(token0.balanceOf(address(pool)), expectedAmount0);
        assertEq(token1.balanceOf(address(pool)), expectedAmount1);

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), params.lowerTick, params.upperTick)
        );
        uint128 posLiquidity = pool.positions(positionKey);
        assertEq(posLiquidity, params.liquidity);

        (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(
            params.lowerTick
        );
        assertTrue(tickInitialized);
        assertEq(tickLiquidity, params.liquidity);

        (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
        assertTrue(tickInitialized);
        assertEq(tickLiquidity, params.liquidity);

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            5602277097478614198912276234240,
            "invalid current sqrtP"
        );
        assertEq(tick, 85176, "invalid current tick");
        assertEq(
            pool.liquidity(),
            1517882343751509868544,
            "invalid current liquidity"
        );
    }

    function testMintInvalidTickRangeLower() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("InvalidTickRange()"));
        pool.mint(address(this), -887273, 0, 0, "");
    }

    function testMintInvalidTickRangeUpper() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("InvalidTickRange()"));
        pool.mint(address(this), 0, 887273, 0, "");
    }

    function testMintZeroLiquidity() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("ZeroLiquidity()"));
        pool.mint(address(this), 0, 1, 0, "");
    }

    function testMintInsufficientTokenBalance() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 0,
            usdcBalance: 0,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: false,
            transferInSwapCallback: true,
            mintLiqudity: false
        });
        setupTestCase(params);

        vm.expectRevert(encodeError("InsufficientInputAmount()"));
        pool.mint(
            address(this),
            params.lowerTick,
            params.upperTick,
            params.liquidity,
            ""
        );
    }
    
    function testCalculateDeltaP() public view{
        uint USDC = 42 ether;
        uint DeltaP;
        uint liquidity = 1517882343751509868544;
        DeltaP=USDC*2**96/liquidity;
        console.log("DeltaP", DeltaP); //2192253463713690532467206957
    }

     function testCalculateTargetSqrtP() public view{
        // ΔP​=Δy​ / L
        uint DeltaSqrtP = 2192253463713690532467206957;   //       42/1517882343751509868544
        uint currentSqrtP = 5602277097478614198912276234240;
                          
        uint TargetSqrtP = currentSqrtP+DeltaSqrtP;
        uint x = 10000000000000;
       
        uint targetP_ = (TargetSqrtP*x/2**96); // 707383482474845    
        uint targetP = (targetP_**2/x); //50039139127823934
        console.log("TargetSqrtP", TargetSqrtP); //5604469350942327889444743441197
                                                 //5604469350942327889444743441197
        console.log("targetP", targetP); //50039139127823934

        // getNextSqrtPriceFromInput
        // sqrtPX96: 5602277097478614198912276234240
        // liquidity: 1517882343751509868544
        // amountIn: 42000000000000000000
        // zeroForOne: false

        //result  5604469350942327889444743441197
            // function getNextSqrtPriceFromInput(
            //     uint160 sqrtPX96,
            //     uint128 liquidity,
            //     uint256 amountIn,
            //     bool zeroForOne
            // ) public pure returns (uint160 sqrtQX96) {
            //     require(sqrtPX96 > 0);
            //     require(liquidity > 0);
            //     return
            //         zeroForOne
            //             ? getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
            //             : getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true);
            // }

    }


    function testCalculateAmount0Delta() public view {
        uint DeltaSqrtP = 2192253463713690532467206957; 
        uint currentSqrtP = 5602277097478614198912276234240;
        uint TargetSqrtP = currentSqrtP+DeltaSqrtP;
        uint liquidity = 1517882343751509868544;
        uint liquidityFixedPoint96 = liquidity*2**96; 
        if (currentSqrtP > TargetSqrtP) (currentSqrtP, TargetSqrtP) = (TargetSqrtP, currentSqrtP);
        // uint amount_out = FullMath.mulDiv(liquidityFixedPoint96, DeltaSqrtP, TargetSqrtP) / currentSqrtP;
       // 120259029008277069663908933879274768668093824630784 
        
        // uint amount_out3 = amount_out2/currentSqrtP;
        // (DeltaSqrtP)/TargetSqrtP/currentSqrtP;
        console.log("liquidityFixedPoint96", liquidityFixedPoint96); //120259029008277069663908933879274768668093824630784
    
    
    
        //  function mulDiv23232(
        //     uint256 a, 
        //     uint256 b, 
        //     uint256 denominator, 
        //     uint256 secondDenominator
        //     ) public pure returns (uint256 result) {
            
        //     uint firstResult = mulDiv(a,b,denominator);
        //     result = firstResult/secondDenominator;
        // }

        // function getAmount0Delta(
        //     uint160 sqrtRatioAX96,
        //     uint160 sqrtRatioBX96,
        //     uint128 liquidity,
        //     bool roundUp
        // ) internal pure returns (uint256 amount0) {
        //     if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        //     uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        //     uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;
        //     require(sqrtRatioAX96 > 0);
        //     return
        //         roundUp
        //             ? UnsafeMath.divRoundingUp(
        //                 FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96),
        //                 sqrtRatioAX96
        //             )
        //             : FullMath.mulDiv(numerator1, numerator2, sqrtRatioBX96) / sqrtRatioAX96;
        // }

    
    
    
    
    
    
    
    
    }

    function testCalculateTick() public view {

        //input 5604469350942327889444743441197  TargetSqrtP
        //result 85184
        //    function getTickAtSqrtRatio(uint160 sqrtPriceX96) public pure returns (int24 tick) {
            
        //     uint256 ratio = uint256(sqrtPriceX96) << 32;
        //     uint256 r = ratio;
        //     uint256 msb = 0;
        //     assembly {
        //         let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
        //         msb := or(msb, f)
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
        //         msb := or(msb, f)
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         let f := shl(5, gt(r, 0xFFFFFFFF))
        //         msb := or(msb, f)
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         let f := shl(4, gt(r, 0xFFFF))
        //         msb := or(msb, f)
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         let f := shl(3, gt(r, 0xFF))
        //         msb := or(msb, f)
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         let f := shl(2, gt(r, 0xF))
        //         msb := or(msb, f)
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         let f := shl(1, gt(r, 0x3))
        //         msb := or(msb, f)
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         let f := gt(r, 0x1)
        //         msb := or(msb, f)
        //     }
        //     if (msb >= 128) r = ratio >> (msb - 127);
        //     else r = ratio << (127 - msb);
        //     int256 log_2 = (int256(msb) - 128) << 64;
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(63, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(62, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(61, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(60, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(59, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(58, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(57, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(56, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(55, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(54, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(53, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(52, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(51, f))
        //         r := shr(f, r)
        //     }
        //     assembly {
        //         r := shr(127, mul(r, r))
        //         let f := shr(128, r)
        //         log_2 := or(log_2, shl(50, f))
        //     }
        //     int256 log_sqrt10001 = log_2 * 255738958999603826347141; // 128.128 number
        //     int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
        //     int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);
        //     tick = tickLow == tickHi ? tickLow : getSqrtRatioAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow;
        // }

        // function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        //     uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
            
        //     uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        //     if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        //     if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        //     if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        //     if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        //     if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        //     if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        //     if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        //     if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        //     if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        //     if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        //     if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        //     if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        //     if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        //     if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        //     if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        //     if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        //     if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        //     if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        //     if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        //     if (tick > 0) ratio = type(uint256).max / ratio;

        //     sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
        // }

    }

    


    function testSwapBuyEth() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 swapAmount = 42 ether; // 42 USDC
        token1.mint(address(this), swapAmount);
        token1.approve(address(this), swapAmount);

        UniswapV3Pool.CallbackData memory extra = UniswapV3Pool.CallbackData({
            token0: address(token0),
            token1: address(token1),
            payer: address(this)
        });

        int256 userBalance0Before = int256(token0.balanceOf(address(this)));

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            abi.encode(extra)
        );

        assertEq(amount0Delta, -0.008396714242162444 ether, "invalid ETH out");
        assertEq(amount1Delta, 42 ether, "invalid USDC in");

        assertEq(
            token0.balanceOf(address(this)),
            uint256(userBalance0Before - amount0Delta),
            "invalid user ETH balance"
        );
        assertEq(
            token1.balanceOf(address(this)),
            0,
            "invalid user USDC balance"
        );

        assertEq(
            token0.balanceOf(address(pool)),
            uint256(int256(poolBalance0) + amount0Delta),
            "invalid pool ETH balance"
        );
        assertEq(
            token1.balanceOf(address(pool)),
            uint256(int256(poolBalance1) + amount1Delta),
            "invalid pool USDC balance"
        );

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            5604469350942327889444743441197,
            "invalid current sqrtP"
        );
        assertEq(tick, 85184, "invalid current tick");
        assertEq(
            pool.liquidity(),
            1517882343751509868544,
            "invalid current liquidity"
        );
    }

    function testSwapInsufficientInputAmount() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: true,
            transferInSwapCallback: false,
            mintLiqudity: true
        });
        setupTestCase(params);

        vm.expectRevert(encodeError("InsufficientInputAmount()"));
        pool.swap(address(this), "");
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // CALLBACKS
    //
    ////////////////////////////////////////////////////////////////////////////
    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
        if (transferInSwapCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(
                data,
                (UniswapV3Pool.CallbackData)
            );

            if (amount0 > 0) {
                IERC20(extra.token0).transferFrom(
                    extra.payer,
                    msg.sender,
                    uint256(amount0)
                );
            }

            if (amount1 > 0) {
                IERC20(extra.token1).transferFrom(
                    extra.payer,
                    msg.sender,
                    uint256(amount1)
                );
            }
        }
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        if (transferInMintCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(
                data,
                (UniswapV3Pool.CallbackData)
            );

            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    function setupTestCase(TestCaseParams memory params)
        internal
        returns (uint256 poolBalance0, uint256 poolBalance1)
    {
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            params.currentSqrtP,
            params.currentTick
        );

        if (params.mintLiqudity) {
            token0.approve(address(this), params.wethBalance);
            token1.approve(address(this), params.usdcBalance);

            UniswapV3Pool.CallbackData memory extra = UniswapV3Pool
                .CallbackData({
                    token0: address(token0),
                    token1: address(token1),
                    payer: address(this)
                });

            (poolBalance0, poolBalance1) = pool.mint(
                address(this),
                params.lowerTick,
                params.upperTick,
                params.liquidity,
                abi.encode(extra)
            );
        }

        transferInMintCallback = params.transferInMintCallback;
        transferInSwapCallback = params.transferInSwapCallback;
    }
}
