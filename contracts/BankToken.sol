pragma solidity ^0.4.24;

import './SafeMath.sol';
import './StandardToken.sol';

contract Owned {
  address internal owner;

  constructor() public {
    owner = msg.sender;
  }

  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) onlyOwner external{
    owner = newOwner;
  }
}

contract BankToken is StandardToken, Owned{
  using SafeMath for uint;

  uint private decimals = 1000000000000000000;
  uint public totalSupply_ = 0;
  uint public stakedSupply; //Tokens currently staked
  uint public liquidSupply; //Tokens able to be sold or transferred
  uint public reserves; //Eth held to pay out liquid tokens
  uint public dividends; //Eth held to pay out dividends already issued
  uint public available; //Eth available for investing or issuing dividends
  uint public fraction = 100; //Fraction of reserves kept to cover all debts to liquid token holders, default is 100%
  uint public minBlocks = 10000; //Minimum number of blocks tokens must be staked for
  mapping (address => bool) public stakedAccount; //Accounts that are staking their tokens
  mapping (address => uint) public stakeExpiration; //Block number when account is able to unstake their tokens
  mapping (address => uint) public dividendsOwed; //Dividends currently owed to each address
  address[] public stakedIndex; //Index of all addresses that are currently staked
  address[] public dividendIndex;
  bool public locked; //Boolean to determine whether this contract is able to buy and sell tokens


  function transfer(address _to, uint256 _value) public returns (bool){
    require(!stakedAccount[msg.sender]);
    return super.transfer(_to, _value);
  }

  function buyTokens() payable external{
    require(!locked);
    require(msg.value > 0);
    //uint tokenPrice = calculatePrice();
    uint tokens = convertEtherToTokens(msg.value);
    //totalSupply += tokens;

    if(stakedAccount[msg.sender]){
      stakeExpiration[msg.sender] = block.number.add(minBlocks);
      stakedSupply += tokens;
      available += msg.value;
    } else {
      liquidSupply += tokens;
      uint fractionalReserve = msg.value.getFractionalAmount(fraction);
      reserves += fractionalReserve;
      if(msg.value.sub(fractionalReserve) > 0){
        available += msg.value.sub(fractionalReserve);
        //Pay some portion to dividends?
      }

    }
    //balanceOf(msg.sender) += tokens;
    _mint(msg.sender, tokens);
  }

  function sellTokens(uint _amount) external{
    require(!locked);
    require(!stakedAccount[msg.sender]);
    require(balanceOf(msg.sender) >= _amount);
    //uint tokenPrice = calculatePrice();
    uint value = convertTokensToEther(_amount);
    uint tokens;
    uint payout;

    if(value > reserves){
      //Run on bank
      autoLock();
      //Calculate tokens that can be sold
      if(value > (available + reserves)){
        tokens = convertEtherToTokens(reserves.add(available));
        payout = reserves.add(available);
      } else {
        available -= value.sub(reserves);
        tokens = _amount;
        payout = value;

        //Adjust reserves
        if(available > liquidSupply.sub(tokens).getFractionalAmount(fraction) ){
          uint newReserve = liquidSupply.sub(tokens).getFractionalAmount(fraction);
          available -= newReserve;
          reserves += newReserve;
        }
      }
      reserves = 0;

    } else {
      tokens = _amount;
      payout = value;
      reserves -= value.getFractionalAmount(fraction);
      //balanceOf(msg.sender) -= _amount;
      //totalSupply -= _amount;
    }
    _burn(msg.sender, tokens);
    liquidSupply -= tokens;
    msg.sender.transfer(payout);
  }

  function stakeTokens() external{
    //Cannot transfer or sell tokens while staked, but can withdraw dividends
    require(balanceOf(msg.sender) > 0);
    require(!stakedAccount[msg.sender]);
    uint unreservedFunds = convertTokensToEther(balanceOf(msg.sender)).getFractionalAmount(fraction);
    stakedAccount[msg.sender] = true;
    stakedIndex.push(msg.sender);
    stakeExpiration[msg.sender] = block.number.add(minBlocks);
    stakedSupply += balanceOf(msg.sender);
    liquidSupply -= balanceOf(msg.sender);
    reserves -= unreservedFunds;
    available += unreservedFunds;
  }

  function unstakeTokens() external{
    require(balanceOf(msg.sender) > 0);
    require(stakedAccount[msg.sender]);
    require(stakeExpiration[msg.sender] < block.number);
    uint reservedFunds = convertTokensToEther(balanceOf(msg.sender));
    if(reservedFunds > available){
      reserves += available;
      available = 0;
    } else {
      reserves += reservedFunds.getFractionalAmount(fraction);
      available -= reservedFunds.getFractionalAmount(fraction);
    }
    stakedSupply -= balanceOf(msg.sender);
    liquidSupply += balanceOf(msg.sender);
    stakedAccount[msg.sender] = false;
    for(uint8 i=0; i<stakedIndex.length; i++){
      if(stakedIndex[i] == msg.sender){
        stakedIndex[i] = stakedIndex[stakedIndex.length-1];
      }
    }
    stakedIndex.length --;
  }

  function issueDividend(uint _amount) onlyOwner external{
    require(available >= _amount);
    dividends += _amount;
    uint dividend = _amount.div(stakedSupply);
    for(uint8 i=0; i<stakedIndex.length; i++){
      if(dividendsOwed[stakedIndex[i]] == 0){
        dividendIndex.push(stakedIndex[i]);
      }
      dividendsOwed[stakedIndex[i]] += balanceOf(stakedIndex[i]).mul(dividend);
    }
    emit LogDividendsIssued(dividend);
  }

  function withdrawDividend() external{
    require(stakedAccount[msg.sender]);
    require(dividendsOwed[msg.sender] > 0);
    require(address(this).balance >= dividendsOwed[msg.sender]);
    uint amount = dividendsOwed[msg.sender];
    for(uint8 i=0; i<dividendIndex.length; i++){
      if(dividendIndex[i] == msg.sender){
        dividendIndex[i] = dividendIndex[dividendIndex.length-1];
      }
    }
    dividendIndex.length --;
    dividendsOwed[msg.sender] = 0;
    dividends -= amount;
    msg.sender.transfer(amount);
  }

  function invest(address _address, uint _amount) onlyOwner external{
    require(available >= _amount);
    //Make a check to confirm that the contract being sent money returns tokens that pay out dividends?
    //Or make it so investment can only be sent to the owner DAO who can manage the logic?
    available -= _amount;
    _address.transfer(_amount);
  }

  function removeFromReserves(uint _amount) onlyOwner external{
    require(reserves >= _amount);
    reserves -= _amount;
    available += _amount;
  }

  function addToReserves(uint _amount) onlyOwner external{
    require(available >= _amount);
    available -= _amount;
    reserves += _amount;
  }

  function changeFractionalReserve(uint _percent) onlyOwner external{
    require(_percent <= 100);
    require(_percent > 0);
    fraction = _percent;
    //Rebalance reserve
    if(liquidSupply > 0){
      reserves = liquidSupply.getFractionalAmount(_percent);
    }
  }

  function clearDividends() onlyOwner external{
    dividends = 0;
    for(uint8 i=0; i<dividendIndex.length; i++){
      dividendsOwed[dividendIndex[i]] = 0;
    }
    available = address(this).balance.sub(reserves);
  }

  function autoLock() private{
    locked = true;
    emit LogMarketState('Markets Locked');
  }

  function lockMarket() onlyOwner external{
    locked = true;
    emit LogMarketState('Markets Locked');
  }

  function unlockMarket() onlyOwner external{
    locked = false;
    emit LogMarketState('Markets Unlocked');
  }

  function convertTokensToEther(uint _tokens) public view returns (uint) {
    //Price floats based on money currently in reserves divided by liquid tokens
    if(reserves == 0){
      return _tokens;
    }
    if(liquidSupply == 0){
      return _tokens;
    }
    //uint reserveMultiplier = uint(100).div(fraction);
    return _tokens.mul(reserves).div(liquidSupply.getFractionalAmount(fraction));
  }

  function convertEtherToTokens(uint _wei) public view returns (uint) {
    //Price floats based on money currently in reserves divided by liquid tokens
    if(reserves == 0){
      return _wei;
    }
    if(liquidSupply == 0){
      return _wei;
    }
    return _wei.mul(liquidSupply).getFractionalAmount(fraction).div(reserves);
  }

  function() payable public{}

  event LogMarketState(string _message);
  event LogDividendsIssued(uint _etherPerToken);


}
