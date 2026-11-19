use testing;
import "./cart.j" as cart;

def struct Case { text as string, want as int };

func testParseQtyTable() {
    def cases as list of Case init [
        Case{text: "1", want: 1}, Case{text: "99", want: 99},
        Case{text: "007", want: 70}];
    for (def c in $cases) {
        def got as int init cart.parseQty($c.text);
        testing.assertEqual({$c.text: $got}, {$c.text: $c.want});
    }
}
