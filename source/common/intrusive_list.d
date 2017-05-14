module intrusive_list;

import std.traits;
import std.range;

struct IntrusiveListLink
{
@nogc:
pure nothrow:
private:
    IntrusiveListLink* mPrev = null;
    IntrusiveListLink* mNext = null;
public:
    ~this()
    {
        unlink();
    }
    @disable this(this);

    void unlink()
    {
        assert(!!mPrev == !!mNext);
        if(mPrev !is null)
        {
            mPrev.mNext = mNext;
            mNext.mPrev = mPrev;
            mNext = null;
            mPrev = null;
        }
    }

    @property isLinked() const
    {
        assert(!!mPrev == !!mNext);
        return mPrev !is &this && mPrev !is null;
    }
}

struct IntrusiveList(T, string Field) if(is(T == struct) || is(T == class))
{
@nogc:
pure nothrow:
private:
    IntrusiveListLink mHead;
    static if(is(T == struct))
    {
        alias Ptr = T*;
    }
    else
    {
        alias Ptr = T;
    }
    static auto getObject(inout(IntrusiveListLink)* p) @trusted
    {
        mixin("enum offset = T."~Field~".offsetof;");
        return cast(inout(Ptr))(cast(inout(void)*)p - offset);
    }
    static auto getLink(inout Ptr obj) @trusted
    {
        mixin("return &obj."~Field~";");
    }
public:
    ~this()
    {
        assert(empty);
    }

    @property empty() const
    {
        return !mHead.isLinked;
    }

    void insertFront(Ptr item)
    {
        assert(item !is null);
        assert(!getLink(item).isLinked);
        assert(!!mHead.mPrev == !!mHead.mNext);
        if(mHead.mPrev is null)
        {
            mHead.mPrev = &mHead;
            mHead.mNext = &mHead;
        }
        getLink(item).mPrev = &mHead;
        getLink(item).mNext = mHead.mNext;

        mHead.mNext.mPrev = getLink(item);
        mHead.mNext       = getLink(item);
    }
    void insertBack(Ptr item)
    {
        assert(item !is null);
        assert(!getLink(item).isLinked);
        assert(!!mHead.mPrev == !!mHead.mNext);
        if(mHead.mPrev is null)
        {
            mHead.mPrev = &mHead;
            mHead.mNext = &mHead;
        }
        getLink(item).mPrev = mHead.mPrev;
        getLink(item).mNext = &mHead;

        mHead.mPrev.mNext = getLink(item);
        mHead.mPrev       = getLink(item);
    }
    void clear()
    {
        IntrusiveListLink* curr = &mHead;
        while(curr.isLinked)
        {
            auto next = curr.mNext;
            curr.unlink();
            curr = next;
        }
    }

    private struct Range(bool Const)
    {
    @nogc:
        pure nothrow:
        static if(Const)
        {
            alias LinkT = const(IntrusiveListLink);
        }
        else
        {
            alias LinkT = IntrusiveListLink;
        }
        private LinkT* mFirst = null;
        private LinkT* mLast  = null;
        private this(LinkT* head)
        {
            assert(head !is null);
            mFirst = head.mNext;
            mLast  = head.mPrev;
        }

        /// Input range primitives.
        @property
        bool empty() const
        {
            assert(!!mFirst == !!mLast);
            return mFirst is null;
        }

        /// ditto
        @property front() inout
        {
            assert(!empty);
            return getObject(mFirst);
        }

        /// ditto
        void popFront()
        {
            assert(!empty);
            if(mFirst is mLast)
            {
                mFirst = null;
                mLast  = null;
            }
            else
            {
                assert(mFirst.mNext !is null && mFirst is mFirst.mNext.mPrev);
                mFirst = mFirst.mNext;
            }
        }

        /// Forward range primitive.
        @property Range save() { return this; }

        auto opSlice() { return this; }

        /// Bidirectional range primitives.
        @property back() inout
        {
            assert(!empty);
            return getObject(mLast);
        }

        /// ditto
        void popBack()
        {
            assert(!empty);
            if(mFirst is mLast)
            {
                mFirst = null;
                mLast  = null;
            }
            else
            {
                assert(mLast.mPrev && mLast is mLast.mPrev.mNext);
                mLast = mLast.mPrev;
            }
        }

        unittest
        {
            static assert(isBidirectionalRange!Range);
        }
    }

    auto opSlice()
    {
        if (empty)
        {
            return Range!false();
        }
        else
        {
            return Range!false(&mHead);
        }
    }

    auto opSlice() const
    {
        if (empty)
        {
            return Range!true();
        }
        else
        {
            return Range!true(&mHead);
        }
    }

    @property front() inout
    {
        assert(!empty);
        return getObject(mHead.mNext);
    }
    @property back() inout
    {
        assert(!empty);
        return getObject(mHead.mPrev);
    }
}

unittest
{
    void test(Node)()
    {
        alias NodeList = IntrusiveList!(Node,"link");
        {
            NodeList list;
            assert(list.empty);
            list.insertFront(new Node);
            assert(!list.empty);
            list.front.link.unlink();
            assert(list.empty);
            list.insertBack(new Node);
            assert(!list.empty);
            list.back.link.unlink();
            assert(list.empty);
        }
        {
            import std.conv;
            NodeList list;
            string str;
            list.insertFront(new Node(0));
            list.insertFront(new Node(1));
            list.insertFront(new Node(2));
            list.insertFront(new Node(3));
            list.insertFront(new Node(4));
            foreach(n;list[])
            {
                str ~= text(n.i);
            }
            assert(str == "43210",str);
            str.length = 0;
            foreach_reverse(n;list[])
            {
                str ~= text(n.i);
            }
            assert(str == "01234",str);
            list.clear();
            assert(list.empty);
            str.length = 0;
            list.insertBack(new Node(0));
            list.insertBack(new Node(1));
            list.insertBack(new Node(2));
            list.insertBack(new Node(3));
            list.insertBack(new Node(4));
            foreach(n;list[])
            {
                str ~= text(n.i);
            }
            assert(str == "01234",str);
            str.length = 0;
            foreach_reverse(n;list[])
            {
                str ~= text(n.i);
            }
            assert(str == "43210",str);
            list.clear();
            assert(list.empty);
        }
        {
            NodeList list;
            auto ns = [
                new Node(0),
                new Node(1),
                new Node(2),
                new Node(3),
                new Node(4)];
            foreach(n;ns[])
            {
                list.insertBack(n);
            }
            assert(!list.empty);
            list.clear();
            assert(list.empty);
            foreach(n;ns[])
            {
                assert(!n.link.isLinked);
            }
        }
    }
    struct Foo
    {
        int i;
        IntrusiveListLink link;
        this(int _i)
        {
            i = _i;
        }
    }
    class Bar
    {
        int i;
        IntrusiveListLink link;
        this(int _i = 0)
        {
            i = _i;
        }
    }
    test!Foo();
    test!Bar();
}