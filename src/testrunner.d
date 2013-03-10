module probat.testrunner;

import std.stdio;
import std.regex;
import std.range;
import std.format;
import std.conv;
import std.exception;
import std.string;
import probat.testenv;
import probat.testtools;

void registerTestRunner()
{
    import core.runtime;
    Runtime.moduleUnitTester = &runner;
}


bool runner()
{
    import core.runtime;
    Runtime.moduleUnitTester = null;
    bool oldSuccess = runModuleUnitTests();
    TestRunner runner = new SilentTestRunner();
    bool newSuccess = runner.run(TestData.instance);
    return oldSuccess && newSuccess;
}

/+
    Only outputs errors
+/


interface TestRunner
{
    bool run(TestData data);
}

class SilentTestRunner : TestRunner
{
    bool run(TestData data)
    {
        size_t failcount = 0;


        foreach(test; data.tests)
        {
            try
            {
                runTestProc(test);
            }
            catch(AssertException e) {

                writeln(e.msg);
                failcount ++;
            }
        }
        return failcount == 0;
    }
}

/+
    TestRunner to use for a special test binary
+/

class StandAloneTestRunner : TestRunner
{
    import std.getopt;

    string[] excludeFiles;
    string[] excludeTags;
    string[] excludeNumbers;

    string[] includeFiles;
    string[] includeTags;
    string[] includeNumbers;

    //specification of form [num|tag][@file]
    string[] runOnly;
    bool verbose;

    this(string[] argv)
    {
        getopt(argv,
               "ex-files", &excludeFiles,
               "ex-tags", &excludeTags,
               "ex-nums", &excludeNumbers,
               "in-files", &includeFiles,
               "in-tags", &includeTags,
               "in-nums", &includeNumbers,
               "only", &runOnly,
               "verbose|v", &verbose
              );
    }


    bool run(TestData data = null)
    {
        if(data is null)
            data = TestData.instance;
        // if runOnly is set, run only these tests and ignore the rest
        if(runOnly.length)
            return doRunOnly(data);

        bool allTrue = true;
        foreach(testFile; data.testsByFile.byKey)
        {
            if(oneMatch(excludeFiles, testFile) && !oneMatch(includeFiles, testFile))
                continue;
            foreach(size_t num, test; data.testsByFile[testFile])
            {
                if(oneMatch(excludeNumbers, to!string(num))
                    && !oneMatch(includeNumbers, to!string(num)))
                    continue;
                if(oneMatch(excludeTags, test.tag) && !oneMatch(includeTags, test.tag))
                    continue;

                allTrue &= runTestProc(test, !verbose, cast(int) num);
            }
        }
        return allTrue;
    }

    bool doRunOnly(TestData data = null)
    {
        if(data is null)
            data = TestData.instance;

        bool allTrue = true;
        foreach(roSpec; runOnly)
        {
            string file, tagOrNum;
            string[] parts = std.string.split(roSpec, "@");
            enforce(parts.length == 1 || parts.length == 2,
                    "invalid runOnly specification");

            if(parts.length == 2)
                file = parts[1];
            tagOrNum = parts[0];

            if(file != "")
            {
                enforce(file in data.testsByFile,
                    format("no tests for %s", file));

                allTrue &= runTestInFile(data.testsByFile[file], tagOrNum);
            }
            else
                allTrue &= runTestByTag(data.tests, tagOrNum);
        }
        return allTrue;
    }

    bool runTestInFile(Range)(Range tests, string tagOrNum)
    {
        // check if its a number
        int num;
        bool numerical = true;
        try
            num = to!int(tagOrNum);
        catch(ConvException excp)
            numerical = false;

        if(numerical)
        {
            tests.popFrontN(num);
            return runTestProc(tests.front, !verbose, num);
        }
        else
        {
            return runTestByTag(tests, tagOrNum);
        }
    }

    bool runTestByTag(Range)(Range tests, string tag)
    {
        bool allTrue = true;
        foreach(test; tests)
        {
            if(tag == test.tag)
                allTrue &= runTestProc(test, !verbose);
        }
        return allTrue;
    }


    bool oneMatch(string[] matchThese, string againstThis)
    {
        foreach(these; matchThese)
        {
            if(againstThis.match(these))
                return true;
        }
        return false;
    }
}


void printPostText(TestData.Test test, bool success)
{
    if(success)
        writeln(" Success!");
    stdout.flush();
}

void printPreText(TestData.Test test, int num = -1)
{
    auto app = appender!string();
    immutable string templNum = "#%s: Running '%s' @ %s:\n\t %s ...";
    immutable string templNoNum = templNum[5 .. $];
    if(num == -1)
        formattedWrite(app, templNoNum, test.tag, test.file, test.desc);
    else
        formattedWrite(app, templNum, num, test.tag, test.file, test.desc);
    write(app.data);
}

void printErrorText(TestData.Test test, AssertException excp, bool tellReason=true)
{
    writeln("  Failure!");
    if(tellReason)
    {
        writef("Reason: %s\n", excp.msg);
    }
}


bool runTestProc(TestData.Test test, bool silent = true, int num = -1)
{
    printPreText(test, num);
    auto oldstdout = stdout;
    auto oldstderr = stderr;
    if(silent)
    {
        stdout.open("/dev/null", "w");
        stdout.open("/dev/null", "w");
    }
    AssertException ex;
    try
        test.testproc();
    catch(AssertException excp)
        ex = excp;

    stdout = oldstdout;
    stderr = oldstderr;
    if(ex !is null)
    {
        printPostText(test, false);
        printErrorText(test, ex);
    }
    else
    {
        printPostText(test, true);
    }
    return ex is null;
}
