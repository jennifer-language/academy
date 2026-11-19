use io;
import "dot.j" as dot;

# from, event, to: the life of an invoice
def steps as list of list of string init [
    ["draft", "send", "sent"], ["sent", "pay", "paid"],
    ["sent", "due date", "overdue"], ["overdue", "remind", "reminded"],
    ["reminded", "pay", "paid"], ["reminded", "90 days", "written off"]];
def g as dot.Graph init dot.digraph("invoice");
$g = dot.graphAttr($g, "rankdir", "LR");
$g = dot.nodeAttr($g, "shape", "box");
$g = dot.nodeAttr($g, "style", "rounded");
for (def s in ["paid", "written off"]) {
    $g = dot.nodeWith($g, $s, {"peripheries": "2"});
}
for (def t in $steps) {
    $g = dot.edgeWith($g, $t[0], $t[2], {"label": $t[1]});
}
io.printf("%s", dot.render($g));
