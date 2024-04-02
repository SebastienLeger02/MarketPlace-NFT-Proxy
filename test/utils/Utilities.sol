// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {DSTest} from "openzeppelin-contracts/lib/forge-std/lib/ds-test/src/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
// Si utilise tokens: import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

contract Utilities is DSTest, StdCheats {
	Vm internal immutable vm = Vm(HEVM_ADDRESS);
	
// Si on utilise des tokens alors ajouter dans les paramêtres: address[] calldata tokens
	function createUser(string memory name) external returns(address payable addr){
		addr = payable(makeAddr(name));
		vm.deal({account: addr, newBalance: 1000 ether});
		
	/**
		* @dev si on veut intégrer des tokens, en plus des ethers, ajouter ce script:

		for (uint256 i; i < tokens.length;) {
			deal({token: tokens[i], to: addr, give: 1000 * 10 ** IERC20Metadata(tokens[i]).decimals()});
			unchecked {
				++i;
			}
		}

		*/
	}

	function mineBlocks(uint256 numBlocks) external {
		uint256 targetBlock = block.number + numBlocks;
		vm.roll(targetBlock);
	}

}