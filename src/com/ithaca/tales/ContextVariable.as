package com.ithaca.tales
{
public class ContextVariable
{
    private var _value: * = null;

    public function ContextVariable(val: *)
    {
        _value = val;
    }

	public function value(currentPath: * = null): *
    {
	    if (_value is Function)
        {
			return _value.apply(this, new Array());
        }
        else
        {
		    return _value;
        }
    }
		
	public function rawValue(): *
    {
		return _value;
    }
		
	public function toString(): String
    {
		return _value.toString();
    }
}
}
