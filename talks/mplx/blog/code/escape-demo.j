# escape-demo.j - tengine prints values as they are, unless you pipe them
use io;
use json;
import "tengine.j" as tengine;

def set as tengine.Set init tengine.newSet();
$set = tengine.add($set, "raw", '<h1>{{ .title }}</h1>');
$set = tengine.add($set, "safe", '<h1>{{ .title | html }}</h1>');
def data as json.Value init json.map({"title": "Tea & <i>cake</i>"});
io.printf("%s\n", tengine.render($set, "raw", $data));
io.printf("%s\n", tengine.render($set, "safe", $data));
