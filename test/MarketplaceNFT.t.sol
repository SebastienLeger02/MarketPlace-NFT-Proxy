// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/MarketplaceNFT.sol";
import "../src/MyNFT.sol";
import "../src/ProxyV1.sol";
import "../test/BaseTest.t.sol";

contract TestMarketplaceNFT is BaseTest {

    event SellOfferCreated(uint256 indexed sellOfferIdCounter);
    event SellOfferAccepted(uint256 indexed _sellOfferIdCounter);
    event SellOfferCancelled(uint256 indexed sellOfferIdCounter);
    event BuyOfferCreated(uint256 indexed buyOfferIdCounter);
    event BuyOfferAccepted(uint256 indexed _buyOfferIdCounter);
    event BuyOfferCancelled(uint256 indexed _buyOfferIdCounter);


    MarketplaceNFT public marketplaceNFT;
    ProxyV1 public proxy;
    MyNFT public nft;


    function setUp() public override {
        super.setUp();

        // Marketplace.sol deployment
        marketplaceNFT = new MarketplaceNFT();
        // MyProxy.sol deployment
        proxy = new ProxyV1(address(marketplaceNFT),abi.encodeWithSignature("initialize(string)", "MarketPlace NFT"));
        // MyNFR.sol deployment
        nft = new MyNFT();

        (bool ok, bytes memory answer) = address(proxy).call(abi.encodeWithSignature("contractOwner()"));
        require (ok, "Call failed contractOwner()");
        address contractOwner =  abi.decode(answer, (address));
        assertEq(contractOwner, users.alice);

        (bool ok2, bytes memory answer2) = address(proxy).call(abi.encodeWithSignature("marketplaceName()"));
        require (ok2, "Call failed marketplaceName()");
        string memory marketplaceName =  abi.decode(answer2, (string));
        assertEq(marketplaceName, "MarketPlace NFT");

        nft.mint(users.alice, 1);
        nft.mint(users.bob, 2);
        nft.mint(users.charlie,3);
        assertEq(IERC721(nft).ownerOf(1), users.alice);
        assertEq(IERC721(nft).ownerOf(2), users.bob);
        assertEq(IERC721(nft).ownerOf(3), users.charlie);
    }

    // _______________________________________
    // --------   Start-up functions ------------
    // _______________________________________

    function test_Initialize() public {
        // NFTMarketplaceTest.sol tries to initialize NFTMarketplace.sol again
        vm.expectRevert();
        (bool ok, ) = address(proxy).call(abi.encodeWithSignature("initialize(string)", "MarketPlace NFT"));
        require (ok, "Call failed initialize()");
    }

    function test_GetImplementation() public {

        assertEq(proxy.getImplementation(), address(marketplaceNFT));
    }

    function test_AuthorizeUpgrades() public {
        // alice tries to upgrade the implementation but she is not the owner
        vm.stopPrank();
        vm.startPrank(address(this));
        vm.expectRevert(bytes4(keccak256("NotOwner()")));
        (bool ok, ) = address(proxy).call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(marketplaceNFT), ""));
        require (ok, "Upgrade failed upgradeToAndCall _ NotOwner");
        vm.stopPrank();
        vm.startPrank(users.alice);
        /// NFTMarketplaceTest.sol (it is the contract owner) upgrades it
        (bool ok2, ) = address(proxy).call(abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(marketplaceNFT), ""));
        require (ok2, "Upgrade failed upgradeToAndCall ");
    }

    // _______________________________________
    // --------   CreateSellOffer ------------
    // _______________________________________

    function test_CreateSellOffer() public {
        ////////// ERROR CHECKING //////////////
        vm.stopPrank();
        vm.startPrank(address(this));
        // Test revert if no owner of NFT
        vm.expectRevert(bytes4(keccak256("NoOwnerOfNft()")));
        // Calls the creatSellOffer() function with the arguments: 
        // address _nftAddress,
        // uint64 _tokenId,
        // uint128 _price
        // uint128 _deadline
        (bool okOwner, ) = address(proxy).call(abi.encodeWithSignature("createSellOffer(address,uint64,uint128,uint128)",
             nft, 1, 2 ether, uint128(block.timestamp) + 1 days));
        require (okOwner, "Call failed createSellOffer() _ NoOwnerOfNft"); 
        
        // alice creates a sell Offer with wrong deadline
        vm.stopPrank();
        vm.startPrank(users.alice);
        // Test the revert if the deadline has passed
        vm.expectRevert(bytes4(keccak256("DeadlinePassed()")));
        (bool okTime, ) = address(proxy).call(abi.encodeWithSignature("createSellOffer(address,uint64,uint128,uint128)",
             nft, 1, 2 ether, uint128(block.timestamp)));
        require (okTime, "Call failed createSellOffer() _ DeadlinePassed");      
        
        // Test revert if price is null
        vm.expectRevert(bytes4(keccak256("PriceNull()")));
        (bool okPrice, ) = address(proxy).call(abi.encodeWithSignature("createSellOffer(address,uint64,uint128,uint128)",
             nft, 1, 0, uint128(block.timestamp) + 1));
        require (okPrice, "Call failed createSellOffer() _ PriceNull"); 

        /////////// SELL OFFER CREATION CHECKING ////////////
        // The contract creating the NFT agrees to transfer the NFT with ID 1 to the "MarketplaceNFT" contract.
        nft.approve(address(proxy), 1);

        //Checks if the counter sellOfferIdCounter() is 0
        (bool okIdCounter1, bytes memory answer) = address(proxy).call(abi.encodeWithSignature("sellOfferIdCounter()"));
        require (okIdCounter1, "Call failed sellOfferIdCounter()"); 
        uint256 offerIdCounter =  abi.decode(answer, (uint256)); 
        assertEq(offerIdCounter, 0);

        // Prepares and controls the SellOfferCreated event to be issued
        vm.expectEmit(true,false,false,false);
        emit SellOfferCreated(1);

        // Calls the creatSellOffer()
        (bool ok, ) = address(proxy).call(abi.encodeWithSignature("createSellOffer(address,uint64,uint128,uint128)",
             nft, 1, 20 ether, uint128(block.timestamp) + 5 days));
        require (ok, "Call failed createSellOffer()");

        //Call getSellOffer() to read the "Offer" struct in the "sellOffers" mapping.
        (bool okGetOffer, bytes memory answerOffer) = address(proxy).call(abi.encodeWithSignature("getSellOffer(uint256)", 0));
        require (okGetOffer, "Call failed getSellOffer()");  
        
        // Check that the offer has been created - Retrieve struct Offer
        MarketplaceNFT.Offer memory offer =  abi.decode(answerOffer, (MarketplaceNFT.Offer));

        // Retrieve the struct "Offer" in order to verify these elements   
        assertEq(offer.offerer, users.alice); // Check if the owner of the offer is "alice".
        assertEq(offer.nftAddress, address(nft)); // Checks if the NFT is the same as the one in the offer 
        assertEq(offer.deadline, block.timestamp + 5 days); // Check deadline
        assertEq(offer.tokenId, 1); // Checks token ID
        assertEq(offer.price, 20 ether); // Checks price 
        assertEq(offer.isEnded, false); // Check if the offer is still open
        
        //Checks if the counter sellOfferIdCounter() has incremented by 1
        (bool okIdCounter2, bytes memory answerCounter) = address(proxy).call(abi.encodeWithSignature("sellOfferIdCounter()"));
        require (okIdCounter2, "Call failed sellOfferIdCounter()");
        uint256 offerIdCounter2 =  abi.decode(answerCounter, (uint256));
        assertEq(offerIdCounter2, 1);


        /////////////////////////// NFT TRANSFER CHECKING ///////////////////////////
        assertEq(nft.ownerOf(1), address(proxy));
        

    }

    // _______________________________________
    // --------  OnERC721Received ------------
    // _______________________________________

    function test_OnERC721Received() public {

        nft.approve(address(proxy), 1);

        (bool ok, ) = address(proxy).call(abi.encodeWithSignature("createSellOffer(address,uint64,uint128,uint128)",
             nft, 1, 20 ether, uint128(block.timestamp) + 5 days));
        require (ok, "Call failed createSellOffer()");

        assertEq(nft.ownerOf(1), address(proxy));

        // assertEq(IERC721(nft).balanceOf(address(users.alice)), 0);
        // assertEq(IERC721(nft).balanceOf(address(proxy)), 1);

    }

    // _______________________________________
    // --------   AcceptSellOffer -------------
    // _______________________________________

    function test_AcceptSellOffer() public {
     
        ////////////// CREATION OFFER //////////////
        nft.approve(address(proxy), 1);

        (bool ok, ) = address(proxy).call(abi.encodeWithSignature("createSellOffer(address,uint64,uint128,uint128)",
             nft, 1, 20 ether, uint128(block.timestamp) + 5 days));
        require (ok, "Call failed createSellOffer()");

        //Call getSellOffer() to read the "Offer" struct in the "sellOffers" mapping.
        (bool okGetOffer, bytes memory answerOffer) = address(proxy).call(abi.encodeWithSignature("getSellOffer(uint256)", 0));
        require (okGetOffer, "Call failed getSellOffer()");  
        
        // Check that the offer has been created - Retrieve struct Offer
        MarketplaceNFT.Offer memory offer =  abi.decode(answerOffer, (MarketplaceNFT.Offer));

        // Retrieve the struct "Offer" in order to verify these elements   
        assertEq(offer.offerer, users.alice); // Check if the owner of the offer is "alice".
        assertEq(offer.nftAddress, address(nft)); // Checks if the NFT is the same as the one in the offer 
        assertEq(offer.deadline, block.timestamp + 5 days); // Check deadline
        assertEq(offer.tokenId, 1); // Checks token ID
        assertEq(offer.price, 20 ether); // Checks price 
        assertEq(offer.isEnded, false); // Check if the offer is still open

        ///////////////// ERROR CHECKING //////////////
        // Test revert if price is not correct
        vm.stopPrank();
        vm.deal(users.bob, 50 ether);
        vm.startPrank(users.bob);
        vm.expectRevert(bytes4(keccak256("BadPrice()")));
        (bool okPrice, ) = address(proxy).call{value: 18 ether}(abi.encodeWithSignature("acceptSellOffer(uint256)", 0));
        require (okPrice, "Call failed acceptSellOffer() _ BadPrice"); 

        // bob accepts it out of deadline
        vm.warp(uint128(block.timestamp) + 10 days);
        vm.expectRevert(bytes4(keccak256("DeadlinePassed()")));
        (bool okTime, ) = address(proxy).call{value: 20 ether}(abi.encodeWithSignature("acceptSellOffer(uint256)", 0));
        require (okTime, "Call failed acceptSellOffer() _ DeadlinePassed"); 

        //////////// SELL OFFER ACCEPT //////////
        /// bob accepts the offer
        //Times 
        vm.warp(1712500350); 

        vm.expectEmit(true, false, false, false);
        emit SellOfferAccepted(0);
        (bool ok2, ) = address(proxy).call{value: 20 ether}(abi.encodeWithSignature("acceptSellOffer(uint256)", 0));
        require (ok2, "Call failed acceptSellOffer()");

        (bool okGetOffer2, bytes memory answerOffer2) = address(proxy).call(abi.encodeWithSignature("getSellOffer(uint256)", 0));
        require (okGetOffer2, "Call failed getSellOffer()");  
        
        // Check that the offer has been created - Retrieve struct Offer
        MarketplaceNFT.Offer memory offer2 =  abi.decode(answerOffer2, (MarketplaceNFT.Offer));

        // Retrieve the struct "Offer" in order to verify these elements   
        assertEq(offer2.price, 20 ether);
        assert(offer2.deadline > block.timestamp); // The deadline remains unchanged
        assertEq(offer2.isEnded, true); // Check "finished" final status
        assertEq(nft.ownerOf(1), users.bob);
        // Checks Bob and Alice's balance after transfer - Bob buys Alice 
        assertEq(users.bob.balance, 30 ether);  // bob 50 - 20   
        assertEq(users.alice.balance, 20 ether); // alice 0 + 20

        /////////////// ERROR CHECKING ///////////////
        /// Charlie tries to accept the same offer
        vm.stopPrank();
        vm.deal(users.charlie, 50 ether);
        vm.prank(users.charlie);
        vm.expectRevert(bytes4(keccak256("OfferClosed()")));
        (bool okClosed, ) = address(proxy).call{value: 20 ether}(abi.encodeWithSignature("acceptSellOffer(uint256)", 0));
        require (okClosed, "Call failed acceptSellOffer() _ OfferClosed"); 
    }

    // _______________________________________
    // -------- CancelSellOffer -------------
    // _______________________________________


    function test_CancelSellOffer() public {
        /// alice creates the sell offer with id 0
        ////////////// CREATION OFFER //////////////
        uint128 deadlineNotPassed = uint128(block.timestamp);

        nft.approve(address(proxy), 1);

        (bool ok, ) = address(proxy).call(abi.encodeWithSignature("createSellOffer(address,uint64,uint128,uint128)",
             nft, 1, 20 ether, uint128(block.timestamp) + 5 days));
        require (ok, "Call failed createSellOffer()");

        //Call getSellOffer() to read the "Offer" struct in the "sellOffers" mapping.
        (bool okGetOffer, bytes memory answerOffer) = address(proxy).call(abi.encodeWithSignature("getSellOffer(uint256)", 0));
        require (okGetOffer, "Call failed getSellOffer()");  
        
        // Check that the offer has been created - Retrieve struct Offer
        MarketplaceNFT.Offer memory offer =  abi.decode(answerOffer, (MarketplaceNFT.Offer));

        // Retrieve the struct "Offer" in order to verify these elements   
        assertEq(offer.offerer, users.alice); // Check if the owner of the offer is "alice".
        assertEq(offer.nftAddress, address(nft)); // Checks if the NFT is the same as the one in the offer 
        assertEq(offer.deadline, block.timestamp + 5 days); // Check deadline
        assertEq(offer.tokenId, 1); // Checks token ID
        assertEq(offer.price, 20 ether); // Checks price 
        assertEq(offer.isEnded, false); // Check if the offer is still open

        /////////////////////////// ERROR CHECKING ///////////////////////////
        // bob tries to cancel it
        vm.stopPrank();
        vm.prank(users.bob);
        vm.warp(block.timestamp + 10 days);
        vm.expectRevert(bytes4(keccak256("NotOwner()")));
        (bool okOwner, ) = address(proxy).call(abi.encodeWithSignature("cancelSellOffer(uint256)", 0));
        require (okOwner, "Call failed cancelSellOffer() _ NotOwner");

        // Check that deadline has not passed
        vm.startPrank(users.alice);
        vm.warp(deadlineNotPassed);
        vm.expectRevert(bytes4(keccak256("DeadlineNotPassed()")));
        (bool okNotPassed, ) = address(proxy).call(abi.encodeWithSignature("cancelSellOffer(uint256)", 0));
        require (okNotPassed, "Call failed cancelSellOffer() _ DeadlineNotPassed");  

        //////////// CANCEL CHECKING ////////////////////////
        /// alice cancels the sell offer
        vm.warp(block.timestamp + 10 days);

        vm.expectEmit(true, false, false, false);
        emit SellOfferCancelled(0);

        (bool ok2, ) = address(proxy).call(abi.encodeWithSignature("cancelSellOffer(uint256)", 0));
        require (ok2, "Call failed cancelSellOffer()");

        (bool okGetOffer2, bytes memory answerOffer2) = address(proxy).call(abi.encodeWithSignature("getSellOffer(uint256)", 0));
        require (okGetOffer2, "Call failed getSellOffer()");  
        // Check that the offer has been created - Retrieve struct Offer
        MarketplaceNFT.Offer memory getSellOffer =  abi.decode(answerOffer2, (MarketplaceNFT.Offer));
        assertEq(getSellOffer.isEnded, true); 

        assertEq(nft.ownerOf(1), users.alice);

        ////////////////// ERROR CHECKING /////////
        /// alice tries to cancel it again
        vm.expectRevert(bytes4(keccak256("OfferClosed()")));
        (bool okOffer, ) = address(proxy).call(abi.encodeWithSignature("cancelSellOffer(uint256)", 0));
        require (okOffer, "Call failed cancelSellOffer() _ OfferClosed");
        
    }

    // _______________________________________
    // -------- CreateBuyOffer -------------
    // _______________________________________

    function test_CreateBuyOffer() public {
        ///////////// ERROR CHECKING ///////////////
        uint128 deadlinePassed = uint128(block.timestamp);
        vm.warp(block.timestamp + 5 days);
        /// bob creates a buy offer with wrong deadline
        vm.deal(users.bob, 50 ether);
        vm.startPrank(users.bob);
        vm.expectRevert(bytes4(keccak256("DeadlinePassed()")));
        (bool okDeadlinePassed, ) = address(proxy).call{value: 10 ether}(abi.encodeWithSignature("createBuyOffer(address,uint64,uint128)",
            nft, 1, uint128(deadlinePassed)));
        require (okDeadlinePassed, "Call failed createBuyOffer() _ DeadlinePassed");

        /// bob creates a buy offer with wrong price
        vm.expectRevert(bytes4(keccak256("BelowZero()")));
        (bool okBelowZero, ) = address(proxy).call{value: 0}(abi.encodeWithSignature("createBuyOffer(address,uint64,uint128)",
            nft, 1, uint128(deadlinePassed + 6 days)));
        require (okBelowZero, "Call failed createBuyOffer() _ BelowZero");    

        /////////////////////////// BUY OFFER CHECKING ///////////////////////////
        vm.expectEmit(true, false, false, false);
        emit BuyOfferCreated(1);

        (bool ok, ) = address(proxy).call{value: 20 ether}(abi.encodeWithSignature("createBuyOffer(address,uint64,uint128)",
            nft, 1, uint128(deadlinePassed + 6 days)));
        require (ok, "Call failed createBuyOffer()");

        //Call getBuyOffer() to read the "Offer" struct in the "buyOffers" mapping.
        (bool okGetOffer, bytes memory answerOffer) = address(proxy).call(abi.encodeWithSignature("getBuyOffer(uint256)", 0));
        require (okGetOffer, "Call failed getBuyOffer()");  
        
        // Check that the offer has been created - Retrieve struct Offer
        MarketplaceNFT.Offer memory offer =  abi.decode(answerOffer, (MarketplaceNFT.Offer));

        // Retrieve the struct "Offer" in order to verify these elements   
        assertEq(offer.offerer, users.bob); // Check if the owner of the offer is "alice".
        assertEq(offer.nftAddress, address(nft)); // Checks if the NFT is the same as the one in the offer 
        assertEq(offer.deadline, deadlinePassed + 6 days); // Check deadline
        assertEq(offer.tokenId, 1); // Checks token ID
        assertEq(offer.price, 20 ether); // Checks price 
        assertEq(offer.isEnded, false); // Check if the offer is still open

        (bool okCounter1, bytes memory answer2) = address(proxy).call(abi.encodeWithSignature("buyOfferIdCounter()"));
        require (okCounter1, "Call failed buyOfferIdCounter");
        uint256 offerIdCounter =  abi.decode(answer2, (uint256)); 
        assertEq(offerIdCounter, 1);
        assertEq(users.bob.balance, 30 ether);
        assertEq(address(proxy).balance, 20 ether);

        /// bob creates another Offer
        (bool ok2, ) = address(proxy).call{value: 15 ether}(abi.encodeWithSignature("createBuyOffer(address,uint64,uint128)",
            nft, 3, uint128(deadlinePassed + 6 days)));
        require (ok2, "Call failed createBuyOffer");

        assertEq(users.bob.balance, 15 ether);
        assertEq(address(proxy).balance, 35 ether);

        (bool okCounter2, bytes memory answer3) = address(proxy).call(abi.encodeWithSignature("buyOfferIdCounter()"));
        require (okCounter2, "Call failed buyOfferIdCounter");
        uint256 offerIdCounter2 =  abi.decode(answer3, (uint256)); 
        assertEq(offerIdCounter2, 2); 
        vm.stopPrank();
    }

    // _______________________________________
    // -------- AcceptBuyOffer -------------
    // _______________________________________

    function test_AcceptBuyOffer() public {
        
        uint128 deadlinePassed = uint128(block.timestamp);

        vm.startPrank(users.bob);
        vm.deal(users.bob, 50 ether);
        (bool ok, ) = address(proxy).call{value: 20 ether}(abi.encodeWithSignature("createBuyOffer(address,uint64,uint128)",
            nft, 1, uint128(deadlinePassed + 6 days)));
        require (ok, "Call failed createBuyOffer()");

        /////////////// ERROR CHECKING ////////////////
        // Alice tries to accept it
        vm.prank(users.charlie);
        vm.expectRevert(bytes4(keccak256("NoOwnerOfNft()")));
        (bool okOwnerOfNft, ) = address(proxy).call(abi.encodeWithSignature("acceptBuyOffer(uint256)", 0));
        require (okOwnerOfNft, "Call failed acceptBuyOffer() _ NoOwnerOfNft");


        // Test the revert if the deadline has passed
        vm.warp(uint128(deadlinePassed + 7 days));
        vm.startPrank(users.alice);
        vm.expectRevert(bytes4(keccak256("DeadlinePassed()")));
        (bool okTime, ) = address(proxy).call(abi.encodeWithSignature("acceptBuyOffer(uint256)", 0));
        require (okTime, "Call failed acceptBuyOffer() _ DeadlinePassed");  

        /////////// ACCEPT BUY OFFER CHECKING ////////////
        // Alice first approves the proxy to move her NFT
        vm.warp(uint128(deadlinePassed + 5 days));
        IERC721(nft).approve(address(proxy), 1);

        vm.expectEmit(true, false, false, false);
        emit BuyOfferAccepted(0);

        (bool ok2, ) = address(proxy).call(abi.encodeWithSignature("acceptBuyOffer(uint256)", 0));
        require (ok2, "Call failed acceptBuyOffer()");

        //Call getBuyOffer() to read the "Offer" struct in the "buyOffers" mapping.
        (bool okGetOffer, bytes memory answerOffer) = address(proxy).call(abi.encodeWithSignature("getBuyOffer(uint256)", 0));
        require (okGetOffer, "Call failed getBuyOffer()");  
        // Check that the offer has been created - Retrieve struct Offer
        MarketplaceNFT.Offer memory offer =  abi.decode(answerOffer, (MarketplaceNFT.Offer));
        // Retrieve the struct "Offer" in order to verify these elements   
        assertEq(offer.isEnded, true); // Check if the offer is still open
        assertEq(IERC721(nft).ownerOf(1), users.bob);
        assertEq(users.alice.balance, 20 ether);
        vm.stopPrank();

        ////////// ERROR CHECKING ///////////////
        // bob tries to accept it again
        vm.prank(users.bob);
        vm.expectRevert(bytes4(keccak256("OfferClosed()")));
        (bool okIsEnded, ) = address(proxy).call(abi.encodeWithSignature("acceptBuyOffer(uint256)", 0));
        require (okIsEnded, "Call failed acceptBuyOffer() _ OfferClosed");  

    }

    // _______________________________________
    // -------- CancelBuyOffer -------------
    // _______________________________________

     function test_CancelBuyOffer() public {

        uint128 deadlinePassed = uint128(block.timestamp);
        vm.startPrank(users.bob);
        vm.deal(users.bob, 50 ether);

        (bool ok, ) = address(proxy).call{value: 20 ether}(abi.encodeWithSignature("createBuyOffer(address,uint64,uint128)",
            nft, 1, uint128(deadlinePassed + 6 days)));
        require (ok, "Call failed createBuyOffer()");

        (bool ok2, ) = address(proxy).call{value: 15 ether}(abi.encodeWithSignature("createBuyOffer(address,uint64,uint128)",
            nft, 3, uint128(deadlinePassed + 6 days)));
        require (ok2, "Call failed createBuyOffer");
        /// Now bob has 15 ether balance and the proxy 35 ether

        /////////// ERROR CHECKING /////////////
        // Checks offer owner, returns error because Alice is not the owner for the offer, NotOwner() 
        vm.warp(deadlinePassed + 7 days);
        vm.prank(users.alice);
        vm.expectRevert(bytes4(keccak256("NotOwner()")));
        (bool okOwner, ) = address(proxy).call(abi.encodeWithSignature("cancelBuyOffer(uint256)", 0));
        require (okOwner, "Call failed cancelBuyOffer() _ NotOwner");

        // Checks if deadline has not passed DeadlineNotPassed() 
        vm.warp(deadlinePassed + 4 days);
        vm.startPrank(users.bob);
        vm.expectRevert(bytes4(keccak256("DeadlineNotPassed()")));
        (bool okTime, ) = address(proxy).call(abi.encodeWithSignature("cancelBuyOffer(uint256)", 0));
        require (okTime, "Call failed cancelBuyOffer() _ DeadlineNotPassed");  

        /////////// CANCELLATION CHECKING /////////////
        /// bob cancels the buy offer with id=0
        vm.warp(deadlinePassed + 7 days);
        vm.expectEmit(true, false, false, false);
        emit BuyOfferCancelled(0);

        (bool ok3, ) = address(proxy).call(abi.encodeWithSignature("cancelBuyOffer(uint256)", 0));
        require (ok3, "Call failed cancelBuyOffer");


        //Call getBuyOffer() to read the "Offer" struct in the "buyOffers" mapping.
        (bool okGetOffer, bytes memory answerOffer) = address(proxy).call(abi.encodeWithSignature("getBuyOffer(uint256)", 0));
        require (okGetOffer, "Call failed getBuyOffer()");  
        // Check that the offer has been created - Retrieve struct Offer
        MarketplaceNFT.Offer memory offer =  abi.decode(answerOffer, (MarketplaceNFT.Offer));
        // Retrieve the struct "Offer" in order to verify these elements   
        assertEq(offer.isEnded, true); 
        assertEq(users.bob.balance, 35 ether);
        assertEq(address(proxy).balance, 15 ether);


        /// bob cancels the buy offer with id=1
        vm.expectEmit(true, false, false, false);
        emit BuyOfferCancelled(1);
        (bool ok4, ) = address(proxy).call(abi.encodeWithSignature("cancelBuyOffer(uint256)", 1));
        require (ok4, "Call failed");

        (bool okGetOffer2, bytes memory answerOffer2) = address(proxy).call(abi.encodeWithSignature("getBuyOffer(uint256)", 0));
        require (okGetOffer2, "Call failed getBuyOffer()");  
        // Check that the offer has been created - Retrieve struct Offer
        MarketplaceNFT.Offer memory getOffer =  abi.decode(answerOffer2, (MarketplaceNFT.Offer));
        // Retrieve the struct "Offer" in order to verify these elements   
        assertEq(getOffer.isEnded, true); 
        assertEq(users.bob.balance, 50 ether);
        assertEq(address(proxy).balance, 0 ether);

        ///////// ERROR CHECKING ////////////
        // Checks if the offer is completed OfferClosed() 
        vm.expectRevert(bytes4(keccak256("OfferClosed()")));
        (bool okClosed, ) = address(proxy).call(abi.encodeWithSignature("cancelBuyOffer(uint256)", 0));
        require (okClosed, "Call failed cancelBuyOffer() _ OfferClosed");  

    }   


}