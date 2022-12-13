// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Locker is Ownable, ReentrancyGuard {

     uint256 public lockFee;
     bool public isPaused;
    
    // Lock struct
     struct Lock {
          uint256 id;
          IERC20 tokenAddress;
          address owner;
          uint256 amount;
          uint256 startDate;
          uint256 endDate;
    }

     Lock[] public locks;

     mapping (address => Lock[]) public myLocks;
     mapping (IERC20 => Lock[]) public tokenLocks;
     mapping (address => mapping(uint256 => uint256)) public globalToPersonalLock;
     mapping (IERC20 => mapping(uint256 => uint256)) public globalToTokenLock;

     // Events
     event NewLock(uint256 _id, IERC20 _tokenAddress, address _owner, uint256 _amount, uint256 _startDate, uint256 _endDate);
     event Unlock(uint256 _id, IERC20 _tokenAddress, address _owner, uint256 _amount);

     // Modifiers
     modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller can not be another smart contract!");
        _;
    }

     // Lock tokens
     function createLock(
          IERC20 _tokenAddress,
          uint256 _amount,
          uint256 _duration
     ) external nonReentrant callerIsUser {
          require(isPaused == false, "The smart contract is paused!");
          require(msg.value == lockFee, "You need to pay the fee!");
          require(_tokenAddress.transferFrom(msg.sender, address(this), _amount), "Transaction failed!");

          uint256 _durationInDays = _duration * 1 days;
          uint256 _id = locks.length;

          Lock memory newLock = Lock(_id, _tokenAddress, msg.sender, _amount, block.timestamp, block.timestamp + _durationInDays);

          locks.push(newLock);

          globalToPersonalLock[msg.sender][_id] = myLocks[msg.sender].length;
          globalToTokenLock[_tokenAddress][_id] = tokenLocks[_tokenAddress].length;

          myLocks[msg.sender].push(newLock);
          tokenLocks[_tokenAddress].push(newLock);

          emit NewLock(_id, _tokenAddress, msg.sender, _amount, block.timestamp, block.timestamp + _durationInDays);
     }

     // Unlock tokens
     function unlockTokens(uint256 _index) external nonReentrant callerIsUser {
          require(isPaused == false, "The smart contract is paused!");
          Lock memory _lock = locks[_index];

          uint256 _amount = _lock.amount;
          IERC20 _tokenAddress = _lock.tokenAddress;

          uint256 _personalId = globalToPersonalLock[msg.sender][_index];
          uint256 _tokenId = globalToTokenLock[_tokenAddress][_index];

          require(msg.sender == _lock.owner, "You are not the owner of the lock!");
          require(_amount != 0, "You already withdrawn the tokens!");

          locks[_index].amount = 0;
          myLocks[msg.sender][_personalId].amount = 0;
          tokenLocks[_tokenAddress][_tokenId].amount = 0;

          require(_lock.endDate <= block.timestamp, "You can't withdraw yet!");

          require(_tokenAddress.transferFrom(address(this), _lock.owner, _amount), "Transaction failed!");

          emit Unlock(_lock.id, _tokenAddress, _lock.owner, _amount);
    }

    // Receive function to allow the smart contract to receive ether
    receive() external payable {}

     // Withdraw ether
    function withdrawEther() external onlyOwner {
        uint256 _balance = address(this).balance;
        address _owner = owner();
        
        (bool sent, ) = _owner.call{value: _balance}("");
        require(sent, "Transaction failed!");
    }

    // Withdraw tokens
    function withdrawWrongTokens(IERC20 _tokenAddress) external onlyOwner {
        uint256 _balance = _tokenAddress.balanceOf(address(this));
        address _owner = owner();
        
        require(_tokenAddress.transfer(_owner, _balance), "Failing to transfer ERC20 tokens!");
    }

    // Setters
    function setNewFee(uint256 _newFee) external onlyOwner {
     lockFee = _newFee;
    }

    function togglePause() external onlyOwner {
     if (isPaused == false) {
          isPaused = true;
     } else {
          isPaused = false;
     }
    }

    // Getters
    function getLocksLength() public view returns (uint256) {
     return locks.length;
    }

    function getLockInfo(uint256 _index) public view returns (uint256, IERC20, uint256, uint256, uint256) {
     Lock memory theLock = locks[_index];

     return (theLock.id, theLock.tokenAddress, theLock.amount, theLock.startDate, theLock.endDate);
    }

    function getMyLocksLength(address _who) public view returns (uint256) {
     return myLocks[_who].length;
    }

    function getGlobalLockFromPersonal(address _who, uint256 _index) public view returns (Lock memory) {
     uint256 _id = globalToPersonalLock[_who][_index];

     return locks[_id];
    }

    function getGlobalLockFromToken(IERC20 _tokenAddress, uint256 _index) public view returns (Lock memory) {
     uint256 _id = globalToTokenLock[_tokenAddress][_index];

     return locks[_id];
    }

}
