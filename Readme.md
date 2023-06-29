# TokenShop  

## What is TokenSwap  

TokenSwap is a simple fixed-price market maker that will buy your memecoins at a fixed price. This is useful for tax-loss harvesting.  

The contract is not owned by anyone, but BuidGuidl has been designated as the the target for any donations. This is simply because BuidlGuidl is one of the best places to learn about Solidity + EVM, and they provide one of the best frameworks (Scaffold-Eth2) to work with. 

## How does it work?  

Before you can access TokenSwap, you need to buy access for the princely sum of `0.005 ether`. The 'msg.sender`s account is credited with `0.005 ether`.

Initializing a pool for a specific token consumes `0.001 ether` from `accounts[msg.sender]`.  

Once a pool exists for your specific token, the TokenSwap contract will buy as much of that token from you as you want to sell, at the fixed offer price of `0.001 ether`.  

Here's the deal:  
Once you've sold your ERC20 tokens, that's it.  

It's gone forever.  

The catch? Well, the BuidlGuidl (or whomever they nominate to take their place) can transfer the ERC20 tokens out. This means that aside from the `0.001 ether` fee that they receive for new pools, they can call `degenMode` on themselves and resell the tokens should the swap price of a memecoin improve. 

**`degenMode`** is dangerous, use with care!

## Will your accountant be happy?  

Each invoice is minted as an ERC721 token with an on-chain SVG invoice from the TokenSwap contract. As near to an on-chain invoice as can be done.  

The invoice contains:  
- Invoice number
- Seller address
- Token address
- Number of tokens sold
- Price
- BlockNumber  

**Please note: you are selling your tokens to TokenSwap and the ERC721 issued is not an invoice from TokenSwap to you (the seller), but is the invoice you as the seller issue to the buyer (TokenSwap). TokenSwap as a piece of autonomous code does not have use for the invoice, or regard for tax regulations, or understanding of local accounting principles. It always remains your responsibility to ensure you compply with your local tax and financial laws.**

