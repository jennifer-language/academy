# "Libraries, modules and decks": a built-in library, a module of your own
# and a deck. Needs the deck in vendor/: run `jvc install` first.
use io;                            # a built-in library
import "./geo.j" as geo;           # a module of your own
import "@jennifer/telegram/";      # a deck, vendored by jvc

io.printf("Earth: %f|prec=0 km around\n", geo.circumference(geo.EARTH_KM));
