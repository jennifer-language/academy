# "Deck capabilities: a label, not a fence". The deck is imported from its
# source folder here; installed with jvc it would be "@demo/colors/".
import "./deck-colors/src/colors.j" as colors;
use io;
use meta;
use strings;

io.printf("build: %s\n", strings.join(meta.CAPABILITIES, ","));
io.printf("%s", colors.shade("teal"));
