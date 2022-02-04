# tender-offer

Organize a tender offer for erc-20 tokens

## background

sometimes, there is insufficient liquidity within exchanges (centralized or decentralized) to
purchace the amount of an erc-20 token someone wants to buy. this contract provides a mechnism
that allows an entity to offer a fixed price per token to any & all token holders. the contract
has a mechanism that ensures tokens will only be transferred once a minimum number of holders
have accepted the offer.

## dev

this project utilizes paradigm's [foundry](https://github.com/gakonst/foundry) toolchain.
to build:
`forge deploy`
to test
`forge test`
