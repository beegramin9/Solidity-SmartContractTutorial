// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

contract Lottery {
    address payable[] public players;
    // address 中 하나는 Eth를 받습니다 => 모두 payable로 선언한다
    address public contractOwner;

    constructor() {
        // 맨 처음 계약을 발행한, 계약의 주인
        contractOwner = msg.sender;
        // 2. contractOwner automatically gets added to the lottery
        // players.push(payable(contractOwner));
    }

    receive() external payable {
        // Each time Ether is sent to the contract in a transcation,
        // receive() gets automatically executed.

        // 1. contractOwner can't participate
        // require(msg.sender != contractOwner,"The contract owner cannot participate");

        // solidity에서 기본 화폐단위는 Wei
        // specify해줘야 한다
        require(
            msg.value == 0.1 ether,
            "Every participants must deposit 0.1 Ether"
        );

        // 계약에 Eth를 보내며 복권에 참가하는
        // address를 payable로 만드는 방법
        players.push(payable(msg.sender));
    }

    function getBalance() public view returns (uint256) {
        require(
            msg.sender == contractOwner,
            "Only the contract owner can view the balance"
        );
        return address(this).balance;
    }

    // computes the hash of the input using keccak256 algorithm
    // abi.encodePacked(combined input) => single argument type bytes
    function getRandomNum() private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        players.length
                    )
                )
            );
        // hashing some deterministic values related to blocks are not trully random,
        // Dive Depper: https://docs.chain.link/docs/get-a-random-number/
    }

    function pickWinner() private view returns (address payable) {
        require(
            msg.sender == contractOwner,
            "Only the contract owner can pick the winner"
        );
        require(players.length >= 3, "At least more than 3 must participate");

        uint256 randomNum = getRandomNum();
        uint256 index = randomNum % players.length;
        address payable winner = players[index];
        return winner;
    }

    function resetPlayers() private {
        players = new address payable[](0);
    }

    function transferEtherToWinner() public {
        address payable winner = pickWinner();
        winner.transfer(getBalance());
        // payable type address는 transfer method를 가진다
        // reciepient.transfer(money)
        resetPlayers();
    }
}
