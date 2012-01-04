package com.ithaca.tales
{
import flash.utils.describeType;
import flash.events.TextEvent;
import mx.utils.StringUtil;

public class TALESUtil
{
    /**
     * Given a list of strings, returns the longest common leading component
     */
    public static function commonPrefix(words: Array): String
    {
        var a: String;
        var b: String;
        var lo: int;
        var hi: int;
        var mid: int;

        if (words.length == 0)
            return "";
        words.sort();
        
        a = words[0];
        b = words[words.length - 1];

        lo = 0
        hi = Math.min(a.length, b.length);
        while (lo < hi)
        {
            mid = Math.floor((lo + hi) / 2) + 1
            if (a.slice(lo, mid) == b.slice(lo, mid))
                lo = mid;
            else
                hi = mid - 1;
        }
        return a.slice(0, hi)
    }

    /**
     * Return the names of valid methods for the object.
     *
     * If numParams is specified, return methods that take the given
     * number of mandatory parameters.
     */
    public static function validMethods(o: Object, numParams: int = -1): Array
    {
        var xml: XML = describeType(o);
        var res: Array = new Array();

        for each (var m: XML in xml..method)
        {
            var mandatoryParam: XMLList = m.parameter.(@optional == false);
            // trace("Checking method " + m.@name + " -> " + mandatoryParam);
            if (numParams == -1 || numParams <= mandatoryParam.length())
                res.push(m.@name);
        }
        res.sort();
        return res;
    }

    /**
     * Return the names of valid properties/variables
     *
     */
    public static function validProperties(o: Object): Array
    {
        var xml: XML = describeType(o);
        var res: Array = new Array();
        var m: XML;

        for each (m in xml..accessor)
        {
            res.push(m.@name);
        }
        for each (m in xml..variable)
        {
            res.push(m.@name);
        }
        res.sort();
        return res;
    }

    /**
     * Handle TextInput event on a TextInput component to implement completion.
     */
    public static function onTALESTextInput(event: TextEvent, contextObject: Object = null, output: Function = null): void
    {
        if (event.text == " ")
        {
            event.preventDefault();
            event.stopPropagation();
            // Completion
            var original_expression: String = StringUtil.trim(event.target.text);
            var arr: Array = original_expression.split('/');
            var expr: String = arr.slice(0, -1).join("/");
            var target: * = null;
            var toComplete: String;
            var possibilities: Array;
            var ctx: Context = new Context(contextObject ? contextObject : event.target);

            if (arr.length == 1)
            {
                // No / -> complete the first part
                toComplete = arr[0];
                expr = "";
            }
            else
            {
                target = ctx.evaluate(expr);
                expr = expr + "/"
                toComplete = arr[arr.length - 1];
                trace("Completing", expr, "(", target, ") with ", toComplete);
            }

            if (toComplete.length == 0)
                possibilities = ctx.validMembers(target);
            else
                possibilities = ctx.validMembers(target).filter(function (o: String, i: int, arr: Array): Boolean
                                                                 {
                                                                     return (o.indexOf(toComplete) == 0);
                                                                 });

            if (possibilities.length == 1)
                // Unique solution
                event.target.text = expr + possibilities[0] + "/";
            else if (possibilities.length > 1)
            {
                var prefix: String = TALESUtil.commonPrefix(possibilities);
                event.target.text = expr + prefix;
                if (output !== null)
                    output("Completions :\n  " + possibilities.map(function(item: *, index: int, array: Array): String
                                                                   {
                                                                       return item.replace(prefix, "");
                                                                   }).join("\n  "));
            }
            else
            {
                event.target.text = original_expression;
            }
            event.target.selectRange(event.target.text.length, event.target.text.length);
        }
    }

}
}
