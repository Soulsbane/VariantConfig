module variantconfig;

import std.string : lineSplitter, split, strip;
import std.stdio : File;
import std.file : exists, readText;
import std.algorithm : sort;
import std.traits : isNumeric;

public import std.variant;

struct VariantConfig
{
private:
	void load() @safe
	{
		if(exists(fileName_))
		{
			auto lines = readText(fileName_).lineSplitter();

			foreach(line; lines)
			{
				auto fields = split(line, separator_);

				if(fields.length == 2)
				{
					string key = strip(fields[0]);
					Variant value = strip(fields[1]);

					values_[key] = value;
				}
			}
		}
	}

	void save() @trusted
	{
		auto configfile = File(fileName_, "w+");

		foreach(key; sort(values_.keys))
		{
			configfile.writeln(key, separator_, values_[key]);
		}
	}

public:
	this(immutable string fileName) @safe
	{
		fileName_ = fileName;
		load();
	}

	~this() @safe
	{
		save();
	}

	bool hasValue(immutable string key) pure @safe
	{
		if(key in values_)
		{
			return true;
		}
		return false;
	}

	Variant getValue(immutable string key) @safe
	{
		return values_.get(key, Variant(0));
	}

	Variant getValue(immutable string key, Variant defval) @safe
	{
		return values_.get(key, Variant(defval));
	}

	void setValue(immutable string key, Variant value) @safe
	{
		values_[key] = value;
	}

	bool remove(immutable string key) pure @safe
	{
		return values_.remove(key);
	}

	Variant opIndex(immutable string key) @safe
	{
		return getValue(key);
	}

	void opIndexAssign(T)(T value, immutable string key) @safe
	{
		setValue(key, Variant(value));
	}

private:
	immutable char separator_ = '=';
	Variant[string] values_;
	immutable string fileName_;
}

int toInt(Variant value) @safe
{
	return value.coerce!(int);
}

long toLong(Variant value) @safe
{
	return value.coerce!(long);
}

bool toBool(Variant value) @safe
{
	return value.coerce!(bool);
}

double toDouble(Variant value) @safe
{
	return value.coerce!(double);
}

real toReal(Variant value) @safe
{
	return value.coerce!(real);
}

string toStr(Variant value) @safe // NOTE: Must be named toStr instead of toString or D buildin will override.
{
	if(value == 0)
	{
		return "";
	}
	return value.coerce!(string);
}

