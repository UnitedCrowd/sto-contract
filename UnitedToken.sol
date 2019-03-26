pragma solidity ^0.4.25;

library SafeMath
{
	function mul(uint a, uint b) internal pure
	returns (uint)
	{
		uint c = a * b;

		assert(a == 0 || c / a == b);

		return c;
	}

	function div(uint a, uint b) internal pure
	returns (uint)
	{
		// assert(b > 0); // Solidity automatically throws when dividing by 0
		uint c = a / b;
		// assert(a == b * c + a % b); // There is no case in which this doesn't hold
		return c;
	}

	function sub(uint a, uint b) internal pure
	returns (uint)
	{
		assert(b <= a);

		return a - b;
	}

	function add(uint a, uint b) internal pure
	returns (uint)
	{
		uint c = a + b;

		assert(c >= a);

		return c;
	}
}

interface ERC20
{
	function totalSupply() view external returns (uint _totalSupply);
	function balanceOf(address _owner) view external returns (uint balance);
	function transfer(address _to, uint _value) external returns (bool success);
	function transferFrom(address _from, address _to, uint _value) external returns (bool success);
	function approve(address _spender, uint _value) external returns (bool success);
	function allowance(address _owner, address _spender) view external returns (uint remaining);

	event Transfer(address indexed _from, address indexed _to, uint _value);
	event Approval(address indexed _owner, address indexed _spender, uint _value);
}

contract Ownable
{
	address public owner;

	event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

	constructor(address _owner) public
	{
		owner = _owner;
	}

	modifier onlyOwner()
	{
		require(msg.sender == owner);
		_;
	}

	function transferOwnership(address newOwner) external onlyOwner
	{
		require(newOwner != address(0));
		owner = newOwner;
		emit OwnershipTransferred(owner, newOwner);
	}
}

contract FreezableToken is Ownable
{
	mapping (address => bool) frozenAccount;

	event FrozenFunds(address _target, bool _frozen);

	constructor(address _owner) Ownable(_owner) public
	{

	}

	function freezeAccount(address _target) public onlyOwner
	{
		frozenAccount[_target] = true;
		emit FrozenFunds(_target, true);
	}

	function unFreezeAccount(address _target) public onlyOwner
	{
		frozenAccount[_target] = false;
		emit FrozenFunds(_target, false);
	}

	function isFrozen(address _target) view public returns (bool)
	{
		return frozenAccount[_target];
	}
}

contract Pausable is Ownable
{
	bool public paused = false;

	event EPause();
	event EUnpause();

	modifier whenPaused()
	{
		require(paused);
		_;
	}

	modifier whenNotPaused()
	{
		require(!paused);
		_;
	}

	function pause() public onlyOwner
	{
		paused = true;
		emit EPause();
	}

	function unpause() public onlyOwner
	{
		paused = false;
		emit EUnpause();
	}

	function isPaused() view public returns(bool)
	{
		return paused;
	}

	function pauseInternal() internal
	{
		paused = true;
		emit EPause();
	}

	function unpauseInternal() internal
	{
		paused = false;
		emit EUnpause();
	}
}

contract DividendToken is ERC20, FreezableToken
{
	using SafeMath for uint;

	uint public totalDividendPoints;
	uint public totalSupply;
	uint8 public decimals = 18;

	mapping (address => uint) public balances;
	mapping (address => uint) public lastDividendPoints;
	mapping (address => mapping (address => uint)) public allowance;

	event DividendAdded(uint amount);

	constructor(uint _totalSupply, address _owner) FreezableToken(_owner) public
	{
		totalSupply = _totalSupply * 10 ** uint(decimals);
		balances[_owner] = totalSupply;
	}

	function dividendsOwing(address account) internal view returns(uint)
	{
		assert(totalDividendPoints >= lastDividendPoints[account]);
		uint newDividendPoints = totalDividendPoints.sub(lastDividendPoints[account]);
		return (balances[account].mul(newDividendPoints)).div(totalSupply);
	}

	modifier updateAccount(address account)
	{
		uint owing = dividendsOwing(account);
		if(owing > 0)
		{
			account.transfer(owing);
		}
		lastDividendPoints[account] = totalDividendPoints;
		_;
	}

	function addDividend() onlyOwner external payable
	{
		require(msg.value > 0);
		totalDividendPoints = totalDividendPoints.add(msg.value);
		emit DividendAdded(msg.value);
	}

	function totalSupply() view external returns (uint _totalSupply)
	{
		return totalSupply;
	}
	function balanceOf(address _owner) view external returns (uint balance)
	{
		return balances[_owner];
	}

	function allowance(address _owner, address _spender) view external returns (uint remaining)
	{
		return allowance[_owner][_spender];
	}
	function _transfer(address _from, address _to, uint _value) updateAccount(_to) updateAccount(msg.sender) internal
	{
		require(_to != address(0));
		require (!isFrozen(_from) && !isFrozen(_to));
		require(balances[_from] >= _value);
		require((balances[_to]).add(_value) > balances[_to]);

		balances[_from] = balances[_from].sub(_value);
		balances[_to] = balances[_to].add(_value);

		emit Transfer(_from, _to, _value);
	}

	function transfer(address _to, uint _value) public returns (bool success)
	{
		_transfer(msg.sender, _to, _value);
		return true;
	}

	function transferFrom(address _from, address _to, uint _value) public returns (bool success)
	{
		require(_value <= allowance[_from][msg.sender]);
		allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
		_transfer(_from, _to, _value);
		return true;
	}

	function approve(address _spender, uint _value) public returns(bool success)
	{
		allowance[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}

	function increaseApproval(address _spender, uint _value) public returns(bool success)
	{
		allowance[msg.sender][_spender] = allowance[msg.sender][_spender].add(_value);
		emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
		return true;
	}

	function decreaseApproval(address _spender, uint _value) public returns(bool success)
	{
		uint oldValue = allowance[msg.sender][_spender];
		if(_value > oldValue)
		{
			allowance[msg.sender][_spender] = 0;
		}
		else
		{
			allowance[msg.sender][_spender] = oldValue.sub(_value);
		}
		emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
		return true;
	}
}

contract PausableToken is DividendToken, Pausable
{
	constructor(uint _totalSupply, address _owner) DividendToken(_totalSupply, _owner) public
	{

	}

	function transfer(address _to, uint _value) public whenNotPaused returns (bool)
	{
		return super.transfer(_to, _value);
	}

	function transferFrom(address _from, address _to, uint _value) public whenNotPaused returns (bool)
	{
		return super.transferFrom(_from, _to, _value);
	}

	function approve(address _spender, uint _value) public whenNotPaused returns (bool)
	{
		return super.approve(_spender, _value);
	}

	function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool success)
	{
		return super.increaseApproval(_spender, _addedValue);
	}

	function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool success)
	{
		return super.decreaseApproval(_spender, _subtractedValue);
	}
}

contract VestableToken is PausableToken
{
	using SafeMath for uint;

	address public vestingTokenWallet;
	struct VestingDetail
	{
		address beneficiary;
		uint startDate;
		uint cliffDate;
		uint durationSec;
		uint released;
		uint fullyVestedAmount;
		bool isRevokable;
		bool revoked;
	}

	mapping (address => VestingDetail) vestingDetails;
	mapping (address => bool) alreadyVested;

	// emitted when new beneficiary added
	event VestedTokenGranted(address beneficiary, uint indexed startDate, uint cliffDate, uint indexed durationSec, uint indexed fullyVestedAmount, bool isRevokable);

	// emitted when vesting revoked - all pending tokens are given out, no further vesting done
	event VestedTokenRevoked(address indexed beneficiary);

	// emitted when tokens released
	event VestedTokenReleased(address indexed beneficiary, uint indexed amount);

	constructor(address _vestingTokenWallet, uint _totalSupply, address _owner) PausableToken(_totalSupply, _owner) public
	{
		vestingTokenWallet = _vestingTokenWallet;
	}

	function grantVestedTokens(address beneficiary, uint fullyVestedAmount, uint startDate, uint cliffSec, uint durationSec, bool isRevokable) public onlyOwner returns(bool) // 0 indicates start "now"
	{
		require(beneficiary != address(0));
		require (!alreadyVested[beneficiary]);
		require(!isFrozen(beneficiary));
		require(durationSec >= cliffSec);

		uint _startDate = startDate;
		if (_startDate == 0)
		{
			_startDate = now;
		}

		uint cliffDate = _startDate.add(cliffSec);

		vestingDetails[beneficiary] = VestingDetail(beneficiary, _startDate, cliffDate, durationSec, 0, fullyVestedAmount, isRevokable, false);
		alreadyVested[beneficiary] = true;

		emit VestedTokenGranted(beneficiary, _startDate, cliffDate, durationSec, fullyVestedAmount, isRevokable);
		return true;
  }

	// lets admin remove a beneficiary vesting schedule
	function revokeVesting(address beneficiary) public onlyOwner returns (bool)
	{
		require(beneficiary != address(0));
		require (vestingDetails[beneficiary].isRevokable == true);

		releaseVestedTokens(beneficiary);
		vestingDetails[beneficiary].revoked = true;
		alreadyVested[beneficiary] = false;

		emit VestedTokenRevoked(beneficiary);
		return true;
	}

	function releaseVestedTokens(address beneficiary) public returns (bool)
	{
		require(beneficiary != address(0));
		require(!isFrozen(beneficiary));
		require(vestingDetails[beneficiary].revoked == false);

		uint unreleased = releasableAmount(beneficiary);

		if (unreleased == 0)
		{
			return true;
		}

		vestingDetails[beneficiary].released = vestingDetails[beneficiary].released.add(unreleased);
		_transfer(vestingTokenWallet, beneficiary, unreleased);
		emit VestedTokenReleased(beneficiary, unreleased);
		return true;
	}

	function releasableAmount(address beneficiary) public view returns (uint)
	{
		return vestedAmount(beneficiary).sub(vestingDetails[beneficiary].released);
	}

	function vestedAmount(address beneficiary) public view returns (uint)
	{
		uint totalBalance = vestingDetails[beneficiary].fullyVestedAmount;

		if (block.timestamp < vestingDetails[beneficiary].cliffDate)
		{
			return 0;
		}
		else if (block.timestamp >= vestingDetails[beneficiary].startDate.add(vestingDetails[beneficiary].durationSec))
		{
			return totalBalance;
		}
		else
		{
			return totalBalance.mul(block.timestamp.sub(vestingDetails[beneficiary].startDate)).div(vestingDetails[beneficiary].durationSec);
		}
	}
}

contract UnitedToken is VestableToken
{
	using SafeMath for uint;

	string public name;
	string public symbol;

	constructor(string _name, string _symbol, address _vestingTokenWallet, uint _totalSupply , address _owner) VestableToken(_vestingTokenWallet, _totalSupply, _owner) public
	{
		name = _name;
		symbol = _symbol;
	}
}
