# TokenShop  

## What is TokenShop  

TokenShop is a simple fixed-price market maker that will buy your worthless memecoins at a fixed price. This is useful for tax-loss harvesting.  

The contract is not owned by anyone, but TokenShop has designated the BuidlGuidl as the target for any donations. This is simply because BuidlGuidl is one of the best places to learn about Solidity + Ethereum, and they provide one of the best frameworks to work with. 

## How does it work?  

Before you can access the TokenShop, you need to buy access for the degen sum of `0.005 ether`. An access pass is then issued and credited with `0.005 ether`.

Initializing a pool for a specific token consumes `0.001 ether`.  

Once a pool exists for your specific token, the TokenShop will buy as much of that token from you as you want to sell, at the fixed price of `0.001 ether`.  

Here's the deal:  
Once you've sold your ERC20 tokens, that's it.  

It's gone forever.  

The catch? Well, the BuidlGuidl (or whomever they nominate to take their place) can transfer the ERC20 tokens out. This means that aside from the `0.001 ether` fee that they receive for new pools, they can call `degenMode` and resell the tokens should the swap price of a memecoin improve. 

**`degenMode`** is dangerous, use with care!

## Will my accountant be happy?  

Each invoice is minted as an ERC721 token with an on-chain SVG invoice from the TokenShop contract. As near to an on-chain invoice as can be done.