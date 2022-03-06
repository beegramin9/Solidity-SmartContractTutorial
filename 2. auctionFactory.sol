// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.12;
import "./2. auctionSmartContract.sol";

// For a platform for multiple auctions, we can't send EOA the raw bytecode of contract
// Because EOA can alter the bytecode
// Best practice: create another contract, which calls a func that calls auction contract
contract AuctionPlatformOwner {
    address public auctionPlatformDeployingEOA;
    address[] public auctionOwners;
    AuctionSmartContract[] public deployedAuctions;

    // mapping deployedAuction => owner;
    constructor() {
        auctionPlatformDeployingEOA = msg.sender;
    }

    function deployAuction() public returns (address) {
        address productSeller = msg.sender;
        AuctionSmartContract newAuction = new AuctionSmartContract(
            productSeller
        );
        deployedAuctions.push(newAuction);
        auctionOwners.push(productSeller);
        return address(newAuction);
    }
}
