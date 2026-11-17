use crate::ast::{Arg, ExprK, Span, StrSeg};
use crate::interp::*;
use crate::methods::{arg, format_string, pos};
use crate::value::*;
use std::rc::Rc;

fn vw(k: VK, src: Span) -> Value {
    Value::View(Rc::new(View { k, src }))
}

fn closure_arg(a: &Args, labels: &[&str]) -> Option<Value> {
    for l in labels {
        if let Some(v) = arg(a, l) {
            return Some(v.clone());
        }
    }
    a.iter().rev().find(|x| x.0.is_none() && matches!(x.1, Value::Fn(_))).map(|x| x.1.clone())
}

fn build(it: &mut Interp, f: Option<Value>, span: Span) -> R<Vec<Rc<View>>> {
    let mut out = vec![];
    if let Some(f) = f {
        let v = match &f {
            Value::Fn(c) => {
                let c = c.clone();
                it.call_callable(&c, vec![], span)?
            }
            other => other.clone(),
        };
        it.to_views(&v, &mut out, span)?;
    }
    Ok(out)
}

fn build_one(it: &mut Interp, f: Option<Value>, span: Span) -> R<Rc<View>> {
    let mut v = build(it, f, span)?;
    Ok(match v.len() {
        0 => Rc::new(View { k: VK::Empty, src: span }),
        1 => v.pop().unwrap(),
        _ => Rc::new(View { k: VK::Stack { axis: Axis::V, align: Align::default(), spacing: None, children: v, lazy: false }, src: span }),
    })
}

pub fn align_of(v: Option<&Value>) -> Align {
    let s = v.and_then(|v| v.sym()).unwrap_or("center");
    match s {
        "leading" => Align { h: -1, v: 0 },
        "trailing" => Align { h: 1, v: 0 },
        "top" => Align { h: 0, v: -1 },
        "bottom" => Align { h: 0, v: 1 },
        "topLeading" => Align { h: -1, v: -1 },
        "topTrailing" => Align { h: 1, v: -1 },
        "bottomLeading" => Align { h: -1, v: 1 },
        "bottomTrailing" => Align { h: 1, v: 1 },
        "firstTextBaseline" | "lastTextBaseline" => Align { h: 0, v: 0 },
        _ => Align { h: 0, v: 0 },
    }
}

fn unit_point(v: Option<&Value>, def: (f64, f64)) -> (f64, f64) {
    match v {
        Some(Value::Sym(s)) => match &**s {
            "top" => (0.5, 0.0),
            "bottom" => (0.5, 1.0),
            "leading" => (0.0, 0.5),
            "trailing" => (1.0, 0.5),
            "topLeading" => (0.0, 0.0),
            "topTrailing" => (1.0, 0.0),
            "bottomLeading" => (0.0, 1.0),
            "bottomTrailing" => (1.0, 1.0),
            "center" => (0.5, 0.5),
            _ => def,
        },
        Some(Value::Tuple(t)) => (t.first().and_then(|x| x.1.as_f()).unwrap_or(def.0), t.get(1).and_then(|x| x.1.as_f()).unwrap_or(def.1)),
        _ => def,
    }
}

fn stops(it: &mut Interp, a: &Args) -> Vec<(Col, f64)> {
    let mut out = vec![];
    let src = arg(a, "colors").or(arg(a, "gradient")).or(arg(a, "stops")).cloned();
    match src {
        Some(Value::Array(cols)) => {
            let n = cols.len().max(2) - 1;
            for (i, c) in cols.iter().enumerate() {
                match c {
                    Value::Tuple(t) => {
                        // Gradient.Stop(color:, location:)
                        let col = t.iter().find(|x| x.0.as_deref() == Some("color")).map(|x| x.1.clone()).unwrap_or(Value::Nil);
                        let loc = t.iter().find(|x| x.0.as_deref() == Some("location")).and_then(|x| x.1.as_f()).unwrap_or(i as f64 / n as f64);
                        if let Some(Paint::Solid(c)) = to_paint(it, &col) {
                            out.push((c, loc));
                        }
                    }
                    _ => {
                        if let Some(Paint::Solid(cc)) = to_paint(it, c) {
                            out.push((cc, i as f64 / n as f64));
                        }
                    }
                }
            }
        }
        Some(Value::Paint(p)) => {
            if let Paint::Linear(s, _, _) = &*p {
                out = s.clone();
            }
        }
        _ => {}
    }
    out
}

pub fn to_paint(it: &mut Interp, v: &Value) -> Option<Paint> {
    match v {
        Value::Paint(p) => Some((**p).clone()),
        Value::Sym(s) => {
            if let Some(c) = semantic_color(s) {
                return Some(Paint::Solid(c));
            }
            match &**s {
                "ultraThinMaterial" => Some(Paint::Material(0.55)),
                "thinMaterial" => Some(Paint::Material(0.7)),
                "regularMaterial" | "bar" | "material" => Some(Paint::Material(0.82)),
                "thickMaterial" | "ultraThickMaterial" => Some(Paint::Material(0.92)),
                "tint" => Some(Paint::Tint),
                _ => None,
            }
        }
        Value::SymCall(n, a) => match &**n {
            "linearGradient" => {
                let st = stops(it, a);
                Some(Paint::Linear(st, unit_point(arg(a, "startPoint"), (0.5, 0.0)), unit_point(arg(a, "endPoint"), (0.5, 1.0))))
            }
            "color" => a.first().and_then(|x| to_paint(it, &x.1)),
            _ => None,
        },
        Value::View(vw) => {
            if let VK::Shape { shape: ShapeK::Rect, fill: Some(p), .. } = &vw.k {
                return Some(p.clone());
            }
            None
        }
        Value::Struct(_) | Value::Nil => None,
        _ => None,
    }
}

pub fn to_font(it: &mut Interp, v: &Value) -> Option<FontSpec> {
    let _ = it;
    match v {
        Value::Font(f) => Some(*f),
        Value::Sym(s) => FontSpec::named(s),
        Value::SymCall(n, a) => match &**n {
            "system" => {
                let mut f = FontSpec::body();
                if let Some(Value::Sym(st)) = pos(a, 0) {
                    if let Some(nf) = FontSpec::named(st) {
                        f = nf;
                    }
                }
                if let Some(s) = arg(a, "size").and_then(|v| v.as_f()) {
                    f.size = s;
                }
                if let Some(w) = arg(a, "weight").and_then(|v| v.sym()).and_then(weight_named) {
                    f.weight = w;
                }
                if let Some(d) = arg(a, "design").and_then(|v| v.sym()) {
                    f.design = match d {
                        "rounded" => 1,
                        "monospaced" => 2,
                        "serif" => 3,
                        _ => 0,
                    };
                }
                Some(f)
            }
            "custom" => {
                let mut f = FontSpec::body();
                if let Some(s) = arg(a, "size").and_then(|v| v.as_f()) {
                    f.size = s;
                }
                Some(f)
            }
            _ => None,
        },
        _ => None,
    }
}

pub fn to_shape(it: &mut Interp, v: &Value) -> Option<ShapeK> {
    let _ = it;
    match v {
        Value::Shape(k) => Some(*k),
        Value::Sym(s) => match &**s {
            "circle" => Some(ShapeK::Circle),
            "capsule" => Some(ShapeK::Capsule),
            "rect" | "rectangle" => Some(ShapeK::Rect),
            "ellipse" => Some(ShapeK::Ellipse),
            _ => None,
        },
        Value::SymCall(n, a) if &**n == "rect" || &**n == "capsule" => {
            if &**n == "capsule" {
                return Some(ShapeK::Capsule);
            }
            if let Some(r) = arg(a, "cornerRadius").and_then(|v| v.as_f()) {
                return Some(ShapeK::Round(r));
            }
            let g = |k: &str| arg(a, k).and_then(|v| v.as_f()).unwrap_or(0.0);
            Some(ShapeK::Uneven([g("topLeadingRadius"), g("topTrailingRadius"), g("bottomTrailingRadius"), g("bottomLeadingRadius")]))
        }
        Value::View(vw) => match &vw.k {
            VK::Shape { shape, .. } => Some(*shape),
            _ => None,
        },
        _ => None,
    }
}

fn text_lit(exprs: &[Arg], i: usize) -> Option<Span> {
    let e = exprs.iter().filter(|a| a.label.is_none()).nth(i)?;
    if let ExprK::Str(segs, inner) = &e.value.k {
        if segs.len() <= 1 && segs.iter().all(|s| matches!(s, StrSeg::Lit(_))) {
            return Some(*inner);
        }
    }
    None
}

fn text_view(s: Rc<str>, lit: Option<Span>, span: Span) -> Value {
    vw(VK::Text { s, lit, attrs: vec![] }, span)
}

fn image_view(name: &str, system: bool, span: Span) -> Rc<View> {
    Rc::new(View { k: VK::Image { name: Rc::from(name), system, resizable: false, fit: None, render_orig: false }, src: span })
}

fn shape_view(k: ShapeK, span: Span) -> Value {
    vw(VK::Shape { shape: k, fill: None, stroke: None, inset: 0.0 }, span)
}

pub fn builtin_ctor(it: &mut Interp, t: &str, a: Args, exprs: &[Arg], aspan: Span, span: Span) -> R<Value> {
    let _ = aspan;
    match t {
        "Text" => {
            let v = pos(&a, 0).cloned().or_else(|| arg(&a, "verbatim").cloned()).unwrap_or(Value::s(""));
            let s = match &v {
                Value::Str(s) => s.clone(),
                other => Rc::from(other.describe()),
            };
            Ok(text_view(s, text_lit(exprs, 0), span))
        }
        "Image" => {
            if let Some(n) = arg(&a, "systemName") {
                return Ok(Value::View(image_view(&n.describe(), true, span)));
            }
            let n = pos(&a, 0).map(|v| v.describe()).unwrap_or_default();
            Ok(Value::View(image_view(&n, false, span)))
        }
        "Label" => {
            if let Some(title) = pos(&a, 0).filter(|v| matches!(v, Value::Str(_))) {
                let title = text_view(title.as_str().unwrap(), text_lit(exprs, 0), span);
                let icon = if let Some(n) = arg(&a, "systemImage") {
                    image_view(&n.describe(), true, span)
                } else if let Some(n) = arg(&a, "image") {
                    image_view(&n.describe(), false, span)
                } else {
                    Rc::new(View { k: VK::Empty, src: span })
                };
                let Value::View(tv) = title else { unreachable!() };
                return Ok(vw(VK::Label { title: tv, icon }, span));
            }
            let title = build_one(it, arg(&a, "title").cloned().or_else(|| pos(&a, 0).cloned()), span)?;
            let icon = build_one(it, arg(&a, "icon").cloned(), span)?;
            Ok(vw(VK::Label { title, icon }, span))
        }
        "VStack" | "HStack" | "ZStack" | "LazyVStack" | "LazyHStack" => {
            let axis = match t {
                "VStack" | "LazyVStack" => Axis::V,
                "HStack" | "LazyHStack" => Axis::H,
                _ => Axis::Z,
            };
            let mut align = align_of(arg(&a, "alignment"));
            if axis == Axis::V {
                align.v = 0;
            }
            if axis == Axis::H {
                align.h = 0;
            }
            let spacing = arg(&a, "spacing").and_then(|v| v.as_f());
            let children = build(it, closure_arg(&a, &["content"]), span)?;
            Ok(vw(VK::Stack { axis, align, spacing, children, lazy: t.starts_with("Lazy") }, span))
        }
        "LazyVGrid" => {
            let cols = match arg(&a, "columns") {
                Some(Value::Array(c)) => c.len().max(1),
                _ => 2,
            };
            let spacing = arg(&a, "spacing").and_then(|v| v.as_f()).unwrap_or(8.0);
            let children = build(it, closure_arg(&a, &["content"]), span)?;
            Ok(vw(VK::Grid { cols, spacing, children }, span))
        }
        "GridItem" => Ok(Value::Nil.clone()).map(|_| Value::Int(1)),
        "LabeledContent" => {
            let title = pos(&a, 0).map(|v| v.describe()).unwrap_or_default();
            let val = pos(&a, 1).map(|v| v.describe()).unwrap_or_default();
            let t = Rc::new(View { k: VK::Text { s: Rc::from(title), lit: text_lit(exprs, 0), attrs: vec![] }, src: span });
            let v = Rc::new(View { k: VK::Mod(Rc::new(View { k: VK::Text { s: Rc::from(val), lit: None, attrs: vec![] }, src: span }), Mod::Fg(Paint::Solid(semantic_color("secondary").unwrap())), span), src: span });
            Ok(vw(VK::Stack { axis: Axis::H, align: Align::default(), spacing: None, children: vec![t, Rc::new(View { k: VK::Spacer(0.0), src: span }), v], lazy: false }, span))
        }
        "Group" | "WindowGroup" => {
            let children = build(it, closure_arg(&a, &["content"]), span)?;
            Ok(vw(VK::Group(children), span))
        }
        "ScrollView" => {
            let axis = match pos(&a, 0) {
                Some(Value::Sym(s)) if &**s == "horizontal" => Axis::H,
                Some(Value::Array(x)) if x.iter().any(|v| v.sym() == Some("horizontal")) => Axis::H,
                _ => Axis::V,
            };
            let indicators = arg(&a, "showsIndicators").map(|v| v.truthy()).unwrap_or(true);
            let id = it.new_id(span);
            let children = build(it, closure_arg(&a, &["content"]), span)?;
            let child = if children.len() == 1 {
                children.into_iter().next().unwrap()
            } else {
                Rc::new(View { k: VK::Stack { axis: if axis == Axis::H { Axis::H } else { Axis::V }, align: Align::default(), spacing: None, children, lazy: false }, src: span })
            };
            Ok(vw(VK::Scroll { axis, child, id, indicators }, span))
        }
        "List" | "Form" => {
            let id = it.new_id(span);
            let children = if let Some(data) = pos(&a, 0).filter(|v| !matches!(v, Value::Fn(_))).cloned() {
                for_each(it, &data, arg(&a, "id").cloned(), closure_arg(&a, &["rowContent", "content"]), span)?
            } else {
                build(it, closure_arg(&a, &["content"]), span)?
            };
            Ok(vw(VK::List { children, id, grouped: t == "Form" }, span))
        }
        "Section" => {
            let header = if let Some(Value::Str(s)) = pos(&a, 0) {
                Some(Rc::new(View { k: VK::Text { s: s.clone(), lit: text_lit(exprs, 0), attrs: vec![] }, src: span }))
            } else if let Some(h) = arg(&a, "header").cloned() {
                Some(build_one(it, Some(h), span)?)
            } else {
                None
            };
            let footer = match arg(&a, "footer").cloned() {
                Some(f) => Some(build_one(it, Some(f), span)?),
                None => None,
            };
            let children = build(it, arg(&a, "content").cloned().or_else(|| a.iter().find(|x| x.0.is_none() && matches!(x.1, Value::Fn(_))).map(|x| x.1.clone())), span)?;
            Ok(vw(VK::Section { header, footer, children }, span))
        }
        "ForEach" => {
            let data = pos(&a, 0).cloned().unwrap_or(Value::Nil);
            let children = for_each(it, &data, arg(&a, "id").cloned(), closure_arg(&a, &["content"]), span)?;
            Ok(vw(VK::Group(children), span))
        }
        "Spacer" => Ok(vw(VK::Spacer(arg(&a, "minLength").and_then(|v| v.as_f()).unwrap_or(0.0)), span)),
        "Divider" => Ok(vw(VK::Divider, span)),
        "Rectangle" => Ok(shape_view(ShapeK::Rect, span)),
        "RoundedRectangle" => {
            let r = arg(&a, "cornerRadius").and_then(|v| v.as_f()).unwrap_or(8.0);
            Ok(shape_view(ShapeK::Round(r), span))
        }
        "UnevenRoundedRectangle" => {
            let g = |k: &str| arg(&a, k).and_then(|v| v.as_f()).unwrap_or(0.0);
            Ok(shape_view(ShapeK::Uneven([g("topLeadingRadius"), g("topTrailingRadius"), g("bottomTrailingRadius"), g("bottomLeadingRadius")]), span))
        }
        "Circle" => Ok(shape_view(ShapeK::Circle, span)),
        "Capsule" => Ok(shape_view(ShapeK::Capsule, span)),
        "Ellipse" => Ok(shape_view(ShapeK::Ellipse, span)),
        "Color" | "UIColor" => {
            if let Some(h) = arg(&a, "hex") {
                let op = arg(&a, "opacity").or(arg(&a, "alpha")).and_then(|v| v.as_f()).unwrap_or(1.0);
                let hv = match h {
                    Value::Str(s) => u32::from_str_radix(s.trim_start_matches('#'), 16).unwrap_or(0),
                    _ => h.as_i().unwrap_or(0) as u32,
                };
                return Ok(Value::Paint(Rc::new(Paint::Solid(Col::hex(hv, op)))));
            }
            if let Some(r) = arg(&a, "red") {
                let g = arg(&a, "green").and_then(|v| v.as_f()).unwrap_or(0.0);
                let b = arg(&a, "blue").and_then(|v| v.as_f()).unwrap_or(0.0);
                let o = arg(&a, "opacity").or(arg(&a, "alpha")).and_then(|v| v.as_f()).unwrap_or(1.0);
                return Ok(Value::Paint(Rc::new(Paint::Solid(Col::rgb(r.as_f().unwrap_or(0.0), g, b, o)))));
            }
            if let Some(w) = arg(&a, "white") {
                let o = arg(&a, "opacity").and_then(|v| v.as_f()).unwrap_or(1.0);
                let w = w.as_f().unwrap_or(0.0);
                return Ok(Value::Paint(Rc::new(Paint::Solid(Col::rgb(w, w, w, o)))));
            }
            if let Some(h) = arg(&a, "hue") {
                let s = arg(&a, "saturation").and_then(|v| v.as_f()).unwrap_or(1.0);
                let b = arg(&a, "brightness").and_then(|v| v.as_f()).unwrap_or(1.0);
                let (r, g, bb) = hsb(h.as_f().unwrap_or(0.0), s, b);
                return Ok(Value::Paint(Rc::new(Paint::Solid(Col::rgb(r, g, bb, 1.0)))));
            }
            let x = arg(&a, "uiColor").or(pos(&a, 0)).cloned().unwrap_or(Value::Nil);
            if let Some(p) = to_paint(it, &x) {
                return Ok(Value::Paint(Rc::new(p)));
            }
            Ok(Value::Paint(Rc::new(Paint::Solid(Col::hex(0x8E8E93, 1.0)))))
        }
        "LinearGradient" | "Gradient" => {
            let st = stops(it, &a);
            Ok(Value::Paint(Rc::new(Paint::Linear(st, unit_point(arg(&a, "startPoint"), (0.5, 0.0)), unit_point(arg(&a, "endPoint"), (0.5, 1.0))))))
        }
        "RadialGradient" => {
            let st = stops(it, &a);
            let r0 = arg(&a, "startRadius").and_then(|v| v.as_f()).unwrap_or(0.0);
            let r1 = arg(&a, "endRadius").and_then(|v| v.as_f()).unwrap_or(200.0);
            Ok(Value::Paint(Rc::new(Paint::Radial(st, r0, r1))))
        }
        "Button" => {
            let destructive = arg(&a, "role").and_then(|v| v.sym()) == Some("destructive");
            let action = arg(&a, "action").cloned();
            if let Some(Value::Str(title)) = pos(&a, 0) {
                let tv = Rc::new(View { k: VK::Text { s: title.clone(), lit: text_lit(exprs, 0), attrs: vec![] }, src: span });
                let label = if let Some(img) = arg(&a, "systemImage") {
                    Rc::new(View { k: VK::Label { title: tv, icon: image_view(&img.describe(), true, span) }, src: span })
                } else {
                    tv
                };
                let act = action.or_else(|| closure_arg(&a, &[])).unwrap_or(Value::Nil);
                return Ok(vw(VK::Button { action: act, label, role_destructive: destructive }, span));
            }
            let fns: Vec<Value> = a.iter().filter(|x| x.0.is_none() && matches!(x.1, Value::Fn(_))).map(|x| x.1.clone()).collect();
            let (act, lab) = match (action, arg(&a, "label").cloned()) {
                (Some(ac), Some(l)) => (ac, Some(l)),
                (Some(ac), None) => (ac, fns.first().cloned()),
                (None, Some(l)) => (fns.first().cloned().unwrap_or(Value::Nil), Some(l)),
                (None, None) => (fns.first().cloned().unwrap_or(Value::Nil), fns.get(1).cloned()),
            };
            let label = build_one(it, lab, span)?;
            Ok(vw(VK::Button { action: act, label, role_destructive: destructive }, span))
        }
        "NavigationStack" | "NavigationView" | "NavigationSplitView" => {
            let id = it.new_id(span);
            it.nav.push(id.clone());
            let root = build_one(it, closure_arg(&a, &["root", "content", "detail"]), span);
            it.nav.pop();
            Ok(vw(VK::NavStack { root: root?, id }, span))
        }
        "NavigationLink" => {
            let dest = arg(&a, "destination").cloned().unwrap_or(Value::Nil);
            if let Some(Value::Str(title)) = pos(&a, 0) {
                let label = Rc::new(View { k: VK::Text { s: title.clone(), lit: text_lit(exprs, 0), attrs: vec![] }, src: span });
                let dest = if matches!(dest, Value::Nil) { closure_arg(&a, &[]).unwrap_or(Value::Nil) } else { dest };
                return Ok(vw(VK::NavLink { dest, label }, span));
            }
            let fns: Vec<Value> = a.iter().filter(|x| x.0.is_none() && matches!(x.1, Value::Fn(_))).map(|x| x.1.clone()).collect();
            let (dest, lab) = if !matches!(dest, Value::Nil) {
                (dest, arg(&a, "label").cloned().or(fns.first().cloned()))
            } else {
                (fns.first().cloned().unwrap_or(Value::Nil), arg(&a, "label").cloned())
            };
            let label = build_one(it, lab, span)?;
            Ok(vw(VK::NavLink { dest, label }, span))
        }
        "TabView" => {
            let id = it.new_id(span);
            let tabs = build(it, closure_arg(&a, &["content"]), span)?;
            Ok(vw(VK::Tabs { tabs, selection: arg(&a, "selection").cloned(), id }, span))
        }
        "Tab" => {
            let title = pos(&a, 0).map(|v| v.describe()).unwrap_or_default();
            let content = build_one(it, closure_arg(&a, &["content"]), span)?;
            let mut v = content;
            let icon = arg(&a, "systemImage").map(|v| v.describe()).unwrap_or_default();
            let item = Rc::new(View {
                k: VK::Label { title: Rc::new(View { k: VK::Text { s: Rc::from(title), lit: text_lit(exprs, 0), attrs: vec![] }, src: span }), icon: image_view(&icon, true, span) },
                src: span,
            });
            v = Rc::new(View { k: VK::Mod(v, Mod::TabItem(item), span), src: span });
            if let Some(val) = arg(&a, "value") {
                v = Rc::new(View { k: VK::Mod(v, Mod::Tag(val.clone()), span), src: span });
            }
            if arg(&a, "role").and_then(|v| v.sym()) == Some("search") {
                v = Rc::new(View { k: VK::Mod(v, Mod::Tag(Value::Sym(Rc::from("__search"))), span), src: span });
            }
            Ok(Value::View(v))
        }
        "TextField" | "SecureField" | "TextEditor" => {
            let placeholder = pos(&a, 0).map(|v| v.describe()).unwrap_or_default();
            let binding = arg(&a, "text").cloned().unwrap_or(Value::Nil);
            let multiline = arg(&a, "axis").and_then(|v| v.sym()) == Some("vertical") || t == "TextEditor";
            let id = it.new_id(span);
            Ok(vw(VK::TextField { placeholder: Rc::from(placeholder), binding, id, secure: t == "SecureField", multiline }, span))
        }
        "Toggle" => {
            let binding = arg(&a, "isOn").cloned().unwrap_or(Value::Nil);
            let label = if let Some(Value::Str(s)) = pos(&a, 0) {
                Rc::new(View { k: VK::Text { s: s.clone(), lit: text_lit(exprs, 0), attrs: vec![] }, src: span })
            } else {
                build_one(it, closure_arg(&a, &["label"]), span)?
            };
            Ok(vw(VK::Toggle { binding, label }, span))
        }
        "ProgressView" => Ok(vw(VK::Shape { shape: ShapeK::Circle, fill: None, stroke: Some((Paint::Solid(semantic_color("systemGray3").unwrap()), 2.5)), inset: 0.0 }, span)),
        "EmptyView" => Ok(vw(VK::Empty, span)),
        "AnyView" => {
            let v = pos(&a, 0).cloned().unwrap_or(Value::Nil);
            Ok(Value::View(it.to_view(&v, span)?))
        }
        "ContentUnavailableView" => {
            let title = pos(&a, 0).map(|v| v.describe()).unwrap_or_default();
            let icon = arg(&a, "systemImage").map(|v| v.describe()).unwrap_or_default();
            let ch = vec![
                Rc::new(View { k: VK::Mod(image_view(&icon, true, span), Mod::Font(FontSpec { size: 44.0, weight: 400, italic: false, design: 0 }), span), src: span }),
                Rc::new(View { k: VK::Mod(Rc::new(View { k: VK::Text { s: Rc::from(title), lit: None, attrs: vec![] }, src: span }), Mod::Font(FontSpec::named("title2").unwrap()), span), src: span }),
            ];
            Ok(vw(VK::Stack { axis: Axis::V, align: Align::default(), spacing: Some(12.0), children: ch, lazy: false }, span))
        }
        "ToolbarItem" | "ToolbarItemGroup" => {
            let pl = arg(&a, "placement").and_then(|v| v.sym()).unwrap_or("automatic").to_string();
            let mut children = build(it, closure_arg(&a, &["content"]), span)?;
            let content = if children.len() == 1 {
                children.pop().unwrap()
            } else {
                Rc::new(View { k: VK::Stack { axis: Axis::H, align: Align::default(), spacing: Some(16.0), children, lazy: false }, src: span })
            };
            Ok(vw(VK::Mod(content, Mod::Tag(Value::Sym(Rc::from(format!("toolbar:{}", pl)))), span), span))
        }
        "GeometryReader" => {
            let proxy = Value::Tuple(Rc::new(vec![(Some(Rc::from("size")), Value::Tuple(Rc::new(vec![(Some(Rc::from("width")), Value::Double(390.0)), (Some(Rc::from("height")), Value::Double(800.0))])))]));
            let f = closure_arg(&a, &["content"]).unwrap_or(Value::Nil);
            let r = it.call_fn(&f, vec![proxy], span)?;
            Ok(Value::View(it.to_view(&r, span)?))
        }
        "Menu" | "Picker" => {
            let label = if let Some(Value::Str(s)) = pos(&a, 0) {
                Rc::new(View { k: VK::Text { s: s.clone(), lit: text_lit(exprs, 0), attrs: vec![] }, src: span })
            } else {
                build_one(it, arg(&a, "label").cloned(), span)?
            };
            Ok(vw(VK::Button { action: Value::Nil, label, role_destructive: false }, span))
        }
        // ---- non-view builtins ----
        "String" => {
            if let Some(f) = arg(&a, "format") {
                let rest: Vec<Value> = a.iter().filter(|x| x.0.is_none()).map(|x| x.1.clone()).collect();
                return Ok(Value::s(&format_string(&f.describe(), &rest)));
            }
            if let Some(Value::Str(s)) = arg(&a, "repeating") {
                let n = arg(&a, "count").and_then(|v| v.as_i()).unwrap_or(0).max(0) as usize;
                return Ok(Value::s(&s.repeat(n)));
            }
            if let Some(Value::Array(items)) = a.first().map(|x| &x.1) {
                return Ok(Value::s(&items.iter().map(|v| v.describe()).collect::<String>()));
            }
            Ok(Value::s(&a.first().map(|x| x.1.describe()).unwrap_or_default()))
        }
        "Int" => Ok(match a.first().map(|x| &x.1) {
            Some(Value::Str(s)) => s.trim().parse::<i64>().map(Value::Int).unwrap_or(Value::Nil),
            Some(v) => Value::Int(v.as_f().unwrap_or(0.0) as i64),
            None => Value::Int(0),
        }),
        "Double" | "CGFloat" | "Float" => Ok(match a.first().map(|x| &x.1) {
            Some(Value::Str(s)) => s.trim().parse::<f64>().map(Value::Double).unwrap_or(Value::Nil),
            Some(v) => Value::Double(v.as_f().unwrap_or(0.0)),
            None => Value::Double(0.0),
        }),
        "Bool" => Ok(Value::Bool(a.first().map(|x| x.1.truthy()).unwrap_or(false))),
        "UUID" => {
            it.uuid += 1;
            Ok(Value::s(&format!("uuid-{}", it.uuid)))
        }
        "Date" => Ok(Value::Double(it.now)),
        "State" => Ok(arg(&a, "initialValue").or(arg(&a, "wrappedValue")).cloned().unwrap_or(Value::Nil)),
        "Array" | "Set" => Ok(match a.first().map(|x| x.1.clone()) {
            Some(v) => Value::Array(Rc::new(it.iter_items(&v, span)?)),
            None => Value::Array(Rc::new(vec![])),
        }),
        "Dictionary" => Ok(Value::Dict(Rc::new(vec![]))),
        "Character" => Ok(a.first().map(|x| x.1.clone()).unwrap_or(Value::s(""))),
        "EdgeInsets" => Ok(Value::Tuple(Rc::new(a))),
        "UnitPoint" | "CGSize" | "CGPoint" => Ok(Value::Tuple(Rc::new(a))),
        "Font" => Ok(Value::Font(FontSpec::body())),
        "Angle" => Ok(arg(&a, "degrees").cloned().unwrap_or(Value::Double(0.0))),
        "PlainButtonStyle" | "BorderlessButtonStyle" => Ok(Value::Sym(Rc::from("plain"))),
        _ => err(span, format!("'{}' is not supported in the browser runtime yet", t)),
    }
}

fn hsb(h: f64, s: f64, v: f64) -> (f64, f64, f64) {
    let i = (h * 6.0).floor();
    let f = h * 6.0 - i;
    let p = v * (1.0 - s);
    let q = v * (1.0 - f * s);
    let t = v * (1.0 - (1.0 - f) * s);
    match (i as i64).rem_euclid(6) {
        0 => (v, t, p),
        1 => (q, v, p),
        2 => (p, v, t),
        3 => (p, q, v),
        4 => (t, p, v),
        _ => (v, p, q),
    }
}

pub fn for_each(it: &mut Interp, data: &Value, id: Option<Value>, f: Option<Value>, span: Span) -> R<Vec<Rc<View>>> {
    let items = it.iter_items(data, span)?;
    let f = f.unwrap_or(Value::Nil);
    let mut out = vec![];
    for (i, item) in items.into_iter().enumerate() {
        let key = match &id {
            Some(Value::KeyPath(kp)) => {
                let mut v = item.clone();
                for p in kp.iter() {
                    v = it.get_member(&v, p, span)?;
                }
                v.describe()
            }
            _ => match &item {
                Value::Struct(s) => s.fields.iter().find(|x| &*x.0 == "id").map(|x| x.1.describe()).unwrap_or_else(|| i.to_string()),
                Value::Enum(_, c, _) => c.to_string(),
                Value::Int(n) => n.to_string(),
                Value::Str(s) => s.to_string(),
                _ => i.to_string(),
            },
        };
        let parent = it.idpath.last().cloned().unwrap_or_else(|| Rc::from(""));
        it.idpath.push(Rc::from(format!("{}[{}:{}]", parent, span.s, key)));
        let r = it.call_fn(&f, vec![item], span);
        let r = r.and_then(|v| it.to_views(&v, &mut out, span));
        it.idpath.pop();
        r?;
    }
    Ok(out)
}

fn edges_of(v: Option<&Value>) -> (bool, bool, bool, bool) {
    // returns (top, leading, bottom, trailing)
    let one = |s: &str| match s {
        "all" => (true, true, true, true),
        "horizontal" => (false, true, false, true),
        "vertical" => (true, false, true, false),
        "top" => (true, false, false, false),
        "bottom" => (false, false, true, false),
        "leading" => (false, true, false, false),
        "trailing" => (false, false, false, true),
        _ => (true, true, true, true),
    };
    match v {
        Some(Value::Sym(s)) => one(s),
        Some(Value::Array(a)) => {
            let mut r = (false, false, false, false);
            for x in a.iter() {
                if let Some(s) = x.sym() {
                    let o = one(s);
                    r = (r.0 || o.0, r.1 || o.1, r.2 || o.2, r.3 || o.3);
                }
            }
            r
        }
        _ => (true, true, true, true),
    }
}

fn wrap(child: Rc<View>, m: Mod, mspan: Span) -> Value {
    let src = child.src;
    let _ = src;
    Value::View(Rc::new(View { k: VK::Mod(child, m, mspan), src: mspan }))
}

pub fn modifier(it: &mut Interp, recv: Value, n: &str, a: Args, exprs: &[Arg], aspan: Span, span: Span) -> R<Value> {
    // user View extensions take priority
    if let Some(f) = it.view_ext.get(n).cloned() {
        return it.call_func(&f, Some(recv), a, span);
    }
    let mspan = aspan;
    let _ = exprs;
    // shape-specific modifiers keep the shape
    if let Value::Shape(k) = &recv {
        let v = vw(VK::Shape { shape: *k, fill: None, stroke: None, inset: 0.0 }, span);
        return modifier(it, v, n, a, exprs, aspan, span);
    }
    if let Value::Paint(p) = &recv {
        let v = vw(VK::Shape { shape: ShapeK::Rect, fill: Some((**p).clone()), stroke: None, inset: 0.0 }, span);
        return modifier(it, v, n, a, exprs, aspan, span);
    }
    let child = it.to_view(&recv, span)?;
    let f0 = a.first().map(|x| x.1.clone());
    // rebuild leaf views for intrinsic modifiers
    match (&child.k, n) {
        (VK::Shape { shape, fill, stroke, inset }, "fill" | "foregroundStyle" | "foregroundColor") if !matches!(n, "foregroundStyle" | "foregroundColor") || fill.is_none() => {
            let p = f0.as_ref().and_then(|v| to_paint(it, v)).or(fill.clone());
            return Ok(vw(VK::Shape { shape: *shape, fill: p, stroke: stroke.clone(), inset: *inset }, child.src));
        }
        (VK::Shape { shape, fill, .. }, "stroke" | "strokeBorder") => {
            let p = f0.as_ref().and_then(|v| to_paint(it, v)).unwrap_or(Paint::Solid(semantic_color("primary").unwrap()));
            let w = arg(&a, "lineWidth").and_then(|v| v.as_f()).or_else(|| arg(&a, "style").and_then(|v| match v {
                Value::SymCall(_, sa) => arg(sa, "lineWidth").and_then(|v| v.as_f()),
                _ => None,
            })).unwrap_or(1.0);
            let _ = fill;
            return Ok(vw(VK::Shape { shape: *shape, fill: Some(Paint::Solid(Col::hex(0, 0.0))), stroke: Some((p, w)), inset: if n == "strokeBorder" { w / 2.0 } else { 0.0 } }, child.src));
        }
        (VK::Image { name, system, fit, render_orig, .. }, "resizable") => {
            let tile = arg(&a, "resizingMode").and_then(|v| v.sym()) == Some("tile");
            let fit = if tile { Some(false) } else { *fit };
            return Ok(vw(VK::Image { name: name.clone(), system: *system, resizable: true, fit, render_orig: tile || *render_orig }, child.src));
        }
        (VK::Image { name, system, resizable, render_orig, .. }, "scaledToFit" | "scaledToFill" | "aspectRatio") => {
            let fit = if n == "aspectRatio" { arg(&a, "contentMode").and_then(|v| v.sym()).map(|s| s == "fit") } else { Some(n == "scaledToFit") };
            return Ok(vw(VK::Image { name: name.clone(), system: *system, resizable: *resizable, fit, render_orig: *render_orig }, child.src));
        }
        (VK::List { children, id, .. }, "listStyle") => {
            let g = f0.as_ref().and_then(|v| v.sym()).map(|s| s == "insetGrouped" || s == "grouped").unwrap_or(false);
            return Ok(vw(VK::List { children: children.clone(), id: id.clone(), grouped: g }, child.src));
        }
        _ => {}
    }
    let num = |i: usize| a.iter().filter(|x| x.0.is_none()).nth(i).and_then(|x| x.1.as_f());
    let m = match n {
        "padding" => {
            if let Some(Value::Tuple(t)) = &f0 {
                let g = |k: &str| t.iter().find(|x| x.0.as_deref() == Some(k)).and_then(|x| x.1.as_f()).unwrap_or(0.0);
                Mod::Padding(Edges { t: g("top"), l: g("leading"), b: g("bottom"), r: g("trailing") })
            } else {
                let edge_arg = a.iter().find(|x| x.0.is_none() && matches!(x.1, Value::Sym(_) | Value::Array(_))).map(|x| &x.1);
                let amount = a.iter().filter(|x| x.0.is_none()).find_map(|x| x.1.as_f()).unwrap_or(16.0);
                let (t, l, b, r) = edges_of(edge_arg);
                let z = |on: bool| if on { amount } else { 0.0 };
                Mod::Padding(Edges { t: z(t), l: z(l), b: z(b), r: z(r) })
            }
        }
        "frame" => {
            let g = |k: &str| arg(&a, k).and_then(|v| v.as_f());
            let align = align_of(arg(&a, "alignment"));
            if ["minWidth", "maxWidth", "minHeight", "maxHeight", "idealWidth", "idealHeight"].iter().any(|k| arg(&a, k).is_some()) {
                Mod::FlexFrame { min_w: g("minWidth"), max_w: g("maxWidth"), min_h: g("minHeight"), max_h: g("maxHeight"), ideal_w: g("idealWidth"), ideal_h: g("idealHeight"), align }
            } else {
                Mod::Frame { w: g("width"), h: g("height"), align }
            }
        }
        "background" | "overlay" => {
            let align = align_of(arg(&a, "alignment"));
            let mut is_style = false;
            let content: Rc<View> = if let Some(c) = arg(&a, "content").cloned() {
                build_one(it, Some(c), span)?
            } else if let Some(v) = f0.clone() {
                match &v {
                    Value::Fn(_) => build_one(it, Some(v), span)?,
                    Value::Struct(_) | Value::View(_) | Value::Views(_) => it.to_view(&v, span)?,
                    _ => {
                        let p = to_paint(it, &v);
                        match p {
                            Some(p) => {
                                is_style = true;
                                let shape = arg(&a, "in").and_then(|s| to_shape(it, s)).unwrap_or(ShapeK::Rect);
                                if arg(&a, "in").is_some() {
                                    is_style = false;
                                }
                                Rc::new(View { k: VK::Shape { shape, fill: Some(p), stroke: None, inset: 0.0 }, src: span })
                            }
                            None => match to_shape(it, &v) {
                                Some(sh) => Rc::new(View { k: VK::Shape { shape: sh, fill: None, stroke: None, inset: 0.0 }, src: span }),
                                None => it.to_view(&v, span)?,
                            },
                        }
                    }
                }
            } else {
                // .background() with no args = default system background
                is_style = true;
                Rc::new(View { k: VK::Shape { shape: ShapeK::Rect, fill: Some(Paint::Solid(semantic_color("systemBackground").unwrap())), stroke: None, inset: 0.0 }, src: span })
            };
            if n == "background" {
                Mod::Background(content, align, is_style)
            } else {
                Mod::Overlay(content, align)
            }
        }
        "safeAreaInset" => {
            let edge = arg(&a, "edge").and_then(|v| v.sym()).unwrap_or("bottom").to_string();
            let content = build_one(it, closure_arg(&a, &["content"]), span)?;
            Mod::Inset(edge == "top", content)
        }
        "font" => match f0.as_ref().and_then(|v| to_font(it, v)) {
            Some(f) => Mod::Font(f),
            None => Mod::Ignored,
        },
        "fontWeight" => Mod::FontWeight(f0.as_ref().and_then(|v| v.sym()).and_then(weight_named).unwrap_or(400)),
        "bold" => {
            if f0.as_ref().map(|v| matches!(v, Value::Bool(false))).unwrap_or(false) {
                Mod::Ignored
            } else {
                Mod::FontWeight(700)
            }
        }
        "italic" => Mod::Italic,
        "fontDesign" => Mod::Design(match f0.as_ref().and_then(|v| v.sym()) {
            Some("rounded") => 1,
            Some("monospaced") => 2,
            Some("serif") => 3,
            _ => 0,
        }),
        "monospaced" => Mod::Design(2),
        "imageScale" => Mod::FontSize(match f0.as_ref().and_then(|v| v.sym()) {
            Some("large") => 1.3,
            Some("small") => 0.8,
            _ => 1.0,
        }),
        "foregroundColor" | "foregroundStyle" => match f0.as_ref().and_then(|v| to_paint(it, v)) {
            Some(p) => Mod::Fg(p),
            None => Mod::Ignored,
        },
        "tint" | "accentColor" => match f0.as_ref().and_then(|v| to_paint(it, v)) {
            Some(p) => Mod::Tint(p),
            None => Mod::Ignored,
        },
        "clipShape" | "mask" => match f0.as_ref().and_then(|v| to_shape(it, v)) {
            Some(s) => Mod::Clip(s),
            None => Mod::Ignored,
        },
        "cornerRadius" => Mod::Clip(ShapeK::Round(num(0).unwrap_or(0.0))),
        "clipped" => Mod::Clip(ShapeK::Rect),
        "opacity" => Mod::Opacity(num(0).unwrap_or(1.0)),
        "offset" => Mod::Offset(arg(&a, "x").and_then(|v| v.as_f()).unwrap_or(0.0), arg(&a, "y").and_then(|v| v.as_f()).unwrap_or(0.0)),
        "shadow" => {
            let c = arg(&a, "color").and_then(|v| to_paint(it, v)).and_then(|p| if let Paint::Solid(c) = p { Some(c) } else { None }).unwrap_or(Col::hex(0, 0.33));
            Mod::Shadow(c, arg(&a, "radius").and_then(|v| v.as_f()).unwrap_or(4.0), arg(&a, "x").and_then(|v| v.as_f()).unwrap_or(0.0), arg(&a, "y").and_then(|v| v.as_f()).unwrap_or(0.0))
        }
        "onTapGesture" => Mod::OnTap(a.iter().rev().find(|x| matches!(x.1, Value::Fn(_))).map(|x| x.1.clone()).unwrap_or(Value::Nil)),
        "onSubmit" => Mod::OnSubmit(a.iter().rev().find(|x| matches!(x.1, Value::Fn(_))).map(|x| x.1.clone()).unwrap_or(Value::Nil)),
        "ignoresSafeArea" | "edgesIgnoringSafeArea" => Mod::IgnoresSafeArea,
        "lineLimit" => Mod::LineLimit(f0.as_ref().and_then(|v| v.as_i()).map(|x| x.max(1) as u32)),
        "multilineTextAlignment" => Mod::TextAlign(match f0.as_ref().and_then(|v| v.sym()) {
            Some("center") => 0,
            Some("trailing") => 1,
            _ => -1,
        }),
        "preferredColorScheme" => match f0.as_ref().and_then(|v| v.sym()) {
            Some("dark") => Mod::Scheme(true),
            Some("light") => Mod::Scheme(false),
            _ => Mod::Ignored,
        },
        "environment" => {
            if let (Some(Value::KeyPath(kp)), Some(v)) = (a.first().map(|x| &x.1), a.get(1).map(|x| &x.1)) {
                if kp.first().map(|s| &**s) == Some("colorScheme") {
                    Mod::Scheme(v.sym() == Some("dark"))
                } else {
                    Mod::Ignored
                }
            } else {
                Mod::Ignored
            }
        }
        "tabItem" => Mod::TabItem(build_one(it, f0.clone(), span)?),
        "badge" => Mod::Badge(f0.clone().unwrap_or(Value::Nil)),
        "tag" => Mod::Tag(f0.clone().unwrap_or(Value::Nil)),
        "navigationTitle" | "navigationBarTitle" => Mod::NavTitle(Rc::from(f0.as_ref().map(|v| v.describe()).unwrap_or_default())),
        "navigationBarTitleDisplayMode" => Mod::NavTitleInline(f0.as_ref().and_then(|v| v.sym()) != Some("large")),
        "toolbar" => {
            if let Some(Value::Sym(s)) = &f0 {
                if &**s == "hidden" {
                    let which = a.iter().find(|x| x.0.as_deref() == Some("for")).and_then(|x| x.1.sym()).unwrap_or("navigationBar");
                    if which == "tabBar" {
                        Mod::Tag(Value::Sym(Rc::from("__tabbar_hidden")))
                    } else {
                        Mod::BarHidden(true)
                    }
                } else {
                    Mod::Ignored
                }
            } else if let Some(c) = closure_arg(&a, &["content"]) {
                let items = build(it, Some(c), span)?;
                let mut out = vec![];
                for v in items {
                    let (pl, inner) = match &v.k {
                        VK::Mod(inner, Mod::Tag(Value::Sym(s)), _) if s.starts_with("toolbar:") => {
                            let p = match &s[8..] {
                                "topBarLeading" | "navigationBarLeading" | "cancellationAction" => -1,
                                "principal" => 0,
                                "bottomBar" => 2,
                                _ => 1,
                            };
                            (p, inner.clone())
                        }
                        _ => (1, v.clone()),
                    };
                    out.push((pl, inner));
                }
                Mod::Toolbar(out)
            } else {
                Mod::Ignored
            }
        }
        "navigationBarHidden" => Mod::BarHidden(f0.as_ref().map(|v| v.truthy()).unwrap_or(true)),
        "navigationBarBackButtonHidden" => Mod::BackHidden,
        "fixedSize" => {
            if a.is_empty() {
                Mod::FixedSize(true, true)
            } else {
                Mod::FixedSize(arg(&a, "horizontal").map(|v| v.truthy()).unwrap_or(false), arg(&a, "vertical").map(|v| v.truthy()).unwrap_or(false))
            }
        }
        "layoutPriority" => Mod::LayoutPriority(num(0).unwrap_or(0.0)),
        "defaultScrollAnchor" => {
            if f0.as_ref().and_then(|v| v.sym()) == Some("bottom") {
                Mod::ScrollBottom
            } else {
                Mod::Ignored
            }
        }
        "border" => {
            let p = f0.as_ref().and_then(|v| to_paint(it, v)).unwrap_or(Paint::Solid(semantic_color("primary").unwrap()));
            Mod::Border(p, arg(&a, "width").and_then(|v| v.as_f()).unwrap_or(1.0))
        }
        "buttonStyle" => match f0.as_ref().and_then(|v| v.sym()) {
            Some("plain") | Some("borderless") => Mod::PlainButton,
            _ => Mod::Ignored,
        },
        "strikethrough" | "underline" if f0.as_ref().map(|v| matches!(v, Value::Bool(false))).unwrap_or(false) => Mod::Ignored,
        "strikethrough" => Mod::Strikethrough,
        "underline" => Mod::Underline,
        "textCase" => Mod::TextCase(f0.as_ref().and_then(|v| v.sym()) == Some("uppercase")),
        "kerning" | "tracking" => Mod::Kerning(num(0).unwrap_or(0.0)),
        "hidden" => Mod::Hidden,
        "disabled" => Mod::Disabled(f0.as_ref().map(|v| v.truthy()).unwrap_or(true)),
        "rotationEffect" => Mod::Rotation(f0.as_ref().and_then(|v| match v {
            Value::SymCall(n, sa) if &**n == "degrees" => sa.first().and_then(|x| x.1.as_f()),
            Value::SymCall(n, sa) if &**n == "radians" => sa.first().and_then(|x| x.1.as_f()).map(|r| r.to_degrees()),
            other => other.as_f(),
        }).unwrap_or(0.0)),
        "scaleEffect" => Mod::Scale(num(0).unwrap_or(1.0)),
        "blur" => Mod::Blur(arg(&a, "radius").and_then(|v| v.as_f()).unwrap_or(0.0)),
        "listRowSeparator" => Mod::ListRowSeparator(f0.as_ref().and_then(|v| v.sym()) != Some("hidden")),
        "listRowInsets" => Mod::ListRowInsets(match &f0 {
            Some(Value::Tuple(t)) => {
                let g = |k: &str| t.iter().find(|x| x.0.as_deref() == Some(k)).and_then(|x| x.1.as_f()).unwrap_or(0.0);
                Some(Edges { t: g("top"), l: g("leading"), b: g("bottom"), r: g("trailing") })
            }
            _ => None,
        }),
        "listRowBackground" => match &f0 {
            Some(v) => {
                let view = match to_paint(it, v) {
                    Some(p) => Rc::new(View { k: VK::Shape { shape: ShapeK::Rect, fill: Some(p), stroke: None, inset: 0.0 }, src: span }),
                    None => it.to_view(v, span)?,
                };
                Mod::ListRowBackground(view)
            }
            None => Mod::Ignored,
        },
        "symbolRenderingMode" | "symbolVariant" | "renderingMode" | "contentShape" | "animation" | "transition" | "id"
        | "accessibilityLabel" | "accessibilityHidden" | "accessibilityElement" | "controlSize" | "textSelection"
        | "keyboardType" | "autocorrectionDisabled" | "textInputAutocapitalization" | "submitLabel" | "focused" | "sheet"
        | "fullScreenCover" | "alert" | "confirmationDialog" | "searchable" | "refreshable" | "swipeActions" | "contextMenu"
        | "scrollDismissesKeyboard" | "scrollIndicators" | "presentationDetents" | "onAppear" | "onDisappear" | "task"
        | "onChange" | "toolbarBackground" | "toolbarColorScheme" | "scrollContentBackground" | "listStyle" | "navigationDestination"
        | "minimumScaleFactor" | "truncationMode" | "lineSpacing" | "allowsTightening" | "monospacedDigit" | "onLongPressGesture"
        | "gesture" | "simultaneousGesture" | "highPriorityGesture" | "zIndex" | "drawingGroup" | "compositingGroup" | "labelStyle"
        | "pickerStyle" | "toggleStyle" | "textFieldStyle" | "headerProspective" | "tabViewStyle" | "listSectionSeparator"
        | "scrollTargetBehavior" | "scrollTargetLayout" | "contentTransition" | "sensoryFeedback" | "symbolEffect"
        | "interactiveDismissDisabled" | "statusBarHidden" | "persistentSystemOverlays" | "environmentObject"
        | "scrollClipDisabled" | "safeAreaPadding" | "containerRelativeFrame" | "geometryGroup" | "tabBarMinimizeBehavior"
        | "glassEffect" | "buttonBorderShape" | "foregroundStyleHierarchical" | "brightness" | "saturation" | "grayscale"
        | "colorMultiply" | "hueRotation" | "luminanceToAlpha" | "matchedGeometryEffect" | "position" => Mod::Ignored,
        _ => {
            it.warnings.push((span, format!("modifier .{}() is not supported yet; ignored", n)));
            Mod::Ignored
        }
    };
    if matches!(m, Mod::Ignored) {
        return Ok(Value::View(child));
    }
    Ok(wrap(child, m, mspan))
}

