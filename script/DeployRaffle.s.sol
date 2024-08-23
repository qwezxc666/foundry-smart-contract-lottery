// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CreateSubscription,FundSubscription,AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        AddConsumer addConsumer = new AddConsumer();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoodinator) =
                createSubscription.createSubscription(config.vrfCoodinator, config.account);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoodinator, config.subscriptionId, config.link, config.account
            );

            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.subscriptionId,
            config.vrfCoodinator,
            config.gasLane,
            config.interval,
            config.callbackGasLimit
            
        );
        vm.stopBroadcast();

        // We already have a broadcast in here
        addConsumer.addConsumer(address(raffle), config.vrfCoodinator, config.subscriptionId, config.account);
        return (raffle, helperConfig);
    }
}