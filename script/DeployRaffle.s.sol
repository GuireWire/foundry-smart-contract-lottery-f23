// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol"; // we need this import to allow us to create subscription in our deployraffle contract

contract DeployRaffle is Script {
    //run function to bring in our Raffle contract
    function run() external returns (Raffle, HelperConfig) {
        //we want to return both the raffle and the helperconfig so our test files can have access to the exact same variables our DeployRaffle contract has access to
        //we will now deploy a new helperconfig. we are deconstructing the networkconfig object to the underlying parameters
        HelperConfig helperConfig = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();
        (
            uint256 subscriptionId,
            bytes32 gasLane,
            uint256 automationUpdateInterval,
            uint256 raffleEntranceFee,
            uint32 callbackGasLimit,
            address vrfCoordinatorV2,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        //we need to create a subscription Id if there is none made
        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (subscriptionId, vrfCoordinatorV2) = createSubscription
                .createSubscription(vrfCoordinatorV2, deployerKey);

            //We need to fund the subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinatorV2,
                uint64(subscriptionId),
                link,
                deployerKey
            );
        }

        vm.startBroadcast(deployerKey);
        Raffle raffle = new Raffle(
            subscriptionId,
            gasLane,
            automationUpdateInterval,
            raffleEntranceFee,
            callbackGasLimit,
            vrfCoordinatorV2
        );
        vm.stopBroadcast();

        // We already have a broadcast in here
        addConsumer.addConsumer(
            address(raffle),
            vrfCoordinatorV2,
            uint64(subscriptionId),
            deployerKey
        );
        return (raffle, helperConfig);
    }
}
