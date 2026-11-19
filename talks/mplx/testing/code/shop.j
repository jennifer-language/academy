# shop.j: asks a REST price service for the price of a sku, in cents.
# Tested by shop_test.j against a fake server.
use json;
import "rest.j" as rest;

export func price(api as rest.Client, sku as string) {
    def v as json.Value init rest.getJson($api, "/prices/" + $sku, {});
    return json.asInt($v, "/cents");
}
