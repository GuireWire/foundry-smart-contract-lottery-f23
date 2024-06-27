// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

/**Version */
pragma solidity ^0.8.18;

/**Imports */
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A Sample Raffle Contract
 * @author Anthony Maguire
 * @notice This contract is for creating a sample raffle
 * @dev This implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /**Errors */
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );
    error Raffle__TransferFailed();
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();

    /**Type Declarations */
    enum RaffleState {
        OPEN, //in solidity these can be converted to integeres, ie 0
        CALCULATING // this would be integer 1
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3; //constant variable all upper case, more gas efficient
    uint32 private constant NUM_WORDS = 1; //for 1 random winner
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subscriptionId; //// NOTE! As of newer versions of Chainlink, the subscription id is a uint256 instead of a uint64
    uint32 private immutable i_callbackGasLimit;

    /** Lottery Variables */
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; //@dev Duration of the lottery in seconds is your interval
    address payable[] private s_players; //storage variable not an immutable variable because number of players constantly changing. address payable because we will pay one of these addresses if they win
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // What data structure should we use? How to keep track of all the Raffle Players?

    /** Events */
    event RequestedRaffleWinner(uint256 indexed requestId); //this will get emitted when we call performUpkeep
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    constructor(
        uint256 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(msg.sender).transfer(balance);
        }
    }

    function enterRaffle() public payable {
        //require(msg.value >= i_entranceFee, "Not enough ETH sent"); this costs more gas
        // require(s_raffleState == RaffleState.OPEN, "Raffle is not open");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender)); //needs payable to allow address get ETH
        //we need an event after a storage update because;
        // 1. Makes migration easier
        // 2. Makes front end "indexing" easier
        emit RaffleEnter(msg.sender);
    }

    //We want pickWinner function to do the following;
    //1. Get a random number
    //2. Use random number to pick player

    //3. Be automatically called
    //when is the winner supposed to be picked?
    /**
     * @dev This is the function that the Chainlink Automation nodes call to see if it's time to perform an Upkeep
     * The following should be true for this to return true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The Contract has ETH (aka players)
     * 4. (Implicit) The subscription is funded with LINK
     */
    function checkUpkeep(
        bytes memory /*checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData */)
    {
        // you can ignore checkdata section by wrapping it in /* */. UpKeep is needed when lottery is ready to pick winner and a bytes memory perform data is when there is any additional data that needs to be passed to perform Upkeep function
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    // function pickWinner() external { have to change pickWinner to perform upkeep to allow for use of Chainlink Automation
    function performUpkeep(bytes calldata /*performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        //we can check to see if enough time is passed in this function

        //eg 1000 - 500 = 500. Interval set to 600s therefore 500s < 600s so not enough time has passed
        //s_lastTimeStamp as we need to keep track of last timestamp in a storage variable

        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //keyHash = gas lane
            uint64(i_subscriptionId), //subscription id you funded with link
            REQUEST_CONFIRMATIONS, //no. of block confirmations
            i_callbackGasLimit, //limit to make sure we dont overspend on this call
            NUM_WORDS //number of random numbers, this will be 1 as there's only 1 winner
        );

        emit RequestedRaffleWinner(requestId); //is this redundant? = yes it is redundant but we will emit it again because we need to be able to test using the output of an event
        //Chainlink VRF is 2 transactions;
        //1. Request the RNG
        //2. Get the random number
    }

    // the function below is used to recall the random number
    // CEI Method - Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // s_players = 10
        //rng = 12
        //12 % 10 = 2 <- so who ever is indexed 2 in the array is our winner
        //1. Checks
        //2.Effects (Our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0); //this resets the s_players array for every new raffle game
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp; //this resets the timestamp for every new raffle
        emit WinnerPicked(recentWinner); // this emits log of winner (see above Events section for the event creation of PickedWinner)

        //3. Interactions (other contracts)
        (bool success, ) = recentWinner.call{value: address(this).balance}(""); //all of ticket sales goes to this winner
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**Getter Function to Get the Entrance Fee */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    //creating a raffle state function to see if raffle is open
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    //to access players array we use the below function;
    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
