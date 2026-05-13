// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

abstract contract Ownable {
    address public owner;

    error NotOwner();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
    }
}

contract ERC165 {
    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        return interfaceId == 0x01ffc9a7;
    }
}

contract SimpleERC721 is ERC165 {
    mapping(uint256 => address) private owners;
    mapping(address => uint256) private balances;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        return owners[tokenId];
    }

    function _mint(address to, uint256 tokenId) internal {
        owners[tokenId] = to;
        balances[to] += 1;
        emit Transfer(address(0), to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == 0x80ac58cd || super.supportsInterface(interfaceId);
    }
}

contract MyNFT is SimpleERC721, Ownable {
    string public name = "Lab6 NFT";
    string public symbol = "L6NFT";
    uint256 public nextTokenId;

    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = nextTokenId;
        nextTokenId += 1;
        _mint(to, tokenId);
        return tokenId;
    }
}
