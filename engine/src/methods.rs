use crate::ast::{Arg, Span};
use crate::interp::*;
use crate::value::*;
use std::rc::Rc;

pub fn arg<'a>(a: &'a Args, label: &str) -> Option<&'a Value> {
    a.iter().find(|x| x.0.as_deref() == Some(label)).map(|x| &x.1)
}
pub fn pos(a: &Args, i: usize) -> Option<&Value> {
    a.iter().filter(|x| x.0.is_none()).nth(i).map(|x| &x.1)
}
fn first(a: &Args) -> Option<&Value> {
    a.first().map(|x| &x.1)
}

pub fn is_mutating(n: &str) -> bool {
    matches!(
        n,
        "append" | "insert" | "remove" | "removeAll" | "removeFirst" | "removeLast" | "toggle" | "sort" | "shuffle"
            | "reverse" | "popLast" | "removeValue" | "updateValue" | "formUnion" | "move"
    )
}

pub fn mutating_applies(v: &Value, n: &str) -> bool {
    match v {
        Value::Array(_) => n != "toggle",
        Value::Bool(_) => n == "toggle",
        Value::Str(_) => matches!(n, "append" | "removeAll" | "removeLast" | "removeFirst" | "insert"),
        Value::Dict(_) => matches!(n, "removeValue" | "updateValue" | "removeAll"),
        Value::Binding(_) => true,
        _ => false,
    }
}

pub fn mutate(it: &mut Interp, cur: &Value, n: &str, a: Args, span: Span) -> R<(Value, Value)> {
    if let Value::Binding(b) = cur {
        let inner = it.read_binding(b);
        return mutate(it, &inner, n, a, span);
    }
    match cur {
        Value::Bool(b) => Ok((Value::Bool(!b), Value::Nil)),
        Value::Str(s) => {
            let mut s = s.to_string();
            let ret = match n {
                "append" => {
                    s.push_str(&first(&a).map(|v| v.describe()).unwrap_or_default());
                    Value::Nil
                }
                "removeAll" => {
                    s.clear();
                    Value::Nil
                }
                "removeLast" => s.pop().map(|c| Value::s(&c.to_string())).unwrap_or(Value::Nil),
                "removeFirst" => {
                    if s.is_empty() {
                        Value::Nil
                    } else {
                        let c = s.remove(0);
                        Value::s(&c.to_string())
                    }
                }
                _ => Value::Nil,
            };
            Ok((Value::Str(Rc::from(s)), ret))
        }
        Value::Dict(d) => {
            let mut d = d.as_ref().clone();
            match n {
                "removeValue" => {
                    let k = first(&a).cloned().unwrap_or(Value::Nil);
                    d.retain(|(x, _)| !values_eq(x, &k));
                }
                "updateValue" => {
                    let v = pos(&a, 0).cloned().unwrap_or(Value::Nil);
                    let k = arg(&a, "forKey").cloned().unwrap_or(Value::Nil);
                    if let Some(s) = d.iter_mut().find(|(x, _)| values_eq(x, &k)) {
                        s.1 = v;
                    } else {
                        d.push((k, v));
                    }
                }
                _ => d.clear(),
            }
            Ok((Value::Dict(Rc::new(d)), Value::Nil))
        }
        Value::Array(arr) => {
            let mut v = arr.as_ref().clone();
            let ret = match n {
                "append" => {
                    if let Some(c) = arg(&a, "contentsOf") {
                        v.extend(it.iter_items(c, span)?);
                    } else if let Some(x) = first(&a) {
                        v.push(x.clone());
                    }
                    Value::Nil
                }
                "insert" => {
                    let x = pos(&a, 0).cloned().unwrap_or(Value::Nil);
                    let at = arg(&a, "at").and_then(|v| v.as_i()).unwrap_or(0).clamp(0, v.len() as i64) as usize;
                    v.insert(at, x);
                    Value::Nil
                }
                "remove" => {
                    let at = arg(&a, "at").and_then(|v| v.as_i()).unwrap_or(-1);
                    if at < 0 || at as usize >= v.len() {
                        return err(span, "remove(at:) index out of range");
                    }
                    v.remove(at as usize)
                }
                "removeAll" => {
                    if let Some(f) = arg(&a, "where").or(first(&a)).cloned() {
                        let mut keep = vec![];
                        for x in v.into_iter() {
                            if !it.call_fn(&f, vec![x.clone()], span)?.truthy() {
                                keep.push(x);
                            }
                        }
                        v = keep;
                    } else {
                        v.clear();
                    }
                    Value::Nil
                }
                "removeFirst" => {
                    if v.is_empty() {
                        return err(span, "removeFirst on empty collection");
                    }
                    v.remove(0)
                }
                "removeLast" | "popLast" => v.pop().unwrap_or(Value::Nil),
                "sort" => {
                    sort_values(it, &mut v, arg(&a, "by").cloned(), span)?;
                    Value::Nil
                }
                "reverse" => {
                    v.reverse();
                    Value::Nil
                }
                "shuffle" => {
                    v.reverse();
                    Value::Nil
                }
                "toggle" => Value::Nil,
                _ => Value::Nil,
            };
            Ok((Value::Array(Rc::new(v)), ret))
        }
        _ => err(span, format!("cannot call mutating '{}' on {}", n, cur.type_name())),
    }
}

fn cmp_values(a: &Value, b: &Value) -> std::cmp::Ordering {
    match (a, b) {
        (Value::Str(x), Value::Str(y)) => x.cmp(y),
        _ => a.as_f().unwrap_or(0.0).partial_cmp(&b.as_f().unwrap_or(0.0)).unwrap_or(std::cmp::Ordering::Equal),
    }
}

fn sort_values(it: &mut Interp, v: &mut Vec<Value>, by: Option<Value>, span: Span) -> R<()> {
    match by {
        None => v.sort_by(cmp_values),
        Some(f) => {
            // insertion sort with fallible comparator (small arrays)
            let mut out: Vec<Value> = vec![];
            for x in v.drain(..) {
                let mut i = out.len();
                while i > 0 {
                    if it.call_fn(&f, vec![x.clone(), out[i - 1].clone()], span)?.truthy() {
                        i -= 1;
                    } else {
                        break;
                    }
                }
                out.insert(i, x);
            }
            *v = out;
        }
    }
    Ok(())
}

pub fn builtin_prop(it: &mut Interp, v: &Value, n: &str, span: Span) -> R<Value> {
    if n == "gradient" && matches!(v, Value::Paint(_) | Value::Sym(_) | Value::SymCall(..)) {
        return builtin_method(it, v, "gradient", vec![], &[], span, span);
    }
    match v {
        Value::Str(s) => match n {
            "count" => return Ok(Value::Int(s.chars().count() as i64)),
            "isEmpty" => return Ok(Value::Bool(s.is_empty())),
            "first" => return Ok(s.chars().next().map(|c| Value::s(&c.to_string())).unwrap_or(Value::Nil)),
            "last" => return Ok(s.chars().last().map(|c| Value::s(&c.to_string())).unwrap_or(Value::Nil)),
            "capitalized" => {
                let out: Vec<String> = s
                    .split(' ')
                    .map(|w| {
                        let mut c = w.chars();
                        match c.next() {
                            Some(f) => f.to_uppercase().collect::<String>() + &c.as_str().to_lowercase(),
                            None => String::new(),
                        }
                    })
                    .collect();
                return Ok(Value::s(&out.join(" ")));
            }
            "description" | "uuidString" => return Ok(v.clone()),
            "isNumber" => return Ok(Value::Bool(s.chars().all(|c| c.is_ascii_digit()))),
            "isLetter" => return Ok(Value::Bool(s.chars().all(|c| c.is_alphabetic()))),
            "startIndex" => return Ok(Value::Int(0)),
            "endIndex" => return Ok(Value::Int(s.chars().count() as i64)),
            _ => {}
        },
        Value::Array(a) => match n {
            "count" => return Ok(Value::Int(a.len() as i64)),
            "isEmpty" => return Ok(Value::Bool(a.is_empty())),
            "first" => return Ok(a.first().cloned().unwrap_or(Value::Nil)),
            "last" => return Ok(a.last().cloned().unwrap_or(Value::Nil)),
            "indices" => return Ok(Value::Range(0, a.len() as i64)),
            "startIndex" => return Ok(Value::Int(0)),
            "endIndex" => return Ok(Value::Int(a.len() as i64)),
            _ => {}
        },
        Value::Dict(d) => match n {
            "count" => return Ok(Value::Int(d.len() as i64)),
            "isEmpty" => return Ok(Value::Bool(d.is_empty())),
            "keys" => return Ok(Value::Array(Rc::new(d.iter().map(|x| x.0.clone()).collect()))),
            "values" => return Ok(Value::Array(Rc::new(d.iter().map(|x| x.1.clone()).collect()))),
            _ => {}
        },
        Value::Range(a, b) => match n {
            "count" => return Ok(Value::Int((b - a).max(0))),
            "lowerBound" => return Ok(Value::Int(*a)),
            "upperBound" => return Ok(Value::Int(*b)),
            "isEmpty" => return Ok(Value::Bool(b <= a)),
            _ => {}
        },
        Value::Int(i) => match n {
            "description" => return Ok(Value::s(&i.to_string())),
            "magnitude" => return Ok(Value::Int(i.abs())),
            _ => {}
        },
        Value::Double(d) => match n {
            "description" => return Ok(Value::s(&v.describe())),
            "magnitude" => return Ok(Value::Double(d.abs())),
            _ => {}
        },
        Value::Bool(_) if n == "description" => return Ok(Value::s(&v.describe())),
        Value::Sym(s) if n == "rawValue" => return Ok(Value::Str(s.clone())),
        _ => {}
    }
    let _ = it;
    // methods referenced without call, or modifiers on paints/fonts: return a bound method
    match v {
        Value::Nil => err(span, format!("value of optional type is nil (accessing '{}')", n)),
        _ => Ok(Value::Method(Box::new(v.clone()), Rc::from(n))),
    }
}

pub fn builtin_static(it: &mut Interp, t: &str, n: &str, span: Span) -> R<Value> {
    match t {
        "Color" | "UIColor" | "ShapeStyle" => {
            if let Some(c) = semantic_color(n) {
                return Ok(Value::Paint(Rc::new(Paint::Solid(c))));
            }
            if n.ends_with("Material") || n == "bar" {
                return Ok(crate::views::to_paint(it, &Value::Sym(Rc::from(n))).map(|p| Value::Paint(Rc::new(p))).unwrap_or(Value::Nil));
            }
        }
        "Font" => {
            if let Some(f) = FontSpec::named(n) {
                return Ok(Value::Font(f));
            }
            if let Some(w) = weight_named(n) {
                return Ok(Value::Sym(Rc::from(n))).map(|v| {
                    let _ = w;
                    v
                });
            }
        }
        "Double" | "CGFloat" | "Float" => match n {
            "infinity" => return Ok(Value::Double(f64::INFINITY)),
            "pi" => return Ok(Value::Double(std::f64::consts::PI)),
            "zero" => return Ok(Value::Double(0.0)),
            _ => {}
        },
        "Int" => match n {
            "max" => return Ok(Value::Int(i64::MAX)),
            "min" => return Ok(Value::Int(i64::MIN)),
            "zero" => return Ok(Value::Int(0)),
            _ => {}
        },
        "Date" if n == "now" => return Ok(Value::Double(it.now)),
        _ => {}
    }
    if BUILTIN_TYPES.contains(&t) {
        return it.implicit(n, span);
    }
    err(span, format!("type '{}' has no member '{}'", t, n))
}

pub fn builtin_static_call(it: &mut Interp, t: &str, n: &str, a: Args, exprs: &[Arg], aspan: Span, span: Span) -> R<Value> {
    // Font.system(...), Color.blue.opacity is a member call on value, Font.custom
    if t == "Font" || t == "Color" || t == "ShapeStyle" || BUILTIN_TYPES.contains(&t) {
        let sym = Value::SymCall(Rc::from(n), Rc::new(a.clone()));
        if t == "Font" {
            if let Some(f) = crate::views::to_font(it, &sym) {
                return Ok(Value::Font(f));
            }
        }
        if let Ok(v) = builtin_static(it, t, n, span) {
            if !matches!(v, Value::Sym(_)) {
                return it.call_value(&v, a, exprs, aspan, span);
            }
        }
        return Ok(sym);
    }
    err(span, format!("type '{}' has no member '{}'", t, n))
}

fn fmt_num(spec: &str, v: &Value) -> String {
    // %d %.1f %02d %@ %s %ld
    let f = v.as_f().unwrap_or(0.0);
    let prec = spec.find('.').and_then(|i| spec[i + 1..].trim_end_matches(|c: char| c.is_alphabetic()).parse::<usize>().ok());
    let width = spec.trim_start_matches('%').split('.').next().unwrap_or("").trim_end_matches(|c: char| c.is_alphabetic());
    let zero = width.starts_with('0');
    let w: usize = width.trim_start_matches('0').parse().unwrap_or(0);
    let body = if spec.ends_with('f') {
        format!("{:.*}", prec.unwrap_or(6), f)
    } else if spec.ends_with('d') || spec.ends_with("ld") || spec.ends_with('i') {
        format!("{}", f as i64)
    } else {
        v.describe()
    };
    if body.len() < w {
        let pad = if zero { "0" } else { " " };
        pad.repeat(w - body.len()) + &body
    } else {
        body
    }
}

pub fn format_string(fmt: &str, args: &[Value]) -> String {
    let mut out = String::new();
    let mut ai = 0;
    let b: Vec<char> = fmt.chars().collect();
    let mut i = 0;
    while i < b.len() {
        if b[i] == '%' && i + 1 < b.len() {
            if b[i + 1] == '%' {
                out.push('%');
                i += 2;
                continue;
            }
            let s = i;
            i += 1;
            while i < b.len() && !b[i].is_alphabetic() && b[i] != '@' {
                i += 1;
            }
            while i < b.len() && b[i] == 'l' {
                i += 1;
            }
            i += 1;
            let spec: String = b[s..i.min(b.len())].iter().collect();
            let v = args.get(ai).cloned().unwrap_or(Value::Nil);
            ai += 1;
            out.push_str(&fmt_num(&spec, &v));
            continue;
        }
        out.push(b[i]);
        i += 1;
    }
    out
}

pub fn builtin_fn(it: &mut Interp, n: &str, a: Args, span: Span) -> R<Value> {
    let vals: Vec<Value> = a.iter().map(|x| x.1.clone()).collect();
    match n {
        "min" | "max" => {
            let mut items = vals.clone();
            if items.len() == 1 {
                items = it.iter_items(&items[0], span)?;
            }
            let mut best: Option<Value> = None;
            for v in items {
                best = Some(match best {
                    None => v,
                    Some(b) => {
                        let o = cmp_values(&v, &b);
                        if (n == "min" && o == std::cmp::Ordering::Less) || (n == "max" && o == std::cmp::Ordering::Greater) {
                            v
                        } else {
                            b
                        }
                    }
                });
            }
            let r = best.unwrap_or(Value::Nil);
            if vals.iter().any(|v| matches!(v, Value::Double(_))) {
                return Ok(r.as_f().map(Value::Double).unwrap_or(r));
            }
            Ok(r)
        }
        "abs" => Ok(match vals.first() {
            Some(Value::Int(i)) => Value::Int(i.abs()),
            Some(v) => Value::Double(v.as_f().unwrap_or(0.0).abs()),
            None => Value::Nil,
        }),
        "round" => Ok(Value::Double(vals.first().and_then(|v| v.as_f()).unwrap_or(0.0).round())),
        "floor" => Ok(Value::Double(vals.first().and_then(|v| v.as_f()).unwrap_or(0.0).floor())),
        "ceil" => Ok(Value::Double(vals.first().and_then(|v| v.as_f()).unwrap_or(0.0).ceil())),
        "sqrt" => Ok(Value::Double(vals.first().and_then(|v| v.as_f()).unwrap_or(0.0).sqrt())),
        "pow" => Ok(Value::Double(vals.first().and_then(|v| v.as_f()).unwrap_or(0.0).powf(vals.get(1).and_then(|v| v.as_f()).unwrap_or(1.0)))),
        "print" => {
            let s: Vec<String> = vals.iter().map(|v| v.describe()).collect();
            it.warnings.push((span, format!("print: {}", s.join(" "))));
            Ok(Value::Nil)
        }
        "withAnimation" => {
            if let Some(f) = vals.iter().rev().find(|v| matches!(v, Value::Fn(_))) {
                let f = f.clone();
                return it.call_fn(&f, vec![], span);
            }
            Ok(Value::Nil)
        }
        "stride" => {
            let from = arg(&a, "from").and_then(|v| v.as_i()).unwrap_or(0);
            let by = arg(&a, "by").and_then(|v| v.as_i()).unwrap_or(1).max(1);
            let (to, incl) = match (arg(&a, "to"), arg(&a, "through")) {
                (Some(t), _) => (t.as_i().unwrap_or(0), false),
                (_, Some(t)) => (t.as_i().unwrap_or(0), true),
                _ => (0, false),
            };
            let mut out = vec![];
            let mut i = from;
            while if incl { i <= to } else { i < to } {
                out.push(Value::Int(i));
                i += by;
                if out.len() > 100000 {
                    break;
                }
            }
            Ok(Value::Array(Rc::new(out)))
        }
        "zip" => {
            let x = it.iter_items(vals.first().unwrap_or(&Value::Nil), span)?;
            let y = it.iter_items(vals.get(1).unwrap_or(&Value::Nil), span)?;
            Ok(Value::Array(Rc::new(x.into_iter().zip(y).map(|(p, q)| Value::Tuple(Rc::new(vec![(None, p), (None, q)]))).collect())))
        }
        "+" => it.binop("+", vals.first().unwrap_or(&Value::Nil), vals.get(1).unwrap_or(&Value::Nil), span),
        "*" => it.binop("*", vals.first().unwrap_or(&Value::Nil), vals.get(1).unwrap_or(&Value::Nil), span),
        "<" => it.binop("<", vals.first().unwrap_or(&Value::Nil), vals.get(1).unwrap_or(&Value::Nil), span),
        ">" => it.binop(">", vals.first().unwrap_or(&Value::Nil), vals.get(1).unwrap_or(&Value::Nil), span),
        _ => err(span, format!("unknown function '{}'", n)),
    }
}

pub fn builtin_method(it: &mut Interp, recv: &Value, n: &str, a: Args, exprs: &[Arg], aspan: Span, span: Span) -> R<Value> {
    let f0 = first(&a).cloned();
    match recv {
        Value::Method(inner, m) => {
            // e.g. value.formatted(...)  where member returned Method; call it
            return builtin_method(it, inner, m, a, exprs, aspan, span).and_then(|v| {
                if n == "callAsFunction" {
                    Ok(v)
                } else {
                    builtin_method(it, &v, n, vec![], exprs, aspan, span)
                }
            });
        }
        Value::Str(s) => {
            let st = s.to_string();
            let sarg = f0.as_ref().map(|v| v.describe()).unwrap_or_default();
            return Ok(match n {
                "uppercased" => Value::s(&st.to_uppercase()),
                "lowercased" => Value::s(&st.to_lowercase()),
                "hasPrefix" => Value::Bool(st.starts_with(&sarg)),
                "hasSuffix" => Value::Bool(st.ends_with(&sarg)),
                "contains" => match &f0 {
                    Some(Value::Fn(_)) => {
                        let f = f0.clone().unwrap();
                        for c in st.chars() {
                            if it.call_fn(&f, vec![Value::s(&c.to_string())], span)?.truthy() {
                                return Ok(Value::Bool(true));
                            }
                        }
                        Value::Bool(false)
                    }
                    _ => Value::Bool(st.contains(&sarg)),
                },
                "localizedCaseInsensitiveContains" | "localizedStandardContains" => Value::Bool(st.to_lowercase().contains(&sarg.to_lowercase())),
                "prefix" => Value::s(&st.chars().take(f0.and_then(|v| v.as_i()).unwrap_or(0).max(0) as usize).collect::<String>()),
                "suffix" => {
                    let k = f0.and_then(|v| v.as_i()).unwrap_or(0).max(0) as usize;
                    let c: Vec<char> = st.chars().collect();
                    Value::s(&c[c.len().saturating_sub(k)..].iter().collect::<String>())
                }
                "dropFirst" => Value::s(&st.chars().skip(f0.and_then(|v| v.as_i()).unwrap_or(1) as usize).collect::<String>()),
                "dropLast" => {
                    let k = f0.and_then(|v| v.as_i()).unwrap_or(1) as usize;
                    let c: Vec<char> = st.chars().collect();
                    Value::s(&c[..c.len().saturating_sub(k)].iter().collect::<String>())
                }
                "split" | "components" => {
                    let sep = arg(&a, "separator").or(arg(&a, "separatedBy")).map(|v| v.describe()).unwrap_or(" ".into());
                    let parts: Vec<Value> = st.split(sep.as_str()).filter(|p| n == "components" || !p.is_empty()).map(Value::s).collect();
                    Value::Array(Rc::new(parts))
                }
                "trimmingCharacters" => Value::s(st.trim()),
                "replacingOccurrences" => {
                    let of = arg(&a, "of").map(|v| v.describe()).unwrap_or_default();
                    let with = arg(&a, "with").map(|v| v.describe()).unwrap_or_default();
                    if of.is_empty() {
                        Value::s(&st)
                    } else {
                        Value::s(&st.replace(&of, &with))
                    }
                }
                "map" | "filter" | "reversed" | "enumerated" | "first" | "compactMap" => {
                    let items = it.iter_items(recv, span)?;
                    let arr = Value::Array(Rc::new(items));
                    let r = builtin_method(it, &arr, n, a, exprs, aspan, span)?;
                    if n == "filter" || n == "reversed" {
                        if let Value::Array(x) = &r {
                            return Ok(Value::s(&x.iter().map(|v| v.describe()).collect::<String>()));
                        }
                    }
                    r
                }
                "isEmpty" => Value::Bool(st.is_empty()),
                "count" => Value::Int(st.chars().count() as i64),
                _ => return err(span, format!("value of type 'String' has no member '{}'", n)),
            });
        }
        Value::Array(_) | Value::Range(..) | Value::Dict(_) => {
            let items = it.iter_items(recv, span)?;
            return array_method(it, recv, items, n, a, span);
        }
        Value::Int(_) | Value::Double(_) => {
            let f = recv.as_f().unwrap_or(0.0);
            return Ok(match n {
                "formatted" => {
                    if let Value::Int(i) = recv {
                        let s = i.abs().to_string();
                        let mut out = String::new();
                        for (k, c) in s.chars().enumerate() {
                            if k > 0 && (s.len() - k) % 3 == 0 {
                                out.push(',');
                            }
                            out.push(c);
                        }
                        Value::s(&format!("{}{}", if *i < 0 { "-" } else { "" }, out))
                    } else {
                        Value::s(&format!("{}", (f * 100.0).round() / 100.0))
                    }
                }
                "isMultiple" => Value::Bool(recv.as_i().unwrap_or(0) % arg(&a, "of").and_then(|v| v.as_i()).unwrap_or(1).max(1) == 0),
                "rounded" => Value::Double(f.round()),
                "description" => Value::s(&recv.describe()),
                "clamped" => Value::Double(f),
                _ => return err(span, format!("value of type '{}' has no member '{}'", recv.type_name(), n)),
            });
        }
        Value::Paint(_) | Value::Sym(_) | Value::SymCall(..) | Value::Font(_) => {
            // color methods
            if let Value::Font(fs) = recv {
                return font_method(*fs, n, &a, span);
            }
            if let Value::Sym(s) = recv {
                if let Some(fs) = FontSpec::named(s) {
                    return font_method(fs, n, &a, span);
                }
            }
            if let Some(p) = crate::views::to_paint(it, recv) {
                match n {
                    "opacity" => return Ok(Value::Paint(Rc::new(p.opacity(f0.and_then(|v| v.as_f()).unwrap_or(1.0))))),
                    "gradient" => {
                        let c = match &p {
                            Paint::Solid(c) => *c,
                            _ => return Ok(Value::Paint(Rc::new(p))),
                        };
                        let lighter = Col { l: lighten(c.l, 0.12), d: lighten(c.d, 0.12) };
                        return Ok(Value::Paint(Rc::new(Paint::Linear(vec![(lighter, 0.0), (c, 1.0)], (0.5, 0.0), (0.5, 1.0)))));
                    }
                    "mix" => return Ok(Value::Paint(Rc::new(p))),
                    _ => {
                        let view = Value::Paint(Rc::new(p));
                        return crate::views::modifier(it, view, n, a, exprs, aspan, span);
                    }
                }
            }
            if let Some(sh) = crate::views::to_shape(it, recv) {
                return crate::views::modifier(it, Value::Shape(sh), n, a, exprs, aspan, span);
            }
            err(span, format!("unknown member '{}' on '{}'", n, recv.describe()))
        }
        Value::Bool(b) if n == "toggled" => Ok(Value::Bool(!b)),
        Value::Nil => Ok(Value::Nil),
        _ => err(span, format!("value of type '{}' has no member '{}'", recv.type_name(), n)),
    }
}

fn lighten(c: [f32; 4], k: f32) -> [f32; 4] {
    [c[0] + (1.0 - c[0]) * k, c[1] + (1.0 - c[1]) * k, c[2] + (1.0 - c[2]) * k, c[3]]
}

fn font_method(mut f: FontSpec, n: &str, a: &Args, span: Span) -> R<Value> {
    match n {
        "bold" => f.weight = 700,
        "italic" => f.italic = true,
        "weight" => {
            if let Some(w) = first(a).and_then(|v| v.sym().map(|s| s.to_string())).and_then(|s| weight_named(&s)) {
                f.weight = w;
            }
        }
        "monospacedDigit" | "smallCaps" | "leading" => {}
        "monospaced" => f.design = 2,
        _ => return err(span, format!("Font has no member '{}'", n)),
    }
    Ok(Value::Font(f))
}

fn array_method(it: &mut Interp, recv: &Value, items: Vec<Value>, n: &str, a: Args, span: Span) -> R<Value> {
    let f0 = first(&a).cloned();
    let arr = |v: Vec<Value>| Value::Array(Rc::new(v));
    Ok(match n {
        "map" | "compactMap" | "flatMap" => {
            let f = f0.ok_or_else(|| RtErr { span, msg: "map needs a closure".into() })?;
            let mut out = vec![];
            for x in items {
                let r = if let Value::KeyPath(kp) = &f {
                    let mut v = x;
                    for p in kp.iter() {
                        v = it.get_member(&v, p, span)?;
                    }
                    v
                } else {
                    it.call_fn(&f, vec![x], span)?
                };
                match (n, r) {
                    ("compactMap", Value::Nil) => {}
                    ("flatMap", Value::Array(inner)) => out.extend(inner.iter().cloned()),
                    (_, r) => out.push(r),
                }
            }
            arr(out)
        }
        "filter" => {
            let f = f0.ok_or_else(|| RtErr { span, msg: "filter needs a closure".into() })?;
            let mut out = vec![];
            for x in items {
                if it.call_fn(&f, vec![x.clone()], span)?.truthy() {
                    out.push(x);
                }
            }
            if let Value::Dict(_) = recv {
                // keep as array of tuples
            }
            arr(out)
        }
        "forEach" => {
            let f = f0.unwrap_or(Value::Nil);
            for x in items {
                it.call_fn(&f, vec![x], span)?;
            }
            Value::Nil
        }
        "first" | "last" | "firstIndex" | "lastIndex" => {
            let f = arg(&a, "where").cloned();
            let of = arg(&a, "of").cloned();
            let idx: Vec<usize> = if n == "first" || n == "firstIndex" { (0..items.len()).collect() } else { (0..items.len()).rev().collect() };
            for i in idx {
                let x = &items[i];
                let hit = match (&f, &of) {
                    (Some(f), _) => it.call_fn(f, vec![x.clone()], span)?.truthy(),
                    (_, Some(o)) => values_eq(x, o),
                    _ => true,
                };
                if hit {
                    return Ok(if n.ends_with("Index") { Value::Int(i as i64) } else { x.clone() });
                }
            }
            Value::Nil
        }
        "contains" => {
            if let Some(f) = arg(&a, "where").cloned().or_else(|| f0.clone().filter(|v| matches!(v, Value::Fn(_)))) {
                for x in items {
                    if it.call_fn(&f, vec![x], span)?.truthy() {
                        return Ok(Value::Bool(true));
                    }
                }
                Value::Bool(false)
            } else {
                let t = f0.unwrap_or(Value::Nil);
                if let Value::Range(lo, hi) = recv {
                    return Ok(Value::Bool(t.as_i().map(|x| x >= *lo && x < *hi).unwrap_or(false)));
                }
                Value::Bool(items.iter().any(|x| values_eq(x, &t)))
            }
        }
        "allSatisfy" => {
            let f = f0.unwrap_or(Value::Nil);
            for x in items {
                if !it.call_fn(&f, vec![x], span)?.truthy() {
                    return Ok(Value::Bool(false));
                }
            }
            Value::Bool(true)
        }
        "count" => {
            let f = arg(&a, "where").cloned().unwrap_or(Value::Nil);
            let mut c = 0;
            for x in items {
                if it.call_fn(&f, vec![x], span)?.truthy() {
                    c += 1;
                }
            }
            Value::Int(c)
        }
        "sorted" => {
            let mut v = items;
            let by = arg(&a, "by").cloned().or(f0);
            if let Some(Value::KeyPath(kp)) = &by {
                let kp = kp.clone();
                let mut keyed = vec![];
                for x in v {
                    let mut k = x.clone();
                    for p in kp.iter() {
                        k = it.get_member(&k, p, span)?;
                    }
                    keyed.push((k, x));
                }
                keyed.sort_by(|p, q| cmp_values(&p.0, &q.0));
                return Ok(arr(keyed.into_iter().map(|x| x.1).collect()));
            }
            sort_values(it, &mut v, by, span)?;
            arr(v)
        }
        "reversed" => {
            let mut v = items;
            v.reverse();
            arr(v)
        }
        "shuffled" => arr(items),
        "prefix" => arr(items.into_iter().take(f0.and_then(|v| v.as_i()).unwrap_or(0).max(0) as usize).collect()),
        "suffix" => {
            let k = f0.and_then(|v| v.as_i()).unwrap_or(0).max(0) as usize;
            let s = items.len().saturating_sub(k);
            arr(items[s..].to_vec())
        }
        "dropFirst" => arr(items.into_iter().skip(f0.and_then(|v| v.as_i()).unwrap_or(1) as usize).collect()),
        "dropLast" => {
            let k = f0.and_then(|v| v.as_i()).unwrap_or(1) as usize;
            let e = items.len().saturating_sub(k);
            arr(items[..e].to_vec())
        }
        "enumerated" => arr(items
            .into_iter()
            .enumerate()
            .map(|(i, x)| Value::Tuple(Rc::new(vec![(Some(Rc::from("offset")), Value::Int(i as i64)), (Some(Rc::from("element")), x)])))
            .collect()),
        "joined" => {
            let sep = arg(&a, "separator").map(|v| v.describe()).unwrap_or_default();
            Value::s(&items.iter().map(|v| v.describe()).collect::<Vec<_>>().join(&sep))
        }
        "reduce" => {
            let mut acc = pos(&a, 0).cloned().unwrap_or(Value::Nil);
            let f = pos(&a, 1).cloned().unwrap_or(Value::Nil);
            for x in items {
                acc = it.call_fn(&f, vec![acc, x], span)?;
            }
            acc
        }
        "min" | "max" => {
            if let Some(by) = arg(&a, "by").cloned() {
                let mut best: Option<Value> = None;
                for x in items {
                    best = Some(match best {
                        None => x,
                        Some(b) => {
                            let less = it.call_fn(&by, vec![x.clone(), b.clone()], span)?.truthy();
                            if (n == "min") == less {
                                x
                            } else {
                                b
                            }
                        }
                    });
                }
                best.unwrap_or(Value::Nil)
            } else {
                builtin_fn(it, n, vec![(None, arr(items))], span)?
            }
        }
        "randomElement" => items.first().cloned().unwrap_or(Value::Nil),
        "index" => {
            let base = pos(&a, 0).and_then(|v| v.as_i()).unwrap_or(0);
            let off = arg(&a, "offsetBy").and_then(|v| v.as_i()).unwrap_or(0);
            Value::Int(base + off)
        }
        _ => return err(span, format!("value of type '{}' has no member '{}'", recv.type_name(), n)),
    })
}
