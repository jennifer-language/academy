# "include, Composer and Packagist": import loads a file as a module under
# its own name; use switches on a built-in library.
import "./util.j" as util;
use io;
use json;

io.printf("%s\n", util.shout("hello"));
io.printf("%s\n", util.reveal());
io.printf("%s\n", json.encode({"lang": "Jennifer"}));
