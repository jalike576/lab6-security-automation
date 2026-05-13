// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BadVault {
    mapping(address => uint) public balances;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {
        balances[tx.origin] += msg.value;
    }

    function withdraw() public {
        uint amount = balances[msg.sender];
        (bool success, ) = msg.sender.call{value: amount}("");
        balances[msg.sender] = 0;
    }

    function suicide() public {
        selfdestruct(payable(owner));
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }
}
