// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    // input paramaters from Raffle contract
    struct NetworkConfig {
        uint256 subscriptionId;
        bytes32 gasLane;
        uint256 automationUpdateInterval;
        uint256 raffleEntranceFee;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2;
        address link;
        uint256 deployerKey;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    event HelperConfig__CreatedMockVRFCoordinator(address vrfCoordinator);

    constructor() {
        if (block.chainid == 11155111) {
            //11155111 is Sepolia's chainid
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    //Deploy on Mainnet ETH
    function getMainnetEthConfig()
        public
        view
        returns (NetworkConfig memory mainnetNetworkConfig)
    {
        mainnetNetworkConfig = NetworkConfig({
            subscriptionId: 0, // If left as 0, our scripts will create one!
            gasLane: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            automationUpdateInterval: 30, // 30 seconds
            raffleEntranceFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    //First we will need to deploy to Sepolia
    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        return
            sepoliaNetworkConfig = NetworkConfig({
                subscriptionId: 64747507628753327729568699735272336201040524299521005470069261295730595969022, // If left as 0, our scripts will create one!
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                automationUpdateInterval: 30, // 30 seconds
                raffleEntranceFee: 0.01 ether,
                callbackGasLimit: 500000, // 500,000 gas
                vrfCoordinatorV2: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    //Now we need our Anvil config with our mocks
    function getOrCreateAnvilConfig()
        public
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        //if function below states if address already exists then it won't create a new one again
        if (activeNetworkConfig.vrfCoordinatorV2 != address(0)) {
            return activeNetworkConfig;
        }

        //we deploy mocks using the below;
        //these parameters are taken from the VRFCoordinatorV2Mock constructor
        uint96 baseFee = 0.25 ether; //this is the base fee Chainlink VRF takes. it says ether but its actually LINK
        uint96 gasPriceLink = 1e9; //1 gwei Link

        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY);
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        emit HelperConfig__CreatedMockVRFCoordinator(
            address(vrfCoordinatorV2Mock)
        );

        anvilNetworkConfig = NetworkConfig({
            subscriptionId: 0, // If left as 0, our scripts will create one!
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // doesn't really matter
            automationUpdateInterval: 30, // 30 seconds
            raffleEntranceFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2: address(vrfCoordinatorV2Mock),
            link: address(link),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
