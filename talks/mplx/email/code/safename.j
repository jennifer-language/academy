use io;
use regex;

func safeName(raw as string) {
    def n as string init regex.replace('[^A-Za-z0-9._-]', $raw, "_");
    $n = regex.replace('^[._]+', $n, "");
    if (len($n) > 80) { $n = $n[len($n) - 80..]; }
    if ($n == "") { $n = "attachment"; }
    return $n;
}

for (def raw in ["invoice-2026-11.pdf", "../../.config/autostart/run.pdf",
    'C:\Windows\evil.pdf', ".bashrc", "Rechnung März.pdf", ""]) {
    io.printf("%s|pad=34 -> %s\n", "\"{$raw}\"", safeName($raw));
}
