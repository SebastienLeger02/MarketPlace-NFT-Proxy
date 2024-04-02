// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "test/utils/Utilities.sol";

contract BaseTest is Test {

		struct Users {
			address payable alice;
			address payable bob;
			address payable charlie;
			address payable jason;
			address payable lea;
}
	  Users public users;
    Utilities internal utils;
	  /**
			* @dev Dans le cas oú l'on veut que nos users utilise des tokens et non des ethers
			* on peut écrire des constantes avec l'adresse du token.
			* Exemple: 
			* address public constant WETH = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2;
	 */
  
    function setUp() public virtual {
        // setup utils
      utils = new Utilities();

		/**
			* @dev Dans l'initialisation des users, qui récupère la function creatUser()
			* tokens : en plus d'avoir des ethers on peut mettre dans un tableau mettre la constante du token, ex: [WETH]
		*/

        // setup users
      users = Users({ 
			alice : utils.createUser("Alice"),
			bob: utils.createUser("Bob"),
			charlie: utils.createUser("Charlie"),
			jason: utils.createUser("Jason"),
			lea: utils.createUser("Lea")
		});

			// Initialise comme utilisateur principal Alice (Owner)
			vm.startPrank({msgSender: users.alice, txOrigin: users.alice});
    }
}