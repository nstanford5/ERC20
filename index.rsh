/**
 * ERC20 contract in Reach
 * 
 * So this contract is implementing the ledger for this token.  
 * IE it's not transferring an external token, the transfer API 
 * is telling this contract to update the ledger of token ownership.
 * This balances map is basically the ownership database for this token.
 * Ownership of the token is programatically defined by this contract, 
 * and every API that interacts with the balance goes through the balances map.
 * IE balanceOf queries the map, transfer updates the map.
 */
'reach 0.1';

export const main = Reach.App(() => {
  setOptions({ connectors: [ETH] });
  // admin participant for deploying and providing parameters
  const D = Participant('Deployer', {
    // Obect for token metadata
    meta: Object({
      name: StringDyn,
      symbol: StringDyn,
      decimals: UInt,
      totalSupply: UInt,
      zeroAddress: Address,
    }),
    // function to notify frontend of contract deployment
    deployed: Fun([Contract], Null),
  });
  // api functions we are allowing to be called
  const ERC20 = API({
    transfer: Fun([Address, UInt], Bool),
    transferFrom: Fun([Address, Address, UInt], Bool),
    approve: Fun([Address, UInt], Bool),
  });
  // views to make information easily accessible to frontends
  const vERC20 = View({
    name: Fun([], StringDyn),
    symbol: Fun([], StringDyn),
    decimals: Fun([], UInt),
    totalSupply: Fun([], UInt),
    balanceOf: Fun([Address], UInt),
    allowance: Fun([Address, Address], UInt),
  });
  // events that the contract will emit
  const eERC20 = Events({
    Transfer: [Address, Address, UInt],
    Approval: [Address, Address, UInt],
  });
  init();
  // get token metadata from the frontend
  D.only(() => {
    const {name, symbol, decimals, totalSupply, zeroAddress} = declassify(interact.meta);
  });
  // publish to consensus
  D.publish(name, symbol, decimals, totalSupply, zeroAddress).check(() => {
    check(decimals < 256, 'decimals fits in UInt8');
  });
  // notify the frontend contract has deployed
  D.interact.deployed(getContract());

  // set view values to token metadata
  vERC20.name.set(() => name);
  vERC20.symbol.set(() => symbol);
  vERC20.decimals.set(() => decimals);
  vERC20.totalSupply.set(() => totalSupply);

  // Maps for querying ledger information on users
  const balances = new Map(Address, UInt);
  const allowances = new Map(Tuple(Address, Address), UInt);

  // setting admin and totalSupply in Map
  balances[D] = totalSupply;
  // why include the total supply in the zeroAddress transfer?
  eERC20.Transfer(zeroAddress, D, totalSupply);

  // we do this when we want our functions to be infinitely available.
  // we aren't transferring anything in and out of the contract in a linear program.
  // We are allowing a service of transferring functions
  // no values to track -- just using the power of parallelReduce for convenience
  const [] = parallelReduce([])
  // defining helper functions
  .define(() => {
    const balanceOf = (owner) => {
      const m_bal = balances[owner];
      return fromSome(m_bal, 0);
    }
    // set the view balance -- to a function?
    vERC20.balanceOf.set(balanceOf);
    // define allowance of tokens
    const allowance = (owner, spender) => {
      const m_bal = allowances[[owner, spender]];
      return fromSome(m_bal, 0);
    }
    // set the view for allowance -- to the allowance function?
    vERC20.allowance.set(allowance);
    // transfer_ (we suffix this because transfer is reserved word in Reach)
    const transfer_ = (from_, to, amount) => {
      // update balances map from
      balances[from_] = balanceOf(from_) - amount;
      // update balances map to
      balances[to] = balanceOf(to) + amount;
      // emit Transfer event
      eERC20.Transfer(from_, to, amount);
    }
  })// end of define
  // the contract never recieves tokens
  .invariant(balance() == 0)
  .while(true)// the loop needs to run infinitely to allow the functions forever
  .api_(ERC20.transfer, (to, amount) => {
    // dynamic assertions
    check(to != zeroAddress, 'ERC20: Transfer to zero address');
    check(balanceOf(this) >= amount, "amount must not be greater than balance");
    return[(k) => {
      // transfer from the caller to specified amount and address
      transfer_(this, to, amount);
      k(true);// must return true to implement ERC20 spec
      return [];// track no values
    }];
  })
  // different parameters than transfer function
  .api_(ERC20.transferFrom, (from_, to, amount) => {
    // dynamic assertions
    check(from_ != zeroAddress, "ERC20: Transfer from zero address");
    check(to != zeroAddress, "ERC20: Transfer to zero address");
    check(balanceOf(from_) >= amount, "amount must not be greater than balance");
    check(allowance(from_, this) >= amount, "amount must not be greater than allowance");
    return[ (k) => {
      // transfer specified amount from, to
      transfer_(from_, to, amount);
      // update allowance amount
      const newAllowance = allowance(from_, this) - amount;
      // set allowances map
      allowances[[from_, this]] = newAllowance;
      // emit Approval Event
      eERC20.Approval(from_, this, newAllowance);
      k(true);// must return Bool for ERC20 spec
      return [];// track no values
    }];
  })
  // approve function
  .api_(ERC20.approve, (spender, amount) => {
    // dynamic assertions
    check(spender != zeroAddress, "ERC20: Approve to zero address");
    return [ (k) => {
      // update allowances map
      allowances[[this, spender]] = amount;
      // emit Approval event
      eERC20.Approval(this, spender, amount);
      k(true);// must return boolean for ERC20 spec
      return [];// track no values
    }];
  });
  commit();
  exit();// we never actually reach this point, the contract lives infinitely
});