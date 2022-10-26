# Workshop: ERC20 in Reach

This workshop will demonstrate the [ERC20 spec](https://eips.ethereum.org/EIPS/eip-20) in [Reach](https://docs.reach.sh/#reach-top).

It assumes prior knowledge of Reach -- we recommend completing the
[Rock, Paper, Scissors](https://docs.reach.sh/tut/rps/) tutorial and the [RSVP](https://docs.reach.sh/tut/rsvp/) tutorial.

It also assumes you are working in a project folder called `erc20`
`$ mkdir erc20`
`cd erc20`

Create your files
`touch index.rsh`
`touch index.mjs`

Working directory, where the reach shell script is installed in `Reach`
`~/Reach/erc20`


## Problem Analysis
Our application is going to implement the ERC20 token spec and allow 
functions to be called indefinitely. We'll implement transfer and approval functions for users.

This program will implement an ownership database of our token. There will not be any external token transfers, we'll save that for the next iteration.

## Who are the users in our application?
There must be one ```Participant``` to deploy the contract and the other users are best defined as `API`s.

## What are the steps of the program?
The program will first accept the token metadata and parameters and then allow our `API` member functions to be called indefinitely. This means we'll use the mighty parallelReduce with special considerations.

Let's define our users.
###### index.rsh
```js
'reach 0.1'

export const main = Reach.App(() => {
  setOptions({connectors: [ETH]});
  const D = Participant('Deployer', {

  });
  const ERC20 = API({

  });
});
```
This structure will allow a single address to bind to `D` and allow `ERC20` functions to be called by other contracts or off-chain by frontends representing any number of different users.

We also want to define Views and Events that make blockchain information more easily accessible to the frontend. Views will increase the visibility of information and Events allow monitoring of significant actions in our Reach program.

###### index.rsh
```js
'reach 0.1'

export const main = Reach.App(() => {
  const D = Participant('Deployer', {

  });
  const ERC20 = API({

  });
  const V = View({

  });
  const E = Events({

  });
  init();
});
```

The application starts with the Deployer providing the token metadata and deploying the contract with the first `publish`. So we add some data definitions to our `Participant`

###### index.rsh
```js
  const D = Participant('Deployer', {
    meta: Object({
      name: StringDyn,
      symbol: StringDyn,
      decimals: UInt,
      totalSupply: UInt,
      zeroAddress: Address,
    }),
    deployed: Fun([Contract], Null),
  });
```

We define the metadata as an Object with specified fields. More on [StringDyn](https://docs.reach.sh/rsh/compute/#rsh_StringDyn)

Then we define a `deployed` function to notify the frontend of contract deployment. This is a best practice when building Reach DApps. It prevents frontend interaction that relies on a deployed contract before it is complete.

Now we consider what functions our `API` members will use. They need to `transfer` `transferFrom` and `approve`. These functions are from the (ERC20 spec)[link]. //here

We'll add this code to our `ERC20 API`

###### index.rsh
```js
  const ERC20 = API({
    transfer: Fun([Addresss, UInt], Bool),
    transferFrom: Fun([Address, Address, UInt], Bool),
    approve: Fun([Address, UInt], Bool),
  });
```

Now let's define our Views and Events. 

Views make information on the blockchain easier to access, they do not provide any values that were not previously available. Good information to make available would be token metadata, token balances and token allowances. We'll add this code to our `View`.

###### index.rsh
```js
  const V = View({
    name: Fun([], StringDyn),
    symbol: Fun([], StringDyn),
    decimals: Fun([], UInt),
    totalSupply: Fun([], UInt),
    balanceOf: Fun([Address], UInt),
    allowance: Fun([Address, Address], UInt),
  });
```

Events emit at significant actions of the program. Events allow monitoring of Reach program actions, they contain a `when` and a `what`. `when` is the time the Event was emitted from the consensus network, `what` is an array of values from the Event.

The significant actions of our program are `Transfer` and `Approval`. We'll add this code to our `Events`.

###### index.rsh
```js
  const E = Events({
    Transfer: [Address, Address, UInt],
    Approval: [Address, Address, UInt],
  });
  init();
```
  
That is all for our data definitions, so we call `init()` to start stepping through the states of our program.

As noted earlier, the first step is to have the `Deployer` provide the token metadata and actually deploy the contract with the first publish.

###### index.rsh
```js
  D.only(() => {
    const {name, symbol, decimals, totalSupply, zeroAddress} = declassify(interact.meta);
  });
  D.publish(name, symbol, decimals, totalSupply, zeroAddress).check(() => {
    check(decimals < 256, 'decimals fit in UInt8');
  });
```

Then the `Deployer` notifies the frontend that the contract is deployed. 
`getContract()` will return the contract value, it cannot be called until after the first `publish`
//here add a break between content and code
###### index.rsh
```js
  D.interact.deployed(getContract());
```

//here use semantic lines. basically means a break at every sentence.
Now we can set the Views related to our token metadata. Remember, this information is already available, because we published it to the blockchain, but it is acessible with some difficulty. `View`s make this as simple as defining a function to provide the information to the frontend. 

Setting the token metadata to the `View`s, provides an easily accessible window into the consensus state.

###### index.rsh
```js
  V.name.set(() => name);
  V.symbol.set(() => symbol);
  V.decimals.set(() => decimals);
  V.totalSupply.set(() => totalSupply);
```

Next we'll create the `Map`s that hold balances and allowances for transfer. Then we'll set the `Deployer` balance to the token supply. 
As this DApp has been designed we will use the `balances` map as our database of ownership. //here oddly worded

###### index.rsh
```js
  const balances = new Map(Address, UInt);
  const allowances = new Map(Tuple(Address, Address), UInt);

  balances[D] = totalSupply;
```

Then we set the balance `Map` for the `Deployer` to the `totalSupply`

Next we'll emit the Event for Transfer to the zero address.

###### index.rsh
```js
  E.Transfer(zeroAddresss, D, totalSupply);
```

Before we go any further in our `rsh` file, let's jump to the frontend `mjs` file.

We'll start with necessary imports and verify EVM connector setting.

###### index.mjs
```js
import * as backend from './build/index.main.mjs';
import {loadStdlib} from '@reach-sh/stdlib';
const stdlib = loadStdlib(process.env);

if(stdlib.connector !== 'ETH'){
  console.log('Sorry, this program only works on EVM networks');
  process.exit(0);
};
```

We'll demonstrate using the frontend standard library to check `assert` statements. It will be useful to define a few helper constants. 

###### index.mjs
```js
const assert = stdlib.assert;
const bigNumberify = stdlib.bigNumberify;
```

Next, let's write some test functions. We of course want to test that they pass when we assume they will, but we also want to check our assumptions about when we expect them to fail.

###### index.mjs
```js
const assertFail = async (promise) => {
  try{
    await promise;
  } catch (e) {
    return;
  }
  throw "Expected exception but did not catch one";
};
```

Next is a function to verify equality.

###### index.mjs
```js
const assertEq = (a, b, context = "assertEq") => {
  if (a === b) return;
  try {
    const res1BN = bigNumberify(a);
    const res2BN = bigNumberify(b);
    if (res1BN.eq(res2BN)) return;
  } catch {}
  assert(false, `${context}: ${a} == ${b}`);
};
```

Now let's create a function to handle deploying our contract and any errors we may encounter.

###### index.mjs
```js
const startMeUp = async (ctc, meta) => {
  const flag = "startup success throw flag"
  try{
    await ctc.p.Deployer({
      meta,
      deployed: (ctc) => {
        throw flag;
      },
    });
  } catch (e) {
    if (e !== flag){
      throw e;
    }
  }
};
```

Then we define the zeroAddress and create our test accounts.

###### index.mjs
```js
const zeroAddress = 'Ox' + '0'.repeat(40);
const accs = await stdlib.newTestAccounts(4, stdlib.parseCurrency(100));
const [acc0, acc1, acc2, acc3] = accs;
const [addr0, addr1, addr2, addr3] = accs.map(a => a.getAddress());
```

Now we can setup our token metadata in an object to eventually be passed to the backend.

###### index.mjs
```js
const totalSupply = 1000_00;
const decimals = 2;
const meta = {
  name: "ERC20Coin",
  symbol: "E2C",
  decimals,
  totalSupply,
  zeroAddress,
};
```

Now that we have our Deployer account and token data, we can deploy the contract and send this info to the backend. We'll use `acc0` as the Deployer.

###### index.mjs
```js
const ctc0 = acc0.contract(backend);
await startMeUp(ctc0, meta);
const ctcInfo = await ctc0.getInfo();
const ctc = (acc) => acc.contract(backend, ctcInfo);
```

We have all of our users created now and the contract is deployed. Now we can go back to our `.rsh` file.

The next thing we want to do is create the functionality for our `apis`. Given that we have many users who need to do something, we want a `parallelReduce`. 

parallelReduce is a powerful data structure, but in this case we'll use it mostly for convenience. This means we will track no values
###### index.rsh
```js
  const [] = parallelreduce([])
```

The `define` block of our parallelReduce will be used to define some helper functions.

First, a function to check the balance and set the related View
###### index.rsh
```js
  .define(() => {
    const balanceOf = (owner) => {
      const m_bal = balances[owner];
      return fromSome(m_bal, 0);
    }
    V.balanceOf.set(balanceOf);
  });
```

Expanding on the `.define` block we want to also set an allowed amount of tokens and its related View.
###### index.rsh
```js
  .define(() => {
    const balanceOf = (owner) => {
      const m_bal = balances[owner];
      return fromSome(m_bal, 0);
    }
    V.balanceOf.set(balanceOf);
    const allowance = (owner, spender) => {
      const m_bal = allowances[[owner, spender]];
      return fromSome(m_bal, 0);
    }
    V.allowance.set(allowance);
  });
```

The last piece we need to add to our `.define` block is the `transfer_` function. We suffix with `_` because `transfer` is a reserved word in Reach. This is one of the significant events defined in our `Events`, so we also emit an Event here.

//here maybe good to note that we can't prefix with _ because that indicates a secret variable

###### index.rsh
```js
  .define(() => {
    const balanceOf = (owner) => {
      const m_bal = balances[owner];
      return fromSome(m_bal, 0);
    };
    V.balanceOf.set(balanceOf);
    const allowance = (owner, spender) => {
      const m_bal = allowances[[owner, spender]];
      return fromSome(m_bal, 0);
    };
    V.allowance.set(allowance);
    const transfer_ = (from_, to, amount) => {
      balances[from_] = balanceOf(from_) - amount;
      balances[to] = balanceOf(to) + amount;
      E.Transfer(from_, to, amount);
    };
  });// end of define block
```

Why do we use `fromSome()` here?

`Map`s are the only variably sized container in Reach. This means that the value we are attempting to reference from the `balances` and `allowances` maps may exist or they may not. This is generally referred to as a optional type and is important to protect against null pointer references.

Option types in Reach are represented by the type [`Maybe`](https://docs.reach.sh/rsh/compute/#maybe) which has two possibilities -- `Some` and `None`. Reach provides the `fromSome()` function to easily consume these `Maybe` values. It takes the `Maybe` value and a default value if `Maybe == None`. `fromSome(Maybe, default)` [fromSome docs](https://docs.reach.sh/rsh/compute/#rsh_fromSome)

The contract account will not actually recieve tokens, so we set a simple `invariant`. We also want these functions to be callable indefinitely, so we set an infinite loop.

###### index.rsh
```js
  .invariant(balance() == 0)
  .while(true)
```

Now that our loop pattern is setup, we can define our `API` member functions.

`transfer` will check for a zeroAddress transfer and verify the balance is not greater than the amount.

###### index.rsh
```js
  .api_(ERC20.transfer, (to, amount) => {
    check(to != zeroAddress, "ERC20: Transfer to zero address");
    check(balanceOf(this) >= amount, "amount must not be greater than balance");
  })
```

The next piece to add to this function is the `return` call. In this case the `PAY_EXPR` is omitted and track no values. We return a Boolean here to match the ERC20 spec

###### index.rsh
```js
  .api_(ERC20.transfer, (to, amount) => {
    check(to != zeroAddress, "ERC20: Transfer to zero address");
    check(balanceOf(this) >= amount, "amount must not be greater than balance");
    return[(k) => {
      transfer_(this, to, amount);
      k(true);
      return [];
    }];
  })
```

The `API` member function `transfer` is now complete. Note, we are allowed to use `transfer` as an identifier for this function because it is an external function, Reach knows this is not for transferring from the contract account.

Next is `transferFrom`, again we start with dynamic assertions checking for the `zeroAddress`, balances and allowances

###### index.rsh
```js
  .api_(ERC20.transferFrom, (from_, to, amount) => {
    check(from_ != zeroAddress, "ERC20: Transfer from zero address");
    check(to != zeroAddress, "ERC20: Transfer to zero address");
    check(balanceOf(from_) >= amount, "amount must not be greater than balance");
    check(allowance(from_, this) >= amount, "amount must not be greater than allowance");
  })
```

After verifying assertions we can add the `return` to our `transferFrom` function. Again we omit the `PAY_EXPR` -- but this time update the `allowances` map and emit an `Approval` Event
###### index.rsh
```js
  .api_(ERC20.transferFrom, (from_, to, amount) => {
    check(from_ != zeroAddress, "ERC20: Transfer from zero address");
    check(to != zeroAddress, "ERC20: Transfer to zero address");
    check(balanceOf(from_) >= amount, "amount must not be greater than balance");
    check(allowance(from_, this) >= amount, "amount must not be greater than allowance");
    return[(k) => {
      transfer_(from_, to, amount);
      const newAllowance = allowance(from_, this) - amount;
      allowances[[from_, this]] = newAllowance;
      E.Approval(from_, this, newAllowance);
      k(true);
      return[];
    }];
  })
```

That completes our `transferFrom` function.

The last function to implement is the `API` member function `approve`. We'll start with its heading and a dynamic check for the `zeroAddress`
###### index.rsh
```js
  .api_(ERC20.approve, (spender, amount) => {
    check(spender != zeroAddress, "ERC20: Approve to zero address");
  })
```

Then we add an update to the `allowances` map and emit an `Approval` Event. This code will be added to our `approve` function.
###### index.rsh
```js
  .api_(ERC20.approve, (spender, amount) => {
    check(spender != zeroAddress, "ERC20: Approve to zero address");
    return[(k) => {
      allowances[[this, spender]] = amount;
      E.Approval(this, spender, amount);
      k(true);
      return [];
    }];
  });
```

This ends our `.rsh` file, though because of our infinite loop -- we never actually reach `exit`
###### index.rsh
```js
  commit();
  exit();
});// end of Reach.App
```

Now we can jump back to our frontend and implement some tests for our new functions.

First a function to verify assertions about the balances of our accounts and their related Views.
###### index.mjs
```js
const assertBalances = async (bal0, bal1, bal2, bal3) => {
  assertEq(bal0, (await ctc0.v.balanceOf(acc0.getAddress()))[1]);
  assertEq(bal1, (await ctc0.v.balanceOf(acc1.getAddress()))[1]);
  assertEq(bal2, (await ctc0.v.balanceOf(acc2.getAddress()))[1]);
  assertEq(bal3, (await ctc0.v.balanceOf(acc3.getAddress()))[1]);
  console.log('assertBalances complete');
}
```

Now a function to verify our Events
###### index.mjs
```js
const assertEvent = async (event, ...expectedArgs) => {
const e = await ctc0.events[event].next();
const actualArgs = e.what;
expectedArgs.forEach((expectedArg, i) => assertEq(actualArgs[i], expectedArg, `${event} field ${i}`));
console.log('assertEvent complete');
};
```

Now we'll define functions to use our `api` calls and include some calls to our `assert` functions.

First is the `transfer` function, follwed by `transferFrom`. We defined our `API` namelessly in the `.rsh` file, so we can access it here in the frontend with `ctc.a.functionName`.
###### index.mjs
```js
const transfer = async (fromAcc, toAcc, amt) => {
  await ctc(fromAcc).a.transfer(toAcc.getAddress(), amt);
  await assertEvent("Transfer", fromAcc.getAddress(), toAcc.getAddress(), amt);
  console.log('transfer complete');
};

const transferFrom = async (spenderAcc, fromAcc, toAcc, amt, allowanceLeft) => {
  const b = await ctc(spenderAcc).a.transferFrom(fromAcc.getAddress(), toAcc.getAddress(), amt);
  await assertEvent("Transfer", fromAcc.getAddress(), toAcc.getAddress(), amt);
  await assertEvent("Approval", fromAcc.getAddress(), spenderAcc.getAddress(), allowanceLeft);
  console.log(`transferFrom complete is ${b}`);
};
```
Notice these functions are calling our previously defined `assert` functions for verification using the frontend standard library.

Now for the `a.approve` function. 
###### index.mjs
```js
const approve = async (fromAcc, spenderAcc, amt) => {
  await ctc(fromAcc).a.approve(spenderAcc.getAddress(), amt);
  await assertEvent("Approval", fromAcc.getAddress(), spenderAcc.getAddress(), amt);
  console.log('approve complete');
}
```

Finally, we can add some tests our program!

We will test to our various functions for pass/fail scenarios. Listed here are all of the calls, we won't cover inputs from each and function names denote expected behavior.
###### index.mjs
```js
// start testing
console.log("starting tests");

// initial transfer event upon minting (when launching contract)
await assertEvent("Transfer", zeroAddress, acc0.getAddress(), totalSupply);
console.log('assertEvent call complete');

// assert balances are equal to view values
// acc0 has the totalSupply at this point, all others are zero
await assertBalances(totalSupply, 0, 0, 0);
console.log('assertBalances call complete');

// transfer of more than you have should fail
await assertFail(transfer(acc1, acc2, 10));
await assertFail(transferFrom(acc1, acc2, acc3, 10, 0));
console.log('assertFail2 call complete');

// transfer of zero should work even if you don't have any
await transfer(acc1, acc2, 0);
console.log('transfer call complete');

// transferFrom of zero should work even the from doesn't have any and the transferer has an allowance of 0
await transferFrom(acc1, acc2, acc3, 0, 0);
console.log('transferFrom call complete');

// transfer 10 from acc0 to acc1
await transfer(acc0, acc1, 10);
await assertBalances(totalSupply - 10, 10, 0, 0);

// assert the allowance for addr3 is 0
assertEq((await ctc0.v.allowance(addr0, addr3))[1], 0);

// approve a new allowance for acc3
await approve(acc0, acc3, 20);
assertEq((await ctc0.v.allowance(addr0, addr3))[1], 20);

// check the balances again, they haven't changed
await assertBalances(totalSupply - 10, 10, 0, 0);

// transferFrom of more than an allowance should fail
await assertFail(transferFrom(acc3, acc0, acc2, 100, 20));

// transferFrom spender, from, to, 10
await transferFrom(acc3, acc0, acc2, 10, 10);
assertEq((await ctc0.v.allowance(addr0, addr3))[1], 10);
await assertBalances(totalSupply - 20, 10, 10, 0);

// transfer the 10 from acc3 back to acc0
await transferFrom(acc3, acc0, acc3, 10, 0);
assertEq((await ctc0.v.allowance(addr0, addr3))[1], 0);

// check the balances
await assertBalances(totalSupply - 30, 10, 10, 10);
// transferFrom should use up the allowance
await assertFail(transferFrom(acc3, acc0, acc3, 1, 0));

// Even if you're rich, you can't transfer more than your balance.
await assertFail(transfer(acc0, acc2, totalSupply - 10));

// approve allowance of 100 tokens to acc0
await approve(acc0, acc1, 100);

// assert the view values are as expected
assertEq((await ctc0.v.name())[1], meta.name, "name()");
assertEq((await ctc0.v.symbol())[1], meta.symbol, "symbol()");
assertEq((await ctc0.v.totalSupply())[1], meta.totalSupply, "totalSupply()");
assertEq((await ctc0.v.decimals())[1], meta.decimals, "decimals()");

console.log("Finished testing!");
```

Now we can run our application.

First set the connector mode to `ETH` with `export REACH_CONNECTOR_MODE=ETH`

Then `../reach run` and you see output that looks like this
```
> index
> node --experimental-modules --unhandled-rejections=strict index.mjs

Starting up...
Completed startMeUp
finised getting contract handles
Starting tests...
assertEvent complete
assertEvent call complete
assertBalances complete
assertBalances call complete
assertFail2 call complete
assertEvent complete
transfer complete
transfer call complete
assertEvent complete
assertEvent complete
transferFrom complete is true
transferFrom call complete
assertEvent complete
transfer complete
assertBalances complete
assertEvent complete
approve complete
assertBalances complete
assertEvent complete
assertEvent complete
transferFrom complete is true
assertBalances complete
assertEvent complete
assertEvent complete
transferFrom complete is true
assertBalances complete
assertEvent complete
approve complete
Finished testing!
```

Th-th-th-that's all, folks!

Below are the complete files

## index.rsh
```js
'reach 0.1';

export const main = Reach.App(() => {
  setOptions({ connectors: [ETH] });
  const D = Participant('Deployer', {
    meta: Object({
      name: StringDyn,
      symbol: StringDyn,
      decimals: UInt,
      totalSupply: UInt,
      zeroAddress: Address,
    }),
    deployed: Fun([Contract], Null),
  });
  const ERC20 = API({
    transfer: Fun([Address, UInt], Bool),
    transferFrom: Fun([Address, Address, UInt], Bool),
    approve: Fun([Address, UInt], Bool),
  });
  const vERC20 = View({
    name: Fun([], StringDyn),
    symbol: Fun([], StringDyn),
    decimals: Fun([], UInt),
    totalSupply: Fun([], UInt),
    balanceOf: Fun([Address], UInt),
    allowance: Fun([Address, Address], UInt),
  });
  const eERC20 = Events({
    Transfer: [Address, Address, UInt],
    Approval: [Address, Address, UInt],
  });
  init();
  D.only(() => {
    const {name, symbol, decimals, totalSupply, zeroAddress} = declassify(interact.meta);
  });
  D.publish(name, symbol, decimals, totalSupply, zeroAddress).check(() => {
    check(decimals < 256, 'decimals fits in UInt8');
  });
  D.interact.deployed(getContract());

  vERC20.name.set(() => name);
  vERC20.symbol.set(() => symbol);
  vERC20.decimals.set(() => decimals);
  vERC20.totalSupply.set(() => totalSupply);

  const balances = new Map(Address, UInt);
  const allowances = new Map(Tuple(Address, Address), UInt);

  balances[D] = totalSupply;
  eERC20.Transfer(zeroAddress, D, totalSupply);

  const [] = parallelReduce([])
  .define(() => {
    const balanceOf = (owner) => {
      const m_bal = balances[owner];
      return fromSome(m_bal, 0);
    }
    vERC20.balanceOf.set(balanceOf);
    const allowance = (owner, spender) => {
      const m_bal = allowances[[owner, spender]];
      return fromSome(m_bal, 0);
    }
    vERC20.allowance.set(allowance);
    const transfer_ = (from_, to, amount) => {
      balances[from_] = balanceOf(from_) - amount;
      balances[to] = balanceOf(to) + amount;
      eERC20.Transfer(from_, to, amount);
    }
  })// end of define
  .invariant(balance() == 0)
  .while(true)
  .api_(ERC20.transfer, (to, amount) => {
    check(to != zeroAddress, 'ERC20: Transfer to zero address');
    check(balanceOf(this) >= amount, "amount must not be greater than balance");
    return[(k) => {
      transfer_(this, to, amount);
      k(true);
      return [];
    }];
  })
  .api_(ERC20.transferFrom, (from_, to, amount) => {
    check(from_ != zeroAddress, "ERC20: Transfer from zero address");
    check(to != zeroAddress, "ERC20: Transfer to zero address");
    check(balanceOf(from_) >= amount, "amount must not be greater than balance");
    check(allowance(from_, this) >= amount, "amount must not be greater than allowance");
    return[ (k) => {
      transfer_(from_, to, amount);
      const newAllowance = allowance(from_, this) - amount;
      allowances[[from_, this]] = newAllowance;
      eERC20.Approval(from_, this, newAllowance);
      k(true);
      return [];
    }];
  })
  .api_(ERC20.approve, (spender, amount) => {
    check(spender != zeroAddress, "ERC20: Approve to zero address");
    return [ (k) => {
      allowances[[this, spender]] = amount;
      eERC20.Approval(this, spender, amount);
      k(true);
      return [];
    }];
  });
  commit();
  exit();
});
```

## index.mjs
```js
import * as backend from './build/index.main.mjs';
import { loadStdlib } from "@reach-sh/stdlib";
const stdlib = loadStdlib(process.env);

if(stdlib.connector !== 'ETH'){
  console.log('Sorry, this program is only compiled on ETH for now');
  process.exit(0);
}
console.log("Starting up...");

const assert = stdlib.assert;
const bigNumberify = stdlib.bigNumberify;

const assertFail = async (promise) => {
  try {
    await promise;
  } catch (e) {
    return;
  }
  throw "Expected exception but did not catch one";
}

const assertEq = (a, b, context = "assertEq") => {
  if (a === b) return;
  try {
    const res1BN = bigNumberify(a);
    const res2BN = bigNumberify(b);
    if (res1BN.eq(res2BN)) return;
  } catch {}
  assert(false, `${context}: ${a} == ${b}`);
}

const startMeUp = async (ctc, meta) => {
  const flag = "startup success throw flag"
  try {
    await ctc.p.Deployer({
      meta,
      deployed: (ctc) => {
        throw flag;
      },
    });
  } catch (e) {
    if ( e !== flag) {
      throw e;
    }
  }
}

const zeroAddress = "0x" + "0".repeat(40);
const accs = await stdlib.newTestAccounts(4, stdlib.parseCurrency(100));
const [acc0, acc1, acc2, acc3] = accs;
const [addr0, addr1, addr2, addr3] = accs.map(a => a.getAddress());

const totalSupply = 1000_00;
const decimals = 2;
const meta = {
  name: "Coinzz",
  symbol: "CZZ",
  decimals,
  totalSupply,
  zeroAddress,
}

const ctc0 = acc0.contract(backend);
await startMeUp(ctc0, meta);
console.log('Completed startMeUp');

const ctcinfo = await ctc0.getInfo();
const ctc = (acc) => acc.contract(backend, ctcinfo);
console.log('finised getting contract handles');

const assertBalances = async (bal0, bal1, bal2, bal3) => {
  assertEq(bal0, (await ctc0.v.balanceOf(acc0.getAddress()))[1]);
  assertEq(bal1, (await ctc0.v.balanceOf(acc1.getAddress()))[1]);
  assertEq(bal2, (await ctc0.v.balanceOf(acc2.getAddress()))[1]);
  assertEq(bal3, (await ctc0.v.balanceOf(acc3.getAddress()))[1]);
  console.log('assertBalances complete');
}

const assertEvent = async (event, ...expectedArgs) => {
  const e = await ctc0.events[event].next();
  const actualArgs = e.what;
  expectedArgs.forEach((expectedArg, i) => assertEq(actualArgs[i], expectedArg, `${event} field ${i}`));
  console.log('assertEvent complete');
}

const transfer = async (fromAcc, toAcc, amt) => {
  await ctc(fromAcc).a.transfer(toAcc.getAddress(), amt);
  await assertEvent("Transfer", fromAcc.getAddress(), toAcc.getAddress(), amt);
  console.log('transfer complete');
}

const transferFrom = async (spenderAcc, fromAcc, toAcc, amt, allowanceLeft) => {
  const b = await ctc(spenderAcc).a.transferFrom(fromAcc.getAddress(), toAcc.getAddress(), amt);
  await assertEvent("Transfer", fromAcc.getAddress(), toAcc.getAddress(), amt);
  await assertEvent("Approval", fromAcc.getAddress(), spenderAcc.getAddress(), allowanceLeft);
  console.log(`transferFrom complete is ${b}`);
}

const approve = async (fromAcc, spenderAcc, amt) => {
  await ctc(fromAcc).a.approve(spenderAcc.getAddress(), amt);
  await assertEvent("Approval", fromAcc.getAddress(), spenderAcc.getAddress(), amt);
  console.log('approve complete');
}


console.log("Starting tests...")

// initial transfer event upon minting (when launching contract)
await assertEvent("Transfer", zeroAddress, acc0.getAddress(), totalSupply);
console.log('assertEvent call complete');

// assert balances are equal to view values
// acc0 has the totalSupply at this point, all others are zero
await assertBalances(totalSupply, 0, 0, 0);
console.log('assertBalances call complete');

// transfer of more than you have should fail
await assertFail(transfer(acc1, acc2, 10));
await assertFail(transferFrom(acc1, acc2, acc3, 10, 0));
console.log('assertFail2 call complete');

// transfer of zero should work even if you don't have any
await transfer(acc1, acc2, 0);
console.log('transfer call complete');

// transferFrom of zero should work even the from doesn't have any and the transferer has an allowance of 0
await transferFrom(acc1, acc2, acc3, 0, 0);
console.log('transferFrom call complete');

// transfer 10 from acc0 to acc1
await transfer(acc0, acc1, 10);
// assert balances are correct after transfer
await assertBalances(totalSupply - 10, 10, 0, 0);

// assert the allowance for addr3 is 0
assertEq((await ctc0.v.allowance(addr0, addr3))[1], 0);
// approve the allowance for add3 to 20
await approve(acc0, acc3, 20);
// assert that allowance is correct
assertEq((await ctc0.v.allowance(addr0, addr3))[1], 20);
// check the balances again -- they haven't changed
await assertBalances(totalSupply - 10, 10, 0, 0);

// transferFrom of more than an allowance should fail
await assertFail(transferFrom(acc3, acc0, acc2, 100, 20));

// transferFrom spender, from, to, 10
await transferFrom(acc3, acc0, acc2, 10, 10);
// assert the allowance for addr3
assertEq((await ctc0.v.allowance(addr0, addr3))[1], 10);
// assertBalances updated after transfer
await assertBalances(totalSupply - 20, 10, 10, 0);
// transfer the 10 from acc3 back to acc0
await transferFrom(acc3, acc0, acc3, 10, 0);
// assert the allowance has changed
assertEq((await ctc0.v.allowance(addr0, addr3))[1], 0);
// check the balances
await assertBalances(totalSupply - 30, 10, 10, 10);
// transferFrom should use up the allowance
await assertFail(transferFrom(acc3, acc0, acc3, 1, 0));

// Even if you're rich, you can't transfer more than your balance.
await assertFail(transfer(acc0, acc2, totalSupply - 10));

// approve allowance of 100 tokens to acc0
await approve(acc0, acc1, 100);

// assert the view values are as expected
assertEq((await ctc0.v.name())[1], meta.name, "name()");
assertEq((await ctc0.v.symbol())[1], meta.symbol, "symbol()");
assertEq((await ctc0.v.totalSupply())[1], meta.totalSupply, "totalSupply()");
assertEq((await ctc0.v.decimals())[1], meta.decimals, "decimals()");

console.log("Finished testing!");
```
