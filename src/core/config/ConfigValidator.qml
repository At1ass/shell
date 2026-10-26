pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Structural check of config.json against config/config.schema.json.
//
// Config-first means the config file IS the interface, and until now a typo in
// it did nothing observable: the key was ignored, the accessor fell back to its
// default, and the user was left believing a setting that never applied. The
// schema already described every key exactly (78/78 paths, verified) — it was
// simply never executed.
//
// Supports the subset this schema actually uses: type, enum, const, required,
// additionalProperties, minimum/maximum, minLength, minItems, uniqueItems,
// pattern, $ref (local), oneOf, allOf and if/then. Anything unknown is SKIPPED
// rather than guessed at: a validator that cries wolf over a valid config is
// worse than none, because it trains the user to ignore it.
Singleton {
    id: root

    // validate(config, schema) -> [{ path, message }]
    function validate(config, schema) {
        const errors = []
        root._check(config, schema, schema, "", errors)
        return errors
    }

    function parse(rawText, schema) {
        try {
            const value = JSON.parse(rawText)
            return { value: value, errors: root.validate(value, schema) }
        } catch (e) {
            return { value: null, errors: [{ path: "(root)", message: "Invalid JSON: " + e.message }] }
        }
    }

    function _resolve(node, rootSchema) {
        // Only local "#/definitions/x" refs exist in this schema.
        let seen = 0
        while (node && node.$ref !== undefined && seen++ < 8) {
            const parts = String(node.$ref).split("/")
            let cur = rootSchema
            for (let i = 1; i < parts.length; i++) {
                if (!cur) break
                cur = cur[parts[i]]
            }
            if (!cur)
                return node
            node = cur
        }
        return node
    }

    function _typeOf(v) {
        if (v === null) return "null"
        if (Array.isArray(v)) return "array"
        if (typeof v === "number") return Number.isInteger(v) ? "integer" : "number"
        if (typeof v === "boolean") return "boolean"
        if (typeof v === "string") return "string"
        if (typeof v === "object") return "object"
        return "unknown"
    }

    function _typeOk(value, expected) {
        const actual = root._typeOf(value)
        if (expected === "number")
            return actual === "number" || actual === "integer"
        return actual === expected
    }

    // Does `value` satisfy `node` at all? Used for oneOf branches and if-clauses,
    // where a mismatch is a normal outcome and must not be reported.
    function _matches(value, node, rootSchema) {
        const probe = []
        root._check(value, node, rootSchema, "", probe)
        return probe.length === 0
    }

    function _check(value, node, rootSchema, path, errors) {
        node = root._resolve(node, rootSchema)
        if (!node || typeof node !== "object")
            return

        const where = path === "" ? "(root)" : path

        if (node.type !== undefined && !root._typeOk(value, node.type)) {
            errors.push({ path: where,
                          message: `expected ${node.type}, got ${root._typeOf(value)}` })
            return          // every further check would just echo this one
        }

        if (node.enum !== undefined && node.enum.indexOf(value) === -1) {
            errors.push({ path: where,
                          message: `"${value}" is not one of: ${node.enum.join(", ")}` })
        }

        if (node.const !== undefined && value !== node.const)
            errors.push({ path: where, message: `must be ${node.const}` })

        if (typeof value === "number") {
            if (node.minimum !== undefined && value < node.minimum)
                errors.push({ path: where, message: `${value} is below the minimum ${node.minimum}` })
            if (node.maximum !== undefined && value > node.maximum)
                errors.push({ path: where, message: `${value} is above the maximum ${node.maximum}` })
        }

        if (typeof value === "string") {
            if (node.minLength !== undefined && value.length < node.minLength)
                errors.push({ path: where, message: `must be at least ${node.minLength} characters` })
            if (node.pattern !== undefined && !(new RegExp(node.pattern)).test(value))
                errors.push({ path: where, message: `does not match ${node.pattern}` })
        }

        if (Array.isArray(value)) {
            if (node.minItems !== undefined && value.length < node.minItems)
                errors.push({ path: where, message: `needs at least ${node.minItems} item(s)` })
            if (node.uniqueItems === true && (new Set(value.map(JSON.stringify))).size !== value.length)
                errors.push({ path: where, message: "entries must be unique" })
            if (node.items !== undefined)
                for (let i = 0; i < value.length; i++)
                    root._check(value[i], node.items, rootSchema, `${where}[${i}]`, errors)
        }

        if (node.oneOf !== undefined) {
            const ok = node.oneOf.filter(branch => root._matches(value, branch, rootSchema)).length === 1
            if (!ok)
                errors.push({ path: where, message: "must match exactly one allowed form" })
        }

        if (value !== null && typeof value === "object" && !Array.isArray(value)) {
            if (Array.isArray(node.required))
                for (const key of node.required)
                    if (value[key] === undefined)
                        errors.push({ path: where, message: `missing required key "${key}"` })

            const props = node.properties || ({})
            for (const key in value) {
                if (props[key] !== undefined) {
                    root._check(value[key], props[key], rootSchema,
                                path === "" ? key : `${path}.${key}`, errors)
                } else if (node.additionalProperties === false && key !== "$schema") {
                    const known = Object.keys(props)
                    errors.push({ path: path === "" ? key : `${path}.${key}`,
                                  message: "unknown key" + (known.length
                                      ? ` — did you mean one of: ${root._nearest(key, known)}?` : "") })
                } else if (node.additionalProperties && typeof node.additionalProperties === "object") {
                    root._check(value[key], node.additionalProperties, rootSchema,
                                path === "" ? key : `${path}.${key}`, errors)
                }
            }

            // Conditional branches refine what is already declared above; they
            // never introduce keys, so they run after the property walk.
            if (Array.isArray(node.allOf))
                for (const branch of node.allOf)
                    root._check(value, branch, rootSchema, path, errors)

            if (node.if !== undefined && node.then !== undefined
                    && root._matches(value, node.if, rootSchema))
                root._check(value, node.then, rootSchema, path, errors)
        }
    }

    // Cheap edit-distance suggestion: a typo is the case this whole file exists
    // for, so naming the intended key is most of the value.
    function _nearest(key, candidates) {
        const scored = candidates.map(c => ({ c: c, d: root._distance(key.toLowerCase(), c.toLowerCase()) }))
        scored.sort((a, b) => a.d - b.d)
        return scored.slice(0, 3).map(s => s.c).join(", ")
    }

    function _distance(a, b) {
        const prev = []
        for (let j = 0; j <= b.length; j++) prev[j] = j
        for (let i = 1; i <= a.length; i++) {
            let carry = prev[0]
            prev[0] = i
            for (let j = 1; j <= b.length; j++) {
                const t = prev[j]
                prev[j] = Math.min(prev[j] + 1, prev[j - 1] + 1,
                                   carry + (a[i - 1] === b[j - 1] ? 0 : 1))
                carry = t
            }
        }
        return prev[b.length]
    }
}
