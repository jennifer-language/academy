# Images, barcodes and labels with Jennifer: the code

The programs behind the slides, for Jennifer 0.27.0. Run them from this
folder; they read and write their files by relative path.

Setup:

- `sh make-samples.sh` creates the sample pictures (`holiday.jpg`,
  `phone.jpg`, `page.jpg`, `logo.svg`) with ImageMagick 7. They stand in for
  the photos used in the talk, so sizes in the output match the slides but
  the pictures do not.
- `jvc install` fetches the two decks in `deck.toml` (`@deckyard/magick`,
  `@deckyard/escl`) into `vendor/`. Only `magick.j`, `magickerr.j`, `scan.j`
  and `esclerr.j` need them; `@deckyard/magick` also needs the `magick`
  command (ImageMagick 7) on the PATH.
- `bomb.png` is a 75-byte PNG header that claims 100000 x 100000 pixels.
- Optional, to read the codes back as on the slides: `zbarimg` (zbar) and
  `pdftoppm` (poppler).

Images (`use images;`):

- `info.j`: `images.info` from the header, decode, `fit` into 320 x 320,
  write JPEG and PNG thumbnails ("Load, look, shrink").
  Run: `jennifer run info.j`
- `edit.j`: crop, resize, grayscale, dither, rotate, drawn side by side into
  `strip.png` ("Crop, resize, turn, dither"). Run: `jennifer run edit.j`
- `hostile.j`: a decompression bomb refused with kind `"limit"` ("Hostile
  pictures"). Run: `jennifer run hostile.j`
- `imgerr.j`: a non-image, a crop outside the image, a 45 degree turn
  ("Errors and limits"). Run: `jennifer run imgerr.j`
- `magick.j`: identify, auto-orient, thumbnail, annotate and write WebP
  through `@deckyard/magick` ("What images does not do: @deckyard/magick").
  Run: `jennifer run magick.j`
- `magickerr.j`: what the built-in library reports for the sideways photo,
  SVG refused unless allowed, the bomb through ImageMagick ("Errors and
  limits"). Run: `jennifer run magickerr.j`

Barcodes (`import "barcode.j"`):

- `qr.j`: one URL as a QR code at the four error correction levels, written
  to `qr-L.png` ... `qr-H.png` ("Barcodes: one Symbol, several renderers").
  Run: `jennifer run qr.j`
- `damage.j`: puts a red sticker on each QR code, `hit-L.png` ... `hit-H.png`
  ("Error correction, tested with a sticker"). Run after `qr.j`:
  `jennifer run damage.j`, then
  `for l in L M Q H; do echo $l: $(zbarimg -q hit-$l.png || echo none); done`
- `codes.j`: Code 128, EAN-13, GS1-128 and Data Matrix as PNG and SVG ("Four
  more symbologies", "Scan them back", "SVG or PNG").
  Run: `jennifer run codes.j`, then `zbarimg -q code128.png ean13.png gs1-128.png`
- `bcerr.j`: a wrong check digit, a character Code 128 cannot hold, too much
  data, an unknown symbology ("Errors and limits").
  Run: `jennifer run bcerr.j`

Labels (`import "label.j"`):

- `shelf.j`: a shelf label rendered as ZPL and as cab JScript ("Labels:
  build, render, emit", "The same label, twice"). Run: `jennifer run shelf.j`
- `labelimg.j`: a picture stored on the printer, referenced from ZPL and cab
  ("Pictures on labels, and sending"). Run: `jennifer run labelimg.j`
- `send.j` and `printer.j`: send a label to a printer's raw port; `printer.j`
  is a stand-in that listens on 127.0.0.1:9100, prints one job and stops
  ("Pictures on labels, and sending"). Talks to the stand-in, not a printer.
  Run: `jennifer run printer.j &` then `jennifer run send.j`
- `lerr.j`: data that would inject ZPL, a zero dpi, a negative quantity
  ("Errors and limits"). Run: `jennifer run lerr.j`
- `ship.j`: the worked example, one shipment as a 100 x 150 mm ZPL label
  (`ship.zpl`) and as a PDF (`ship.pdf`) with embedded barcodes ("Worked
  example: the shipping label in ZPL", "The same shipment as a PDF", "The
  result"). Run: `jennifer run ship.j`, then
  `pdftoppm -r 150 -png ship.pdf ship && zbarimg -q ship-1.png`

Scanning (`@deckyard/escl`):

- `scan.j` and `fakescanner.j`: scan a page over eSCL, threshold it to black
  and white, and save it as `letter.pdf` ("A scanned page as a PDF:
  @deckyard/escl", "What came back"). `fakescanner.j` is a stand-in eSCL
  scanner on 127.0.0.1:8080 that answers one job with `page.jpg` and stops;
  it is not a real scanner.
  Run: `jennifer run fakescanner.j &` then `jennifer run scan.j 127.0.0.1:8080`.
  With a real scanner, pass its `host:port` instead.
- `esclerr.j`: the error when nothing answers on 127.0.0.1:8080 ("Errors
  and limits"). Run it with the fake scanner stopped:
  `jennifer run esclerr.j`
