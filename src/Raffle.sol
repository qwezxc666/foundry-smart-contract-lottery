// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//*和视频不一样*/
//VRFCoordinatorV2_5Mock 在测试环境中模拟第三方服务的行为，确保合约在接收到不同的随机数时能够正确运行。
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {VRFConsumerBaseV2Plus} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/*不知道下面的方式为啥引入不进去，感觉路径也没问题*/
// import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
// import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 * @title
 * @author
 * @notice
 * @dev
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    //状态
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    //入场费  immutable gas费低
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    VRFCoordinatorV2_5Mock private immutable i_vrfCoodinator;
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;

    //枚举状态
    enum RaffleState {
        OPEN, //0
        CALULATING //1
    }
    RaffleState private s_raffleState;
    /** Events */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);

    //继承一个合约时，通常需要在子合约的构造函数中调用父合约的构造函数，以确保父合约能够正确初始化。
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoodinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoodinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoodinator = VRFCoordinatorV2_5Mock(vrfCoodinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    //进入彩票
    function enterRaffle() external payable {
        // require(msg.value >=i_entranceFee,"Not enough ETH sent!");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        //保存每个人的地址  +payable是为了确保地址是发送eth的用户地址
        s_players.push(payable(msg.sender));

        //测试 这是多余的吗
        emit EnteredRaffle(msg.sender);
    }

    //利用link自动化启动合约调用
    //抽取彩票获胜者
    //注意在计算随机数的时候不希望有人再加入
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALULATING;

        // Will revert if subscription is not set and funded.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        // Quiz... is this redundant?
        emit RequestedRaffleWinner(requestId);
    }

    //获胜者在什么时候被选出
    /* @dev 是否需要选出获胜者，chainlink会调用这个函数，判断是否到了抽奖的时间，如果为true，则会选出获胜者
     * @param  空
     * @return upkeepNeeded 是否需要选出获胜者
     * @return 附加数据
     */

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        //规定的时间间隔是否已经过去 (timeHasPassed)。合约是否处于开放状态 (isOpen)。合约是否有足够的资金 (hasBalance)。是否有玩家参与 (hasPlayers)。

        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // can we comment this out?
    }

    //CEI "Checks-Effects-Interactions"（检查-效果-交互）设计模式
    //Checks: 检查输入条件或合约状态，防止非法操作。
    // Effects: 更新合约的内部状态，确保在与外部交互之前已经做好准备。
    // Interactions: 与外部进行交互，如发送 ETH 或调用其他合约。
    //内部重写的作用？
    //获取随机数
    function fulfillRandomWords(
        uint256 _requestId,
        //todo 这里用calldata还是memory  calldata只读不能修改 memory 可读可修改  _randomWords并没有修改
        uint256[] calldata _randomWords
    ) internal override {
        //通过取模运算判断谁是winner？

        // require(s_requests[_requestId].exists, "request not found");
        // s_requests[_requestId].fulfilled = true;
        // s_requests[_requestId].randomWords = _randomWords;
        // emit RequestFulfilled(_requestId, _randomWords);

        /**Checks**/
        /**Effects**/
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        //重置
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner); //放这是为了更好地遵循 CEI 模式 预防 潜在的安全问题，特别是防止重入攻击
        //call 方法返回两个值：一个布尔值 bool 表示调用是否成功，和一个 bytes memory 类型的返回数据。 ("");这里是一个空的字节数组，表示没有调用任何具体的函数，只是发送 ETH。
        /**Interactions**/
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__TransferFailed();
        }
        //通知外部系统谁是抽奖的赢家
        // emit WinnerPicked(winner);
    }

    //获取入场费  external，意味着这个函数只能通过外部调用来访问，而不能通过合约内部的其他函数调用。这种设计可以节省一些Gas费，
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
