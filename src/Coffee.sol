// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title BuyMeACoffee
 * @author Rakib Hossain
 * @notice A decentralized platform for supporters to send tips to creators
 * @dev Allows creators to register and receive tips from supporters with messages
 */
contract BuyMeACoffee {
    /**
     * @notice Represents a supporter's message and tip
     * @param from Address of the supporter who sent the tip
     * @param timestamp Block timestamp when the tip was sent
     * @param name Display name of the supporter
     * @param message Personal message from the supporter
     */
    struct Memo {
        address from;
        uint256 timestamp;
        string name;
        string message;
    }

    /**
     * @notice Represents a registered creator's profile
     * @param name Display name of the creator
     * @param about Short bio or description of the creator
     * @param owner Payable address of the creator (receives withdrawals)
     * @param totalReceived Total amount of wei received by this creator
     */
    struct Creator {
        string name;
        string about;
        address payable owner;
        uint256 totalReceived;
    }

    /// @notice Mapping from creator address to their profile
    mapping(address => Creator) public creators;

    /// @notice Mapping from creator name hash to their address
    mapping(bytes32 => address) private creatorByName;

    /// @notice Mapping from creator address to their array of received memos
    mapping(address => Memo[]) private memosByCreator;

    /// @notice Mapping to track balance per creator (for accurate withdrawals)
    mapping(address => uint256) private creatorBalances;

    /**
     * @notice Emitted when a supporter sends a tip to a creator
     * @param creator Address of the creator receiving the tip
     * @param from Address of the supporter sending the tip
     * @param amount Amount of wei sent
     * @param timestamp Block timestamp of the transaction
     * @param name Display name of the supporter
     * @param message Message from the supporter
     */
    event NewCoffee(
        address indexed creator, address indexed from, uint256 amount, uint256 timestamp, string name, string message
    );

    /**
     * @notice Emitted when a new creator registers on the platform
     * @param creator Address of the registered creator
     * @param name Display name of the creator
     * @param about Bio or description of the creator
     */
    event CreatorRegistered(address indexed creator, string name, string about);

    /**
     * @notice Emitted when a creator withdraws their funds
     * @param creator Address of the creator
     * @param amount Amount of wei withdrawn
     */
    event FundsWithdrawn(address indexed creator, uint256 amount);

    /**
     * @notice Emitted when a creator updates their profile
     * @param creator Address of the creator
     * @param name New display name
     * @param about New bio/description
     */
    event CreatorUpdated(address indexed creator, string name, string about);

    /// @notice Thrown when an empty name is provided
    error EmptyName();

    /// @notice Thrown when trying to register an already registered creator
    error AlreadyRegistered();

    /// @notice Thrown when no ETH is sent with a tip
    error NoFundsSent();

    /// @notice Thrown when trying to tip an unregistered creator
    error CreatorNotRegistered();

    /// @notice Thrown when caller is not a registered creator
    error NotACreator();

    /// @notice Thrown when there are no funds to withdraw
    error NoFundsToWithdraw();

    /// @notice Thrown when a withdrawal transfer fails
    error WithdrawFailed();

    /**
     * @notice Registers a new creator on the platform
     * @dev Creator can only register once; address becomes their unique identifier
     * @param _name Display name for the creator (must not be empty)
     * @param _about Short bio or description of the creator
     */
    function registerCreator(string calldata _name, string calldata _about) external {
        if (bytes(_name).length == 0) revert EmptyName();
        if (creators[msg.sender].owner != address(0)) {
            revert AlreadyRegistered();
        }

        bytes32 nameHash = keccak256(bytes(_name));
        if (creatorByName[nameHash] != address(0)) revert AlreadyRegistered();

        creators[msg.sender] = Creator({name: _name, about: _about, owner: payable(msg.sender), totalReceived: 0});

        creatorByName[nameHash] = msg.sender;

        emit CreatorRegistered(msg.sender, _name, _about);
    }

    /**
     * @notice Updates an existing creator's profile information
     * @dev Only the creator themselves can update their profile
     * @param _name New display name (must not be empty)
     * @param _about New bio or description
     */
    function updateCreator(string calldata _name, string calldata _about) external {
        if (creators[msg.sender].owner == address(0)) revert NotACreator();
        if (bytes(_name).length == 0) revert EmptyName();

        bytes32 oldHash = keccak256(bytes(creators[msg.sender].name));
        bytes32 newHash = keccak256(bytes(_name));

        if (oldHash != newHash) {
            if (creatorByName[newHash] != address(0)) {
                revert AlreadyRegistered();
            }
            delete creatorByName[oldHash];
            creatorByName[newHash] = msg.sender;
        }

        creators[msg.sender].name = _name;
        creators[msg.sender].about = _about;

        emit CreatorUpdated(msg.sender, _name, _about);
    }

    /**
     * @notice Sends a tip (coffee) to a creator with a message
     * @dev Requires ETH to be sent with the transaction
     * @param _creator Address of the creator receiving the tip
     * @param _name Display name of the supporter (can be anonymous)
     * @param _message Personal message to the creator
     */
    function buyCoffee(address payable _creator, string calldata _name, string calldata _message) external payable {
        if (msg.value == 0) revert NoFundsSent();
        if (creators[_creator].owner == address(0)) {
            revert CreatorNotRegistered();
        }

        // Record the memo
        memosByCreator[_creator].push(
            Memo({from: msg.sender, timestamp: block.timestamp, name: _name, message: _message})
        );

        // Update creator's totals
        creators[_creator].totalReceived += msg.value;
        creatorBalances[_creator] += msg.value;

        emit NewCoffee(_creator, msg.sender, msg.value, block.timestamp, _name, _message);
    }

    /**
     * @notice Allows a creator to withdraw their accumulated tips
     * @dev Transfers the entire balance to the creator's address
     */
    function withdraw() external {
        if (creators[msg.sender].owner == address(0)) revert NotACreator();

        uint256 amount = creatorBalances[msg.sender];
        if (amount == 0) revert NoFundsToWithdraw();

        // Reset balance before transfer (Checks-Effects-Interactions pattern)
        creatorBalances[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            // Revert balance if transfer fails
            creatorBalances[msg.sender] = amount;
            revert WithdrawFailed();
        }

        emit FundsWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Retrieves all memos (tips with messages) for a specific creator
     * @param _creator Address of the creator
     * @return Array of Memo structs containing supporter messages and tips
     */
    function getMemos(address _creator) external view returns (Memo[] memory) {
        return memosByCreator[_creator];
    }

    /**
     * @notice Retrieves the profile information for a specific creator
     * @param _creator Address of the creator
     * @return Creator struct containing profile information
     */
    function getCreator(address _creator) external view returns (Creator memory) {
        return creators[_creator];
    }

    /**
     * @notice Retrieves the profile information for a specific creator
     * @param _name Name of the creator
     * @return Creator struct containing profile information
     */

    function getCreatorByName(string calldata _name) external view returns (Creator memory) {
        address creator = creatorByName[keccak256(bytes(_name))];
        if (creator == address(0)) revert CreatorNotRegistered();
        return creators[creator];
    }

    /**
     * @notice Gets the current withdrawable balance for a creator
     * @param _creator Address of the creator
     * @return Balance in wei available for withdrawal
     */
    function getCreatorBalance(address _creator) external view returns (uint256) {
        return creatorBalances[_creator];
    }

    /**
     * @notice Gets the total number of memos (tips) a creator has received
     * @param _creator Address of the creator
     * @return Number of memos received
     */
    function getMemoCount(address _creator) external view returns (uint256) {
        return memosByCreator[_creator].length;
    }

    /**
     * @notice Retrieves a paginated list of memos for gas efficiency
     * @dev Useful for creators with many memos to avoid out-of-gas errors
     * @param _creator Address of the creator
     * @param _offset Starting index for pagination
     * @param _limit Maximum number of memos to return
     * @return Array of Memo structs (paginated)
     */
    function getMemosPaginated(address _creator, uint256 _offset, uint256 _limit)
        external
        view
        returns (Memo[] memory)
    {
        Memo[] storage allMemos = memosByCreator[_creator];

        if (_offset >= allMemos.length) {
            return new Memo[](0);
        }

        uint256 end = _offset + _limit;
        if (end > allMemos.length) {
            end = allMemos.length;
        }

        uint256 size = end - _offset;
        Memo[] memory page = new Memo[](size);

        for (uint256 i = 0; i < size; i++) {
            page[i] = allMemos[_offset + i];
        }

        return page;
    }
}
