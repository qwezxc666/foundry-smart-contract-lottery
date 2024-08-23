// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18; 

import {Script, console2} from "forge-std/Script.sol";
//是一个模拟（mock）合约，专门用于测试依赖于Chainlink VRF（可验证随机函数）功能的智能合约
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from '../test/mocks/LinkToken.sol';

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;
    //用于测试
    address public FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    //Sepolia 测试网
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    //ETH_MAINNET_CHAIN_ID
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}
contract HelperConfig is Script, CodeConstants{
    error HelperConfig__InvalidChainId();
    struct NetworkConfig{
        uint256 entranceFee;
        uint256 interval;
        address vrfCoodinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        // uint256 deployerKey; 
        address account;

    }
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;
    NetworkConfig public localNetworkConfig;
    uint256 public constant DEFAULT_ANVIL_KEY=
    0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    //网络配置参数
    NetworkConfig public activeNetworkConfig;
    constructor () {
        if(block.chainid==11155111){
            activeNetworkConfig=getSepoliaEthConfig();
        } else{
            activeNetworkConfig=getOrCreateAnvilEthConfig();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoodinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }
    
    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        networkConfigs[chainId] = networkConfig;
    }

    //为什么这里用memory? 因为 NetworkConfig 只是临时创建并返回的
    //为什么不能是view 要用pure？ 使用 pure 是因为这个函数不涉及任何状态变量的读取或修改  两处设置都是为了减少gas费
    function getSepoliaEthConfig() public view returns (NetworkConfig memory){
        return
            NetworkConfig({
                entranceFee:0.01 ether,
                interval:30,
                vrfCoodinator:0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane:0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                // subscriptionId:33466641475413953891448861904934993587289092474661034521531589866482416155925 ,//用自己订阅的id
                subscriptionId:0 ,
                callbackGasLimit:500000 ,//500,000 gas
                link:0x779877A7B0D9E8603169DdbD7836e478b4624789,
                // deployerKey:vm.envUint("PRIVATE_KEY"), //? 加入这个为什么要改为view
                account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network config
        if (localNetworkConfig.vrfCoodinator != address(0)) {
            return localNetworkConfig;
        }

        console2.log(unicode"⚠️ You have deployed a mock conract!");
        console2.log("Make sure this was intentional");
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        LinkToken link = new LinkToken();
        uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            subscriptionId: subscriptionId,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // doesn't really matter
            interval: 30, // 30 seconds
            entranceFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoodinator: address(vrfCoordinatorV2_5Mock),
            link: address(link),
            account: FOUNDRY_DEFAULT_SENDER
        });
        vm.deal(localNetworkConfig.account, 100 ether);
        return localNetworkConfig;
    }
    // function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory){
    //     // Check to see if we set an active network config
    //     if (localNetworkConfig.vrfCoodinator != address(0)) {
    //         return localNetworkConfig;
    //     }

    //     uint96 baseFee= 0.25 ether;
    //     uint96 gasPriceLink=1e9;
    //     int256 weiPerUnitLink= 1e16;
    //     // int256 _weiPerUnitLink= 4e15;

    //     //vm 是 Foundry 的一种虚拟机（Virtual Machine）命令接口，它用于模拟智能合约的运行环境，并允许开发者在合约代码中插入调试和测试的逻辑。
    //     //  开始模拟广播
    //     vm.startBroadcast();
    //     //    i_base_fee = _baseFee;i_gas_price = _gasPrice;i_wei_per_unit_link = _weiPerUnitLink;
    //     VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
    //         baseFee,
    //         gasPriceLink,
    //         weiPerUnitLink
    //     );
    //     LinkToken link=new LinkToken();
    //     // 停止广播
    //     vm.stopBroadcast();
            
    //         localNetworkConfig=NetworkConfig({
    //             entranceFee:0.01 ether,
    //             interval:30,
    //             vrfCoodinator:address(vrfCoordinatorMock),
    //             gasLane:0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
    //             subscriptionId:0 ,//用自己订阅的id
    //             callbackGasLimit:500000, //500,000 gas
    //             link: address(link),
    //             deployerKey:DEFAULT_ANVIL_KEY,
    //             account: FOUNDRY_DEFAULT_SENDER 
    
    //         });
    //         vm.deal(localNetworkConfig.account, 100 ether);
    //     return localNetworkConfig;
    // }
}