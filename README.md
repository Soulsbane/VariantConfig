# DEPRECATED
I don't use D much nowadays and as such making this project deprecated.

# Description
VariantConfig is a key/value config file format that uses an associative array to store key/value pairs.

# Examples
```d
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

	assert(config.get("aBool", true).coerce!bool == true);
	assert(config.asBool("aBool")); // Syntactic sugar
	assert(config["aBool"].coerce!bool == true); // Also works but rather awkward
	assert(config.coerce!bool("aBool") == true); // Also works and more natural

	assert(config.contains("time"));

	immutable auto number = config["number"];

	assert(number == 12_071);
	assert(config["decimal"] == 3443.443);

	assert(config.contains("another.world"));
	assert(config["another.world"] == "hello");

	config["another.japan"] = true;
	assert(config["another.japan"] == true);

	config.remove("another.world");

	assert(config.contains("another.world") == false);
	assert(config.contains("anothers", "world") == false);

	assert(config.contains("number"));
	config.remove("number");
	assert(config.contains("number") == false);

	// Tests for nonexistent keys
	assert(config.asString("nonexistent", "Value doesn't exist!") == "Value doesn't exist!");
	config["nonexistent"] = "The value now exists!!!";
	assert(config.asString("nonexistent", "The value now exists!!!") == "The value now exists!!!");

	auto group = config.getGroup("another");

	foreach(value; group)
	{
		assert(value.key == "japan");
		assert(value.value == true);
	}

	config.set("aBool", false);
	assert(config["aBool"] == false);
	debug config.save();

	config["aBool"] = true;
	assert(config["aBool"] == true);
	assert(config["aBool"].toString == "true");

	assert(config.get!int("numberGroup", "numberValue", 1234) == 1234);

	immutable string customFileName = "custom-config-format.dat";
	debug config.save(customFileName);

	VariantConfig configLoadTest;

	bool isLoadedTest = configLoadTest.loadFile("doesnt-exist.dat");
	assert(isLoadedTest == false);

	isLoadedTest = configLoadTest.loadFile(customFileName);
	assert(isLoadedTest == true);

	string noEqualSign = "
		equal=sign
		time=12:04
		This is a really long sentence to test for a really long value string!
	";

	immutable bool equalSignValue = config.loadString(noEqualSign);
	assert(equalSignValue == false);

	auto groups = config.getGroups();

	writeln("Listing groups: ");
	writeln;

	foreach(currGroup; groups)
	{
		writeln(currGroup);
	}

	string invalidGroup = "
		[first]
		equal=sign
		time=12:04
		[second
		another=key value is here
	";

	immutable bool invalidGroupValue = config.loadString(invalidGroup);
	assert(invalidGroupValue == false);

	string emptyString;

	immutable bool emptyLoad = config.loadString(emptyString);
	assert(emptyLoad == false);
```

