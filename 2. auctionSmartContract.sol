// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.12;
import "./2. auctionFactory.sol";

// Decentralized auction like an eBay alternative
contract AuctionSmartContract {
    // to make more sense,
    uint256 bidIncrement;
    // Block timestamps are set by miner, can be easily spoofed.
    // Instead, we calculate the time based on the block number.
    uint256 public oneWeekInSeconds = 604800;

    // Products come with metadata: descriptions, images
    // Which is expensive to save on blockchain
    // Alternative: decentralized off-chain solution, IPFS
    string public ipfsHash;
    address payable public productSeller;

    uint256 public startBlock;
    uint256 public endBlock;

    uint256 public highestBindingBid;
    address payable public highestBidder;
    mapping(address => uint256) public cumDepositsOf;

    constructor(address auctionDeployingEOA) {
        productSeller = payable(auctionDeployingEOA);
        auctionState = State.Running;
        startBlock = block.number; // current block number
        endBlock = startBlock + oneWeekInSeconds / 15; // Ethereum block generation intervene is 15 secs
        ipfsHash = "";
        bidIncrement = 1 ether;
    }

    enum State {
        Running,
        Ended,
        Canceled
    }
    State public auctionState;

    modifier shouldBeProductSeller() {
        require(
            msg.sender == productSeller,
            "should be the owner of the product"
        );
        _;
    }

    modifier shouldBeNotProductSeller() {
        require(
            msg.sender != productSeller,
            "The owner of the product cannot bid!"
        );
        _;
    }

    modifier shouldBeRunning() {
        require(block.number >= startBlock, "The auction has not started yet.");
        require(block.number <= endBlock, "The auction expired.");
        require(auctionState == State.Running, "The auction is not running.");
        // 이거 redundant한데... 나중에 수정할듯
        _;
    }

    // I want to separate these helper functions in a separate files
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        // pure: cannot access any data outside the function
        // meaning of pure: given a, b, this func will always give c

        // view: can access global variables in same contract
        // both are read-only
        return a < b ? a : b;
    }

    function cancelAuction() public shouldBeProductSeller {
        // isProductSeller
        auctionState = State.Canceled;
    }

    function placeANewBidMoreThan1Ether()
        public
        payable
        shouldBeNotProductSeller
        shouldBeRunning
    {
        // function name too long, newBid
        require(msg.value >= 1 ether, "You must bid over 1 ether.");
        uint256 newSumOfBid = cumDepositsOf[msg.sender] + msg.value;
        require(
            newSumOfBid > highestBindingBid,
            "You must top the current highest binding bid to have a chance."
        ); // the bid increment is not high enough
        // only makes sense when newSumOfBid is greater
        // otherwise, highestBidder won't renew anyway

        // newSumOfBid is greater, now let's renew highestBidder!
        cumDepositsOf[msg.sender] = newSumOfBid;

        if (newSumOfBid <= cumDepositsOf[highestBidder]) {
            // nothing's entering this section? dry running, paper
            highestBindingBid = min(
                newSumOfBid + bidIncrement,
                cumDepositsOf[highestBidder]
            );
        } else {
            // when the first bidder bids, cumDepositsOf[highestBidder] automatically becomes 0
            // because highestBidder key doesn't exist on cumDepositsOf, so falls back to default uint value
            highestBindingBid = min(
                newSumOfBid,
                cumDepositsOf[highestBidder] + bidIncrement
            );
            highestBidder = payable(msg.sender);
        }
    }

    function eachReceiveMoneyOnceAuctionOver() public {
        require(
            msg.sender == productSeller || cumDepositsOf[msg.sender] > 0,
            "Only product seller or those who have bid money can finalize the auction."
        );

        address payable recipient;
        uint256 money;
        uint256 finalPriceOfProduct = highestBindingBid;

        if (auctionState == State.Canceled) {
            // due to canceled, every bidder but productSeller gets refund
            recipient = payable(msg.sender);
            money = cumDepositsOf[msg.sender];
        } else if (endBlock < block.number) {
            if (msg.sender == productSeller) {
                // Aution was successfully over, now the seller gets money
                recipient = productSeller;
                money = finalPriceOfProduct;
            } else if (msg.sender == highestBidder) {
                // The highest bidder pays the price
                recipient = highestBidder;
                money = cumDepositsOf[msg.sender] - finalPriceOfProduct;
            } else {
                // Other bidder wants to retain the deposit, they failed to buy the product
                recipient = payable(msg.sender);
                money = cumDepositsOf[msg.sender];
            }
        } else {
            revert("Auction must be cancelled or expired.");
        }
        cumDepositsOf[msg.sender] = 0;
        // why is this right?
        // reentrancy, DAO 1.0 dao fault
        recipient.transfer(money);
    }
}
