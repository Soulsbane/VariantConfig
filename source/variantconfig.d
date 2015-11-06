module variantconfig;

import std.string : lineSplitter, split, strip, indexOf;
import std.stdio : File, writeln;
import std.file : exists, readText;
import std.algorithm : sort, find;
import std.traits : isNumeric;
import std.path : isValidFilename;

public import std.variant;

struct VariantConfig
{
private:
	void load(immutable string fileName) @safe
	{
		string text;

		if(fileName.indexOf("=") == -1)
		{
			if(exists(fileName))
			{
				text = readText(fileName);
			}
		}
		else
		{
			text = fileName; // In this case it's a string not a filename.
		}

		processText(text);
	}

	void save() @trusted
	{
		auto configfile = File(fileName_, "w+");

		foreach(key; sort(values_.keys))
		{
			configfile.writeln(key, separator_, values_[key]);
		}
	}

	void processText(immutable string text) @trusted
	{
		auto lines = text.lineSplitter();

		foreach(line; lines)
		{
			auto fields = split(line, separator_);

			if(fields.length == 2)
			{
				values_[fields[0].strip] = fields[1].strip;
			}
		}
	}
public:
	this(immutable string fileName) @safe
	{
		fileName_ = fileName;
		load(fileName);
	}

	~this() @safe
	{
		if(valuesModified_)
		{
			save();
		}
	}

	bool hasValue(immutable string key) pure @safe
	{
		if(key in values_)
		{
			return true;
		}
		return false;
	}

	Variant getValue(immutable string key) @trusted
	{
		return values_.get(key, Variant(0));
	}

	Variant getValue(immutable string key, Variant defval) @trusted
	{
		return values_.get(key, Variant(defval));
	}

	void setValue(immutable string key, Variant value) @trusted
	{
		values_[key] = value;
		valuesModified_ = true;
	}

	bool remove(immutable string key) pure @safe
	{
		return values_.remove(key);
	}

	Variant opIndex(immutable string key) @trusted
	{
		return getValue(key);
	}

	void opIndexAssign(T)(T value, immutable string key) @trusted
	{
		setValue(key, Variant(value));
	}

private:
	immutable char separator_ = '=';
	Variant[string] values_;
	immutable string fileName_; // Only used for saving
	bool valuesModified_;
}

int toInt(Variant value) @trusted
{
	return value.coerce!(int);
}

long toLong(Variant value) @trusted
{
	return value.coerce!(long);
}

bool toBool(Variant value) @trusted
{
	return value.coerce!(bool);
}

double toDouble(Variant value) @trusted
{
	return value.coerce!(double);
}

real toReal(Variant value) @trusted
{
	return value.coerce!(real);
}

string toStr(Variant value) @trusted // NOTE: Must be named toStr instead of toString or D buildin will override.
{
	if(value == 0)
	{
		return "";
	}
	return value.coerce!(string);
}

unittest
{
	string test = "
		aBool=true
		float=3443.443
		number=12071
		sentence=This is a really long sentence to test for a really long value string!
		time=12:04
	";

	auto config = VariantConfig(test);
	long number = config["number"].toLong;
	bool aBool = config["aBool"].toBool;
	string sentence = config["sentence"].toStr;
	string time = config["time"].toStr;
	double aDouble = config["aDouble"].toDouble;

	assert(number == 12071);
	assert(aBool == true);
	assert(sentence == "This is a really long sentence to test for a really long value string!");
	assert(time == "12:04");
	assert(aDouble == 3443.443);
}
