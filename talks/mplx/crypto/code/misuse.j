use io;
use crypto;
import "jwt.j" as jwt;
import "totp.j" as totp;
def k as bytes init crypto.randBytes(32);
try { jwt.verify("none", "a.b.", $k); } catch (e) { io.printf("%s | %s\n", $e.kind, $e.message); }
def short as bytes init crypto.randBytes(16);
try { jwt.sign("HS256", jwt.decode(jwt.sign("HS256", jwt.header(jwt.sign("HS256", jwt.decode("eyJhbGciOiJIUzI1NiJ9.eyJhIjoxfQ.x"), $k)), $k)), $short); } catch (e) { io.printf("%s | %s\n", $e.kind, $e.message); }
def o as totp.Options;
$o.digits = -4;
$o.period = -30;
io.printf("%s\n", totp.generateAt("JBSWY3DPEHPK3PXP", 59, $o));
try { totp.verifyWindow("JBSWY3DPEHPK3PXP", "123456", 50, $o); } catch (e) { io.printf("%s | %s\n", $e.kind, $e.message); }
