# A loopback stand-in for an eSCL scanner, after the deck's own test fake:
# it answers one platen job with page.jpg, then stops.
use httpd;
use fs;
use io;
use encoding;

def const CAPS as string init '<?xml version="1.0" encoding="UTF-8"?>
<scan:ScannerCapabilities xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm"
    xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03">
  <pwg:Version>2.63</pwg:Version>
  <pwg:MakeAndModel>Loopback test scanner</pwg:MakeAndModel>
  <scan:Platen><scan:PlatenInputCaps>
    <scan:MinWidth>8</scan:MinWidth><scan:MaxWidth>2480</scan:MaxWidth>
    <scan:MinHeight>8</scan:MinHeight><scan:MaxHeight>3508</scan:MaxHeight>
    <scan:SettingProfiles><scan:SettingProfile>
      <scan:ColorModes><scan:ColorMode>Grayscale8</scan:ColorMode>
        <scan:ColorMode>RGB24</scan:ColorMode></scan:ColorModes>
      <scan:DocumentFormats><pwg:DocumentFormat>image/jpeg</pwg:DocumentFormat></scan:DocumentFormats>
      <scan:SupportedResolutions><scan:DiscreteResolutions>
        <scan:DiscreteResolution><scan:XResolution>150</scan:XResolution><scan:YResolution>150</scan:YResolution></scan:DiscreteResolution>
        <scan:DiscreteResolution><scan:XResolution>300</scan:XResolution><scan:YResolution>300</scan:YResolution></scan:DiscreteResolution>
      </scan:DiscreteResolutions></scan:SupportedResolutions>
    </scan:SettingProfile></scan:SettingProfiles>
  </scan:PlatenInputCaps></scan:Platen>
</scan:ScannerCapabilities>
';

def const STATUS as string init '<?xml version="1.0" encoding="UTF-8"?>
<scan:ScannerStatus xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03"
    xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
<pwg:Version>2.63</pwg:Version><pwg:State>Idle</pwg:State>
<scan:Jobs><scan:JobInfo><pwg:JobUri>/eSCL/ScanJobs/7</pwg:JobUri>
<pwg:JobUuid>7</pwg:JobUuid><pwg:JobState>Completed</pwg:JobState>
<pwg:JobStateReasons><pwg:JobStateReason>JobCompletedSuccessfully</pwg:JobStateReason></pwg:JobStateReasons>
</scan:JobInfo></scan:Jobs></scan:ScannerStatus>';

def srv as httpd.Server init httpd.listen("127.0.0.1:8080");
def done as bool init false;
while (not $done) {
    def req as httpd.Request init httpd.accept($srv);
    def what as string init httpd.method($req) + " " + httpd.path($req);
    io.printf("fake scanner: %s\n", $what);
    def body as bytes init encoding.encode("utf-8", "");
    def code as int init 200;
    if ($what == "GET /eSCL/ScannerCapabilities") {
        httpd.setHeader($req, "Content-Type", "text/xml");
        $body = encoding.encode("utf-8", CAPS);
    } elseif ($what == "POST /eSCL/ScanJobs") {
        httpd.setHeader($req, "Location", "/eSCL/ScanJobs/7");
        $code = 201;
    } elseif ($what == "GET /eSCL/ScanJobs/7/NextDocument") {
        httpd.setHeader($req, "Content-Type", "image/jpeg");
        $body = fs.readBytes("page.jpg");
    } elseif ($what == "GET /eSCL/ScannerStatus") {
        httpd.setHeader($req, "Content-Type", "text/xml");
        $body = encoding.encode("utf-8", STATUS);
    } elseif ($what == "DELETE /eSCL/ScanJobs/7") {
        $code = 204;
        $done = true;
    } else {
        $code = 404;
    }
    httpd.respond($req, $code, $body);
}
httpd.shutdown($srv);
