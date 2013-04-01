module probat.testtools;

import std.conv, std.string, std.range;
import core.exception;


class AssertException : Exception
{
    this(A...)(A a)
    {
        super(a);
    }
}

bool assNis(T,Q)(T t, Q q, string file = __FILE__, size_t line = __LINE__)
{
    if(t !is q)
        return true;

    throw new AssertException("assNis", file, line);
}

bool assNeq(T, Q)(T t, Q q, string file = __FILE__, size_t line = __LINE__)
{
    if(t != q)
        return true;

    static if(__traits(compiles, to!string(t)))
        string tstr = to!string(t);
    else
        string tstr = "lhs";

    static if(__traits(compiles, to!string(q)))
        string qstr = to!string(q);
    else
        string qstr = "rhs";


    string msg = format("assNeq fails: [%s] == [%s]", tstr, qstr);
    throw new AssertException(msg, file, line);
}

bool assEq(T, Q)(T t, Q q, string file = __FILE__, size_t line = __LINE__)
    if(!isForwardRange!T || !isForwardRange!Q)
{
    if(t == q)
        return true;

    static if(__traits(compiles, to!string(t)))
        string tstr = to!string(t);
    else
        string tstr = "lhs";

    static if(__traits(compiles, to!string(q)))
        string qstr = to!string(q);
    else
        string qstr = "rhs";


    string msg = format("assEq fails: [%s] != [%s]", tstr, qstr);
    throw new AssertException(msg, file, line);
}

bool assEq(T, Q)(T t, Q q, string file = __FILE__, size_t line = __LINE__)
    if(isForwardRange!T && isForwardRange!Q && !isInfinite!T)
{
    auto tOrig = t.save;
    auto qOrig = q.save;
    bool equal = true;
    while(!t.empty)
    {
        if(q.empty)
        {
            equal = false;
            break;
        }
        auto curT = t.front;
        t.popFront;
        auto curQ = q.front;
        q.popFront;
        if(t != q)
        {
            equal = false;
            break;
        }
    }
    if(!q.empty)
        equal = false;

    if(equal)
        return true;

    static if(__traits(compiles, to!string(tOrig)))
        string tstr = to!string(tOrig);
    else
        string tstr = "lhs";

    static if(__traits(compiles, to!string(qOrig)))
        string qstr = to!string(qOrig);
    else
        string qstr = "rhs";


    string msg = format("assEq fails: [%s] != [%s]", tstr, qstr);
    throw new AssertException(msg, file, line);

}

void assertThrows(Ex = Exception, E)(lazy E expr,
                                     string file = __FILE__,
                                     size_t line = __LINE__)
{
    bool threw = false;
    string msg = "Did not throw";

    static if(! is(Ex == Exception) )
    {
        try {
            expr();
        }
        catch(Ex e)
        {
            threw = true;
        }

        catch(Exception wrong)
        {
            msg = "Threw the wrong exception";
        }
    }
    else
    {
        try {
            expr();
        }
        catch(Ex e)
        {
            threw = true;
        }
    }
    if(!threw)
    {
        throw new AssertException(msg, file, line);
    }
}
