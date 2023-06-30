# TokenShop  

## What is TokenSwap  

TokenSwap is a simple fixed-price market maker that will buy your memecoins at a fixed price. This is useful for tax-loss harvesting.  

The contract is not owned by anyone, but BuidGuidl has been designated as the the target for any donations. This is simply because BuidlGuidl is one of the best places to learn about Solidity + EVM, and they provide one of the best frameworks (Scaffold-Eth2) to work with. 

## How does it work?  

Before you can access TokenSwap, you need to buy access for the princely sum of `0.005 ether`. The `msg.sender`'s account is credited with `0.004 ether` and the funding beneficiary is allocated `0.001 ether`.   

Initializing a pool for a specific token consumes `0.001 ether` from `accounts[msg.sender]`. This acts as an anti-spam filter.  

Once a pool exists for your specific token, the TokenSwap contract will buy as much of that token from you as you want to sell, at the fixed offer price of `0.001 ether`.  

Here's the deal:  
Once you've sold your ERC20 tokens, that's it.  

It's gone forever.  

The catch? Well, the BuidlGuidl (or whomever they nominate to take their place) can transfer the ERC20 tokens out. This means that aside from the `0.001 ether` fee that they receive for access, they can go *degen* on themselves and resell the tokens should the swap price of a memecoin improve. 

## Will your accountant be happy?  

Each invoice is minted as an ERC721 token with an on-chain SVG invoice from the TokenSwap contract. As near to an on-chain invoice as can be done.  

The invoice contains:  
- Invoice number
- Seller address
- Token address
- Number of tokens sold
- Price
- BlockNumber  

**Please note: you are selling your tokens to TokenSwap and the ERC721 issued is not an invoice from TokenSwap to you (the seller), but is the invoice you as the seller issue to the buyer (TokenSwap). TokenSwap as a piece of autonomous code does not have use for the invoice, or regard for tax regulations, or understanding of local accounting principles. It always remains your responsibility to ensure you comply with your local tax and financial laws.**  

## FAQs  

#### What's the point of this?  
We've all been there, watching etherscan or the mempool, looking for that new `PEPE` token, hoping your bag goes to the moon. In most cases, it doesn't. Please research tax loss harvesting - always look for local information. But the gist of it is that if you sell your tokens for less than what you bought them, that is a way to "capture" this loss for tax purposes. In the seller's opinion, the tokens sold will never go up in value again. The `TokenSwap` contract is an expression of the contrary opinion, held for the public good, and with the ability to act on that opinion should sentiment on the token sold change. 

#### Why can I only buy access with 0.005 ether?  
There is no mechanism to refund access which you've bought back to you as a user. To keep the potential for loss of funds small a user is only allowed to send `0.005 ether` to the contract at a time. If you are using TokenSwap you have already been degen, and TokenSwap won't enable you further.  

#### What is this "target beneficiary"?  
To start with the target beneficiary is the **BuidlGuidl**, simply because they've done so much to help onboard devs into web3. 

The web3 ethos is built around public goods. TokenSwap is intended as a public good for Ethereum. The idea is that should BuidlGuidl (or whichever target beneficiary is currently slotted in) decide they would like to nominate a different public good, they can pass on the benefit that project by calling `nominateTarget`. 