// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol"; //console prints out what it does
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {CodeConstants} from "./HelperConfig.s.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorV2_5 = helperConfig
            .getConfigByChainId(block.chainid)
            .vrfCoordinatorV2_5;
        address account = helperConfig
            .getConfigByChainId(block.chainid)
            .account;
        return createSubscription(vrfCoordinatorV2_5, account);
    }

    //function below creates the subscription based on the vrfCoordinator

    function createSubscription(
        address vrfCoordinatorV2_5,
        address account
    ) public returns (uint256, address) {
        console.log("Creating subscription on chainId: ", block.chainid); //this logs the subscription being created
        vm.startBroadcast(account);
        //we are going to call the create subscription function on the VRFCoordinatorMock
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId); //this gives you a log of what your sub id is
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return (subId, vrfCoordinatorV2_5);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

//we are going to use our Config to help us create a subscription^^

contract AddConsumer is Script {
    function addConsumer(
        address contractToAddToVRF,
        address vrfCoordinator,
        uint256 subId,
        address account
    ) public {
        console.log("Adding consumer contract:", contractToAddToVRF);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("On ChainId:", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            contractToAddToVRF
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig
            .getConfig()
            .vrfCoordinatorV2_5;
        address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2_5, subId, account);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}

//Below we need to make a new contract to fund the subscription
contract FundSubscription is CodeConstants, Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        //we need subscription Id, LINK address, and VRFCoordinatorV2 address
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig
            .getConfig()
            .vrfCoordinatorV2_5;
        address link = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        if (subId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint256 updatedSubId, address updatedVRFv2) = createSub.run();
            subId = updatedSubId;
            vrfCoordinatorV2_5 = updatedVRFv2;
            console.log(
                "New SubId Created! ",
                subId,
                "VRF Address: ",
                vrfCoordinatorV2_5
            );
        }

        fundSubscription(vrfCoordinatorV2_5, subId, link, account);
    }

    //here we will run the same functions that the frontend would do when funding a subscription
    function fundSubscription(
        address vrfCoordinatorV2_5,
        uint256 subId,
        address link,
        address account
    ) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2_5);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(
                vrfCoordinatorV2_5,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}
