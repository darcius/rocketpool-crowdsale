pragma solidity ^0.4.10;
import "./base/StandardToken.sol";
import "./lib/Arithmetic.sol";

/// @title The main Rocket Pool Token (RPL) crowdsale contract
/// @author David Rugendyke

 // Tokens allocated proportionately to each sender according to amount of ETH contributed as a fraction of the total amount of ETH contributed by all senders.
 // credit for original idea and base contract goes to hiddentao - https://github.com/hiddentao/ethereum-token-sales


contract RocketPoolToken is StandardToken {


    /**** Properties ***********/

    string public name = 'Rocket Pool Token';
    string public symbol = 'RPL';
    uint256 public constant decimals = 18;
    string public version = "1.0";
    uint256 public totalSupply = 50**6;         // 50 Million
    uint256 private calcBase = 1**decimals;     // Use this as our base unit to remove the decimal place by multiplying and dividing by it since solidity doesn't support reals yet

    // Important Addresses
    address public depositAddress;        // Deposit address for ETH for ICO owner

    // Crowdsale Params
    bool public isFinalised;              // True when ICO finalized and successful
    uint256 public targetEth;             // Target ETH to raise
    uint256 public maxEthAllocation;      // Max ETH allowed per account
    uint256 public fundingStartBlock;     // When to start allowing funding
    uint256 public fundingEndBlock;       // When to stop allowing funding
 
    // Calculated values
    mapping (address => uint256) contributions;          // ETH contributed per address
    uint256 contributedTotal;                            // Total ETH contributed


    /*** Events ****************/

    event CreateRPLToken(string _name);
    event Contribute(address _sender, uint256 _value);
    event FinaliseSale(address _sender);
    event RefundContribution(address _sender, uint256 _value);
    event ClaimTokens(address _sender, uint256 _value);

    /*** Tests *****************/
    event FlagUint(uint256 flag);
    event FlagAddress(address flag);

    
    /**** Methods ***********/

    // Constructor
    /// @dev RPL Token Init
    /// @param _targetEth The target ether amount required for the crowdsale
    /// @param _maxEthAllocation The max ether allowed per account
    /// @param _depositAddress The address that will receive the funds when the crowdsale is finalised
    /// @param _fundingStartBlock The start block for the crowdsale
    /// @param _fundingEndBlock The end block for the crowdsale
    function RocketPoolToken(uint256 _targetEth, uint256 _maxEthAllocation, address _depositAddress, uint256 _fundingStartBlock, uint256 _fundingEndBlock) {
        // Initialise params
        isFinalised = false;
        targetEth = _targetEth;                        
        maxEthAllocation = _maxEthAllocation;   
        depositAddress = _depositAddress;
        fundingStartBlock = _fundingStartBlock;
        fundingEndBlock = _fundingEndBlock;
        // Fire event
        CreateRPLToken(name);
    }

    /// @dev Accepts ETH from a contributor
    function() payable external {
        
        /*
        FlagUint(targetEth);
        FlagUint(maxEthAllocation);
        FlagAddress(depositAddress);
        FlagUint(fundingStartBlock);
        FlagUint(fundingEndBlock);
        FlagUint(1);
        FlagUint(block.number);
        FlagUint(msg.value);
        */

        // Did they send anything?
        assert(msg.value > 0);  
        // Check if we're ok to receive contributions, have we started?
        assert(block.number > fundingStartBlock);       
        // Already ended?
        assert(block.number < fundingEndBlock);        
        // Max sure the user has not exceeded their ether allocation
        assert((contributions[msg.sender] + msg.value) <= maxEthAllocation);              
        // Add to contributions
        contributions[msg.sender] += msg.value;
        contributedTotal += msg.value;
        // Fire event
        Contribute(msg.sender, msg.value); 
    }

    /// @dev Get the contribution total of ETH from a contributor
    /// @param _owner The owners address
    function contributionOf(address _owner) constant returns (uint256 balance) {
        return contributions[_owner];
    }

    /// @dev Finalizes the funding and sends the ETH to deposit address
    function finaliseFunding() external {
        // Finalise the crowdsale funds
        assert(!isFinalised);                       
        // Wrong sender?
        assert(msg.sender == depositAddress);            
        // Not yet finished?
        assert(block.number > fundingEndBlock);         
        // Not enough raised?
        assert(contributedTotal >= targetEth);                 
        // We're done now
        isFinalised = true;
        // Send to deposit address - revert all state changes if it doesn't make it
        if (!depositAddress.send(targetEth)) throw;
        // Fire event
        FinaliseSale(msg.sender);
    }

    /// @dev Allows contributors to claim their tokens and/or a refund. If funding failed then they get back all their Ether, otherwise they get back any excess Ether
    function claimTokensAndRefund() external {
        // Must have previously contributed
        assert(contributions[msg.sender] > 0); 
        // Crowdfund completed
        assert(block.number > fundingEndBlock);    
        // If not enough funding
        if (contributedTotal < targetEth) {
            // Refund my full contribution
            if (!msg.sender.send(contributions[msg.sender])) throw;
            // Fire event
            RefundContribution(msg.sender, contributions[msg.sender]);
        } else {
            // Calculate what percent of the ether raised came from me
            uint256 percEtherContributed = Arithmetic.overflowResistantFraction(contributions[msg.sender], calcBase, contributedTotal);
            // Calculate how many tokens I get
            balances[msg.sender] = Arithmetic.overflowResistantFraction(percEtherContributed, totalSupply, calcBase);
            // Calculate the refund this user will receive
            if (!msg.sender.send(Arithmetic.overflowResistantFraction(percEtherContributed, (contributedTotal - targetEth), calcBase))) throw;
            // Fire event
            ClaimTokens(msg.sender, balances[msg.sender]);
      }
      // All done
      contributions[msg.sender] = 0;
    }
}
