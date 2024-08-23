// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    /* Events */
    event RequestedRaffleWinner(uint256 indexed requestId);
    // event RaffleEnter(address indexed player);
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed player);

    HelperConfig helperConfig;
    Raffle raffle;

    //网络配置参数
    uint256 entranceFee;
    uint256 interval;
    address vrfCoodinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    LinkToken link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        interval = config.interval;
        console.log("setUp interval", interval);
        entranceFee = config.entranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoodinator = config.vrfCoodinator;
        link = LinkToken(config.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoodinator).fundSubscription(
                subscriptionId,
                LINK_BALANCE
            );
        }
        link.approve(vrfCoodinator, LINK_BALANCE);
        vm.stopPrank();
    }

    /////////
    // enterRaffle  //
    ////////////
    /**
     * forge test --match-test testRaffleInitializesInOpenState -vv
     * Result: PASS
     */
    function testRaffleInitializesInOpenState() public view {
        //如果 assert 失败（即条件为 false），它将消耗掉所有剩余的 gas，并回滚整个交易。
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /**
     * forge test --match-test testRaffleRevertsWhenYouDontPayEnough -vv
     * Result: PASS
     */
    function testRaffleRevertsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);
        //Act /Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    /**
     * forge test --match-test testRaffleRecordsPlayerWhenTheyEnter -vv
     * Result: PASS
     */
    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    //检查当玩家进入 Raffle 时是否会发出正确的事件
    /**
     * forge test --match-test testEmitsEventOnEntrance -vvvv
     * Check Result: Failed
     * Reason: 发出事件的名称和 Raffle.sol 不符
     */
    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        //?
        vm.expectEmit(true, false, false, false, address(raffle));
        // emit RaffleEnter(PLAYER);
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //测试不能进入  当处于计算状态时  测试这个要写本地的订阅、消费者
    /**
     * forge test --match-test testCantEnterWhenRaffleIsCalculating -vvvv
     * Result: Wrong
     */
    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        console.log(
            "Before upkeep - Raffle state:",
            uint(raffle.getRaffleState())
        );
        console.log("Before upkeep - Block timestamp:", block.timestamp);
        console.log(
            "Before upkeep - Last timestamp:",
            raffle.getLastTimeStamp()
        );

        // 看了很久，没有找到为什么这里的间隔时间会这么大
        //"Before upkeep - Interval:", 97767009708314305665643641779529925837712974602641641141825456487478243071475
        console.log("Before upkeep - Interval:", raffle.getInterval());
        console.log(
            "Before upkeep - Time passed:",
            block.timestamp - raffle.getLastTimeStamp()
        );

        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////
    // checkUpkeep  //
    //////////////
    //forge test --match-test testCheckUpkeepReturnsFalseIfthasNoBalance
    //检查当合约没有余额时，raffle.checkUpkeep 函数是否正确返回 false。
    function testCheckUpkeepReturnsFalseIfthasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    //forge test --match-test testCheckUpkeepReturnsFalseIfRaffleNotOpen
    //测试当抽奖活动（raffle）未处于开放状态时，checkUpkeep 函数是否能正确返回 false。
    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    ///  ///    //
    ///performUpkeep ////
    ///////////
    //测试的是 performUpkeep 操作是否在 checkUpkeep 确认需要进行 upkeep 操作时才能执行。
    //forge test --match-test testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // It doesnt revert
        raffle.performUpkeep("");
    }

    //确保当不满足执行 upkeep 的条件时，performUpkeep 函数会正确地抛出错误并回退，而不会错误地执行下去。
    //forge test --match-test testPerformUpkeepRevertsIfCheckUpkeepIsFalse
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    //?
    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    ///如果我需要使用事件的输出进行测试怎么办?
    //forge test --match-test teestPerformUpkeepUpdatesRaffleStateAndEmitsRequsetId
    function teestPerformUpkeepUpdatesRaffleStateAndEmitsRequsetId()
        public
        raffleEnteredAndTimePassed
    {
        //Act
        vm.recordLogs();
        raffle.performUpkeep(""); //emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    //////////////////
    //fulfillRandomwords//
    ////////////////////
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    //确保在某些条件下（比如 performUpkeep 没有被正确调用之前），调用 fulfillRandomWords 函数会导致回滚，并抛出 "nonexistent request" 的错误消息。
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
        public
        skipFork
    {
        // Arrange
        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoodinator).fulfillRandomWords(
            0,
            address(raffle)
        );

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoodinator).fulfillRandomWords(
            1,
            address(raffle)
        );
    }

    //forge test --match-test testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
        skipFork
    {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoodinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}

//总结下vm用到的函数
// function prank(address msgSender)
