#include "cyber_world_generator.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <initializer_list>
#include <limits>
#include <stdexcept>
#include <string>

namespace godot {
namespace {
namespace gen = cybersand::generation;

[[noreturn]] void invalid(const std::string& context, const char* message) {
    throw std::invalid_argument(context + ": " + message);
}

std::string string_value(const Variant& value, const std::string& context) {
    if (value.get_type() != Variant::STRING && value.get_type() != Variant::STRING_NAME)
        invalid(context, "expected a string");
    const String text = value;
    if (text.length() > 256) invalid(context, "string exceeds 256 characters");
    for (std::int64_t index = 0; index < text.length(); ++index)
        if (text[index] == U'\0') invalid(context, "embedded NUL in string");
    const auto encoded = text.utf8();
    return std::string(encoded.get_data(), static_cast<std::size_t>(encoded.length()));
}

Dictionary dictionary_value(const Variant& value, const std::string& context) {
    if (value.get_type() != Variant::DICTIONARY) invalid(context, "expected a dictionary");
    return value;
}

Array array_value(const Variant& value, std::size_t capacity, const std::string& context) {
    if (value.get_type() != Variant::ARRAY) invalid(context, "expected an array");
    const Array array = value;
    if (static_cast<std::uint64_t>(array.size()) > capacity)
        invalid(context, "array exceeds its declared capacity");
    return array;
}

double number_value(const Variant& value, const std::string& context) {
    if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT)
        invalid(context, "expected a finite number");
    const double number = value;
    if (!std::isfinite(number)) invalid(context, "expected a finite number");
    return number;
}

std::int64_t integer_value(const Variant& value, const std::string& context) {
    if (value.get_type() == Variant::INT) return static_cast<std::int64_t>(value);
    const double number = number_value(value, context);
    // JSON imports may represent integers as doubles. Accept exact integral
    // values only within the interoperable 53-bit domain, never a rounded seed.
    if (std::trunc(number) != number || number < -9007199254740991.0 ||
        number > 9007199254740991.0)
        invalid(context, "expected an exact integer (JSON numbers are limited to 53 bits)");
    return static_cast<std::int64_t>(number);
}

std::int64_t bounded_integer(const Variant& value, std::int64_t minimum,
                             std::int64_t maximum, const std::string& context) {
    const auto number = integer_value(value, context);
    if (number < minimum || number > maximum) invalid(context, "integer is outside its domain");
    return number;
}

void fields(const Dictionary& dictionary, std::initializer_list<const char*> allowed,
            const std::string& context) {
    if (static_cast<std::uint64_t>(dictionary.size()) > allowed.size())
        invalid(context, "too many fields or an unknown field");
    const Array keys = dictionary.keys();
    for (std::int64_t index = 0; index < keys.size(); ++index) {
        const auto key = string_value(keys[index], context);
        if (std::none_of(allowed.begin(), allowed.end(), [&](const char* candidate) {
                return key == candidate;
            })) throw std::invalid_argument(context + ": unknown field '" + key + "'");
    }
}

Variant required(const Dictionary& dictionary, const char* name, const std::string& context) {
    if (!dictionary.has(name)) throw std::invalid_argument(context + ": missing '" + name + "'");
    return dictionary[name];
}

std::vector<std::string> strings(const Variant& value, std::size_t capacity,
                               const std::string& context) {
    const auto array = array_value(value, capacity, context);
    std::vector<std::string> result;
    result.reserve(static_cast<std::size_t>(array.size()));
    for (std::int64_t index = 0; index < array.size(); ++index)
        result.push_back(string_value(array[index], context));
    return result;
}

std::vector<gen::ParameterEdit> parameter_edits(const Variant& value,
                                              const std::string& context) {
    const auto dictionary = dictionary_value(value, context);
    if (dictionary.size() > 12) invalid(context, "too many parameters");
    const auto keys = dictionary.keys();
    std::vector<gen::ParameterEdit> result;
    for (std::int64_t index = 0; index < keys.size(); ++index) {
        const auto key = string_value(keys[index], context);
        const auto parameter = gen::parse_parameter(key);
        if (!parameter) throw std::invalid_argument(context + ": unknown parameter '" + key + "'");
        result.push_back({*parameter, number_value(dictionary[keys[index]], context + "." + key)});
    }
    return result;
}

void apply_parameters(gen::Parameters& parameters, const std::vector<gen::ParameterEdit>& edits) {
    for (const auto& edit : edits) {
        switch (edit.parameter) {
            case gen::Parameter::SurfaceY: parameters.surface_y = edit.value; break;
            case gen::Parameter::Relief: parameters.relief = edit.value; break;
            case gen::Parameter::FeatureScale: parameters.feature_scale = edit.value; break;
            case gen::Parameter::CaveThreshold: parameters.cave_threshold = edit.value; break;
            case gen::Parameter::StrataPeriod: parameters.strata_period = edit.value; break;
            case gen::Parameter::Warp: parameters.warp = edit.value; break;
            case gen::Parameter::CorridorWidth: parameters.corridor_width = edit.value; break;
            case gen::Parameter::DistrictSize: parameters.district_size = edit.value; break;
            case gen::Parameter::RoomSize: parameters.room_size = edit.value; break;
            case gen::Parameter::WallThickness: parameters.wall_thickness = edit.value; break;
            case gen::Parameter::Detail: parameters.detail = edit.value; break;
            case gen::Parameter::FluidLevel: parameters.fluid_level = edit.value; break;
        }
    }
}

gen::Candidate candidate_value(const Variant& value, const std::string& context) {
    const auto candidate = gen::parse_candidate(string_value(value, context));
    if (!candidate) invalid(context, "unknown generation candidate");
    return *candidate;
}

cybersand::Material material_value(const Variant& value, const std::string& context) {
    const auto number = bounded_integer(value, 0, 255, context);
    if (!cybersand::valid_material(static_cast<std::uint16_t>(number)))
        invalid(context, "invalid material identifier");
    return static_cast<cybersand::Material>(number);
}

cybersand::RectI64 bounds_value(const Variant& value, const std::string& context) {
    const auto array = array_value(value, 4, context);
    if (array.size() != 4) invalid(context, "expected [x,y,width,height]");
    return {integer_value(array[0], context), integer_value(array[1], context),
            integer_value(array[2], context), integer_value(array[3], context)};
}

std::vector<gen::Point> points_value(const Variant& value, std::size_t capacity,
                                     const std::string& context) {
    const auto array = array_value(value, capacity, context);
    std::vector<gen::Point> result;
    result.reserve(static_cast<std::size_t>(array.size()));
    for (std::int64_t index = 0; index < array.size(); ++index) {
        const auto point = array_value(array[index], 2, context);
        if (point.size() != 2) invalid(context, "each point must be [x,y]");
        result.push_back({number_value(point[0], context), number_value(point[1], context)});
    }
    return result;
}

gen::ThemeSelection themes_value(const Variant& value, std::size_t capacity,
                                  const std::string& context) {
    const auto dictionary = dictionary_value(value, context);
    fields(dictionary, {"weights", "exclude"}, context);
    gen::ThemeSelection selection{{}, {}};
    if (dictionary.has("weights")) {
        const auto weights = dictionary_value(dictionary["weights"], context + ".weights");
        if (static_cast<std::uint64_t>(weights.size()) > capacity)
            invalid(context, "too many theme weights");
        const auto keys = weights.keys();
        for (std::int64_t index = 0; index < keys.size(); ++index)
            selection.weights.push_back({string_value(keys[index], context),
                                         number_value(weights[keys[index]], context)});
    }
    if (dictionary.has("exclude")) selection.exclude = strings(dictionary["exclude"], capacity, context);
    return selection;
}

int priority_value(const Dictionary& dictionary, const std::string& context) {
    return dictionary.has("priority") ? static_cast<int>(bounded_integer(dictionary["priority"],
        std::numeric_limits<int>::min(), std::numeric_limits<int>::max(), context + ".priority")) : 0;
}

gen::Recipe parse_recipe(const Dictionary& input, std::uint64_t revision) {
    fields(input, {"schema", "seed", "chunk_size", "candidate", "parameters", "themes",
                   "strokes", "paths", "overrides", "modules", "limits", "catalogue",
                   "fields", "aggregates", "modifiers"}, "recipe");
    gen::Recipe recipe;
    recipe.revision = revision;
    if (input.has("schema")) recipe.schema = static_cast<std::uint32_t>(bounded_integer(
        input["schema"], 1, 1, "schema"));
    if (input.has("seed")) recipe.seed = static_cast<std::uint64_t>(bounded_integer(
        input["seed"], 0, std::numeric_limits<std::int64_t>::max(), "seed"));
    if (input.has("chunk_size")) recipe.chunk_size = static_cast<std::int32_t>(bounded_integer(
        input["chunk_size"], 8, 256, "chunk_size"));
    if (input.has("candidate")) recipe.candidate = candidate_value(input["candidate"], "candidate");
    if (input.has("parameters")) apply_parameters(recipe.parameters, parameter_edits(input["parameters"], "parameters"));
    if (input.has("limits")) {
        const auto limits = dictionary_value(input["limits"], "limits");
        fields(limits, {"max_themes", "max_strokes", "max_points_per_path", "max_paths",
                        "max_overrides", "max_modules", "max_fields", "max_aggregates",
                        "max_modifiers", "max_operations_per_chunk"}, "limits");
        // The adapter permits tightening the native candidate's construction
        // budgets. A user document cannot expand its own parser/memory bound.
        const auto limit = [&](const char* name, std::size_t maximum) {
            return limits.has(name) ? static_cast<std::size_t>(bounded_integer(limits[name], 1,
                static_cast<std::int64_t>(maximum), std::string("limits.") + name)) : maximum;
        };
        recipe.limits.max_themes = limit("max_themes", recipe.limits.max_themes);
        recipe.limits.max_strokes = limit("max_strokes", recipe.limits.max_strokes);
        recipe.limits.max_points_per_path = limit("max_points_per_path", recipe.limits.max_points_per_path);
        recipe.limits.max_paths = limit("max_paths", recipe.limits.max_paths);
        recipe.limits.max_overrides = limit("max_overrides", recipe.limits.max_overrides);
        recipe.limits.max_modules = limit("max_modules", recipe.limits.max_modules);
        recipe.limits.max_fields = limit("max_fields", recipe.limits.max_fields);
        recipe.limits.max_aggregates = limit("max_aggregates", recipe.limits.max_aggregates);
        recipe.limits.max_modifiers = limit("max_modifiers", recipe.limits.max_modifiers);
        if (limits.has("max_operations_per_chunk")) recipe.limits.max_operations_per_chunk =
            static_cast<std::uint64_t>(bounded_integer(limits["max_operations_per_chunk"], 1,
                static_cast<std::int64_t>(recipe.limits.max_operations_per_chunk), "limits.max_operations_per_chunk"));
    }
    if (input.has("catalogue")) {
        const auto catalogue = array_value(input["catalogue"], recipe.limits.max_themes, "catalogue");
        for (std::int64_t index = 0; index < catalogue.size(); ++index) {
            const auto item = dictionary_value(catalogue[index], "catalogue");
            fields(item, {"id", "parents", "concrete", "palette", "parameters"}, "catalogue");
            gen::Theme theme;
            theme.id = string_value(required(item, "id", "catalogue"), "catalogue.id");
            if (item.has("parents")) theme.parents = strings(item["parents"], recipe.limits.max_themes, "catalogue.parents");
            if (item.has("concrete")) {
                if (item["concrete"].get_type() != Variant::BOOL) invalid("catalogue.concrete", "expected a boolean");
                theme.concrete = static_cast<bool>(item["concrete"]);
            }
            if (item.has("parameters")) theme.parameters = parameter_edits(item["parameters"], "catalogue.parameters");
            if (item.has("palette")) {
                const auto palette = dictionary_value(item["palette"], "catalogue.palette");
                fields(palette, {"rock", "surface", "accent", "fluid"}, "catalogue.palette");
                if (palette.has("rock")) theme.palette.rock = material_value(palette["rock"], "palette.rock");
                if (palette.has("surface")) theme.palette.surface = material_value(palette["surface"], "palette.surface");
                if (palette.has("accent")) theme.palette.accent = material_value(palette["accent"], "palette.accent");
                if (palette.has("fluid")) theme.palette.fluid = material_value(palette["fluid"], "palette.fluid");
            }
            recipe.catalogue.push_back(std::move(theme));
        }
    }
    if (input.has("themes")) recipe.themes = themes_value(input["themes"], recipe.limits.max_themes, "themes");
    if (input.has("strokes")) {
        const auto array = array_value(input["strokes"], recipe.limits.max_strokes, "strokes");
        for (std::int64_t index = 0; index < array.size(); ++index) {
            const auto item = dictionary_value(array[index], "stroke");
            fields(item, {"id", "points", "radius", "strength", "falloff", "priority", "themes", "parameters"}, "stroke");
            gen::BrushStroke stroke;
            stroke.id = string_value(required(item, "id", "stroke"), "stroke.id");
            stroke.points = points_value(required(item, "points", "stroke"), recipe.limits.max_points_per_path, "stroke.points");
            if (item.has("radius")) stroke.radius = number_value(item["radius"], "stroke.radius");
            if (item.has("strength")) stroke.strength = number_value(item["strength"], "stroke.strength");
            if (item.has("falloff")) stroke.falloff = number_value(item["falloff"], "stroke.falloff");
            stroke.priority = priority_value(item, "stroke");
            if (item.has("themes")) stroke.themes = themes_value(item["themes"], recipe.limits.max_themes, "stroke.themes");
            if (item.has("parameters")) stroke.parameters = parameter_edits(item["parameters"], "stroke.parameters");
            recipe.strokes.push_back(std::move(stroke));
        }
    }
    if (input.has("paths")) {
        const auto array = array_value(input["paths"], recipe.limits.max_paths, "paths");
        for (std::int64_t index = 0; index < array.size(); ++index) {
            const auto item = dictionary_value(array[index], "path");
            fields(item, {"id", "points", "width", "material", "priority"}, "path");
            gen::GuidePath path;
            path.id = string_value(required(item, "id", "path"), "path.id");
            path.points = points_value(required(item, "points", "path"), recipe.limits.max_points_per_path, "path.points");
            if (item.has("width")) path.width = number_value(item["width"], "path.width");
            if (item.has("material")) path.material = material_value(item["material"], "path.material");
            path.priority = priority_value(item, "path");
            recipe.paths.push_back(std::move(path));
        }
    }
    if (input.has("overrides")) {
        const auto array = array_value(input["overrides"], recipe.limits.max_overrides, "overrides");
        for (std::int64_t index = 0; index < array.size(); ++index) {
            const auto item = dictionary_value(array[index], "override");
            fields(item, {"id", "bounds", "material", "candidate", "parameters", "priority"}, "override");
            gen::HardOverride override;
            override.id = string_value(required(item, "id", "override"), "override.id");
            override.bounds = bounds_value(required(item, "bounds", "override"), "override.bounds");
            if (item.has("material")) override.material = material_value(item["material"], "override.material");
            if (item.has("candidate")) override.candidate = candidate_value(item["candidate"], "override.candidate");
            if (item.has("parameters")) override.parameters = parameter_edits(item["parameters"], "override.parameters");
            override.priority = priority_value(item, "override");
            recipe.overrides.push_back(std::move(override));
        }
    }
    if (input.has("modules")) {
        const auto array = array_value(input["modules"], recipe.limits.max_modules, "modules");
        for (std::int64_t index = 0; index < array.size(); ++index) {
            const auto item = dictionary_value(array[index], "module");
            fields(item, {"id", "module", "version", "bounds", "parameters", "after", "priority",
                          "application", "exclusion", "strength"}, "module");
            gen::ModuleInstance module;
            module.id = string_value(required(item, "id", "module"), "module.id");
            module.module = string_value(required(item, "module", "module"), "module.module");
            module.bounds = bounds_value(required(item, "bounds", "module"), "module.bounds");
            if (item.has("version")) module.version = static_cast<std::uint32_t>(bounded_integer(
                item["version"], 1, std::numeric_limits<std::uint32_t>::max(), "module.version"));
            if (item.has("parameters")) {
                const auto parameters = dictionary_value(item["parameters"], "module.parameters");
                if (parameters.size() > 32) invalid("module.parameters", "too many parameters");
                const auto keys = parameters.keys();
                for (std::int64_t key = 0; key < keys.size(); ++key)
                    module.parameters.emplace(string_value(keys[key], "module.parameters"),
                                              number_value(parameters[keys[key]], "module.parameters"));
            }
            if (item.has("after")) module.after = strings(item["after"], recipe.limits.max_modules, "module.after");
            module.priority = priority_value(item, "module");
            if (item.has("application")) module.application = string_value(item["application"], "module.application");
            if (item.has("exclusion")) module.exclusion = string_value(item["exclusion"], "module.exclusion");
            if (item.has("strength")) module.strength = number_value(item["strength"], "module.strength");
            recipe.modules.push_back(std::move(module));
        }
    }
    if (input.has("fields")) {
        const auto array = array_value(input["fields"], recipe.limits.max_fields, "fields");
        for (std::int64_t index = 0; index < array.size(); ++index) {
            const auto item = dictionary_value(array[index], "field");
            fields(item, {"id", "kind", "inputs", "parameters", "warp_x", "warp_y", "context"}, "field");
            gen::FieldNode node;
            node.id = string_value(required(item, "id", "field"), "field.id");
            const auto kind = gen::parse_field_kind(string_value(required(item, "kind", "field"), "field.kind"));
            if (!kind) invalid("field.kind", "unknown field kind");
            node.kind = *kind;
            if (item.has("inputs")) node.inputs = strings(item["inputs"], recipe.limits.max_fields, "field.inputs");
            if (item.has("parameters")) {
                const auto parameters = dictionary_value(item["parameters"], "field.parameters");
                if (parameters.size() > 32) invalid("field.parameters", "too many parameters");
                const auto keys = parameters.keys();
                for (std::int64_t key = 0; key < keys.size(); ++key)
                    node.parameters.emplace(string_value(keys[key], "field.parameters"),
                                            number_value(parameters[keys[key]], "field.parameters"));
            }
            if (item.has("warp_x")) node.warp_x = string_value(item["warp_x"], "field.warp_x");
            if (item.has("warp_y")) node.warp_y = string_value(item["warp_y"], "field.warp_y");
            if (item.has("context")) node.context = string_value(item["context"], "field.context");
            recipe.fields.push_back(std::move(node));
        }
    }
    if (input.has("aggregates")) {
        const auto array = array_value(input["aggregates"], recipe.limits.max_aggregates, "aggregates");
        for (std::int64_t index = 0; index < array.size(); ++index) {
            const auto item = dictionary_value(array[index], "aggregate");
            fields(item, {"id", "components", "grain_size", "variation"}, "aggregate");
            gen::Aggregate aggregate;
            aggregate.id = string_value(required(item, "id", "aggregate"), "aggregate.id");
            const auto components = array_value(required(item, "components", "aggregate"), 16, "aggregate.components");
            for (std::int64_t component_index = 0; component_index < components.size(); ++component_index) {
                const auto component = dictionary_value(components[component_index], "aggregate.component");
                fields(component, {"material", "weight"}, "aggregate.component");
                aggregate.components.push_back({material_value(required(component, "material", "aggregate.component"),
                    "aggregate.component.material"), component.has("weight") ? number_value(component["weight"], "aggregate.component.weight") : 1.0});
            }
            if (item.has("grain_size")) aggregate.grain_size = static_cast<std::int32_t>(bounded_integer(item["grain_size"], 1, 4096, "aggregate.grain_size"));
            if (item.has("variation")) aggregate.variation = string_value(item["variation"], "aggregate.variation");
            recipe.aggregates.push_back(std::move(aggregate));
        }
    }
    if (input.has("modifiers")) {
        const auto array = array_value(input["modifiers"], recipe.limits.max_modifiers, "modifiers");
        for (std::int64_t index = 0; index < array.size(); ++index) {
            const auto item = dictionary_value(array[index], "modifier");
            fields(item, {"id", "priority", "bounds", "points", "radius", "falloff", "strength", "application", "exclusion",
                          "context", "context_material", "themes", "parameters", "mappings", "material", "aggregate"}, "modifier");
            gen::Modifier modifier;
            modifier.id = string_value(required(item, "id", "modifier"), "modifier.id");
            modifier.priority = priority_value(item, "modifier");
            if (item.has("bounds")) modifier.bounds = bounds_value(item["bounds"], "modifier.bounds");
            if (item.has("points")) modifier.points = points_value(item["points"], recipe.limits.max_points_per_path, "modifier.points");
            if (item.has("radius")) modifier.radius = number_value(item["radius"], "modifier.radius");
            if (item.has("falloff")) modifier.falloff = number_value(item["falloff"], "modifier.falloff");
            if (item.has("strength")) modifier.strength = number_value(item["strength"], "modifier.strength");
            if (item.has("application")) modifier.application = string_value(item["application"], "modifier.application");
            if (item.has("exclusion")) modifier.exclusion = string_value(item["exclusion"], "modifier.exclusion");
            if (item.has("context")) {
                const auto context = gen::parse_context_predicate(string_value(item["context"], "modifier.context"));
                if (!context) invalid("modifier.context", "unknown context predicate");
                modifier.context = *context;
            }
            if (item.has("context_material")) modifier.context_material = material_value(item["context_material"], "modifier.context_material");
            if (item.has("themes")) modifier.themes = themes_value(item["themes"], recipe.limits.max_themes, "modifier.themes");
            if (item.has("parameters")) modifier.parameters = parameter_edits(item["parameters"], "modifier.parameters");
            if (item.has("mappings")) {
                const auto mappings = array_value(item["mappings"], 12, "modifier.mappings");
                for (std::int64_t mapping_index = 0; mapping_index < mappings.size(); ++mapping_index) {
                    const auto mapping = dictionary_value(mappings[mapping_index], "modifier.mapping");
                    fields(mapping, {"parameter", "field", "low", "high"}, "modifier.mapping");
                    const auto parameter = gen::parse_parameter(string_value(required(mapping, "parameter", "modifier.mapping"), "modifier.mapping.parameter"));
                    if (!parameter) invalid("modifier.mapping.parameter", "unknown terrain parameter");
                    modifier.mappings.push_back({*parameter, string_value(required(mapping, "field", "modifier.mapping"), "modifier.mapping.field"),
                        number_value(required(mapping, "low", "modifier.mapping"), "modifier.mapping.low"),
                        number_value(required(mapping, "high", "modifier.mapping"), "modifier.mapping.high")});
                }
            }
            if (item.has("material")) modifier.material = material_value(item["material"], "modifier.material");
            if (item.has("aggregate")) modifier.aggregate = string_value(item["aggregate"], "modifier.aggregate");
            recipe.modifiers.push_back(std::move(modifier));
        }
    }
    return recipe;
}

String hexadecimal(std::uint64_t value) {
    constexpr char digits[] = "0123456789abcdef";
    char buffer[17]{};
    for (int index = 15; index >= 0; --index) {
        buffer[index] = digits[value & 15U];
        value >>= 4U;
    }
    return String(buffer);
}

const char* state_name(gen::ResultState state) {
    switch (state) {
        case gen::ResultState::Pending: return "running";
        case gen::ResultState::Ready: return "ready";
        case gen::ResultState::Cancelled: return "cancelled";
        case gen::ResultState::Failed: return "failed";
    }
    return "failed";
}

Dictionary failure(const char* error) {
    Dictionary result;
    result["ok"] = false;
    result["error"] = String(error);
    return result;
}
} // namespace

CyberWorldGenerator::CyberWorldGenerator() = default;
CyberWorldGenerator::~CyberWorldGenerator() = default;

void CyberWorldGenerator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "recipe"), &CyberWorldGenerator::configure);
    ClassDB::bind_method(D_METHOD("get_configuration"), &CyberWorldGenerator::get_configuration);
    ClassDB::bind_method(D_METHOD("get_catalogue"), &CyberWorldGenerator::get_catalogue);
    ClassDB::bind_method(D_METHOD("generate_chunk", "coord", "diagnostic"), &CyberWorldGenerator::generate_chunk, DEFVAL(String()));
    ClassDB::bind_method(D_METHOD("begin_chunk", "coord", "diagnostic"), &CyberWorldGenerator::begin_chunk, DEFVAL(String()));
    ClassDB::bind_method(D_METHOD("advance", "cell_budget"), &CyberWorldGenerator::advance);
}

Dictionary CyberWorldGenerator::configure(const Dictionary& input) {
    try {
        if (revision_ == static_cast<std::uint64_t>(std::numeric_limits<std::int64_t>::max()))
            return failure("generator revision exhausted");
        auto candidate = gen::Generator::compile(parse_recipe(input, revision_ + 1));
        auto configuration = input.duplicate(true);
        auto result = Dictionary();
        result["ok"] = true;
        result["error"] = "";
        result["revision"] = static_cast<std::int64_t>(revision_ + 1);
        result["fingerprint"] = hexadecimal(candidate->fingerprint());
        if (job_) job_->cancel();
        job_.reset();
        generator_ = std::move(candidate);
        configuration_ = std::move(configuration);
        ++revision_;
        return result;
    } catch (const std::exception& error) { return failure(error.what()); }
    catch (...) { return failure("unknown generation configuration failure"); }
}

Dictionary CyberWorldGenerator::get_configuration() const {
    return configuration_.duplicate(true);
}

Dictionary CyberWorldGenerator::get_catalogue() const {
    Dictionary result;
    Array themes, modules, candidates, parameters;
    const auto catalogue = generator_ && !generator_->recipe().catalogue.empty()
        ? generator_->recipe().catalogue : gen::Generator::builtin_themes();
    for (const auto& theme : catalogue) {
        Dictionary item;
        Array parents;
        item["id"] = String(theme.id.c_str());
        item["concrete"] = theme.concrete;
        for (const auto& parent : theme.parents) parents.push_back(String(parent.c_str()));
        item["parents"] = parents;
        themes.push_back(item);
    }
    for (const auto& module : gen::Generator::builtin_modules()) {
        Dictionary item;
        item["id"] = String(module.c_str());
        item["version"] = 1;
        modules.push_back(item);
    }
    for (const auto candidate : {gen::Candidate::Strata, gen::Candidate::FlowNetwork, gen::Candidate::DistrictGrammar})
        candidates.push_back(gen::candidate_name(candidate));
    for (int parameter = 0; parameter < 12; ++parameter)
        parameters.push_back(gen::parameter_name(static_cast<gen::Parameter>(parameter)));
    result["themes"] = themes;
    result["modules"] = modules;
    result["candidates"] = candidates;
    result["parameters"] = parameters;
    result["minimum_chunk_size"] = 8;
    result["maximum_chunk_size"] = 256;
    Array field_kinds, field_contexts, contexts;
    for (const auto& spec : gen::field_kind_specs()) {
        Dictionary item;
        item["id"] = String(spec.name);
        item["input_count"] = static_cast<std::int64_t>(spec.input_count);
        item["supports_warp"] = spec.supports_warp;
        item["requires_context"] = spec.requires_context;
        Array settings;
        for (const auto& setting : spec.parameters) {
            Dictionary description;
            description["name"] = String(setting.name);
            description["default_value"] = setting.default_value;
            description["minimum"] = setting.minimum;
            description["maximum"] = setting.maximum;
            description["integer"] = setting.integer;
            settings.push_back(description);
        }
        item["parameters"] = settings;
        field_kinds.push_back(item);
    }
    for (const auto* name : gen::field_context_names()) field_contexts.push_back(String(name));
    for (const auto context : {gen::ContextPredicate::Any, gen::ContextPredicate::Empty, gen::ContextPredicate::Occupied,
                              gen::ContextPredicate::Solid, gen::ContextPredicate::Fluid, gen::ContextPredicate::Material})
        contexts.push_back(String(gen::context_predicate_name(context)));
    result["field_kinds"] = field_kinds;
    result["field_contexts"] = field_contexts;
    result["modifier_contexts"] = contexts;
    result["maximum_fields"] = 64;
    result["maximum_aggregates"] = 32;
    result["maximum_modifiers"] = 64;
    return result;
}

Dictionary CyberWorldGenerator::metadata(cybersand::ChunkCoord coord) const {
    Dictionary result;
    result["ok"] = true;
    result["error"] = "";
    result["chunk_x"] = coord.x;
    result["chunk_y"] = coord.y;
    result["chunk_size"] = generator_ ? generator_->recipe().chunk_size : 0;
    result["revision"] = static_cast<std::int64_t>(revision_);
    result["fingerprint"] = generator_ ? hexadecimal(generator_->fingerprint()) : String();
    return result;
}

Dictionary CyberWorldGenerator::copy_result(const gen::ChunkResult& chunk) const {
    auto result = metadata(chunk.chunk);
    result["state"] = state_name(chunk.state);
    result["completed_cells"] = static_cast<std::int64_t>(chunk.cells.size());
    result["operations"] = static_cast<std::int64_t>(chunk.operations);
    result["revision"] = static_cast<std::int64_t>(chunk.revision);
    result["fingerprint"] = hexadecimal(chunk.fingerprint);
    if (chunk.state != gen::ResultState::Ready || !generator_->accepts(chunk)) {
        result["ok"] = false;
        result["error"] = chunk.error.empty() ? String("result is not a current complete chunk") : String(chunk.error.c_str());
        return result;
    }
    PackedByteArray cells;
    if (cells.resize(static_cast<std::int64_t>(chunk.cells.size())) != OK)
        return failure("cannot allocate copied chunk output");
    static_assert(sizeof(cybersand::Material) == 1);
    if (!chunk.cells.empty()) std::memcpy(cells.ptrw(), chunk.cells.data(), chunk.cells.size());
    result["cells"] = cells;
    result["hash"] = hexadecimal(chunk.content_hash);
    result["receipt_hash"] = hexadecimal(chunk.receipt_hash);
    PackedFloat32Array diagnostics;
    if (diagnostics.resize(static_cast<std::int64_t>(chunk.diagnostics.size())) != OK)
        return failure("cannot allocate copied diagnostic output");
    if (!chunk.diagnostics.empty()) std::memcpy(diagnostics.ptrw(), chunk.diagnostics.data(), chunk.diagnostics.size() * sizeof(float));
    result["diagnostic"] = String(chunk.diagnostic.c_str());
    result["diagnostics"] = diagnostics;
    return result;
}

Dictionary CyberWorldGenerator::generate_chunk(Vector2i coord, const String& diagnostic) const {
    if (!generator_) return failure("configure a generator before requesting chunks");
    try { return copy_result(generator_->generate({coord.x, coord.y}, string_value(diagnostic, "diagnostic"))); }
    catch (const std::exception& error) { return failure(error.what()); }
    catch (...) { return failure("unknown chunk generation failure"); }
}

Dictionary CyberWorldGenerator::begin_chunk(Vector2i coord, const String& diagnostic) {
    if (!generator_) return failure("configure a generator before requesting chunks");
    try {
        auto candidate = generator_->begin({coord.x, coord.y}, string_value(diagnostic, "diagnostic"));
        if (job_) job_->cancel();
        job_ = std::move(candidate);
        job_chunk_ = {coord.x, coord.y};
        return job_status();
    } catch (const std::exception& error) { return failure(error.what()); }
    catch (...) { return failure("unknown chunk preparation failure"); }
}

Dictionary CyberWorldGenerator::job_status() const {
    if (!job_) {
        auto result = metadata({});
        result["state"] = "idle";
        result["completed_cells"] = 0;
        return result;
    }
    if (job_->state() != gen::ResultState::Pending) {
        auto result = copy_result(job_->result());
        result["completed_cells"] = static_cast<std::int64_t>(job_->completed_cells());
        return result;
    }
    auto result = metadata(job_chunk_);
    result["state"] = "running";
    result["completed_cells"] = static_cast<std::int64_t>(job_->completed_cells());
    return result;
}

Dictionary CyberWorldGenerator::advance(std::int64_t cell_budget) {
    if (cell_budget < 0) return failure("cell budget must be non-negative");
    if (!job_) return job_status();
    try {
        // A caller can ask for a whole chunk, but no single native advance can
        // exceed the fixed output area or overflow a 32-bit Web size_t.
        const auto area = static_cast<std::uint64_t>(generator_->recipe().chunk_size) *
                          static_cast<std::uint64_t>(generator_->recipe().chunk_size);
        (void)job_->advance(static_cast<std::size_t>(std::min<std::uint64_t>(
            static_cast<std::uint64_t>(cell_budget), area)));
        return job_status();
    } catch (const std::exception& error) { return failure(error.what()); }
    catch (...) { return failure("unknown incremental generation failure"); }
}

} // namespace godot
