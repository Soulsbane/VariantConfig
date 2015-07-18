#Description
VariantConfig is a key/value config file format that uses an associative array to store key/value pairs.

#Examples
```d
auto config = VariantConfig("app.config");
long number = config["number"].toLong;
bool aBool = config["aBool"].toBool;
string text = config["sentence"].toStr;

config["opTest"] = "Does it work";
config["opNum"] = 90210;
config["aBool"] = true;
```
#File Contents
```
TodoTaskPattern=([A-Z]+):(.*)
aBool=true
equalsText=([A-Z]+):(.*)
float=3443.443
foo=bar
number=12071
opNum=90210
opTest=Does it work
sentence=This is a really long sentence to test for a really long value string!
spacetest=this is testing starting and trailing spaces
testfield=123466
time=12:04
```

