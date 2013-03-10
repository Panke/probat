module probat.testenv;

import std.stdio;
import std.exception;
import std.algorithm;
import std.conv;
import std.traits;
import std.variant;
import std.range;
import std.string;

enum State { NotRun, Success, Failure };

auto flatten(RangeOfRange)(RangeOfRange ror)
{
    alias ElementType!RangeOfRange Range;
    alias ElementType!Range E;

    struct Result
    {
        RangeOfRange _ror;

        this(RangeOfRange ror) { _ror = ror; }

        @property
        E front()
        {
            return _ror.front.front;
        }

        void popFront()
        {
            if(_ror.front.empty)
                _ror.popFront;
            _ror.front.popFront;
        }

        @property
        bool empty()
        {
            while(!_ror.empty && _ror.front.empty)
                _ror.popFront;

            return _ror.empty;
        }
    }

    return Result(ror);
}

class TestData
{
    struct Test
    {
        void delegate() testproc;
        string desc;
        string file;
        string tag;

        this(void delegate() dg, string desc, string tag, string file)
        {
            this.desc = desc;
            this.testproc = dg;
            this.file = file;
            this.tag = tag;
        }
    }

    Test[][string] _testsByFile;

    @property testsByFile() { return _testsByFile; }

    @property auto tests()
    {
        return flatten(_testsByFile.values);
    }

    private this() {};

    @property
    static TestData instance()
    {
        if(self_ is null)
        {
            self_ = new TestData();
            return self_;
        }
        return self_;
    }

    void register(Test tmp)
    {
        _testsByFile[tmp.file] ~= tmp;
    }


    private static TestData self_;

}


void testCase(string desc, void delegate() dg, string tag = "", string file = __FILE__)
{
    TestData.Test tmp = TestData.Test(dg, desc, tag, file);
    TestData.instance.register(tmp);
}



