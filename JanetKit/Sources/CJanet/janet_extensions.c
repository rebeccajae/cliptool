#include "janet.h"

// `defrule` is implemented in C because it needs to root the matcher/transform
// values and call back into Swift's RuleStorage. The JSON/XML/base64 helpers
// are implemented in Swift (JanetExtensions.swift) and registered from Swift so
// the Swift compiler retains their `@_cdecl` symbols in Release builds.
extern void clipfmt_add_rule(int32_t mode, const char *name, Janet predicate, Janet transform);

static Janet defrule_cfun(int32_t argc, Janet *argv) {
    janet_fixarity(argc, 4);
    // Use the type-checking accessors so a malformed call (e.g. a non-string
    // name or a non-keyword trigger) raises a catchable Janet error via
    // janet_panic, instead of dereferencing a mistyped union and crashing the
    // host process. The error propagates through janet_dostring/janet_pcall
    // back to ConfigWatcher, which surfaces it in the menu.
    const char *name = (const char *)janet_getstring(argv, 0);
    JanetKeyword kw = janet_getkeyword(argv, 1);
    int32_t mode = janet_cstrcmp(kw, "always") ? 1 : 0;
    Janet matcher = argv[2];
    Janet transform = argv[3];
    janet_gcroot(matcher);
    janet_gcroot(transform);
    clipfmt_add_rule(mode, name, matcher, transform);
    return janet_wrap_nil();
}

void clipfmt_defrule_cfun(JanetTable *env) {
    JanetReg cfuns[] = {
        {"defrule", defrule_cfun,
         "(defrule name :always|:manual matcher transform)\n\n"
         "Register a clipboard formatting rule. matcher receives the clipboard string\n"
         "as its argument and returns truthy if the rule applies. transform receives\n"
         "the clipboard string and returns the transformed string."},
        {NULL, NULL, NULL}
    };
    janet_cfuns(env, NULL, cfuns);
}
