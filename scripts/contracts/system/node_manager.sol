pragma solidity ^0.4.14;

import "../common/address_array.sol";
import "../common/SafeMath.sol";

/// @title The interface of node_manager
/// @author ["Cryptape Technologies <contact@cryptape.com>"]
interface NodeInterface {

    event NewNode(address indexed _node);
    event ApproveNode(address indexed _node);
    event DeleteNode(address indexed _node);
    event AddAdmin(address indexed _account, address indexed _sender);
    event SetStake(address indexed _node, uint stake);

    /// @notice Add an admin
    function addAdmin(address) public returns (bool);
    /// @notice Apply to be consensus node. status will be ready
    function newNode(address _node) public returns (bool);
    /// @notice Approve to be consensus node. status will be start
    function approveNode(address _node) public returns (bool);
    /// @notice Delete the consensus node that has been approved. status will be close
    function deleteNode(address _node) public returns (bool);
    /// @notice List the consensus nodes that have been approved
    /// which means list the node whose status is start
    function listNode() public constant returns (address[]);
    /*
     * @notice Get the status of the node:
     * @return 0: Close
     * @return 1: Ready
     * @return 2: Start
     */
    function getStatus(address _node) public constant returns (uint8);
    /// @notice Check the account is admin
    function isAdmin(address) public constant returns (bool);
    /// @notice Set node stake
    function setStake(address _node, uint stake) public;
    /// @notice Node stake list
    function listStake() public constant returns (uint[] _stakes);
    /// @notice Stake permillage
    function stakePermillage(address _node) public constant returns (uint);
}

/// @title Node manager contract
/// @author ["Cryptape Technologies <contact@cryptape.com>"]
/// @notice The address: 0x00000000000000000000000000000000013241a2
contract NodeManager is NodeInterface {

    mapping(address => NodeStatus) public status;
    mapping(address => bool) admins;
    // Recode the operation of the block
    mapping(uint => bool) block_op;
    // Consensus node list
    address[] nodes;
    mapping(address => uint) stakes;

    // Default: Close
    enum NodeStatus { Close, Ready, Start }

    modifier onlyAdmin {
        require(admins[msg.sender]);
        _;
    }

    // Should operate one time in a block
    modifier oneOperate {
        require(!block_op[block.number]);
        _;
    }

    modifier onlyClose(address _node) {
        require(NodeStatus.Close == status[_node]);
        _;
    }

    modifier onlyStart(address _node) {
        require(NodeStatus.Start == status[_node]);
        _;
    }

    modifier onlyReady(address _node) {
        require(NodeStatus.Ready == status[_node]);
        _;
    }

    /// @notice Setup
    function NodeManager(address[] _nodes, address[] _admins, uint[] _stakes) public {
        // Initialize the address to Start
        require(_nodes.length == _stakes.length);
        for (uint i = 0; i < _nodes.length; i++) {
            status[_nodes[i]] = NodeStatus.Start;
            nodes.push(_nodes[i]);
            stakes[_nodes[i]] = _stakes[i];
        }

        // Initialize the address of admins
        for (uint j = 0; j < _admins.length; j++) {
            admins[_admins[j]] = true;
        }
    }

    /// @notice Add an admin
    /// @param _account Address of the admin
    /// @return true if successed, otherwise false
    function addAdmin(address _account)
        public
        onlyAdmin
        returns (bool)
    {
        admins[_account] = true;
        AddAdmin(_account, msg.sender);
        return true;
    }

    /// @notice Add a new node
    /// @param _node The node to be added
    /// @return true if successed, otherwise false
    function newNode(address _node)
        public
        onlyClose(_node)
        returns (bool)
    {
        status[_node] = NodeStatus.Ready;
        NewNode(_node);
        return true;
    }

    /// @notice Approve the new node
    /// @param _node The node to be approved
    /// @return true if successed, otherwise false
    function approveNode(address _node)
        public
        onlyAdmin
        oneOperate
        onlyReady(_node)
        returns (bool)
    {
        status[_node] = NodeStatus.Start;
        block_op[block.number] = true;
        nodes.push(_node);
        ApproveNode(_node);
        return true;
    }

    /// @notice Delete the node
    /// @param _node The node to be deleted
    /// @return true if successed, otherwise false
    function deleteNode(address _node)
        public
        onlyAdmin
        oneOperate
        onlyStart(_node)
        returns (bool)
    {
        require(AddressArray.remove(_node, nodes));
        block_op[block.number] = false;
        status[_node] = NodeStatus.Close;
        stakes[_node] = 0;
        DeleteNode(_node);
        return true;
    }

    /// @notice Query the consensus nodes
    /// @return All the consensus nodes
    function listNode() public constant returns (address[]) {
        return nodes;
    }

    /// @notice Query the status of node
    /// @param _node The node to be deleted
    /// @return The status of the node
    function getStatus(address _node) public constant returns (uint8) {
        return uint8(status[_node]);
    }

    /// @notice Check the account is admin
    /// @param _account The address to be checked
    /// @return true if it is, otherwise false
    function isAdmin(address _account) public constant returns (bool) {
        return admins[_account];
    }

    /// @notice Set node stake
    function setStake(address _node, uint stake)
        public
        onlyAdmin
    {
        SetStake(_node, stake);
        stakes[_node] = stake;
    }

    /// @notice Node stake list
    /// @return All the node stake list
    function listStake() public constant returns (uint[] memory _stakes) {
        _stakes = new uint[](nodes.length);
        for (uint j = 0; j < nodes.length; j++) {
            _stakes[j] = stakes[nodes[j]];
        }
        return _stakes;
    }

    /// @notice Stake permillage
    /// This is the slot number which ignore the remainder, not exactly precise.
    /// https://en.wikipedia.org/wiki/Largest_remainder_method
    /// Hare quota
    function stakePermillage(address _node) public constant returns (uint) {
        uint total;
        for (uint j = 0; j < nodes.length; j++) {
            total = SafeMath.add(total, stakes[nodes[j]]);
        }
        return SafeMath.div(SafeMath.mul(stakes[_node], 1000), total);
    }
}
