pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @notice TenderOffer allows someone to make a fix-price (in ETH) offer for some number of
 * ERC-20 tokens. The offerer can set a minimum number of tokens she is willing to buy,
 * and once that minimum number is committed, anyone can fulfil the commitments at a min price.
 * @author Jake Nyquist (jake@nyqu.ist)
 */
contract TenderOffer is Pausable, Ownable, ReentrancyGuard {
    event Commitment(address comitter, uint256 numTokens);
    event Settled(address comitter, uint256 tokens, uint256 paymentInWei);
    // number of the subject ERC-20 tokens that have been committed
    uint256 private totalCommitted = 0;
    mapping(address => uint256) private _commitments;
    uint256 private _minimumCommittments;

    // address of ERC-20 token contract that the tender offer is buying
    IERC20 private _tokenContract;

    // address of the contract that will recieve all of the purchased tokens
    // after the tender offer is executed
    address private _tokenRecipientAddress;

    // the offer per token in the ERC-20, in wei
    uint256 public offerPerTokenWei;

    // flag to be set after the first time transfers are executed
    bool private _minimumMet = false;

    /** @notice create a tender offer contract
     * @param _tokenRecipient the address that will become the owner of the target ERC-20 tokens
     * @param _buyingTokenAddress the address of the ERC-20 token contract
     * @param minimumTokens the minimum number of tokens that must be committed for the owner to complete the transfer
     * @param offerPerToken the amount of eth, in wei, that will be paid per token to accounts that redeem this offer
     */
    constructor(
        address _tokenRecipient,
        address _buyingTokenAddress,
        uint256 minimumTokens,
        uint256 offerPerToken
    ) {
        // start the contract in a paused state.
        _pause();

        _tokenContract = IERC20(_buyingTokenAddress);
        _tokenRecipientAddress = _tokenRecipient;
        _minimumCommittments = minimumTokens;
        offerPerTokenWei = offerPerToken;
    }

    /**
     * @notice withdrawl all of the ETH from the contract
     * NOTE: In order to prevent stranded funds (i.e. committments that cannot be honored),
     * the owner is able to withdrawl all eth from the contract. However, after this eth is
     * withdrawn the contract will not execute the tender offer.
     */
    function withdrawEth() public onlyOwner {
        Address.sendValue(payable(owner()), address(this).balance);
    }

    /**
     * @notice anyone holding the relevant ERC-20 tokens is able to commit them here
     * if they've approved this contract.
     * @param numTokens the number of tokens to commit to the buyout offer
     */
    function pledgeTokens(uint256 numTokens) public whenNotPaused nonReentrant {
        require(
            _tokenContract.allowance(msg.sender, address(this)) >= numTokens,
            "commitTokens -- contract must be approved to transfer committed tokens"
        );
        require(
            (totalCommitted + numTokens) * offerPerTokenWei >
                address(this).balance,
            "commitTokens -- commitment cannot exceed balance within the contract"
        );
        _commitments[msg.sender] = numTokens;
        totalCommitted = totalCommitted + numTokens;

        emit Commitment(msg.sender, numTokens);
    }

    /**
     * @notice fufill the commitments after the minimum number of tokens have already been committed.
     * NOTE: This function can be called multiple times in different transactions
     * in the event that too many addresses are contained here.
     * NOTE: calling this method is permissionless as long as the minimum number of commitments
     * have been made and there is sufficient eth in the contract.
     * @param recipients the array of recipients */
    function executeTenderOffer(address[] calldata recipients)
        public
        whenNotPaused
        nonReentrant
    {
        // ensure that we either have surpassed the stated minimum of the offer for the first
        // time on this invocation or has been bet on a previous invocatiom
        require(
            totalCommitted > _minimumCommittments || _minimumMet,
            "executeTenderOffer -- minimum token committment has not been met yet"
        );
        // ensure that the contract currently has enough funds to honor all of the outstanding commitments before
        // preferentially fufilling certain commitments at the expense of others.
        require(
            totalCommitted * offerPerTokenWei > address(this).balance,
            "executTenderOffer -- contract has insufficient funds to honor the outstanding offers"
        );

        _minimumMet = true;
        uint256 total = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 tokens = _commitments[recipients[i]];
            address payable recipient = payable(recipients[i]);
            uint256 numWei = _commitments[recipients[i]] * offerPerTokenWei;
            // if the contract is no longer authorized, do not transfer any funds.
            if (_tokenContract.allowance(recipient, address(this)) >= tokens) {
                _tokenContract.transferFrom(recipient, address(this), tokens);
                Address.sendValue(recipient, numWei);
                emit Settled(recipient, tokens, numWei);
            }
            totalCommitted = totalCommitted - numWei;
            delete (_commitments[recipients[i]]);
        }
    }

    //// util methods

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
