# 0.27.0: match destructures an indexed subject, no temporary variable.
use io;

def enum Tree {
    Leaf{value as int},
    Node{left as int, right as int}
};

# A tree as a list: a Node holds the indexes of its children.
def nodes as list of Tree init [
    Tree.Node{left: 1, right: 2},
    Tree.Leaf{value: 3},
    Tree.Node{left: 3, right: 4},
    Tree.Leaf{value: 4},
    Tree.Leaf{value: 5}
];

func total(nodes as list of Tree, i as int) {
    match ($nodes[$i]) {
        when Leaf(lf) { return $lf.value; }
        when Node(nd) { return total($nodes, $nd.left) + total($nodes, $nd.right); }
    }
    return 0;
}

io.printf("sum of the leaves: %d\n", total($nodes, 0));
