# build.j - turn posts/*.md into a small static site in public/
use fs;
use io;
use json;
use lists;
use path;
use strings;
use time;
use toml;
import "markdown.j" as markdown;
import "tengine.j" as tengine;
import "html.j" as html;
import "feed.j" as feed;
import "ical.j" as ical;
import "vcard.j" as vcard;

def struct Post {
    slug as string, title as string, date as time.Time,
    summary as string, body as string
};

func readSite(file as string) {
    def conf as toml.Value init toml.decode(fs.readString($file));
    def site as map of string to string init {};
    for (def key in toml.keys($conf)) {
        $site[$key] = toml.asString($conf, "/" + $key);
    }
    return $site;
}

func readPost(file as string) {
    def text as string init fs.readString($file);
    if (not strings.startsWith($text, "+++\n")) {
        throw Error{kind: "blog", message: "{$file}: no +++ at the top"};
    }
    def stop as int init strings.indexOf($text, "\n+++\n", 4);
    if ($stop < 0) {
        throw Error{kind: "blog", message: "{$file}: no closing +++"};
    }
    def meta as toml.Value init toml.decode($text[4..$stop]);
    return Post{
        slug: path.stem($file)[11..],
        title: toml.asString($meta, "/title"),
        date: toml.asDatetime($meta, "/date"),
        summary: toml.asString($meta, "/summary"),
        body: markdown.toHtml($text[$stop + 5..])
    };
}

func loadPosts(dir as string) {
    def posts as list of Post init [];
    for (def name in fs.list($dir)) {
        if (path.ext($name) == ".md") {
            $posts[] = readPost(path.join($dir, $name));
        }
    }
    return lists.reverse($posts);
}

func loadEvents(file as string) {
    def doc as toml.Value init toml.decode(fs.readString($file));
    def events as list of ical.Event init [];
    for (def i in 0..toml.length($doc, "/event")) {
        def e as toml.Value init toml.get($doc, "/event/{$i}");
        def ev as ical.Event init ical.event(
            toml.asString($e, "/id"),
            toml.asDatetime($e, "/start"),
            toml.asDatetime($e, "/end"),
            toml.asString($e, "/title"));
        $ev = ical.locate($ev, toml.asString($e, "/place"));
        if (time.after($ev.start, time.now())) {
            $events[] = $ev;
        }
    }
    return $events;
}

func showDate(t as time.Time) {
    return time.format($t, "%d %B %Y");
}

func postData(p as Post) {
    return json.map({
        "slug": $p.slug,
        "title": $p.title,
        "date": showDate($p.date),
        "summary": $p.summary,
        "body": $p.body
    });
}

func eventList(events as list of ical.Event) {
    def items as list of html.Node init [];
    for (def ev in $events) {
        def day as html.Node init html.text(showDate($ev.start));
        def kids as list of html.Node init [];
        $kids[] = html.element("strong", [], [$day]);
        $kids[] = html.text(" " + $ev.summary + ", " + $ev.location);
        $items[] = html.element("li", [], $kids);
    }
    return html.render(html.element("ul", [], $items));
}

func renderPage(page as string, data as json.Value) {
    def set as tengine.Set init tengine.newSet();
    def layout as string init fs.readString("templates/layout.tmpl");
    $set = tengine.add($set, "layout", $layout);
    def body as string init fs.readString("templates/" + $page);
    $set = tengine.add($set, "page", $body);
    return tengine.render($set, "layout", $data);
}

func writeFile(file as string, content as string) {
    fs.mkdirAll(path.dir($file));
    fs.writeString($file, $content);
    io.printf("wrote %s\n", $file);
}

func buildFeed(posts as list of Post, title as string, url as string) {
    def entries as list of feed.Entry init [];
    for (def p in $posts) {
        def link as string init "{$url}/posts/{$p.slug}/";
        def e as feed.Entry init feed.entry($p.title, $link);
        $e = feed.entryId($e, $link);
        $e = feed.entryPublished($e, $p.date);
        $e = feed.entrySummary($e, $p.summary);
        $entries[] = $e;
    }
    def f as feed.Feed init feed.feed($title, $url);
    $f = feed.feedUpdated($f, $posts[0].date);
    return feed.addAll($f, $entries);
}

func buildCard(site as map of string to string) {
    def c as vcard.Card init vcard.card($site["author"]);
    $c = vcard.withName($c, $site["family"], $site["given"]);
    $c = vcard.addEmail($c, $site["email"]);
    $c = vcard.withUrl($c, $site["url"]);
    $c = vcard.withNote($c, "Writes about Jennifer.");
    return vcard.encode($c);
}

func main() {
    def site as map of string to string init readSite("site.toml");
    def posts as list of Post init loadPosts("posts");
    def events as list of ical.Event init loadEvents("events.toml");
    def cards as list of json.Value init [];
    for (def p in $posts) {
        $cards[] = postData($p);
        def data as json.Value init json.map();
        $data = json.set($data, "/site", json.map($site));
        $data = json.set($data, "/title", $p.title);
        $data = json.set($data, "/post", postData($p));
        def page as string init renderPage("post.tmpl", $data);
        writeFile("public/posts/{$p.slug}/index.html", $page);
    }
    def home as json.Value init json.map();
    $home = json.set($home, "/site", json.map($site));
    $home = json.set($home, "/title", "Home");
    $home = json.set($home, "/posts", json.list($cards));
    $home = json.set($home, "/events", eventList($events));
    writeFile("public/index.html", renderPage("index.tmpl", $home));
    def f as feed.Feed init buildFeed(
        $posts, $site["title"], $site["url"]);
    writeFile("public/feed.xml", feed.build("rss", $f));
    writeFile("public/atom.xml", feed.build("atom", $f));
    def cal as ical.Calendar init ical.calendar();
    for (def ev in $events) {
        $cal = ical.add($cal, $ev);
    }
    writeFile("public/events.ics", ical.encode($cal));
    writeFile("public/author.vcf", buildCard($site));
}

main();
