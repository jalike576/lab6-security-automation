// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract GoodVault {
    mapping(address => uint256) public balances;
    address public immutable owner;
    bool private locked;

    error NoBalance();
    error TransferFailed();
    error ReentrantCall();

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() public nonReentrant {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NoBalance();

        balances[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
