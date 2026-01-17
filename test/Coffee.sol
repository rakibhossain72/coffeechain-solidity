// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {BuyMeACoffee} from "../src/Coffee.sol";

/**
 * @title RejectPayment
 * @notice A malicious contract that rejects any incoming payments
 * @dev Used to test withdrawal failure scenarios in BuyMeACoffee
 */
contract RejectPayment {
    address public buyMeACoffee;

    constructor(address _buyMeACoffee) {
        buyMeACoffee = _buyMeACoffee;
    }

    receive() external payable {
        revert("Rejecting payment");
    }
}

/**
 * @title BuyMeACoffeeTest
 * @notice Comprehensive test suite for BuyMeACoffee contract with 100% coverage
 * @dev Tests all functions, edge cases, access control, and reverts
 */
contract BuyMeACoffeeTest is Test {
    BuyMeACoffee public coffee;

    // Test accounts
    address public creator1;
    address public creator2;
    address public supporter1;
    address public supporter2;
    address public nonCreator;

    // Test constants
    string constant CREATOR1_NAME = "Alice Creator";
    string constant CREATOR1_ABOUT = "Building cool stuff";
    string constant CREATOR2_NAME = "Bob Builder";
    string constant CREATOR2_ABOUT = "Making DApps";
    string constant SUPPORTER1_NAME = "Charlie Supporter";
    string constant SUPPORTER2_NAME = "Diana Fan";
    string constant MESSAGE1 = "Great work!";
    string constant MESSAGE2 = "Love your content";
    uint256 constant TIP_AMOUNT = 1 ether;

    // Events to test
    event CreatorRegistered(address indexed creator, string name, string about);
    event NewCoffee(
        address indexed creator, address indexed from, uint256 amount, uint256 timestamp, string name, string message
    );
    event FundsWithdrawn(address indexed creator, uint256 amount);
    event CreatorUpdated(address indexed creator, string name, string about);

    function setUp() public {
        coffee = new BuyMeACoffee();

        // Set up test accounts with labels for easier debugging
        creator1 = makeAddr("creator1");
        creator2 = makeAddr("creator2");
        supporter1 = makeAddr("supporter1");
        supporter2 = makeAddr("supporter2");
        nonCreator = makeAddr("nonCreator");

        // Fund test accounts
        vm.deal(creator1, 100 ether);
        vm.deal(creator2, 100 ether);
        vm.deal(supporter1, 100 ether);
        vm.deal(supporter2, 100 ether);
        vm.deal(nonCreator, 100 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // REGISTRATION TESTS
    // ══════════════════════════════════════════════════════════════════════════

    function test_RegisterCreator_Success() public {
        vm.startPrank(creator1);

        vm.expectEmit(true, false, false, true);
        emit CreatorRegistered(creator1, CREATOR1_NAME, CREATOR1_ABOUT);

        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        BuyMeACoffee.Creator memory creator = coffee.getCreator(creator1);
        assertEq(creator.name, CREATOR1_NAME);
        assertEq(creator.about, CREATOR1_ABOUT);
        assertEq(creator.owner, creator1);
        assertEq(creator.totalReceived, 0);

        vm.stopPrank();
    }

    function test_RegisterCreator_EmptyName_Reverts() public {
        vm.startPrank(creator1);

        vm.expectRevert(BuyMeACoffee.EmptyName.selector);
        coffee.registerCreator("", CREATOR1_ABOUT);

        vm.stopPrank();
    }

    function test_RegisterCreator_AlreadyRegistered_Reverts() public {
        vm.startPrank(creator1);

        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.expectRevert(BuyMeACoffee.AlreadyRegistered.selector);
        coffee.registerCreator("New Name", "New About");

        vm.stopPrank();
    }

    function test_RegisterCreator_EmptyAbout_Success() public {
        vm.startPrank(creator1);

        coffee.registerCreator(CREATOR1_NAME, "");

        BuyMeACoffee.Creator memory creator = coffee.getCreator(creator1);
        assertEq(creator.name, CREATOR1_NAME);
        assertEq(creator.about, "");

        vm.stopPrank();
    }

    function test_RegisterCreator_MultipleCreators() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(creator2);
        coffee.registerCreator(CREATOR2_NAME, CREATOR2_ABOUT);

        BuyMeACoffee.Creator memory c1 = coffee.getCreator(creator1);
        BuyMeACoffee.Creator memory c2 = coffee.getCreator(creator2);

        assertEq(c1.name, CREATOR1_NAME);
        assertEq(c2.name, CREATOR2_NAME);
    }

    function test_RegisterCreator_LongStrings() public {
        string memory longName = "This is a very long name that someone might use for their creator profile";
        string memory longAbout =
            "This is an extremely long about section that describes in great detail what this creator does and their background and interests and goals and aspirations";

        vm.prank(creator1);
        coffee.registerCreator(longName, longAbout);

        BuyMeACoffee.Creator memory creator = coffee.getCreator(creator1);
        assertEq(creator.name, longName);
        assertEq(creator.about, longAbout);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // UPDATE CREATOR TESTS
    // ══════════════════════════════════════════════════════════════════════════

    function test_UpdateCreator_Success() public {
        vm.startPrank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        string memory newName = "Updated Name";
        string memory newAbout = "Updated About";

        vm.expectEmit(true, false, false, true);
        emit CreatorUpdated(creator1, newName, newAbout);

        coffee.updateCreator(newName, newAbout);

        BuyMeACoffee.Creator memory creator = coffee.getCreator(creator1);
        assertEq(creator.name, newName);
        assertEq(creator.about, newAbout);

        vm.stopPrank();
    }

    function test_UpdateCreator_NotRegistered_Reverts() public {
        vm.startPrank(nonCreator);

        vm.expectRevert(BuyMeACoffee.NotACreator.selector);
        coffee.updateCreator("Name", "About");

        vm.stopPrank();
    }

    function test_UpdateCreator_EmptyName_Reverts() public {
        vm.startPrank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.expectRevert(BuyMeACoffee.EmptyName.selector);
        coffee.updateCreator("", "New About");

        vm.stopPrank();
    }

    function test_UpdateCreator_PreservesTotalReceived() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: TIP_AMOUNT}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        vm.prank(creator1);
        coffee.updateCreator("New Name", "New About");

        BuyMeACoffee.Creator memory creator = coffee.getCreator(creator1);
        assertEq(creator.totalReceived, TIP_AMOUNT);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // BUY COFFEE TESTS
    // ══════════════════════════════════════════════════════════════════════════

    function test_BuyCoffee_Success() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.startPrank(supporter1);

        vm.expectEmit(true, true, false, true);
        emit NewCoffee(creator1, supporter1, TIP_AMOUNT, block.timestamp, SUPPORTER1_NAME, MESSAGE1);

        coffee.buyCoffee{value: TIP_AMOUNT}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        BuyMeACoffee.Creator memory creator = coffee.getCreator(creator1);
        assertEq(creator.totalReceived, TIP_AMOUNT);
        assertEq(coffee.getCreatorBalance(creator1), TIP_AMOUNT);

        vm.stopPrank();
    }

    function test_BuyCoffee_NoFunds_Reverts() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.startPrank(supporter1);

        vm.expectRevert(BuyMeACoffee.NoFundsSent.selector);
        coffee.buyCoffee{value: 0}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        vm.stopPrank();
    }

    function test_BuyCoffee_CreatorNotRegistered_Reverts() public {
        vm.startPrank(supporter1);

        vm.expectRevert(BuyMeACoffee.CreatorNotRegistered.selector);
        coffee.buyCoffee{value: TIP_AMOUNT}(payable(nonCreator), SUPPORTER1_NAME, MESSAGE1);

        vm.stopPrank();
    }

    function test_BuyCoffee_MultipleTips() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        vm.prank(supporter2);
        coffee.buyCoffee{value: 2 ether}(payable(creator1), SUPPORTER2_NAME, MESSAGE2);

        BuyMeACoffee.Creator memory creator = coffee.getCreator(creator1);
        assertEq(creator.totalReceived, 3 ether);
        assertEq(coffee.getCreatorBalance(creator1), 3 ether);
    }

    function test_BuyCoffee_CreatesMemo() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: TIP_AMOUNT}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        BuyMeACoffee.Memo[] memory memos = coffee.getMemos(creator1);
        assertEq(memos.length, 1);
        assertEq(memos[0].from, supporter1);
        assertEq(memos[0].name, SUPPORTER1_NAME);
        assertEq(memos[0].message, MESSAGE1);
        assertEq(memos[0].timestamp, block.timestamp);
    }

    function test_BuyCoffee_EmptyNameAndMessage() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: TIP_AMOUNT}(payable(creator1), "", "");

        BuyMeACoffee.Memo[] memory memos = coffee.getMemos(creator1);
        assertEq(memos[0].name, "");
        assertEq(memos[0].message, "");
    }

    function test_BuyCoffee_DifferentAmounts() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 0.1 ether;
        amounts[1] = 0.5 ether;
        amounts[2] = 1 ether;
        amounts[3] = 5 ether;
        amounts[4] = 10 ether;

        uint256 totalExpected = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            vm.prank(supporter1);
            coffee.buyCoffee{value: amounts[i]}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);
            totalExpected += amounts[i];
        }

        assertEq(coffee.getCreatorBalance(creator1), totalExpected);
    }

    function test_BuyCoffee_SameSupporterMultipleTimes() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.startPrank(supporter1);
        coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, "First tip");
        coffee.buyCoffee{value: 2 ether}(payable(creator1), SUPPORTER1_NAME, "Second tip");
        coffee.buyCoffee{value: 3 ether}(payable(creator1), SUPPORTER1_NAME, "Third tip");
        vm.stopPrank();

        BuyMeACoffee.Memo[] memory memos = coffee.getMemos(creator1);
        assertEq(memos.length, 3);
        assertEq(coffee.getCreatorBalance(creator1), 6 ether);
    }

    function test_BuyCoffee_ToMultipleCreators() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(creator2);
        coffee.registerCreator(CREATOR2_NAME, CREATOR2_ABOUT);

        vm.startPrank(supporter1);
        coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);
        coffee.buyCoffee{value: 2 ether}(payable(creator2), SUPPORTER1_NAME, MESSAGE2);
        vm.stopPrank();

        assertEq(coffee.getCreatorBalance(creator1), 1 ether);
        assertEq(coffee.getCreatorBalance(creator2), 2 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // WITHDRAW TESTS
    // ══════════════════════════════════════════════════════════════════════════

    function test_Withdraw_Success() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: TIP_AMOUNT}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        uint256 balanceBefore = creator1.balance;

        vm.startPrank(creator1);

        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(creator1, TIP_AMOUNT);

        coffee.withdraw();

        assertEq(creator1.balance, balanceBefore + TIP_AMOUNT);
        assertEq(coffee.getCreatorBalance(creator1), 0);

        vm.stopPrank();
    }

    function test_Withdraw_NotACreator_Reverts() public {
        vm.startPrank(nonCreator);

        vm.expectRevert(BuyMeACoffee.NotACreator.selector);
        coffee.withdraw();

        vm.stopPrank();
    }

    function test_Withdraw_NoFunds_Reverts() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.startPrank(creator1);

        vm.expectRevert(BuyMeACoffee.NoFundsToWithdraw.selector);
        coffee.withdraw();

        vm.stopPrank();
    }

    function test_Withdraw_MultipleTimes() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        // First tip and withdraw
        vm.prank(supporter1);
        coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        vm.prank(creator1);
        coffee.withdraw();

        assertEq(coffee.getCreatorBalance(creator1), 0);

        // Second tip and withdraw
        vm.prank(supporter2);
        coffee.buyCoffee{value: 2 ether}(payable(creator1), SUPPORTER2_NAME, MESSAGE2);

        uint256 balanceBefore = creator1.balance;

        vm.prank(creator1);
        coffee.withdraw();

        assertEq(creator1.balance, balanceBefore + 2 ether);
        assertEq(coffee.getCreatorBalance(creator1), 0);
    }

    function test_Withdraw_AfterMultipleTips() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        vm.prank(supporter2);
        coffee.buyCoffee{value: 2 ether}(payable(creator1), SUPPORTER2_NAME, MESSAGE2);

        vm.prank(supporter1);
        coffee.buyCoffee{value: 3 ether}(payable(creator1), SUPPORTER1_NAME, "Another tip");

        uint256 balanceBefore = creator1.balance;

        vm.prank(creator1);
        coffee.withdraw();

        assertEq(creator1.balance, balanceBefore + 6 ether);
    }

    function test_Withdraw_DoesNotAffectOtherCreators() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(creator2);
        coffee.registerCreator(CREATOR2_NAME, CREATOR2_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        vm.prank(supporter1);
        coffee.buyCoffee{value: 2 ether}(payable(creator2), SUPPORTER1_NAME, MESSAGE1);

        vm.prank(creator1);
        coffee.withdraw();

        assertEq(coffee.getCreatorBalance(creator1), 0);
        assertEq(coffee.getCreatorBalance(creator2), 2 ether);
    }

    function test_Withdraw_PreservesTotalReceived() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: TIP_AMOUNT}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        vm.prank(creator1);
        coffee.withdraw();

        BuyMeACoffee.Creator memory creator = coffee.getCreator(creator1);
        assertEq(creator.totalReceived, TIP_AMOUNT);
    }

    // Test withdrawal to contract that reverts
    function test_Withdraw_FailedTransfer_Reverts() public {
        // Deploy malicious contract that rejects payments
        RejectPayment malicious = new RejectPayment(address(coffee));

        // Register malicious contract as a creator
        vm.prank(address(malicious));
        coffee.registerCreator("Malicious", "I reject payments");

        vm.prank(supporter1);
        coffee.buyCoffee{value: TIP_AMOUNT}(payable(address(malicious)), SUPPORTER1_NAME, MESSAGE1);

        vm.startPrank(address(malicious));
        vm.expectRevert(BuyMeACoffee.WithdrawFailed.selector);
        coffee.withdraw();
        vm.stopPrank();

        // Balance should be restored after failed withdrawal
        assertEq(coffee.getCreatorBalance(address(malicious)), TIP_AMOUNT);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════

    function test_GetMemos_EmptyForNewCreator() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        BuyMeACoffee.Memo[] memory memos = coffee.getMemos(creator1);
        assertEq(memos.length, 0);
    }

    function test_GetMemos_EmptyForNonCreator() public {
        BuyMeACoffee.Memo[] memory memos = coffee.getMemos(nonCreator);
        assertEq(memos.length, 0);
    }

    function test_GetMemos_ReturnsAllMemos() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        vm.prank(supporter2);
        coffee.buyCoffee{value: 2 ether}(payable(creator1), SUPPORTER2_NAME, MESSAGE2);

        BuyMeACoffee.Memo[] memory memos = coffee.getMemos(creator1);
        assertEq(memos.length, 2);
        assertEq(memos[0].from, supporter1);
        assertEq(memos[1].from, supporter2);
    }

    function test_GetCreator_UnregisteredReturnsEmpty() public {
        BuyMeACoffee.Creator memory creator = coffee.getCreator(nonCreator);
        assertEq(creator.name, "");
        assertEq(creator.about, "");
        assertEq(creator.owner, address(0));
        assertEq(creator.totalReceived, 0);
    }

    function test_GetCreator_ReturnsCorrectData() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        BuyMeACoffee.Creator memory creator = coffee.getCreator(creator1);
        assertEq(creator.name, CREATOR1_NAME);
        assertEq(creator.about, CREATOR1_ABOUT);
        assertEq(creator.owner, creator1);
    }

    function test_GetCreatorBalance_Zero() public {
        assertEq(coffee.getCreatorBalance(creator1), 0);
    }

    function test_GetCreatorBalance_AfterTips() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: 5 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        assertEq(coffee.getCreatorBalance(creator1), 5 ether);
    }

    function test_GetCreatorBalance_AfterWithdraw() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: 3 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        vm.prank(creator1);
        coffee.withdraw();

        assertEq(coffee.getCreatorBalance(creator1), 0);
    }

    function test_GetMemoCount_Zero() public {
        assertEq(coffee.getMemoCount(creator1), 0);
    }

    function test_GetMemoCount_AfterTips() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(supporter1);
            coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);
        }

        assertEq(coffee.getMemoCount(creator1), 5);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PAGINATION TESTS
    // ══════════════════════════════════════════════════════════════════════════

    function test_GetMemosPaginated_EmptyArray() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        BuyMeACoffee.Memo[] memory memos = coffee.getMemosPaginated(creator1, 0, 10);
        assertEq(memos.length, 0);
    }

    function test_GetMemosPaginated_OffsetBeyondLength() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        BuyMeACoffee.Memo[] memory memos = coffee.getMemosPaginated(creator1, 10, 5);
        assertEq(memos.length, 0);
    }

    function test_GetMemosPaginated_FirstPage() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        // Create 10 memos
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(supporter1);
            coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);
        }

        BuyMeACoffee.Memo[] memory memos = coffee.getMemosPaginated(creator1, 0, 5);
        assertEq(memos.length, 5);
        assertEq(memos[0].from, supporter1);
    }

    function test_GetMemosPaginated_MiddlePage() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(supporter1);
            coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);
        }

        BuyMeACoffee.Memo[] memory memos = coffee.getMemosPaginated(creator1, 3, 4);
        assertEq(memos.length, 4);
    }

    function test_GetMemosPaginated_LastPage() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        for (uint256 i = 0; i < 7; i++) {
            vm.prank(supporter1);
            coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);
        }

        BuyMeACoffee.Memo[] memory memos = coffee.getMemosPaginated(creator1, 5, 5);
        assertEq(memos.length, 2); // Only 2 remaining
    }

    function test_GetMemosPaginated_LimitExceedsRemaining() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(supporter1);
            coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);
        }

        BuyMeACoffee.Memo[] memory memos = coffee.getMemosPaginated(creator1, 0, 100);
        assertEq(memos.length, 5);
    }

    function test_GetMemosPaginated_SingleItem() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.prank(supporter1);
        coffee.buyCoffee{value: 1 ether}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        BuyMeACoffee.Memo[] memory memos = coffee.getMemosPaginated(creator1, 0, 1);
        assertEq(memos.length, 1);
        assertEq(memos[0].name, SUPPORTER1_NAME);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MISSING COVERAGE TESTS
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Tests the getCreatorByName view function
     */
    function test_GetCreatorByName_Success() public {
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        BuyMeACoffee.Creator memory creator = coffee.getCreatorByName(CREATOR1_NAME);
        assertEq(creator.name, CREATOR1_NAME);
        assertEq(creator.owner, creator1);
    }

    /**
     * @notice Tests that getCreatorByName reverts for unregistered names
     */
    function test_GetCreatorByName_NotRegistered_Reverts() public {
        vm.expectRevert(BuyMeACoffee.CreatorNotRegistered.selector);
        coffee.getCreatorByName("NonExistentName");
    }

    /**
     * @notice Tests updateCreator when the name remains the same (branch coverage)
     */
    function test_UpdateCreator_SameName_Success() public {
        vm.startPrank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        // Update only the 'about' section, keeping the name identical
        coffee.updateCreator(CREATOR1_NAME, "New About Info");

        BuyMeACoffee.Creator memory creator = coffee.getCreator(creator1);
        assertEq(creator.name, CREATOR1_NAME);
        assertEq(creator.about, "New About Info");
        vm.stopPrank();
    }

    /**
     * @notice Tests that updateCreator reverts if the new name is already taken by another creator
     */
    function test_UpdateCreator_NewNameAlreadyTaken_Reverts() public {
        // Register Creator 1
        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        // Register Creator 2
        vm.prank(creator2);
        coffee.registerCreator(CREATOR2_NAME, CREATOR2_ABOUT);

        // Creator 1 tries to change their name to Creator 2's name
        vm.startPrank(creator1);
        vm.expectRevert(BuyMeACoffee.AlreadyRegistered.selector);
        coffee.updateCreator(CREATOR2_NAME, "Trying to steal name");
        vm.stopPrank();
    }

    /**
     * @notice Tests updating to a completely new, available name
     */
    function test_UpdateCreator_NewName_Success() public {
        vm.startPrank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        string memory brandNewName = "Brand New Name";
        coffee.updateCreator(brandNewName, CREATOR1_ABOUT);

        // Verify mapping was updated and old name was deleted
        BuyMeACoffee.Creator memory creator = coffee.getCreatorByName(brandNewName);
        assertEq(creator.owner, creator1);

        // This should now revert because the old name was deleted
        vm.expectRevert(BuyMeACoffee.CreatorNotRegistered.selector);
        coffee.getCreatorByName(CREATOR1_NAME);
        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════

    function testFuzz_BuyCoffee_Amount(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1000 ether);

        vm.prank(creator1);
        coffee.registerCreator(CREATOR1_NAME, CREATOR1_ABOUT);

        vm.deal(supporter1, amount);

        vm.prank(supporter1);
        coffee.buyCoffee{value: amount}(payable(creator1), SUPPORTER1_NAME, MESSAGE1);

        assertEq(coffee.getCreatorBalance(creator1), amount);
    }
}
