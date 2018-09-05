var BigNumber = require('bignumber.js');

const Token = artifacts.require("./BankToken.sol");

const ETH = 1000000000000000000;

contract('Bank Token Contract', async() => {
  const owner = web3.eth.accounts[0];
  const user1 = web3.eth.accounts[1];
  const user2 = web3.eth.accounts[2];
  const user3 = web3.eth.accounts[3];
  const user4 = web3.eth.accounts[4];
  const user5 = web3.eth.accounts[5];

  it('Deploy contract', async() => {
    token = await Token.new();
    await token.changeFractionalReserve(80);
  });

  it('Buy tokens', async() => {
    await token.buyTokens({from: user1, value: 10*ETH});
    let user1Balance = await token.balanceOf(user1);
    console.log('User 1: ' + user1Balance);

    let liquidSupply = await token.liquidSupply();
    let stakedSupply = await token.stakedSupply();
    let reserves = await token.reserves();
    let available = await token.available();
    let tokenPrice = await token.convertTokensToEther(ETH);

    console.log('Liquid Supply: ' + liquidSupply/ETH);
    console.log('Staked Supply: ' + stakedSupply/ETH);
    console.log('Reserve: ' + reserves/ETH);
    console.log('Available Funds: ' + available/ETH);
    console.log('Token Price: ' + tokenPrice);

    await token.stakeTokens({from: user1});

    liquidSupply = await token.liquidSupply();
    stakedSupply = await token.stakedSupply();
    reserves = await token.reserves();
    available = await token.available();
    tokenPrice = await token.convertTokensToEther(ETH);

    console.log('Liquid Supply: ' + liquidSupply/ETH);
    console.log('Staked Supply: ' + stakedSupply/ETH);
    console.log('Reserve: ' + reserves/ETH);
    console.log('Available Funds: ' + available/ETH);
    console.log('Token Price: ' + tokenPrice);

    await token.buyTokens({from: user2, value: 5*ETH});
    let user2Balance = await token.balanceOf(user2);
    console.log('User 2: ' + user2Balance);

    liquidSupply = await token.liquidSupply();
    stakedSupply = await token.stakedSupply();
    reserves = await token.reserves();
    available = await token.available();
    tokenPrice = await token.convertTokensToEther(ETH);

    console.log('Liquid Supply: ' + liquidSupply/ETH);
    console.log('Staked Supply: ' + stakedSupply/ETH);
    console.log('Reserve: ' + reserves/ETH);
    console.log('Available Funds: ' + available/ETH);
    console.log('Token Price: ' + tokenPrice);
  });

  it('Invest money', async() => {
    await token.invest(owner, 3*ETH, {from: owner});

    let liquidSupply = await token.liquidSupply();
    let stakedSupply = await token.stakedSupply();
    let reserves = await token.reserves();
    let available = await token.available();
    let tokenPrice = await token.convertTokensToEther(ETH);

    console.log('Liquid Supply: ' + liquidSupply/ETH);
    console.log('Staked Supply: ' + stakedSupply/ETH);
    console.log('Reserve: ' + reserves/ETH);
    console.log('Available Funds: ' + available/ETH);
    console.log('Token Price: ' + tokenPrice);

  });

  it('Change price by altering reserves', async() => {
    let reserves = await token.reserves();
    await token.addToReserves(reserves*0.01);
    tokenPrice = await token.convertTokensToEther(ETH);
    console.log('Token Price: ' + tokenPrice);
    available = await token.available();
    console.log('Available Funds: ' + available/ETH);
  });

  it('Sell tokens', async() => {
    let user2Balance = await token.balanceOf(user2);
    await token.sellTokens(user2Balance, {from: user2});
    user2Balance = await token.balanceOf(user2);
    console.log('User 2: ' + user2Balance);

    let liquidSupply = await token.liquidSupply();
    let stakedSupply = await token.stakedSupply();
    let reserves = await token.reserves();
    let available = await token.available();
    let tokenPrice = await token.convertTokensToEther(ETH);

    console.log('Liquid Supply: ' + liquidSupply/ETH);
    console.log('Staked Supply: ' + stakedSupply/ETH);
    console.log('Reserve: ' + reserves/ETH);
    console.log('Available Funds: ' + available/ETH);
    console.log('Token Price: ' + tokenPrice);
  });
});
