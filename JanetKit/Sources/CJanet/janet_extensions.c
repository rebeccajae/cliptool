#include "janet.h"

// Forward declarations of Swift functions
extern Janet swift_json_valid(int32_t argc, Janet *argv);
extern Janet swift_json_pretty(int32_t argc, Janet *argv);

static const JanetReg json_cfuns[] = {
    {"json/valid?", swift_json_valid, "(json/valid? str)\n\nReturns true if str is valid JSON."},
    {"json/pretty", swift_json_pretty, "(json/pretty str)\n\nReturns pretty-printed JSON string."},
    {NULL, NULL, NULL}
};

void janet_register_extensions(JanetTable *env) {
    janet_cfuns(env, NULL, json_cfuns);
}
