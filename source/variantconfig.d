/**
*	This module manages a config file format in the form of key=value. Much like an ini file but simpler.
*
*	Author: Paul Crane
*/

module raijin.keyvalueconfig;

import std.conv : to;
import std.string : lineSplitter, indexOf, strip, startsWith, endsWith, stripLeft, stripRight;
import std.stdio : File, writeln;
import std.file : exists, readText;
import std.algorithm : sort, findSplit, filter, canFind, remove;
import std.range : take;
import std.array : empty, array;
import std.typecons : tuple;
import std.variant;

import typeutils;

private enum DEFAULT_GROUP_NAME = null;
private enum DEFAULT_CONFIG_FILE_NAME = "app.config";

private struct KeyValueData
{
	string key;
	Variant value;
	string group;
	string comment;
}

/**
*	Handles the processing of config files.
*/
struct VariantConfig
{
private:

	/**
	*	Processes the text found in config file into an array of KeyValueData structures.
	*
	*	Params:
	*		text = The text to be processed.
	*/
	bool processText(const string text) @trusted
	{
		auto lines = text.lineSplitter();
		string currentGroupName = DEFAULT_GROUP_NAME;
		string currentComment;

		foreach(line; lines)
		{
			line = strip(line);

			if(line.empty)
			{
				continue;
			}
			else if(line.startsWith("#"))
			{
				currentComment = line[1..$];
			}
			else if(line.startsWith("["))
			{
				if(line.endsWith("]"))
				{
					immutable string groupName = line[1..$-1];
					currentGroupName = groupName;
				}
				else
				{
					return false; // Error incomplete group.
				}
			}
			else
			{
				auto groupAndKey = line.findSplit("=");
				auto key = groupAndKey[0].stripRight();
				immutable auto value = groupAndKey[2].stripLeft();

				if(groupAndKey[1].length)
				{
					KeyValueData data;

					data.key = key;
					data.group = currentGroupName;

					if(value.isInteger)
					{
						data.value = to!long(value);
					}
					else if(value.isDecimal)
					{
						data.value = to!double(value);
					}
					else if(isBoolean(value, AllowNumericBooleanValues.no))
					{
						data.value = to!bool(value);
					}
					else
					{
						data.value = value;
					}

					if(currentComment != "")
					{
						data.comment = currentComment;
						currentComment = string.init;
					}

					values_ ~= data;
				}
				else
				{
					return false; // Error line doesn't contain an = sign.
				}
			}
		}

		return true;
	}

	/**
	*	Determines if the group string is in the form of group.key.
	*
	*	Params:
	*		value = The string to test.
	*
	*	Returns:
	*		true if the string is in the group.key form false otherwise.
	*/
	bool isGroupString(const string value) pure @safe
	{
		if(value.indexOf(".") == -1)
		{
			return false;
		}
		return true;
	}

	/**
	*	Retrieves the group and key from a string in the form of group.key.
	*
	*	Params:
	*		value = The string to process.
	*
	*	Returns:
	*		A tuple containing the group and key.
	*/
	auto getGroupAndKeyFromString(const string value) pure @safe
	{
		auto groupAndKey = value.findSplit(".");
		auto group = groupAndKey[0].strip();
		auto key = groupAndKey[2].strip();

		return tuple!("group", "key")(group, key);
	}

public:

	/**
	*	Saves config values to the config file.
	*
	*	Params:
	*		fileName = Name of the file which values will be stored. "app.config" by default.
	*/
	void save(string fileName = DEFAULT_CONFIG_FILE_NAME) @trusted
	{
		if(fileName != string.init && valuesModified_)
		{
			auto configfile = File(fileName, "w+");
			string curGroup;

			foreach(key, data; values_)
			{
				if(curGroup != data.group)
				{
					curGroup = data.group;
					if(curGroup != DEFAULT_GROUP_NAME)
					{
						configfile.writeln("[", curGroup, "]");
					}
				}

				if(data.comment.length)
				{
					configfile.writeln("#", data.comment);
				}

				configfile.writeln(data.key, " = ", data.value);
			}
		}
	}

	/**
	*	Loads a config fileName(app.config by default) to be processed.
	*
	*	Params:
	*		fileName = The name of the file to be processed/loaded.
	*	Returns:
	*		Returns true on a successful load false otherwise.
	*/
	bool loadFile(string fileName = DEFAULT_CONFIG_FILE_NAME) @safe
	{
		if(exists(fileName))
		{
			return processText(readText(fileName));
		}
		else
		{
			return false;
		}
	}

	/**
	*	Similar to loadFile but loads and processes the passed string instead.
	*
	*	Params:
	*		text = The string to process.
	*	Returns:
	*		Returns true on a successful load false otherwise.
	*/

	bool loadString(const string text) @safe
	{
		if(text.length)
		{
			return processText(text);
		}
		else
		{
			return false;
		}
	}

	/**
	*	Retrieves the value T associated with key where T is the designated type to be converted to.
	*
	*	Params:
	*		key = Name of the key to get.
	*
	*	Returns:
	*		The value associated with key.
	*
	*/
	Variant get(const string key) @safe
	{
		string defaultValue;

		if(isGroupString(key))
		{
			auto groupAndKey = getGroupAndKeyFromString(key);
			return get(groupAndKey.group, groupAndKey.key, defaultValue);
		}
		else
		{
			return get(DEFAULT_GROUP_NAME, key, defaultValue);
		}
	}

	/**
	*	Retrieves the value T associated with key where T is the designated type to be converted to.
	*
	*	Params:
	*		key = Name of the key to get.
	*		defaultValue = Allow the assignment of a default value if key does not exist.
	*
	*	Returns:
	*		The value associated with key.
	*
	*/
	Variant get(const string key, string defaultValue) @safe
	{
		if(isGroupString(key))
		{
			auto groupAndKey = getGroupAndKeyFromString(key);
			return get(groupAndKey.group, groupAndKey.key, defaultValue);
		}
		else
		{
			return get(DEFAULT_GROUP_NAME, key, defaultValue);
		}
	}

	/**
	*	Retrieves the value T associated with key where T is the designated type to be converted to.
	*
	*	Params:
	*		group = Name of the group to retrieve ie portion [groupName] of config file/string.
	*		key = Name of the key to get.
	*		defaultValue = Allow the assignment of a default value if key does not exist.
	*
	*	Returns:
	*		The value of value of the key/value pair.
	*
	*/
	Variant get(const string group, const string key, string defaultValue) @trusted
	{
		if(containsGroup(group))
		{
			return getGroupValue(group, key, defaultValue);
		}
		else
		{
			return Variant(defaultValue);
		}
	}

	/**
	*	Gets the value associated with the group and key.
	*
	*	Params:
	*		group = Name of the group the value is stored in.
	*		key = Name of the key the value is stored in.
	*
	*	Returns:
	*		The value associated with the group and key.
	*/
	Variant getGroupValue(T)(const string group, const string key, const T defaultValue = T.init) @trusted
	{
		Variant value = defaultValue;
		auto found = values_.filter!(a => (a.group == group) && (a.key == key));

		if(!found.empty)
		{
			value = found.front.value;
		}

		return value;
	}

	/**
	*	Retrieves key/values associated with the group portion of a config file/string.
	*
	*	Params:
	*		group = Name of the the group to retrieve.
	*
	*	Returns:
	*		Returns an array containing all the key/values associated with group.
	*
	*/
	auto getGroup(const string group) @trusted
	{
		return values_.filter!(a => a.group == group);
	}

	/**
	*	Retrieves an array containing key/values of all groups in the configfile omitting groupless key/values.
	*
	*	Returns:
	*		An array containing every group.
	*/
	auto getGroups()
	{
		return values_.filter!(a => a.group != "");
	}

	/**
	*	Sets a config value.
	*
	*	Params:
	*		key = Name of the key to set. Can be in the group.key form.
	*		value = The value to be set to.
	*/
	void set(T)(const string key, const T value) @trusted
	{
		if(isGroupString(key))
		{
			auto groupAndKey = getGroupAndKeyFromString(key);
			auto group = groupAndKey.group;

			set(group, key, value);
		}
		else
		{
			set(DEFAULT_GROUP_NAME, key, value);
		}
	}

	/**
	*	Sets a config value.
	*
	*	Params:
	*		group = Name of the group key belongs to.
	*		key = Name of the key to set.
	*		value = The value to be set to.
	*/
	void set(T = string)(const string group, const string key, const T value) @trusted
	{
		//auto foundValue = values_.filter!(a => (a.group == group) && (a.key == key));

		//foundValue.front.value = value.to!T;
		///valuesModified_ = true;

		auto foundValue = values_.filter!(a => (a.group == group) && (a.key == key));

		if(foundValue.empty)
		{
			KeyValueData data;

			data.key = key;
			data.group = group;
			data.value = value;

			values_ ~= data;
		}
		else
		{
			foundValue.front.value = value;
		}

		valuesModified_ = true;
	}

	/**
	*	Determines if the key is found in the config file.
	*	The key can be either its name of in the format of groupName.keyName or just the key name.
	*
	*	Params:
	*		key = Name of the key to get the value of
	*
	*	Returns:
	*		true if the config file contains the key false otherwise.
	*/
	bool contains(const string key) @trusted
	{
		if(isGroupString(key))
		{
			auto groupAndKey = getGroupAndKeyFromString(key);
			return contains(groupAndKey.group, groupAndKey.key);
		}
		else
		{
			return contains(DEFAULT_GROUP_NAME, key);
		}
	}

	/**
	*	Determines if the key is found in the config file.
	*
	*	Params:
	*		group = Name of the group to get entries from.
	*		key = Name of the key to get the value from.
	*
	*	Returns:
	*		true if the config file contains the key false otherwise.
	*/
	bool contains(const string group, const string key) @trusted
	{
		if(containsGroup(group))
		{
			auto groupValues = getGroup(group);
			return groupValues.canFind!(a => a.key == key);
		}
		else
		{
			return false; // The group wasn't found so no point in checking for a group and value.
		}
	}

	/**
	*	Determines if the given group exists.
	*
	*	Params:
	*		group = Name of the group to check for.
	*
	*	Returns:
	*		true if the group exists false otherwise.
	*/
	bool containsGroup(const string group) @trusted
	{
		return values_.canFind!(a => a.group == group);
	}

	/**
	*	Removes a key/value from config file.
	*	The key can be either its name of in the format of groupName.keyName or just the keyName.
	*
	*	Params:
	*		key = Name of the key to remove. Can be in the group.name format.
	*
	*	Returns:
	*		true if it was successfully removed false otherwise.
	*/
	bool remove(const string key) @trusted
	{
		if(isGroupString(key))
		{
			auto groupAndKey = getGroupAndKeyFromString(key);

			valuesModified_ = true;
			return remove(groupAndKey.group, groupAndKey.key);
		}
		else
		{
			valuesModified_ = true;
			return remove(DEFAULT_GROUP_NAME, key);
		}
	}

	/**
	*	Removes a key/value from config file.
	*	The key can be either its name of in the format of group.keyor just the key.
	*
	*	Params:
	*		group = Name of the group where key is found.
	*		key = Name of the key to remove.
	*
	*	Returns:
	*		true if it was successfully removed false otherwise.
	*/
	bool remove(const string group, const string key) @trusted
	{
		values_ = values_.remove!(a => (a.group == group) && (a.key == key));
		valuesModified_ = true;

		return contains(group, key);
	}

	/**
	*	Removes a group from the config file.
	*
	*	Params:
	*		group = Name of the group to remove.
	*
	*	Returns:
	*		true if group was successfully removed false otherwise.
	*/
	bool removeGroup(const string group) @trusted
	{
		values_ = values_.remove!(a => a.group == group);
		valuesModified_ = true;

		return containsGroup(group);
	}

	/**
	*	Allows config values to be accessed as you would with an associative array.
	*
	*	Params:
	*		key = Name of the value to retrieve
	*
	*	Returns:
	*		The string value associated with the key.
	*/
	Variant opIndex(const string key) @trusted
	{
		return get(key);
	}

	/**
	*	Allows config values to be assigned as you would with an associative array.
	*
	*	Params:
	*		key = Name of the key to assign the value to.
	*		value = The value in which key should be assigned to.
	*/
	void opIndexAssign(T)(T value, const string key) @trusted
	{
		set(key, value);
	}

	/**
	*	Converts the value of key to type of T. Works the same as std.variant's coerce.
	*
	*	Params:
	*		key = Name of the key to retrieve.
	*
	*	Returns:
	*		T = The converted value.
	*/
	T coerce(T)(const string key, const T defaultValue = T.init) @trusted
	{
		Variant value = defaultValue;
		if(contains(key))
		{
			value = get(key);
		}
		return value.coerce!T;
	}

	/// Gets the value and converts it to a bool.
	alias getBool = coerce!bool;

	/// Gets the value and converts it to a int.
	alias getInt = coerce!int;

	/// Gets the value and converts it to a float.
	alias getFloat = coerce!float;

	/// Gets the value and converts it to a real.
	alias getReal = coerce!real;

	/// Gets the value and converts it to a long.
	alias getLong = coerce!long;

	/// Gets the value and converts it to a byte.
	alias getByte = coerce!byte;

	/// Gets the value and converts it to a short.
	alias getShort = coerce!short;

	/// Gets the value and converts it to a double.
	alias getDouble = coerce!double;

	/// Gets the value and converts it to a string.
	alias getString = coerce!string;

private:
	KeyValueData[] values_;
	bool valuesModified_;
}

alias KeyValueConfig = VariantConfig; //NOTE: Temporary will remove once conversion is complete.

///
unittest
{
	string text = "
		aBool=true
		decimal = 3443.443
		number=12071
		#Here is a comment
		sentence=This is a really long sentence to test for a really long value string!
		time=12:04
		[section]
		groupSection=is really cool if this works!
		japan=true
		babymetal=the one
		[another]
		#And another comment!
		world=hello
		japan=false
	";

	VariantConfig config;

	immutable bool loaded = config.loadString(text);
	assert(loaded, "Failed to load string!");

	assert(config.containsGroup("section"));
	config.removeGroup("section");
	assert(config.containsGroup("section") == false);

	assert(config.get("aBool").coerce!bool == true);
	assert(config.getBool("aBool")); // Syntactic sugar
	assert(config["aBool"].coerce!bool == true); // Also works but rather awkward
	assert(config.coerce!bool("aBool") == true); // Also works and more natural

	assert(config.contains("time"));

	immutable auto number = config["number"];

	assert(number == 12_071);
	assert(config["decimal"] == 3443.443);

	assert(config.contains("another.world"));
	assert(config["another.world"] == "hello");
	config.remove("another.world");
	assert(config.contains("another.world") == false);
	assert(config.contains("anothers", "world") == false);

	assert(config.contains("number"));
	config.remove("number");
	assert(config.contains("number") == false);

	assert(config["another.japan"] == false);

	// Tests for nonexistent keys
	assert(config.getString("nonexistent", "Value doesn't exist!") == "Value doesn't exist!");
	config["nonexistent"] = "The value now exists!!!";
	assert(config.getString("nonexistent", "The value now exists!!!") == "The value now exists!!!");

	writeln("KeyValueConfig: Testing getGroup...");

	auto group = config.getGroup("another");

	foreach(value; group)
	{
		writeln(value);
	}

	writeln();

	config.set("aBool", false);
	assert(config["aBool"] == false);
	config["aBool"] = true;
	assert(config["aBool"] == true);
	assert(config["aBool"].toString == "true");

	debug config.save();
	debug config.save("custom-config-format.dat");

	string noEqualSign = "
		equal=sign
		time=12:04
		This is a really long sentence to test for a really long value string!
	";

	immutable bool equalSignValue = config.loadString(noEqualSign);
	assert(equalSignValue == false);

	string invalidGroup = "
		[first]
		equal=sign
		time=12:04
		[second
		another=key value is here
	";

	immutable bool invalidGroupValue = config.loadString(invalidGroup);
	assert(invalidGroupValue == false);
}
