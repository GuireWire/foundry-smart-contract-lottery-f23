# Proveably Random Raffle Contracts 

# About

This code is to create a provably random smart contract lottery.

# What do we want the smart contract to do?

1. Users can enter by paying for a ticket
   1. The ticket fees are going to go to the winnder during the draw
2. After X period of time, the lottery will automatically draw a winner
   1. And this will be done programmatically
3. We will do this using Chainlink VRF & Chainlink Automation
   1. Chainlink VRF -> Generates Randomness
   2. Chainlink Automation -> Time based trigger to automatically trigger lottery 

# Tests!

1. Write some deploy scripts
2. Write our tests that will;
   1. Work on a local chain
   2. on a Forked Testnet
   3. on a Forked Mainnet