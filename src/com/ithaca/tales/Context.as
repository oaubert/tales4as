/**
 * Basic TALES interpreter.
 *
 * It interprets a subset of TALES expressions.
 */
package com.ithaca.tales
{
import mx.utils.StringUtil;

public class Context
{
    private var _this: * = this;
    private var locals: Object = new Object();
    private var globals: Object = new Object();

    public function Context(ref: *, locals: Object = null)
    {
        this._this = ref;
        if (locals !== null)
            this.locals = locals;
        this.locals['this'] = ref;
    }

    public function validMembers(o: Object): Array
    {
        if (o === null)
        {
            var res: Array = new Array();
            for (var p: String in this.locals)
                res.push(p);
            res.sort();
            return res;
        }
        else
            return TALESUtil.validProperties(o).concat(TALESUtil.validMethods(o, 0));
    }
    public function callable(f: *): Boolean
    {
        return (f is Function);
    }

	public function evaluate(expr: String): *
    {
        var protocol: String;
        var subexpr: String;

        expr = StringUtil.trim(expr);

        if (expr.substring(0, 5) == 'path:')
            return this.evaluatePath(StringUtil.trim(expr.substring(5)))
        /*
        else if (expr.substring(0, 7) == 'exists:')
            return this.evaluateExists(StringUtil.trim(expr.substring(7)))
        else if (expr.substring(0, 7) == 'nocall:')
            return this.evaluateNoCall(StringUtil.trim(expr.substring(7)))
        else if (expr.substring(0, 4) == 'not:')
            return this.evaluateExists(StringUtil.trim(expr.substring(4)))
        */
        else if (expr.substring(0, 7) == 'string:')
            return this.evaluateString(StringUtil.trim(expr.substring(7)))
		else
			return this.evaluatePath(expr)
    }

    public function evaluatePath(expr: String): *
    {
        trace("Evaluating path: ", expr);
        var allPaths: Array = expr.split('|')
		if (allPaths.length > 1)
        {
			for each (var path: String in allPaths)
            {
				try
                {
					return this.evaluate(StringUtil.trim(path))
                }
                catch (e: PathNotFoundException)
                {
					// Path didn't exist, try the next one
					continue;
                }
            }
			// No paths evaluated - raise exception.
            throw new PathNotFoundException("No path evaluated");
        }
		else
        {
			// A single path - so let's evaluate it.
			// This *can* raise PathNotFoundException
			return this.traversePath(allPaths[0])
        }
    }

	public function evaluateString(expr: String): *
    {
        trace("Evaluating String ", expr);
		var result: String = "";
		var skipCount: int = 0;
        var pathResult: String;

		for (var position: uint = 0 ; position < expr.length ; position++)
        {
			if (skipCount > 0)
				skipCount -= 1
			else
            {
				if (expr.charAt(position) == '$')
                {
					if (expr.charAt(position + 1) == '$')
                    {
						// Escaped $ sign
						result += '$';
						skipCount = 1;
                    }
					else if (expr.charAt(position + 1) == '{') 
                    {
						// Looking for a path!
						var endPos: int = expr.indexOf('}', position + 1);
						if (endPos > 0)
                        {
							var path: String = expr.slice(position + 2, endPos);
                            //  Evaluate the path - missing paths raise exceptions as normal.
							try
                            {
								pathResult = this.evaluate(path);
                            }
							catch (e: PathNotFoundException)
                            {
								// This part of the path didn't evaluate to anything - leave blank
								pathResult = ''
                            }
							if (pathResult !== null)
                            {
                                result += pathResult;
                            }
							skipCount = endPos - position;
                        }
                    }
					else
                    {
						// It's a variable
						endPos = expr.indexOf(' ', position + 1);
						if (endPos == -1)
							endPos = expr.length;
						path = expr.slice(position + 1, endPos);

						// Evaluate the variable - missing paths raise exceptions as normal.
						try
                        {
							pathResult = this.traversePath(path)
                        }
						catch (e: PathNotFoundException)
                        {
							// This part of the path didn't evaluate to anything - leave blank
							pathResult = ''
                        }
						if (pathResult !== null)
                        {
							result += pathResult;
                        }
						skipCount = endPos - position - 1;
                    }
                }
				else
                {
					result += expr.charAt(position);
                }
            }
        }
		return result;
    }

    public function traversePath(expr: String, canCall: Boolean = true): *
    {
        // canCall only applies to the *final* path destination, not points down the path.
	    // Check for and correct for trailing/leading quotes
        trace("traversePath ", expr);
		if (expr.charAt(0) == '"' || expr.charAt(0) == "'")
        {
			if (expr.charAt(expr.length - 1) == '"' || expr.charAt(expr.length - 1) == "'")
				expr = expr.slice(1, -1);
			else
				expr = expr.slice(1);
        }
		else if (expr.charAt(expr.length - 1) == '"' || expr.charAt(expr.length - 1) == "'")
			expr = expr.slice(0, -1);
        if (expr.charAt(expr.length - 1) == "/")
            // Trailing /, simply remove
            expr = expr.slice(0, -1)
		var pathList: Array = expr.split('/');
		
		var path: * = pathList[0];
        var val: *;
		if (path.charAt(0) == '?')
        {
			path = path.slice(1);
			if (this.locals.hasOwnProperty(path))
            {
				path = this.locals[path];
				if (path is ContextVariable)
                    path = (path as ContextVariable).value()
                else if (callable(path))
                    path = (path as Function).apply(this, new Array());
            }			
			else if (this.globals.hasOwnProperty(path))
            {
				path = this.globals[path];
				if (path is ContextVariable)
                    path = (path as ContextVariable).value();
                else if (callable(path))
                    path = (path as Function).apply(this, new Array());
            }
        }
		if (this.locals.hasOwnProperty(path))
			val = this.locals[path]
		else if (this.globals.hasOwnProperty(path))
			val = this.globals[path]  
		else
        {
            try
            {
                val = this[path];
            }
            catch (e: Error)
            {
			    // If we can't find it then raise an exception
			    throw new PathNotFoundException("Property '" + path + "' not found in " + this);
            }
        }
		var index: uint = 1;

		for each (path in pathList.slice(1))
        {
			if (path.charAt(0) == '?')
            {
				path = path.slice(1);
				if (this.locals.hasOwnProperty(path))
                {
					path = this.locals[path];
					if (path is ContextVariable)
                        path = (path as ContextVariable).value();
					else if (callable (path))
                        path = (path as Function).apply(this, new Array());
                }
				else if (this.globals.hasOwnProperty(path))
                {
					path = this.globals[path];
					if (path is ContextVariable)
                        path = path.value();
					else if (callable (path))
                        path = path.apply(this, new Array());
                }
				trace("Dereferenced to ", path)
            }
			try 
            {
                var temp: *;
				if (val is ContextVariable)
                    temp = val.value((index, pathList));
				else if (callable(val))
                    temp = val.apply(this, new Array());
				else
                    temp = val;
            } 
            catch (e: ContextVariable) 
            {
                // Fast path for those functions that return values
				return e.value()
            }
				
            trace("Temp=", temp);
            try
            {
                val = temp[path];
            }
            catch (e: Error)
            {
                try
                {
                    val = temp[int(path)];
                }
                catch (e: Error)
                {
				    throw new PathNotFoundException("Property " + path + " not found in " + temp);
                }
            }

			index = index + 1
        }
        trace("Found value ", val);

		if (canCall)
        {
			try
            {
                var result: *;
				if (val is ContextVariable)
                    result = val.value((index,pathList))
				else if (callable(val))
                    result = val.apply(temp, new Array());
				else
                    result = val;
            }
			catch (e: ContextVariable)
            {
				// Fast path for those functions that return values
				return e.value()
            }
        }
		else
        {
			if (val is ContextVariable)
                result = val.realValue;
			else
                result = val;
        }
		return result
    }
}
}
