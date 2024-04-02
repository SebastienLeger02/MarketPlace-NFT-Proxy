// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Contrat NFT - 
 * @author Sébastien Léger
 * @notice This is a contract for the creation of NFT based on the ERC721 pattern.
*/

contract MyNFT is ERC721 {

    /**
        * @notice 'Library' use Strings.sol.
        * @dev I need to convert a "uint256" to a string
    */
    using Strings for uint256;

    /**
        * @notice 'error' Warns the user of errors
        * @dev error role, triggers when:
        * 'CantidadInvalida()' : The owner's wallet contains less than 0.1 ether.
        * 'InvalidZeroAddress()' : The new owner is address 0x00.
        * 'NotOwner()' : The owner not is msg.sender
        * 'TransferFaild()' : When the answer is false, that the transaction was not completed correctly.
    */
    error CantidadInvalida();
    error InvalidZeroAddress();
    error NotOwner();
    error TransferFaild();
    

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    string public baseURI;
    address public theOwner;
    
    mapping(address owner => uint256) private _balances;

    modifier onlyOwner() {
        if(msg.sender != theOwner) revert NotOwner();
        _;
    }

    constructor() ERC721("ProjectFinal", "PR") {
        theOwner = msg.sender;
    }

    function mint(address to, uint256 tokenId) external payable {
        if(msg.value > 0.1 ether) revert CantidadInvalida();
        _safeMint(to, tokenId);
    }

    function tokenURI(uint256 id) public view override returns(string memory) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, id.toString(), ".json")) : "";
    }

    function setOwner(address newOwner) external onlyOwner {
        if(newOwner == address(0)) revert InvalidZeroAddress();
        address oldOwner = theOwner;
        theOwner = newOwner;
        emit OwnerChanged(oldOwner, newOwner);
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _requireOwned(tokenId);
    }
    
    function approve(address to, uint256 tokenId) public override {
        _approve(to, tokenId, _msgSender());
    }

    function withdraw(address to) external onlyOwner {
        (bool ok, ) = to.call{value: address(this).balance}("");
        if(!ok) revert TransferFaild();
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function balanceOf(address owner) public view override returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return _balances[owner];
    }

}