use io;
use fs;
use regex;

def text as string init fs.readString("sample.txt");
def count as int init 0;
for (def word in regex.split('\s+', $text)) {
    if ($word != "") {
        $count = $count + 1;
    }
}
io.printf("{$count} words\n");
