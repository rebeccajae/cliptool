#include "janet.h"

// Forward declarations of Swift functions
extern Janet swift_json_valid(int32_t argc, Janet *argv);
extern Janet swift_json_pretty(int32_t argc, Janet *argv);
extern Janet swift_xml_valid(int32_t argc, Janet *argv);
extern Janet swift_xml_pretty(int32_t argc, Janet *argv);
extern Janet swift_base64_decode(int32_t argc, Janet *argv);
extern void clipfmt_add_rule(int32_t mode, const char *name, Janet predicate, Janet transform);

static Janet defrule_cfun(int32_t argc, Janet *argv) {
    janet_fixarity(argc, 4);
    const char *name = (const char *)janet_unwrap_string(argv[0]);
    const uint8_t *kw = janet_unwrap_keyword(argv[1]);
    int32_t mode = janet_cstrcmp(kw, "always") ? 1 : 0;
    Janet matcher = argv[2];
    Janet transform = argv[3];
    janet_gcroot(matcher);
    janet_gcroot(transform);
    clipfmt_add_rule(mode, name, matcher, transform);
    return janet_wrap_nil();
}

static const JanetReg cfuns[] = {
    {"json/valid?", swift_json_valid, "(json/valid? str)\n\nReturns true if str is valid JSON."},
    {"json/pretty", swift_json_pretty, "(json/pretty str)\n\nReturns pretty-printed JSON string."},
    {"xml/valid?", swift_xml_valid, "(xml/valid? str)\n\nReturns true if str is valid XML."},
    {"xml/pretty", swift_xml_pretty, "(xml/pretty str)\n\nReturns pretty-printed XML string."},
    {"base64/decode", swift_base64_decode, "(base64/decode str)\n\nBase64-decodes str and returns the decoded UTF-8 string."},
    {"defrule", defrule_cfun,
     "(defrule name :always|:manual matcher transform)\n\n"
     "Register a clipboard formatting rule. matcher receives the clipboard string\n"
     "as its argument and returns truthy if the rule applies. transform receives\n"
     "the clipboard string and returns the transformed string."},
    {NULL, NULL, NULL}
};

void janet_register_extensions(JanetTable *env) {
    janet_cfuns(env, NULL, cfuns);
}
