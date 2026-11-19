# Invoices for the open orders of a (stand-in) shop: GraphQL in,
# VIES checks with a cache and an audit trail, @deckyard/money for the
# amounts, one PDF per invoice. Talks to the VIES *test* service.
use fs;
use io;
use json;
use math;
use os;
use strings;
use time;
import "@deckyard/money/" as money;
import "@deckyard/vies/" as vies;
import "flatdb.j" as flatdb;
import "graphql.j" as graphql;
import "jsonl.j" as jsonl;
import "pdf.j" as pdf;

def const SELLER as string init "Example Consulting GmbH";
def const SELLER_ADDR as string init "Beispielgasse 7, 4020 Linz, Austria";
def const SELLER_CC as string init "AT";
def const SELLER_VAT as string init "U12345678";
def const VAT_RATE as string init "0.20"; # Austrian standard rate
def const CACHE as string init "vat-cache.json";
def const AUDIT as string init "vat-audit.jsonl";
def const ORDERS as string init 'query Orders($first: Int!, $after: String) {
  orders(status: OPEN, first: $first, after: $after) {
    nodes { number date customer { name country vatId }
            lines { description qty unitPrice currency } }
    pageInfo { hasNextPage endCursor }
  }
}';

# ---- orders from GraphQL ------------------------------------------
func fetchOrders(gql as graphql.Client) {
    def nodes as list of json.Value init [];
    def vars as json.Value init json.map({"first": 3});
    while (true) {
        def conn as json.Value init json.get(
            graphql.query($gql, ORDERS, $vars), "/data/orders");
        for (def i in 0..json.length($conn, "/nodes")) {
            $nodes[] = json.get($conn, "/nodes/" + io.sprintf("%d", $i));
        }
        if (not json.asBool($conn, "/pageInfo/hasNextPage")) {
            return $nodes;
        }
        $vars = json.set($vars, "/after",
            json.asString($conn, "/pageInfo/endCursor"));
    }
    return $nodes;
}

# ---- VAT ID checks: cache, VIES, audit trail ----------------------
def struct Check {
    vatId as string,
    status as string, # "valid", "invalid" or "unverified"
    source as string, # "vies" or "cache"
    date as string,
    proof as string,
    detail as string
};

func today() {
    return time.format(time.now(), "%Y-%m-%d");
}

func audit(order as string, c as Check) {
    def rec as json.Value init json.map({"at": time.iso(time.now()),
        "order": $order, "vatId": $c.vatId, "status": $c.status,
        "source": $c.source, "proof": $c.proof, "detail": $c.detail});
    jsonl.appendFile(AUDIT, [$rec]);
}

func askVies(vc as vies.Client, id as vies.VatId) {
    def c as Check init Check{vatId: $id.country + $id.number,
        status: "unverified", source: "vies", date: today(), proof: "",
        detail: ""};
    try {
        def r as vies.ApproxResult init vies.checkApprox($vc, $id.country,
            $id.number, SELLER_CC, SELLER_VAT);
        $c.proof = $r.requestIdentifier;
        $c.status = "invalid";
        if ($r.valid) {
            $c.status = "valid";
        }
    } catch (e) {
        if ($e.kind == vies.ERROR_KIND) {
            def ve as vies.ViesError init $e;
            if (not $ve.transient) {
                throw $e;      # INVALID_INPUT, blocked, a bad reply
            }
            $c.detail = $ve.code;
        } elseif ($e.kind == "timeout" or $e.kind == "net"
                or $e.kind == "closed") {
            $c.detail = $e.kind;
        } else {
            throw $e;
        }
    }
    return $c;
}

func verify(vc as vies.Client, vatId as string, order as string) {
    def id as vies.VatId init vies.parse($vatId);
    def key as string init "/" + $id.country + $id.number;
    def db as flatdb.DB init flatdb.open(CACHE);
    if (flatdb.has($db, $key)) {
        def hit as json.Value init flatdb.get($db, $key);
        if (json.asString($hit, "/date") == today()) {
            def c as Check init Check{vatId: $id.country + $id.number,
                status: "valid", source: "cache", date: today(),
                proof: json.asString($hit, "/proof"), detail: ""};
            audit($order, $c);
            return $c;
        }
    }
    def c as Check init askVies($vc, $id);
    audit($order, $c);
    if ($c.status == "valid") {     # only a positive answer is cached
        $db = flatdb.set($db, $key, json.map({"date": $c.date,
            "proof": $c.proof}));
        $db = flatdb.save($db);
    }
    return $c;
}

# ---- the tax decision ---------------------------------------------
def struct Treatment {
    kind as string,
    rate as string,
    percent as string,
    note as string
};

func treatment(country as string, c as Check) {
    if ($country == SELLER_CC) {
        return Treatment{kind: "domestic", rate: VAT_RATE, percent: "20",
            note: ""};
    }
    if ($c.status == "valid") {
        return Treatment{kind: "reverse-charge", rate: "0", percent: "0",
            note: "Reverse charge: VAT is due from the recipient."};
    }
    if ($c.status == "invalid") {
        return Treatment{kind: "no-valid-id", rate: VAT_RATE, percent: "20",
            note: ""};
    }
    return Treatment{kind: "held", rate: "", percent: "", note: ""};
}

# ---- amounts ------------------------------------------------------
def struct Totals {
    lines as list of money.Money,
    net as money.Money,
    vat as money.Money,
    gross as money.Money
};

func totals(order as json.Value, t as Treatment) {
    def lines as list of money.Money init [];
    for (def i in 0..json.length($order, "/lines")) {
        def l as json.Value init
            json.get($order, "/lines/" + io.sprintf("%d", $i));
        def unit as money.Money init money.parse(
            json.asString($l, "/unitPrice"), json.asString($l, "/currency"));
        $lines[] = money.multiply($unit,
            io.sprintf("%d", json.asInt($l, "/qty")), "half-even");
    }
    def net as money.Money init money.sum($lines, "EUR");
    def vat as money.Money init money.multiply($net, $t.rate, "half-up");
    return Totals{lines: $lines, net: $net, vat: $vat,
        gross: money.add($net, $vat)};
}

# ---- the PDF ------------------------------------------------------
def const FONT as string init "Helvetica";
def const BOLD as string init "Helvetica-Bold";

func right(pg as pdf.Page, x as int, y as int, font as string,
        s as string) {
    def w as int init math.ceil(pdf.measureText($font, 10, $s));
    return pdf.text($pg, $x - $w, $y, $font, 10, $s);
}

func eur(m as money.Money) {
    return money.format($m) + " EUR";
}

func render(order as json.Value, c as Check, t as Treatment,
        tot as Totals) {
    def number as string init json.asString($order, "/number");
    def pg as pdf.Page init pdf.page(595, 842); # A4 portrait
    $pg = pdf.text($pg, 50, 780, BOLD, 16, SELLER);
    $pg = pdf.text($pg, 50, 764, FONT, 9,
        SELLER_ADDR + ", VAT ID " + SELLER_CC + SELLER_VAT);
    $pg = pdf.text($pg, 50, 700, FONT, 10, pdf.toWinAnsi(
        json.asString($order, "/customer/name"), "?"));
    if ($c.vatId != "") {
        $pg = pdf.text($pg, 50, 686, FONT, 10, "VAT ID " + $c.vatId);
    }
    $pg = pdf.text($pg, 50, 640, BOLD, 14, "Invoice " + $number);
    $pg = pdf.text($pg, 50, 624, FONT, 10, "Date " + today()
        + ", delivery " + json.asString($order, "/date"));
    $pg = pdf.color($pg, 230, 230, 230);
    $pg = pdf.rect($pg, 50, 586, 495, 18, true);
    $pg = pdf.color($pg, 0, 0, 0);
    $pg = pdf.text($pg, 55, 591, BOLD, 10, "Description");
    $pg = right($pg, 400, 591, BOLD, "Qty");
    $pg = right($pg, 470, 591, BOLD, "Unit");
    $pg = right($pg, 540, 591, BOLD, "Amount");
    def y as int init 570;
    for (def i in 0..len($tot.lines)) {
        def l as json.Value init
            json.get($order, "/lines/" + io.sprintf("%d", $i));
        $pg = pdf.text($pg, 55, $y, FONT, 10, pdf.toWinAnsi(
            json.asString($l, "/description"), "?"));
        $pg = right($pg, 400, $y, FONT,
            io.sprintf("%d", json.asInt($l, "/qty")));
        $pg = right($pg, 470, $y, FONT, json.asString($l, "/unitPrice"));
        $pg = right($pg, 540, $y, FONT, money.format($tot.lines[$i]));
        $y = $y - 16;
    }
    $pg = pdf.line($pg, 330, $y + 6, 545, $y + 6);
    $y = $y - 12;
    $pg = pdf.text($pg, 330, $y, FONT, 10, "Net");
    $pg = right($pg, 540, $y, FONT, eur($tot.net));
    $pg = pdf.text($pg, 330, $y - 16, FONT, 10, "VAT " + $t.percent + " %");
    $pg = right($pg, 540, $y - 16, FONT, eur($tot.vat));
    $pg = pdf.text($pg, 330, $y - 34, BOLD, 10, "Total");
    $pg = right($pg, 540, $y - 34, BOLD, eur($tot.gross));
    if ($t.note != "") {
        $pg = pdf.text($pg, 50, $y - 70, BOLD, 10, $t.note);
        $pg = pdf.text($pg, 50, $y - 84, FONT, 9, "VAT ID checked on "
            + $c.date + ", VIES consultation number " + $c.proof + ".");
    }
    def doc as pdf.Document init pdf.addPage(pdf.document(), $pg);
    $doc = pdf.info($doc, "Title", "Invoice " + $number);
    fs.writeBytes("invoice-" + $number + ".pdf", pdf.render($doc));
}

# ---- main ---------------------------------------------------------
def gql as graphql.Client init graphql.withTimeout(graphql.bearer(
    graphql.client("http://127.0.0.1:8099/graphql"),
    os.getEnv("SHOP_TOKEN")), 10000);
def vc as vies.Client init vies.withTimeout(
    vies.withRetries(vies.sandboxClient(), 2, 1000), 10000);

for (def o in fetchOrders($gql)) {
    def number as string init json.asString($o, "/number");
    def country as string init json.asString($o, "/customer/country");
    def c as Check init Check{vatId: "", status: "", source: "",
        date: today(), proof: "", detail: ""};
    if ($country != SELLER_CC) {
        $c = verify($vc, json.asString($o, "/customer/vatId"), $number);
    }
    def t as Treatment init treatment($country, $c);
    if ($t.kind == "held") {
        io.printf("%s %s held: VAT ID %s unverified (%s)\n", $number,
            $country, $c.vatId, $c.detail);
        continue;
    }
    def tot as Totals init totals($o, $t);
    render($o, $c, $t, $tot);
    io.printf("%s %s %s|pad=14 net %s|pad=8|align=right VAT %s|pad=7|align=right %s\n",
        $number, $country, $t.kind, money.format($tot.net),
        money.format($tot.vat), strings.trim($c.source));
}
