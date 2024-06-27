// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {CreateSubscription} from "../../script/Interactions.s.sol";

contract RaffleTest is StdCheats, Test {
    /**Events */
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    Raffle public raffle;
    HelperConfig public helperConfig;

    //creating state variables for the raffle deployer section that references the HelperConfig variables
    uint64 subscriptionId;
    bytes32 gasLane;
    uint256 automationUpdateInterval;
    uint256 raffleEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2;

    //we will create a starting user to interact with raffle
    address public PLAYER = makeAddr("player"); //we are using a foundry cheat to create a player for us with a starting balance
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    //set up function to create raffle deployer
    function setUp() external {
        //create our raffle deployer
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run(); //because our DeployRaffle contract is returning a raffle and helperConfig
        vm.deal(PLAYER, STARTING_USER_BALANCE); // this cheatcode gives PLAYER some money

        (
            ,
            gasLane,
            automationUpdateInterval,
            raffleEntranceFee,
            callbackGasLimit,
            vrfCoordinatorV2, // link
            // deployerKey
            ,

        ) = helperConfig.activeNetworkConfig();
    }

    //function to test if raffle opens in open state
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // we made a raffle state function in the Raffle contract to cover this
        // Raffle.RaffleState.OPEN means that on any raffle contract, the RaffleState enum/type - get the open value for that.
    }

    ////////////////////////////
    // enter Raffle function  //
    ////////////////////////////
    function testRaffleRevertsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER); //pretend to be the player
        //Act & //Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    //this test is to test if player is recorded in array when they enter the raffle
    function testRaffleRecordsPlayerWhenTheyEnter() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: raffleEntranceFee}();
        //Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    //we will test emit event
    function testEmitsEventonEntrance() public {
        vm.prank(PLAYER);
        // when we write expectEmit, we emit the event we expect to see and then perform the call
        vm.expectEmit(true, false, false, false, address(raffle)); //this only has one indexed parameter (aka Topic). first one true, other 2 parameters are false, and final one is false as no checkdata
        //Manually emit event we expect
        emit RaffleEnter(PLAYER);
        //Perform the call
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    //we will write a test for the if Raffle not open statement
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER); //we are pretending to be player
        raffle.enterRaffle{value: raffleEntranceFee}(); //this is us entering the raffle
        vm.warp(block.timestamp + automationUpdateInterval + 1); // cheat to set specific block.timestamp
        vm.roll(block.number + 1); // cheat to set specific block.number
        raffle.performUpkeep(""); //this puts raffle into CALCULATING State meaning this test should check to see if we cant enter raffle

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER); //this here is setting up the next real call of entering the raffle
        raffle.enterRaffle{value: raffleEntranceFee}(); //this should revert here as Raffle should be in Calculating State
    }

    /////////////////////////
    // checkUpkeep function //
    //////////////////////////
    //test returns false if Raffle has no balance
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    //test to return false if Raffle isn't open
    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); //checkUpkeep should return false if we are in Calculating state
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    //test to check if returns false if enough time hasnt passed
    // Challenge 1. testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    // Challenge 2. testCheckUpkeepReturnsTrueWhenParametersGood
    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /////////////////////////
    // performUpkeep       //
    /////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // It doesnt revert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector( //cheatcode
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep(""); //we are expecting this to fail with error code (Raffle.Raffle__UpkeepNotNeeded.selector) with these parameters(currentBalance,numPlayers,rState)
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    //What if I need to test using the output of an event?
    //If i'm building a Chainlink like system, i need to be able to test for events being emitted and values being emitted
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        // Act
        vm.recordLogs(); //cheatcode to start recording all the emitted events
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs(); //import VM into RaffleTest.t.sol
        bytes32 requestId = entries[1].topics[1]; //all logs are recorded as bytes32 in foundry, 0 topic refers to entire event (emit RequestedRaffleWinner(requestId)), whereas 1 topic refers to requestId
        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0); //this makes sure the requestId is generated
        assert(uint(raffleState) == 1); // 0 = open, 1 = calculating
    }

    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEntered skipFork {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords( //import VRFCoordinatorV2Mock into RaffleTest.t.sol
            randomRequestId, //this is known as fuzz test - foundry creates random number and calls this test many times with many random numbers
            address(raffle)
        );
    }

    //One Big Test
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
            address player = address(uint160(i)); //this is same as address(1), address(2) etc and will generate an address based off this number
            hoax(player, 1 ether); // hoax cheatcode - this gives our player 1 ETH and we pretend to be player
            raffle.enterRaffle{value: raffleEntranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        //now we need to pretend to be Chainlink VRF to get random number and pick winner
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = raffleEntranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
