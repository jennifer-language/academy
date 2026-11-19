# The module imported by imports.j ("include, Composer and Packagist").
export func shout(s as string) {
    return $s + "!";
}

# Not exported, so it stays private to this module.
func helper() {
    return "hidden";
}

export func reveal() {
    return helper();
}
