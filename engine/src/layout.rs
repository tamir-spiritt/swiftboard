use crate::ast::Span;
use crate::interp::{Interp, RtErr};
use crate::value::*;
use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

// ---------------- host text measurement ----------------

#[cfg(target_arch = "wasm32")]
#[link(wasm_import_module = "env")]
extern "C" {
    fn host_measure(fp: *const u8, fl: usize, tp: *const u8, tl: usize) -> f64;
    fn host_img_aspect(np: *const u8, nl: usize) -> f64;
}

thread_local! {
    static MCACHE: RefCell<HashMap<(String, String), f64>> = RefCell::new(HashMap::new());
}

pub fn measure(font: &str, text: &str) -> f64 {
    if text.is_empty() {
        return 0.0;
    }
    let key = (font.to_string(), text.to_string());
    if let Some(v) = MCACHE.with(|c| c.borrow().get(&key).cloned()) {
        return v;
    }
    #[cfg(target_arch = "wasm32")]
    let w = unsafe { host_measure(font.as_ptr(), font.len(), text.as_ptr(), text.len()) };
    #[cfg(not(target_arch = "wasm32"))]
    let w = {
        let size: f64 = font.split("px").next().and_then(|s| s.split(' ').last()).and_then(|s| s.parse().ok()).unwrap_or(17.0);
        text.chars().count() as f64 * size * 0.52
    };
    MCACHE.with(|c| {
        let mut c = c.borrow_mut();
        if c.len() > 20000 {
            c.clear();
        }
        c.insert(key, w);
    });
    w
}

fn img_aspect(name: &str) -> f64 {
    #[cfg(target_arch = "wasm32")]
    {
        unsafe { host_img_aspect(name.as_ptr(), name.len()) }
    }
    #[cfg(not(target_arch = "wasm32"))]
    {
        let _ = name;
        1.0
    }
}

// ---------------- geometry ----------------

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Rect {
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64,
}

impl Rect {
    pub fn new(x: f64, y: f64, w: f64, h: f64) -> Rect {
        Rect { x, y, w, h }
    }
    pub fn r(&self) -> f64 {
        self.x + self.w
    }
    pub fn b(&self) -> f64 {
        self.y + self.h
    }
    pub fn intersects(&self, o: &Rect) -> bool {
        self.x < o.r() && o.x < self.r() && self.y < o.b() && o.y < self.b()
    }
    pub fn inter(&self, o: &Rect) -> Rect {
        let x = self.x.max(o.x);
        let y = self.y.max(o.y);
        let r = self.r().min(o.r());
        let b = self.b().min(o.b());
        Rect::new(x, y, (r - x).max(0.0), (b - y).max(0.0))
    }
    pub fn contains(&self, px: f64, py: f64) -> bool {
        px >= self.x && px <= self.r() && py >= self.y && py <= self.b()
    }
}

#[derive(Clone, Copy, Debug, Default)]
pub struct Size {
    pub w: f64,
    pub h: f64,
}

#[derive(Clone, Copy, Debug)]
pub struct P {
    pub w: Option<f64>,
    pub h: Option<f64>,
}

fn fin(v: Option<f64>) -> Option<f64> {
    v.filter(|x| x.is_finite())
}

// ---------------- environment ----------------

#[derive(Clone)]
pub struct Env {
    pub font: FontSpec,
    pub fg: Option<Paint>,
    pub tint: Paint,
    pub dark: bool,
    pub line_limit: Option<u32>,
    pub talign: i8,
    pub full: Rect,
    pub safe: Rect,
    pub in_button: bool,
    pub plain_button: bool,
    pub nav: Option<Rc<str>>,
    pub axis: Option<Axis>,
    pub upper: bool,
    pub strike: bool,
    pub underline: bool,
    pub kerning: f64,
    pub img_scale: f64,
    pub submit: Option<Value>,
    pub disabled: bool,
    pub in_list: bool,
}

impl Env {
    pub fn root(dark: bool, full: Rect, safe: Rect) -> Env {
        Env {
            font: FontSpec::body(),
            fg: None,
            tint: Paint::Solid(semantic_color("blue").unwrap()),
            dark,
            line_limit: None,
            talign: -1,
            full,
            safe,
            in_button: false,
            plain_button: false,
            nav: None,
            axis: None,
            upper: false,
            strike: false,
            underline: false,
            kerning: 0.0,
            img_scale: 1.0,
            submit: None,
            disabled: false,
            in_list: false,
        }
    }
    fn key(&self) -> u64 {
        let mut h: u64 = (self.font.size * 100.0) as u64;
        h = h.wrapping_mul(31).wrapping_add(self.font.weight as u64);
        h = h.wrapping_mul(31).wrapping_add(self.font.design as u64 + if self.font.italic { 7 } else { 0 });
        h = h.wrapping_mul(31).wrapping_add(self.line_limit.unwrap_or(0) as u64);
        h = h.wrapping_mul(31).wrapping_add(match self.axis {
            None => 0,
            Some(Axis::H) => 1,
            Some(Axis::V) => 2,
            Some(Axis::Z) => 3,
        });
        h = h.wrapping_mul(31).wrapping_add((self.img_scale * 100.0) as u64 + self.upper as u64 + (self.kerning * 10.0) as u64);
        h
    }
}

// ---------------- output ----------------

pub enum Action {
    Call(Value),
    Push(Rc<str>, Value),
    Pop(Rc<str>),
    Tab(Rc<str>, Option<Value>, Value, usize),
    Focus(usize),
    Toggle(Value),
}

pub struct Input {
    pub rect: Rect,
    pub id: Rc<str>,
    pub font: String,
    pub color: String,
    pub binding: Value,
    pub value: String,
    pub placeholder: String,
    pub submit: Option<Value>,
    pub multiline: bool,
    pub secure: bool,
}

pub struct ScrollRegion {
    pub rect: Rect,
    pub id: Rc<str>,
    pub max: f64,
    pub horizontal: bool,
}

pub struct Elem {
    pub rect: Rect,
    pub kind: &'static str,
    pub src: Span,
    pub lit: Option<Span>,
    pub mods: Vec<(Span, &'static str)>,
    pub font: Option<FontSpec>,
    pub color: Option<[f32; 4]>,
    pub text: Option<Rc<str>>,
    pub depth: u32,
}

pub struct Lay<'a> {
    pub it: &'a mut Interp,
    pub ops: String,
    pub nops: usize,
    pub hits: Vec<(Rect, usize)>,
    pub actions: Vec<Action>,
    pub inputs: Vec<Input>,
    pub scrolls: Vec<ScrollRegion>,
    pub elems: Vec<Elem>,
    pub errors: Vec<RtErr>,
    cache: HashMap<(usize, u64, u64, u64), Size>,
    // nodes referenced by cache keys stay alive for the whole pass (no address reuse)
    keep: Vec<Rc<View>>,
    clip: Rect,
    chain: Vec<(Span, &'static str)>,
    chain_rect: Option<Rect>,
    depth: u32,
    pub focused: Option<Rc<str>>,
    tabbar_hidden: bool,
    hit_clip: Vec<Rect>,
    anchor_next: bool,
}

fn pkey(v: Option<f64>) -> u64 {
    match v {
        None => u64::MAX,
        Some(x) => x.to_bits(),
    }
}

fn col_css(c: [f32; 4]) -> String {
    format!(
        "\"rgba({},{},{},{})\"",
        (c[0].clamp(0.0, 1.0) * 255.0).round() as i32,
        (c[1].clamp(0.0, 1.0) * 255.0).round() as i32,
        (c[2].clamp(0.0, 1.0) * 255.0).round() as i32,
        ((c[3].clamp(0.0, 1.0) * 1000.0).round() / 1000.0)
    )
}

pub fn jstr(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 2);
    o.push('"');
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            '\r' => o.push_str("\\r"),
            '\t' => o.push_str("\\t"),
            c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)),
            c => o.push(c),
        }
    }
    o.push('"');
    o
}

fn n(f: f64) -> String {
    if !f.is_finite() {
        return "0".into();
    }
    let r = (f * 100.0).round() / 100.0;
    if r == r.trunc() {
        format!("{}", r as i64)
    } else {
        format!("{}", r)
    }
}

fn radii(shape: ShapeK, r: Rect) -> (u8, [f64; 4]) {
    let m = r.w.min(r.h) / 2.0;
    match shape {
        ShapeK::Rect => (0, [0.0; 4]),
        ShapeK::Round(k) => (0, [k.min(m); 4]),
        ShapeK::Capsule => (0, [m; 4]),
        ShapeK::Circle => (2, [0.0; 4]),
        ShapeK::Ellipse => (1, [0.0; 4]),
        ShapeK::Uneven(a) => (0, [a[0].min(m), a[1].min(m), a[2].min(m), a[3].min(m)]),
    }
}

fn shape_rect(shape: ShapeK, r: Rect) -> Rect {
    if let ShapeK::Circle = shape {
        let d = r.w.min(r.h);
        Rect::new(r.x + (r.w - d) / 2.0, r.y + (r.h - d) / 2.0, d, d)
    } else {
        r
    }
}

impl<'a> Lay<'a> {
    pub fn new(it: &'a mut Interp, clip: Rect) -> Lay<'a> {
        Lay {
            it,
            ops: String::with_capacity(64 * 1024),
            nops: 0,
            hits: vec![],
            actions: vec![],
            inputs: vec![],
            scrolls: vec![],
            elems: vec![],
            errors: vec![],
            cache: HashMap::new(),
            keep: Vec::new(),
            clip,
            chain: vec![],
            chain_rect: None,
            depth: 0,
            focused: None,
            tabbar_hidden: false,
            hit_clip: vec![],
            anchor_next: false,
        }
    }

    fn op(&mut self, s: String) {
        if self.nops > 0 {
            self.ops.push(',');
        }
        self.ops.push_str(&s);
        self.nops += 1;
    }

    fn paint_json(&self, p: &Paint, env: &Env, r: Rect) -> String {
        match p {
            Paint::Solid(c) => col_css(c.pick(env.dark)),
            Paint::Tint => self.paint_json(&env.tint.clone(), env, r),
            Paint::Material(a) => {
                let c = if env.dark { [0.11, 0.11, 0.12, (*a as f32).min(1.0)] } else { [0.98, 0.98, 0.98, (*a as f32).min(1.0)] };
                format!("{{\"mat\":{}}}", col_css(c))
            }
            Paint::Linear(stops, s, e) => {
                let st: Vec<String> = stops.iter().map(|(c, o)| format!("[{},{}]", n(*o), col_css(c.pick(env.dark)))).collect();
                format!(
                    "{{\"lin\":[{},{},{},{}],\"stops\":[{}]}}",
                    n(r.x + s.0 * r.w),
                    n(r.y + s.1 * r.h),
                    n(r.x + e.0 * r.w),
                    n(r.y + e.1 * r.h),
                    st.join(",")
                )
            }
            Paint::Radial(stops, r0, r1) => {
                let st: Vec<String> = stops.iter().map(|(c, o)| format!("[{},{}]", n(*o), col_css(c.pick(env.dark)))).collect();
                format!("{{\"rad\":[{},{},{},{}],\"stops\":[{}]}}", n(r.x + r.w / 2.0), n(r.y + r.h / 2.0), n(*r0), n(*r1), st.join(","))
            }
        }
    }

    fn fill(&mut self, shape: ShapeK, r: Rect, p: &Paint, env: &Env) {
        let r = shape_rect(shape, r);
        let (k, rr) = radii(shape, r);
        let pj = self.paint_json(p, env, r);
        self.op(format!("[\"F\",{},{},{},{},{},{},{},{},{},{}]", k, n(r.x), n(r.y), n(r.w), n(r.h), n(rr[0]), n(rr[1]), n(rr[2]), n(rr[3]), pj));
    }

    fn stroke(&mut self, shape: ShapeK, r: Rect, p: &Paint, w: f64, env: &Env) {
        let r = shape_rect(shape, r);
        let (k, rr) = radii(shape, r);
        let pj = self.paint_json(p, env, r);
        self.op(format!("[\"S\",{},{},{},{},{},{},{},{},{},{},{}]", k, n(r.x), n(r.y), n(r.w), n(r.h), n(rr[0]), n(rr[1]), n(rr[2]), n(rr[3]), pj, n(w)));
    }

    fn push_clip(&mut self, shape: ShapeK, r: Rect) -> Rect {
        let r = shape_rect(shape, r);
        let (k, rr) = radii(shape, r);
        self.op(format!("[\"C\",{},{},{},{},{},{},{},{},{}]", k, n(r.x), n(r.y), n(r.w), n(r.h), n(rr[0]), n(rr[1]), n(rr[2]), n(rr[3])));
        let old = self.clip;
        self.clip = self.clip.inter(&r);
        self.hit_clip.push(self.clip);
        old
    }

    fn pop_clip(&mut self, old: Rect) {
        self.op("[\"P\"]".into());
        self.clip = old;
        self.hit_clip.pop();
    }

    fn hit(&mut self, r: Rect, a: Action) {
        let r = match self.hit_clip.last() {
            Some(c) => r.inter(c),
            None => r,
        };
        self.actions.push(a);
        self.hits.push((r, self.actions.len() - 1));
    }

    fn fg_color(&self, env: &Env) -> Paint {
        if let Some(p) = &env.fg {
            return p.clone();
        }
        if env.in_button && !env.plain_button {
            return env.tint.clone();
        }
        Paint::Solid(semantic_color("primary").unwrap())
    }

    fn solid(&self, p: &Paint, env: &Env) -> [f32; 4] {
        match p {
            Paint::Solid(c) => c.pick(env.dark),
            Paint::Tint => self.solid(&env.tint.clone(), env),
            Paint::Linear(s, _, _) | Paint::Radial(s, _, _) => s.first().map(|x| x.0.pick(env.dark)).unwrap_or([0.0, 0.0, 0.0, 1.0]),
            Paint::Material(_) => [0.5, 0.5, 0.5, 1.0],
        }
    }

    // ---------------- text ----------------

    fn line_h(f: &FontSpec) -> f64 {
        (f.size * 1.2 + 1.5).round()
    }

    fn wrap(&self, text: &str, font: &str, maxw: Option<f64>, limit: Option<u32>) -> Vec<(String, f64)> {
        let mut lines: Vec<(String, f64)> = vec![];
        for para in text.split('\n') {
            match maxw {
                None => {
                    let w = measure(font, para);
                    lines.push((para.to_string(), w));
                }
                Some(mw) => {
                    let full = measure(font, para);
                    if full <= mw + 0.5 {
                        lines.push((para.to_string(), full));
                        continue;
                    }
                    let mut cur = String::new();
                    let words: Vec<&str> = para.split(' ').collect();
                    for (i, w) in words.iter().enumerate() {
                        let cand = if cur.is_empty() { w.to_string() } else { format!("{} {}", cur, w) };
                        let cw = measure(font, &cand);
                        if cw <= mw + 0.5 || cur.is_empty() {
                            if cw > mw + 0.5 && cur.is_empty() {
                                // break long word by chars
                                let mut part = String::new();
                                for ch in w.chars() {
                                    let c2 = format!("{}{}", part, ch);
                                    if measure(font, &c2) > mw + 0.5 && !part.is_empty() {
                                        let pw = measure(font, &part);
                                        lines.push((std::mem::take(&mut part), pw));
                                        part.push(ch);
                                    } else {
                                        part = c2;
                                    }
                                }
                                cur = part;
                            } else {
                                cur = cand;
                            }
                        } else {
                            let pw = measure(font, &cur);
                            lines.push((std::mem::take(&mut cur), pw));
                            cur = w.to_string();
                        }
                        let _ = i;
                    }
                    let pw = measure(font, &cur);
                    lines.push((cur, pw));
                }
            }
        }
        if let Some(l) = limit {
            let l = l as usize;
            if lines.len() > l {
                let rest: Vec<String> = lines[l - 1..].iter().map(|x| x.0.clone()).collect();
                lines.truncate(l - 1);
                let joined = rest.join(" ");
                let mw = maxw.unwrap_or(f64::INFINITY);
                lines.push(self.ellipsize(&joined, font, mw));
            } else if let (Some(mw), Some(last)) = (maxw, lines.last()) {
                if last.1 > mw + 0.5 {
                    let t = last.0.clone();
                    let n = lines.len();
                    lines[n - 1] = self.ellipsize(&t, font, mw);
                }
            }
        }
        lines
    }

    fn ellipsize(&self, s: &str, font: &str, mw: f64) -> (String, f64) {
        let w = measure(font, s);
        if w <= mw + 0.5 {
            return (s.to_string(), w);
        }
        let chars: Vec<char> = s.chars().collect();
        let (mut lo, mut hi) = (0usize, chars.len());
        while lo < hi {
            let mid = (lo + hi + 1) / 2;
            let cand: String = chars[..mid].iter().collect::<String>().trim_end().to_string() + "…";
            if measure(font, &cand) <= mw + 0.5 {
                lo = mid;
            } else {
                hi = mid - 1;
            }
        }
        let out: String = chars[..lo].iter().collect::<String>().trim_end().to_string() + "…";
        let w = measure(font, &out);
        (out, w)
    }

    fn text_str(&self, s: &str, env: &Env) -> String {
        if env.upper {
            s.to_uppercase()
        } else {
            s.to_string()
        }
    }

    // ---------------- sizing ----------------

    pub fn size(&mut self, v: &Rc<View>, p: P, env: &Env) -> Size {
        let key = (Rc::as_ptr(v) as *const u8 as usize, pkey(p.w), pkey(p.h), env.key());
        if let Some(s) = self.cache.get(&key) {
            return *s;
        }
        let s = self.size_inner(v, p, env);
        self.cache.insert(key, s);
        self.keep.push(v.clone());
        s
    }

    fn size_inner(&mut self, v: &Rc<View>, p: P, env: &Env) -> Size {
        match &v.k {
            VK::Text { s, .. } => {
                let font = env.font.css(1.0);
                let t = self.text_str(s, env);
                let lines = self.wrap(&t, &font, fin(p.w), env.line_limit);
                let w = lines.iter().map(|l| l.1).fold(0.0, f64::max);
                Size { w: w.ceil(), h: lines.len() as f64 * Self::line_h(&env.font) }
            }
            VK::Image { name, system, resizable, fit, .. } => {
                if *resizable {
                    let aspect = if *system { 1.0 } else { img_aspect(name).max(0.01) };
                    let (pw, ph) = (p.w.unwrap_or(if *system { env.font.size } else { 100.0 }), p.h.unwrap_or(if *system { env.font.size } else { 100.0 }));
                    match fit {
                        Some(true) => {
                            if !pw.is_finite() && !ph.is_finite() {
                                return Size { w: 100.0, h: 100.0 / aspect };
                            }
                            let w = pw.min(ph * aspect);
                            Size { w, h: w / aspect }
                        }
                        Some(false) => {
                            let w = if pw.is_finite() { pw } else { ph * aspect };
                            let h = if ph.is_finite() { ph } else { pw / aspect };
                            Size { w, h }
                        }
                        None => Size { w: pw, h: ph },
                    }
                } else if *system {
                    let s = (env.font.size * 1.18 * env.img_scale).round();
                    Size { w: s, h: s }
                } else {
                    let a = img_aspect(name).max(0.01);
                    Size { w: 100.0 * a, h: 100.0 }
                }
            }
            VK::Shape { .. } => Size { w: p.w.unwrap_or(10.0), h: p.h.unwrap_or(10.0) },
            VK::Spacer(min) => match env.axis {
                Some(Axis::H) => Size { w: p.w.unwrap_or(*min).max(*min), h: 0.0 },
                Some(Axis::V) => Size { w: 0.0, h: p.h.unwrap_or(*min).max(*min) },
                _ => Size { w: p.w.unwrap_or(*min).max(*min), h: p.h.unwrap_or(*min).max(*min) },
            },
            VK::Divider => match env.axis {
                Some(Axis::H) => Size { w: 0.5, h: p.h.unwrap_or(0.0) },
                _ => Size { w: p.w.unwrap_or(0.0), h: 0.5 },
            },
            VK::Stack { axis: Axis::Z, align: _, children, .. } => {
                let mut env2 = env.clone();
                env2.axis = None;
                let mut s = Size::default();
                for c in children.iter() {
                    let cs = self.size(c, p, &env2);
                    s.w = s.w.max(cs.w);
                    s.h = s.h.max(cs.h);
                }
                s
            }
            VK::Stack { axis, spacing, children, .. } => {
                let (sizes, sp) = self.stack_sizes(children, *axis, *spacing, p, env);
                let mut main = 0.0;
                let mut cross: f64 = 0.0;
                for s in &sizes {
                    if *axis == Axis::V {
                        main += s.h;
                        cross = cross.max(s.w);
                    } else {
                        main += s.w;
                        cross = cross.max(s.h);
                    }
                }
                main += sp.iter().sum::<f64>();
                if *axis == Axis::V {
                    Size { w: cross, h: main }
                } else {
                    Size { w: main, h: cross }
                }
            }
            VK::Grid { cols, spacing, children } => {
                let w = fin(p.w).unwrap_or(320.0);
                let cw = (w - spacing * (*cols as f64 - 1.0)) / *cols as f64;
                let mut h = 0.0;
                for row in children.chunks(*cols) {
                    let mut rh: f64 = 0.0;
                    for c in row {
                        rh = rh.max(self.size(c, P { w: Some(cw), h: None }, env).h);
                    }
                    h += rh + spacing;
                }
                Size { w, h: (h - spacing).max(0.0) }
            }
            VK::Group(children) => {
                let st = Rc::new(View { k: VK::Stack { axis: Axis::V, align: Align::default(), spacing: None, children: children.clone(), lazy: false }, src: v.src });
                self.size(&st, p, env)
            }
            VK::Scroll { axis, child, .. } => {
                let mut env2 = env.clone();
                env2.axis = None;
                let cp = if *axis == Axis::H { P { w: None, h: fin(p.h) } } else { P { w: fin(p.w), h: None } };
                let cs = self.size(child, cp, &env2);
                Size { w: p.w.unwrap_or(cs.w), h: p.h.unwrap_or(cs.h) }
            }
            VK::List { .. } | VK::NavStack { .. } | VK::Tabs { .. } => Size { w: p.w.unwrap_or(env.full.w), h: p.h.unwrap_or(env.full.h) },
            VK::Section { header, children, footer } => {
                let mut all: Vec<Rc<View>> = vec![];
                if let Some(h) = header {
                    all.push(h.clone());
                }
                all.extend(children.iter().cloned());
                if let Some(f) = footer {
                    all.push(f.clone());
                }
                let st = Rc::new(View { k: VK::Stack { axis: Axis::V, align: Align { h: -1, v: 0 }, spacing: None, children: all, lazy: false }, src: v.src });
                self.size(&st, p, env)
            }
            VK::Button { label, .. } | VK::NavLink { label, .. } => {
                let mut e = env.clone();
                e.in_button = true;
                self.size(label, p, &e)
            }
            VK::Label { title, icon } => {
                let mut e = env.clone();
                e.axis = Some(Axis::H);
                let i = self.size(icon, P { w: None, h: None }, &e);
                let tw = p.w.map(|w| (w - i.w - 8.0).max(0.0));
                let t = self.size(title, P { w: tw, h: p.h }, &e);
                Size { w: i.w + 8.0 + t.w, h: i.h.max(t.h) }
            }
            VK::TextField { multiline, binding, placeholder, .. } => {
                let lh = Self::line_h(&env.font);
                let mut h = lh;
                if *multiline {
                    let val = self.it.read_binding_val(binding);
                    let font = env.font.css(1.0);
                    let lines = self.wrap(if val.is_empty() { placeholder } else { &val }, &font, fin(p.w), env.line_limit);
                    h = lines.len().max(1) as f64 * lh;
                }
                Size { w: p.w.unwrap_or(measure(&env.font.css(1.0), placeholder).max(40.0)), h }
            }
            VK::Toggle { label, .. } => {
                let l = self.size(label, P { w: p.w.map(|w| w - 59.0), h: None }, env);
                Size { w: p.w.unwrap_or(l.w + 59.0), h: l.h.max(31.0) }
            }
            VK::Pushed { view, .. } => self.size(view, p, env),
            VK::Empty => Size::default(),
            VK::Mod(child, m, _) => self.size_mod(child, m, p, env),
        }
    }

    fn mod_env(&self, m: &Mod, env: &Env) -> Option<Env> {
        let mut e = env.clone();
        match m {
            Mod::Font(f) => e.font = *f,
            Mod::FontWeight(w) => e.font.weight = *w,
            Mod::FontSize(s) => e.img_scale = *s,
            Mod::Italic => e.font.italic = true,
            Mod::Design(d) => e.font.design = *d,
            Mod::Fg(p) => e.fg = Some(p.clone()),
            Mod::Tint(p) => e.tint = p.clone(),
            Mod::LineLimit(l) => e.line_limit = *l,
            Mod::TextAlign(a) => e.talign = *a,
            Mod::Scheme(d) => e.dark = *d,
            Mod::PlainButton => e.plain_button = true,
            Mod::TextCase(u) => e.upper = *u,
            Mod::Strikethrough => e.strike = true,
            Mod::Underline => e.underline = true,
            Mod::Kerning(k) => e.kerning = *k,
            Mod::OnSubmit(a) => e.submit = Some(a.clone()),
            Mod::Disabled(d) => e.disabled = *d,
            _ => return None,
        }
        Some(e)
    }

    fn size_mod(&mut self, child: &Rc<View>, m: &Mod, p: P, env: &Env) -> Size {
        if let Some(e) = self.mod_env(m, env) {
            return self.size(child, p, &e);
        }
        match m {
            Mod::Padding(ed) => {
                let cp = P { w: p.w.map(|w| (w - ed.l - ed.r).max(0.0)), h: p.h.map(|h| (h - ed.t - ed.b).max(0.0)) };
                let cs = self.size(child, cp, env);
                Size { w: cs.w + ed.l + ed.r, h: cs.h + ed.t + ed.b }
            }
            Mod::Frame { w, h, .. } => {
                let cp = P { w: w.or(p.w), h: h.or(p.h) };
                if w.is_some() && h.is_some() {
                    // still size child so its cache is warm
                    return Size { w: w.unwrap(), h: h.unwrap() };
                }
                let cs = self.size(child, cp, env);
                Size { w: w.unwrap_or(cs.w), h: h.unwrap_or(cs.h) }
            }
            Mod::FlexFrame { min_w, max_w, min_h, max_h, ideal_w, ideal_h, .. } => {
                let clampv = |v: Option<f64>, lo: Option<f64>, hi: Option<f64>, ideal: Option<f64>| -> Option<f64> {
                    let v = match v {
                        Some(x) => Some(x),
                        None => ideal,
                    };
                    v.map(|mut x| {
                        if let Some(h) = hi {
                            x = x.min(h);
                        }
                        if let Some(l) = lo {
                            x = x.max(l);
                        }
                        x
                    })
                };
                let cp = P { w: clampv(p.w, *min_w, *max_w, *ideal_w), h: clampv(p.h, *min_h, *max_h, *ideal_h) };
                let cs = self.size(child, cp, env);
                let dim = |pv: Option<f64>, c: f64, lo: Option<f64>, hi: Option<f64>| -> f64 {
                    if lo.is_none() && hi.is_none() {
                        return c;
                    }
                    let base = match pv {
                        Some(x) => x,
                        None => c,
                    };
                    let mut r = match hi {
                        Some(h) => base.min(h),
                        None => base.min(c.max(lo.unwrap_or(0.0))),
                    };
                    if hi.is_some() && pv.is_none() {
                        r = c;
                    }
                    if let Some(l) = lo {
                        r = r.max(l);
                    }
                    if hi.is_some() && r < c && lo.is_none() && pv.is_some() {
                        // proposal smaller than child: frame follows proposal (child overflows)
                    }
                    r
                };
                Size { w: dim(p.w, cs.w, *min_w, *max_w), h: dim(p.h, cs.h, *min_h, *max_h) }
            }
            Mod::FixedSize(hz, vt) => {
                let cp = P { w: if *hz { None } else { p.w }, h: if *vt { None } else { p.h } };
                self.size(child, cp, env)
            }
            Mod::Inset(_, content) => {
                let cs = self.size(content, P { w: p.w, h: None }, env);
                let inner = self.size(child, P { w: p.w, h: p.h.map(|h| (h - cs.h).max(0.0)) }, env);
                Size { w: inner.w.max(cs.w), h: inner.h + cs.h }
            }
            _ => self.size(child, p, env),
        }
    }

    fn stack_sizes(&mut self, children: &[Rc<View>], axis: Axis, spacing: Option<f64>, p: P, env: &Env) -> (Vec<Size>, Vec<f64>) {
        let mut env2 = env.clone();
        env2.axis = Some(axis);
        let kids: Vec<&Rc<View>> = children.iter().collect();
        let nk = kids.len();
        let mut sp = vec![0.0; nk.saturating_sub(1)];
        for i in 0..sp.len() {
            sp[i] = spacing.unwrap_or_else(|| {
                // SwiftUI default spacing: 8, but 0 next to Spacer is still 8; text-text in VStack is ~ 8
                8.0
            });
        }
        let total_sp: f64 = sp.iter().sum();
        let mut sizes = vec![Size::default(); nk];
        let (main_p, cross_p) = if axis == Axis::V { (p.h, p.w) } else { (p.w, p.h) };
        let mk = |main: Option<f64>| if axis == Axis::V { P { w: cross_p, h: main } } else { P { w: main, h: cross_p } };
        match main_p {
            None => {
                for (i, c) in kids.iter().enumerate() {
                    sizes[i] = self.size(c, mk(None), &env2);
                }
            }
            Some(total) => {
                let avail = total - total_sp;
                let mut flex = vec![];
                for (i, c) in kids.iter().enumerate() {
                    let lo = self.size(c, mk(Some(0.0)), &env2);
                    let hi = self.size(c, mk(Some(f64::INFINITY)), &env2);
                    let (l, h) = if axis == Axis::V { (lo.h, hi.h) } else { (lo.w, hi.w) };
                    let prio = layout_priority(c);
                    flex.push((i, -prio, h - l));
                }
                flex.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap().then(a.2.partial_cmp(&b.2).unwrap_or(std::cmp::Ordering::Equal)));
                // SwiftUI offers space to regular views first; spacers only reserve their minimum
                let is_sp = |v: &Rc<View>| matches!(v.k, VK::Spacer(_));
                let mut spacer_min = 0.0;
                for c in kids.iter() {
                    if let VK::Spacer(m) = c.k {
                        spacer_min += m;
                    }
                }
                let (regular, spacers): (Vec<_>, Vec<_>) = flex.into_iter().partition(|x| !is_sp(kids[x.0]));
                let mut remaining = avail - spacer_min;
                // SwiftUI gives views with a finite ideal size their ideal when everything fits;
                // greedy views (shapes, maxWidth: .infinity) then share what is left
                let main_of = |s: Size| if axis == Axis::V { s.h } else { s.w };
                let mut ideal = vec![f64::INFINITY; nk];
                for (i, _, _) in regular.iter() {
                    ideal[*i] = main_of(self.size(kids[*i], mk(Some(f64::INFINITY)), &env2));
                }
                let fixed: Vec<usize> = regular.iter().map(|x| x.0).filter(|i| ideal[*i].is_finite() && ideal[*i] < 1e6).collect();
                let fixed_sum: f64 = fixed.iter().map(|i| ideal[*i]).sum();
                let regular: Vec<(usize, f64, f64)> = if remaining.is_finite() && fixed_sum <= remaining + 0.5 && !fixed.is_empty() {
                    for &i in &fixed {
                        let s = self.size(kids[i], mk(Some(ideal[i])), &env2);
                        sizes[i] = s;
                        remaining -= main_of(s);
                    }
                    regular.into_iter().filter(|x| !fixed.contains(&x.0)).collect()
                } else {
                    regular
                };
                let mut left = regular.len() as f64;
                for (i, _, _) in regular {
                    let offer = if remaining.is_finite() { (remaining / left).max(0.0) } else { remaining };
                    let s = self.size(kids[i], mk(Some(offer)), &env2);
                    sizes[i] = s;
                    let used = if axis == Axis::V { s.h } else { s.w };
                    remaining -= used;
                    left -= 1.0;
                }
                remaining += spacer_min;
                let mut left = spacers.len() as f64;
                for (i, _, _) in spacers {
                    let offer = if remaining.is_finite() { (remaining / left).max(0.0) } else { remaining };
                    let s = self.size(kids[i], mk(Some(offer)), &env2);
                    sizes[i] = s;
                    let used = if axis == Axis::V { s.h } else { s.w };
                    remaining -= used;
                    left -= 1.0;
                }
            }
        }
        (sizes, sp)
    }

    // ---------------- placement ----------------

    fn register(&mut self, v: &Rc<View>, rect: Rect, env: &Env, kind: &'static str) {
        let chain = std::mem::take(&mut self.chain);
        let outer = self.chain_rect.take().unwrap_or(rect);
        if !outer.intersects(&self.clip) && !chain.is_empty() {
            return;
        }
        let (lit, text) = match &v.k {
            VK::Text { lit, s, .. } => (*lit, Some(s.clone())),
            _ => (None, None),
        };
        let color = match &v.k {
            VK::Text { .. } | VK::Image { .. } => Some(self.solid(&self.fg_color(env), env)),
            VK::Shape { fill, .. } => Some(self.solid(&fill.clone().unwrap_or_else(|| self.fg_color(env)), env)),
            _ => None,
        };
        let font = match &v.k {
            VK::Text { .. } | VK::Image { .. } | VK::TextField { .. } => Some(env.font),
            _ => None,
        };
        let vis = outer.inter(&self.clip);
        if vis.w <= 0.0 || vis.h <= 0.0 {
            return;
        }
        self.elems.push(Elem { rect: outer, kind, src: v.src, lit, mods: chain, font, color, text, depth: self.depth });
    }

    pub fn place(&mut self, v: &Rc<View>, rect: Rect, env: &Env) {
        self.depth += 1;
        if self.depth > 400 {
            self.depth -= 1;
            return;
        }
        self.place_inner(v, rect, env);
        self.depth -= 1;
    }

    fn place_inner(&mut self, v: &Rc<View>, rect: Rect, env: &Env) {
        // cull
        let visible = rect.intersects(&Rect::new(self.clip.x - 1.0, self.clip.y - 1.0, self.clip.w + 2.0, self.clip.h + 2.0));
        match &v.k {
            VK::Mod(child, m, mspan) => {
                if self.chain.is_empty() {
                    self.chain_rect = Some(rect);
                }
                self.chain.push((*mspan, mod_name(m)));
                self.place_mod(child, m, rect, env);
                return;
            }
            _ => {}
        }
        let kind = kind_name(&v.k);
        if !visible && !matches!(v.k, VK::NavStack { .. } | VK::Tabs { .. }) {
            self.chain.clear();
            self.chain_rect = None;
            return;
        }
        self.register(v, rect, env, kind);
        match &v.k {
            VK::Text { s, .. } => {
                let fs = env.font;
                let font = fs.css(1.0);
                let t = self.text_str(s, env);
                let lines = self.wrap(&t, &font, Some(rect.w + 0.5), env.line_limit);
                let lh = Self::line_h(&fs);
                let col = col_css(self.solid(&self.fg_color(env), env));
                let col = if env.disabled { col_css(semantic_color("tertiary").unwrap().pick(env.dark)) } else { col };
                let mut y = rect.y;
                for (line, w) in lines {
                    let x = match env.talign {
                        0 => rect.x + (rect.w - w) / 2.0,
                        1 => rect.r() - w,
                        _ => rect.x,
                    };
                    let base = y + lh / 2.0 + fs.size * 0.34;
                    if y + lh >= self.clip.y && y <= self.clip.b() {
                        self.op(format!("[\"T\",{},{},{},{},{}]", n(x), n(base), jstr(&font), col, jstr(&line)));
                        if env.strike || env.underline {
                            let ly = if env.strike { base - fs.size * 0.3 } else { base + 2.0 };
                            self.op(format!("[\"F\",0,{},{},{},1,0,0,0,0,{}]", n(x), n(ly), n(w), col));
                        }
                    }
                    y += lh;
                }
            }
            VK::Image { name, system, resizable, fit, render_orig } => {
                let col = col_css(self.solid(&self.fg_color(env), env));
                if *system {
                    let s = if *resizable { rect.w.min(rect.h) } else { (env.font.size * 1.18 * env.img_scale).round() };
                    let r = Rect::new(rect.x + (rect.w - s) / 2.0, rect.y + (rect.h - s) / 2.0, s, s);
                    self.op(format!("[\"I\",{},{},{},{},{},{},{}]", jstr(name), n(r.x), n(r.y), n(r.w), n(r.h), col, env.font.weight));
                } else {
                    let mode = match fit {
                        _ if *render_orig && *resizable => 3,
                        Some(true) => 1,
                        Some(false) => 2,
                        None => 0,
                    };
                    self.op(format!("[\"M\",{},{},{},{},{},{}]", jstr(name), n(rect.x), n(rect.y), n(rect.w), n(rect.h), mode));
                }
            }
            VK::Shape { shape, fill, stroke, inset } => {
                let r = Rect::new(rect.x + inset, rect.y + inset, rect.w - inset * 2.0, rect.h - inset * 2.0);
                let p = fill.clone().unwrap_or_else(|| self.fg_color(env));
                if stroke.is_none() || fill.is_none() {
                    if stroke.is_none() {
                        self.fill(*shape, r, &p, env);
                    }
                } else if let Some(Paint::Solid(c)) = fill {
                    if c.l[3] > 0.0 {
                        self.fill(*shape, r, &p, env);
                    }
                } else {
                    self.fill(*shape, r, &p, env);
                }
                if let Some((sp, w)) = stroke {
                    self.stroke(*shape, r, sp, *w, env);
                }
            }
            VK::Spacer(_) | VK::Empty => {}
            VK::Divider => {
                let c = Paint::Solid(semantic_color("separator").unwrap());
                self.fill(ShapeK::Rect, Rect::new(rect.x, rect.y, rect.w.max(0.5), rect.h.max(0.5)), &c, env);
            }
            VK::Stack { axis: Axis::Z, align, children, .. } => {
                let mut env2 = env.clone();
                env2.axis = None;
                for c in children.iter() {
                    let cs = self.size(c, P { w: Some(rect.w), h: Some(rect.h) }, &env2);
                    let r = align_in(rect, cs, *align);
                    self.place(c, r, &env2);
                }
            }
            VK::Stack { axis, align, spacing, children, .. } => {
                let (sizes, sp) = self.stack_sizes(children, *axis, *spacing, P { w: Some(rect.w), h: Some(rect.h) }, env);
                let mut env2 = env.clone();
                env2.axis = Some(*axis);
                let mut cur = if *axis == Axis::V { rect.y } else { rect.x };
                for (i, c) in children.iter().enumerate() {
                    let s = sizes[i];
                    let r = if *axis == Axis::V {
                        let x = match align.h {
                            -1 => rect.x,
                            1 => rect.r() - s.w,
                            _ => rect.x + (rect.w - s.w) / 2.0,
                        };
                        Rect::new(x, cur, s.w, s.h)
                    } else {
                        let y = match align.v {
                            -1 => rect.y,
                            1 => rect.b() - s.h,
                            _ => rect.y + (rect.h - s.h) / 2.0,
                        };
                        Rect::new(cur, y, s.w, s.h)
                    };
                    self.place(c, r, &env2);
                    cur += if *axis == Axis::V { s.h } else { s.w };
                    if i < sp.len() {
                        cur += sp[i];
                    }
                }
            }
            VK::Grid { cols, spacing, children } => {
                let cw = (rect.w - spacing * (*cols as f64 - 1.0)) / *cols as f64;
                let mut y = rect.y;
                for row in children.chunks(*cols) {
                    let mut rh: f64 = 0.0;
                    for c in row {
                        rh = rh.max(self.size(c, P { w: Some(cw), h: None }, env).h);
                    }
                    for (i, c) in row.iter().enumerate() {
                        let s = self.size(c, P { w: Some(cw), h: Some(rh) }, env);
                        let cell = Rect::new(rect.x + i as f64 * (cw + spacing), y, cw, rh);
                        self.place(c, align_in(cell, s, Align::default()), env);
                    }
                    y += rh + spacing;
                }
            }
            VK::Group(children) => {
                let st = Rc::new(View { k: VK::Stack { axis: Axis::V, align: Align::default(), spacing: None, children: children.clone(), lazy: false }, src: v.src });
                self.place(&st, rect, env);
            }
            VK::Scroll { axis, child, id, .. } => {
                let mut env2 = env.clone();
                env2.axis = None;
                let horizontal = *axis == Axis::H;
                let cp = if horizontal { P { w: None, h: Some(rect.h) } } else { P { w: Some(rect.w), h: None } };
                let cs = self.size(child, cp, &env2);
                let anchor_bottom = std::mem::take(&mut self.anchor_next);
                let (ext, off, top_in, _bot_in) = self.begin_scroll(id, rect, if horizontal { cs.w } else { cs.h }, env, horizontal, anchor_bottom);
                let old = self.push_clip(ShapeK::Rect, ext);
                let cr = if horizontal {
                    Rect::new(ext.x - off, ext.y, cs.w.max(ext.w), ext.h)
                } else {
                    Rect::new(ext.x, ext.y + top_in - off, ext.w, cs.h)
                };
                let mut env3 = env2.clone();
                env3.full = ext;
                env3.safe = ext;
                let cs2 = if horizontal { Size { w: cs.w, h: rect.h } } else { Size { w: rect.w, h: cs.h } };
                let r = if horizontal { Rect::new(cr.x, cr.y, cs2.w, cs2.h) } else { Rect::new(cr.x + (ext.w - cs2.w) / 2.0, cr.y, cs2.w, cs2.h) };
                self.place(child, r, &env3);
                self.pop_clip(old);
            }
            VK::List { children, id, grouped } => self.place_list(children, id, *grouped, rect, env),
            VK::Section { header, footer, children } => {
                let mut all: Vec<Rc<View>> = vec![];
                if let Some(h) = header {
                    all.push(h.clone());
                }
                all.extend(children.iter().cloned());
                if let Some(f) = footer {
                    all.push(f.clone());
                }
                let st = Rc::new(View { k: VK::Stack { axis: Axis::V, align: Align { h: -1, v: 0 }, spacing: None, children: all, lazy: false }, src: v.src });
                self.place(&st, rect, env);
            }
            VK::Button { action, label, role_destructive } => {
                if !env.disabled {
                    self.hit(rect, Action::Call(action.clone()));
                }
                let mut e = env.clone();
                e.in_button = true;
                if *role_destructive {
                    e.fg = Some(Paint::Solid(semantic_color("red").unwrap()));
                }
                self.place(label, rect, &e);
            }
            VK::NavLink { dest, label } => {
                if let Some(nav) = &env.nav {
                    self.hit(rect, Action::Push(nav.clone(), dest.clone()));
                }
                let mut e = env.clone();
                e.in_button = true;
                e.plain_button = e.plain_button || env.in_list;
                self.place(label, rect, &e);
            }
            VK::Label { title, icon } => {
                let mut e = env.clone();
                e.axis = Some(Axis::H);
                let is = self.size(icon, P { w: None, h: None }, &e);
                let ts = self.size(title, P { w: Some((rect.w - is.w - 8.0).max(0.0)), h: Some(rect.h) }, &e);
                let mut ie = e.clone();
                if env.in_list && env.fg.is_none() {
                    ie.fg = Some(env.tint.clone());
                }
                self.place(icon, Rect::new(rect.x, rect.y + (rect.h - is.h) / 2.0, is.w, is.h), &ie);
                self.place(title, Rect::new(rect.x + is.w + 8.0, rect.y + (rect.h - ts.h) / 2.0, ts.w, ts.h), &e);
            }
            VK::TextField { placeholder, binding, id, secure, multiline } => {
                let val = self.it.read_binding_val(binding);
                let font = env.font.css(1.0);
                let focused = self.focused.as_deref() == Some(&**id);
                let lh = Self::line_h(&env.font);
                if !focused {
                    let (txt, col) = if val.is_empty() {
                        (placeholder.to_string(), semantic_color("tertiary").unwrap())
                    } else {
                        (if *secure { "•".repeat(val.chars().count()) } else { val.clone() }, Col { l: self.solid(&self.fg_color(env), env), d: self.solid(&self.fg_color(env), env) })
                    };
                    let lines = if *multiline { self.wrap(&txt, &font, Some(rect.w), None) } else { vec![self.ellipsize(&txt, &font, rect.w)] };
                    let mut y = rect.y + (if *multiline { 0.0 } else { (rect.h - lh) / 2.0 });
                    for (l, _) in lines {
                        self.op(format!("[\"T\",{},{},{},{},{}]", n(rect.x), n(y + lh / 2.0 + env.font.size * 0.34), jstr(&font), col_css(col.pick(env.dark)), jstr(&l)));
                        y += lh;
                    }
                }
                let col = col_css(self.solid(&self.fg_color(env), env));
                self.inputs.push(Input {
                    rect,
                    id: id.clone(),
                    font,
                    color: col,
                    binding: binding.clone(),
                    value: val,
                    placeholder: placeholder.to_string(),
                    submit: env.submit.clone(),
                    multiline: *multiline,
                    secure: *secure,
                });
                let idx = self.inputs.len() - 1;
                self.hit(rect, Action::Focus(idx));
            }
            VK::Toggle { binding, label } => {
                let on = self.it.read_binding_v(binding).truthy();
                let ls = self.size(label, P { w: Some(rect.w - 59.0), h: None }, env);
                self.place(label, Rect::new(rect.x, rect.y + (rect.h - ls.h) / 2.0, ls.w, ls.h), env);
                let sw = Rect::new(rect.r() - 51.0, rect.y + (rect.h - 31.0) / 2.0, 51.0, 31.0);
                let bg = if on { Paint::Solid(semantic_color("green").unwrap()) } else { Paint::Solid(Col::dyn_hex(0x787880, 0.16, 0x787880, 0.32)) };
                self.fill(ShapeK::Capsule, sw, &bg, env);
                let kx = if on { sw.r() - 29.0 } else { sw.x + 2.0 };
                self.op(format!("[\"SH\",\"rgba(0,0,0,0.18)\",4,0,2]"));
                self.fill(ShapeK::Circle, Rect::new(kx, sw.y + 2.0, 27.0, 27.0), &Paint::Solid(Col::hex(0xFFFFFF, 1.0)), env);
                self.op("[\"P\"]".into());
                self.hit(rect, Action::Toggle(binding.clone()));
            }
            VK::NavStack { root, id } => self.place_nav(root, id, rect, env),
            VK::Tabs { tabs, selection, id } => self.place_tabs(tabs, selection, id, rect, env),
            VK::Pushed { view, .. } => self.place(view, rect, env),
            VK::Mod(..) => unreachable!(),
        }
    }

    fn begin_scroll(&mut self, id: &Rc<str>, rect: Rect, content: f64, env: &Env, horizontal: bool, anchor_bottom: bool) -> (Rect, f64, f64, f64) {
        let mut ext = rect;
        let mut top_in = 0.0;
        let mut bot_in = 0.0;
        if !horizontal {
            if (rect.y - env.safe.y).abs() < 0.5 && env.safe.y > env.full.y {
                top_in = env.safe.y - env.full.y;
                ext.y = env.full.y;
                ext.h += top_in;
            }
            if (rect.b() - env.safe.b()).abs() < 0.5 && env.full.b() > env.safe.b() {
                bot_in = env.full.b() - env.safe.b();
                ext.h += bot_in;
            }
        }
        let view = if horizontal { ext.w } else { ext.h };
        let max = (content + top_in + bot_in - view).max(0.0);
        let key = id.to_string();
        let pin_key = format!("{}:pin", id);
        let mut off = match self.it.ui.get(&key) {
            Some(o) => *o,
            None => {
                if anchor_bottom {
                    max
                } else {
                    0.0
                }
            }
        };
        if anchor_bottom && self.it.ui.get(&pin_key).cloned().unwrap_or(1.0) > 0.5 {
            off = max;
        }
        off = off.clamp(0.0, max);
        self.it.ui.insert(key, off);
        if anchor_bottom {
            self.it.ui.insert(pin_key, if off >= max - 1.0 { 1.0 } else { 0.0 });
        }
        self.scrolls.push(ScrollRegion { rect: ext.inter(&self.clip), id: id.clone(), max, horizontal });
        (ext, off, top_in, bot_in)
    }

    fn place_mod(&mut self, child: &Rc<View>, m: &Mod, rect: Rect, env: &Env) {
        if let Some(e) = self.mod_env(m, env) {
            self.place(child, rect, &e);
            return;
        }
        match m {
            Mod::Padding(ed) => {
                let r = Rect::new(rect.x + ed.l, rect.y + ed.t, (rect.w - ed.l - ed.r).max(0.0), (rect.h - ed.t - ed.b).max(0.0));
                self.place(child, r, env);
            }
            Mod::Frame { align, .. } | Mod::FlexFrame { align, .. } => {
                let (cp_w, cp_h) = match m {
                    Mod::FlexFrame { min_w, max_w, min_h, max_h, .. } => {
                        let cl = |v: f64, lo: &Option<f64>, hi: &Option<f64>| {
                            let mut x = v;
                            if let Some(h) = hi {
                                x = x.min(*h);
                            }
                            if let Some(l) = lo {
                                x = x.max(*l);
                            }
                            x
                        };
                        (cl(rect.w, min_w, max_w), cl(rect.h, min_h, max_h))
                    }
                    _ => (rect.w, rect.h),
                };
                let cs = self.size(child, P { w: Some(cp_w), h: Some(cp_h) }, env);
                let r = align_in(rect, cs, *align);
                self.place(child, r, env);
            }
            Mod::FixedSize(hz, vt) => {
                let cs = self.size(child, P { w: if *hz { None } else { Some(rect.w) }, h: if *vt { None } else { Some(rect.h) } }, env);
                self.place(child, align_in(rect, cs, Align::default()), env);
            }
            Mod::Background(bg, align, is_style) => {
                let saved = std::mem::take(&mut self.chain);
                let saved_r = self.chain_rect.take();
                let mut br = rect;
                if *is_style {
                    br = self.extend_safe(rect, env);
                }
                let bs = if *is_style { Size { w: br.w, h: br.h } } else { self.size(bg, P { w: Some(rect.w), h: Some(rect.h) }, env) };
                let mut benv = env.clone();
                benv.axis = None;
                let r = if *is_style { br } else { align_in(rect, bs, *align) };
                self.place(bg, r, &benv);
                self.chain = saved;
                self.chain_rect = saved_r;
                self.place(child, rect, env);
            }
            Mod::Overlay(ov, align) => {
                self.place(child, rect, env);
                let mut oenv = env.clone();
                oenv.axis = None;
                let os = self.size(ov, P { w: Some(rect.w), h: Some(rect.h) }, &oenv);
                let r = align_in(rect, os, *align);
                self.place(ov, r, &oenv);
            }
            Mod::Inset(top, content) => {
                let cs = self.size(content, P { w: Some(rect.w), h: None }, env);
                let (cr, ir) = if *top {
                    (Rect::new(rect.x, rect.y + cs.h, rect.w, rect.h - cs.h), Rect::new(rect.x, rect.y, rect.w, cs.h))
                } else {
                    (Rect::new(rect.x, rect.y, rect.w, rect.h - cs.h), Rect::new(rect.x, rect.b() - cs.h, rect.w, cs.h))
                };
                // like SwiftUI: the inset shrinks the safe area; views that ignore it still reach the edge
                let mut e2 = env.clone();
                if *top {
                    let nb = e2.safe.b();
                    e2.safe.y = cr.y;
                    e2.safe.h = (nb - cr.y).max(0.0);
                } else {
                    e2.safe.h = (cr.b() - e2.safe.y).max(0.0);
                }
                self.place(child, cr, &e2);
                let saved = std::mem::take(&mut self.chain);
                self.chain_rect = None;
                self.place(content, ir, env);
                let _ = saved;
            }
            Mod::Clip(shape) => {
                let old = self.push_clip(*shape, rect);
                self.place(child, rect, env);
                self.pop_clip(old);
            }
            Mod::Opacity(a) => {
                self.op(format!("[\"A\",{}]", n(*a)));
                self.place(child, rect, env);
                self.op("[\"P\"]".into());
            }
            Mod::Blur(r) => {
                self.op(format!("[\"B\",{}]", n(*r)));
                self.place(child, rect, env);
                self.op("[\"P\"]".into());
            }
            Mod::Shadow(c, r, x, y) => {
                self.op(format!("[\"SH\",{},{},{},{}]", col_css(c.pick(env.dark)), n(*r), n(*x), n(*y)));
                self.place(child, rect, env);
                self.op("[\"P\"]".into());
            }
            Mod::Offset(x, y) => {
                self.place(child, Rect::new(rect.x + x, rect.y + y, rect.w, rect.h), env);
            }
            Mod::Rotation(deg) => {
                self.op(format!("[\"X\",{},{},{},1]", n(rect.x + rect.w / 2.0), n(rect.y + rect.h / 2.0), n(*deg)));
                self.place(child, rect, env);
                self.op("[\"P\"]".into());
            }
            Mod::Scale(s) => {
                self.op(format!("[\"X\",{},{},0,{}]", n(rect.x + rect.w / 2.0), n(rect.y + rect.h / 2.0), n(*s)));
                self.place(child, rect, env);
                self.op("[\"P\"]".into());
            }
            Mod::OnTap(a) => {
                if !env.disabled {
                    self.hit(rect, Action::Call(a.clone()));
                }
                self.place(child, rect, env);
            }
            Mod::IgnoresSafeArea => {
                let r = self.extend_safe(rect, env);
                let mut e2 = env.clone();
                e2.safe = e2.full;
                self.place(child, r, &e2);
            }
            Mod::Border(p, w) => {
                self.place(child, rect, env);
                self.stroke(ShapeK::Rect, Rect::new(rect.x + w / 2.0, rect.y + w / 2.0, rect.w - w, rect.h - w), p, *w, env);
            }
            Mod::StrokeOverlay(shape, p, w) => {
                self.place(child, rect, env);
                self.stroke(*shape, rect, p, *w, env);
            }
            Mod::ScrollBottom => {
                self.anchor_next = true;
                self.place(child, rect, env);
            }
            Mod::Hidden => {
                self.chain.clear();
                self.chain_rect = None;
            }
            Mod::Tag(Value::Sym(s)) if &**s == "__tabbar_hidden" => {
                self.tabbar_hidden = true;
                self.place(child, rect, env);
            }
            _ => self.place(child, rect, env),
        }
    }

    fn extend_safe(&self, rect: Rect, env: &Env) -> Rect {
        let mut r = rect;
        if (rect.y - env.safe.y).abs() < 0.5 {
            r.h += r.y - env.full.y;
            r.y = env.full.y;
        }
        if (rect.b() - env.safe.b()).abs() < 0.5 {
            r.h = env.full.b() - r.y;
        }
        if (rect.x - env.safe.x).abs() < 0.5 {
            r.w += r.x - env.full.x;
            r.x = env.full.x;
        }
        if (rect.r() - env.safe.r()).abs() < 0.5 {
            r.w = env.full.r() - r.x;
        }
        r
    }

    // ---------------- list ----------------

    fn place_list(&mut self, children: &[Rc<View>], id: &Rc<str>, grouped: bool, rect: Rect, env: &Env) {
        let bg_rect = self.extend_safe(rect, env);
        let bg = if grouped { semantic_color("systemGroupedBackground").unwrap() } else { semantic_color("systemBackground").unwrap() };
        self.fill(ShapeK::Rect, bg_rect, &Paint::Solid(bg), env);
        // flatten into sections
        struct Sec {
            header: Option<Rc<View>>,
            footer: Option<Rc<View>>,
            rows: Vec<Rc<View>>,
        }
        let mut secs: Vec<Sec> = vec![];
        let mut loose: Vec<Rc<View>> = vec![];
        for c in children {
            if let VK::Section { header, footer, children } = &c.k {
                if !loose.is_empty() {
                    secs.push(Sec { header: None, footer: None, rows: std::mem::take(&mut loose) });
                }
                let mut rows = vec![];
                for r in children {
                    if let VK::Group(g) = &r.k {
                        rows.extend(g.iter().cloned());
                    } else {
                        rows.push(r.clone());
                    }
                }
                secs.push(Sec { header: header.clone(), footer: footer.clone(), rows });
            } else {
                loose.push(c.clone());
            }
        }
        if !loose.is_empty() {
            secs.push(Sec { header: None, footer: None, rows: loose });
        }
        let inset = if grouped { 16.0 } else { 0.0 };
        let pad_h = 20.0;
        let row_w = rect.w - inset * 2.0;
        let mut renv = env.clone();
        renv.in_list = true;
        renv.axis = None;
        // measure
        let mut heights: Vec<Vec<f64>> = vec![];
        let mut total = if grouped { 8.0 } else { 0.0 };
        let mut hdr_h = vec![];
        for s in &secs {
            let mut hs = vec![];
            let hh = if let Some(h) = &s.header {
                let mut he = renv.clone();
                he.font = FontSpec::named("footnote").unwrap();
                he.upper = grouped;
                let hsz = self.size(h, P { w: Some(row_w - pad_h * 2.0), h: None }, &he);
                hsz.h + if grouped { 14.0 } else { 12.0 }
            } else if grouped {
                20.0
            } else {
                0.0
            };
            hdr_h.push(hh);
            total += hh;
            for r in &s.rows {
                let (ins, _) = row_meta(r);
                let ins = ins.unwrap_or(Edges { t: 11.0, l: pad_h, b: 11.0, r: pad_h });
                let rs = self.size(r, P { w: Some(row_w - ins.l - ins.r - if is_link(r) { 20.0 } else { 0.0 }), h: None }, &renv);
                let h = (rs.h + ins.t + ins.b).max(if ins.t == 0.0 && ins.b == 0.0 { 0.0 } else { 44.0 });
                hs.push(h);
                total += h;
            }
            if let Some(f) = &s.footer {
                let fs = self.size(f, P { w: Some(row_w - pad_h * 2.0), h: None }, &renv);
                total += fs.h + 12.0;
            }
            heights.push(hs);
        }
        total += 20.0;
        let (ext, off, top_in, _) = self.begin_scroll(id, rect, total, env, false, false);
        let old = self.push_clip(ShapeK::Rect, ext);
        let mut y = ext.y + top_in - off + if grouped { 8.0 } else { 0.0 };
        for (si, s) in secs.iter().enumerate() {
            if let Some(h) = &s.header {
                let mut he = renv.clone();
                he.font = if grouped { FontSpec::named("footnote").unwrap() } else { FontSpec { size: 15.0, weight: 600, italic: false, design: 0 } };
                he.upper = grouped;
                he.fg = Some(Paint::Solid(semantic_color(if grouped { "secondary" } else { "primary" }).unwrap()));
                let hsz = self.size(h, P { w: Some(row_w - pad_h * 2.0), h: None }, &he);
                let hy = y + hdr_h[si] - hsz.h - 6.0;
                if !grouped {
                    self.fill(ShapeK::Rect, Rect::new(rect.x, y, rect.w, hdr_h[si]), &Paint::Solid(semantic_color("secondarySystemBackground").unwrap()), env);
                }
                self.place(h, Rect::new(rect.x + inset + pad_h, hy, hsz.w, hsz.h), &he);
            }
            y += hdr_h[si];
            let sec_h: f64 = heights[si].iter().sum();
            let card = Rect::new(rect.x + inset, y, row_w, sec_h);
            let mut cold = None;
            let clear_rows = !s.rows.is_empty() && s.rows.iter().all(|r| row_meta(r).1.is_some());
            if grouped && !clear_rows {
                self.fill(ShapeK::Round(26.0), card, &Paint::Solid(semantic_color("secondarySystemGroupedBackground").unwrap()), env);
                cold = Some(self.push_clip(ShapeK::Round(26.0), card));
            }
            for (ri, r) in s.rows.iter().enumerate() {
                let h = heights[si][ri];
                let rr = Rect::new(card.x, y, row_w, h);
                if rr.intersects(&self.clip) {
                    let (ins, rbg) = row_meta(r);
                    let ins = ins.unwrap_or(Edges { t: 11.0, l: pad_h, b: 11.0, r: pad_h });
                    if let Some(bgv) = rbg {
                        self.place(&bgv, rr, env);
                    }
                    let link = is_link(r);
                    // row-wide tap targets
                    if let Some(a) = row_action(r) {
                        match a {
                            RowAct::Call(v) => self.hit(rr, Action::Call(v)),
                            RowAct::Push(d) => {
                                if let Some(nav) = &env.nav {
                                    self.hit(rr, Action::Push(nav.clone(), d));
                                }
                            }
                        }
                    }
                    let inner_w = row_w - ins.l - ins.r - if link { 20.0 } else { 0.0 };
                    let rs = self.size(r, P { w: Some(inner_w), h: Some(h - ins.t - ins.b) }, &renv);
                    let cr = Rect::new(rr.x + ins.l, rr.y + ins.t + ((h - ins.t - ins.b) - rs.h) / 2.0, rs.w.min(inner_w).max(if is_fill_row(r) { inner_w } else { 0.0 }), rs.h);
                    self.place(r, Rect::new(cr.x, cr.y, rs.w, rs.h), &renv);
                    if link {
                        let c = col_css(semantic_color("tertiary").unwrap().pick(env.dark));
                        self.op(format!("[\"I\",\"chevron.right\",{},{},14,14,{},600]", n(rr.r() - ins.r - 12.0), n(rr.y + h / 2.0 - 7.0), c));
                    }
                    if ri + 1 < s.rows.len() && row_sep(r) {
                        self.fill(ShapeK::Rect, Rect::new(rr.x + ins.l, rr.b() - 0.5, row_w - ins.l, 0.5), &Paint::Solid(semantic_color("separator").unwrap()), env);
                    }
                }
                y += h;
            }
            if let Some(o) = cold {
                self.pop_clip(o);
            }
            if let Some(f) = &s.footer {
                let mut fe = renv.clone();
                fe.font = FontSpec::named("footnote").unwrap();
                fe.fg = Some(Paint::Solid(semantic_color("secondary").unwrap()));
                let fs = self.size(f, P { w: Some(row_w - pad_h * 2.0), h: None }, &fe);
                self.place(f, Rect::new(rect.x + inset + pad_h, y + 6.0, fs.w, fs.h), &fe);
                y += fs.h + 12.0;
            }
        }
        self.pop_clip(old);
    }

    // ---------------- navigation ----------------

    fn place_nav(&mut self, root: &Rc<View>, id: &Rc<str>, rect: Rect, env: &Env) {
        let rect = self.extend_safe(rect, env);
        let path = match self.it.state.get(&format!("{}.__path", id)) {
            Some(Value::Array(a)) => a.as_ref().clone(),
            _ => vec![],
        };
        let mut top = root.clone();
        if let Some(dest) = path.last() {
            self.it.nav.push(id.clone());
            self.it.idpath.push(Rc::from(format!("{}/p{}", id, path.len())));
            let r = match dest {
                Value::Fn(c) => {
                    let c = c.clone();
                    self.it.call_callable(&c, vec![], Span::default()).and_then(|v| self.it.to_view(&v, Span::default()))
                }
                other => self.it.to_view(other, Span::default()),
            };
            self.it.idpath.pop();
            self.it.nav.pop();
            match r {
                Ok(v) => top = v,
                Err(e) => {
                    self.errors.push(e);
                }
            }
        }
        let meta = nav_meta(&top);
        let hidden = meta.hidden;
        let mut e = env.clone();
        e.nav = Some(id.clone());
        e.full = rect;
        let bar_top = env.safe.y.max(rect.y);
        let bar_h = 52.0;
        let large = !meta.inline && meta.title.is_some() && path.is_empty();
        let large_h = if large { 52.0 } else { 0.0 };
        let content_top = if hidden { bar_top } else { bar_top + bar_h + large_h };
        let safe_b = env.safe.b().min(rect.b());
        e.safe = Rect::new(rect.x, content_top, rect.w, (safe_b - content_top).max(0.0));
        // page background
        self.fill(ShapeK::Rect, rect, &Paint::Solid(semantic_color("systemBackground").unwrap()), env);
        let content = Rect::new(rect.x, content_top, rect.w, (safe_b - content_top).max(0.0));
        let cs = self.size(&top, P { w: Some(content.w), h: Some(content.h) }, &e);
        let cr = Rect::new(content.x + (content.w - cs.w) / 2.0, content.y + (content.h - cs.h) / 2.0, cs.w, cs.h);
        self.place(&top, cr, &e);
        if hidden {
            return;
        }
        // bar
        let mut be = env.clone();
        be.nav = Some(id.clone());
        let bar = Rect::new(rect.x, rect.y, rect.w, bar_top + bar_h + large_h - rect.y);
        self.op(format!("[\"F\",0,{},{},{},{},0,0,0,0,{{\"fade\":{}}}]", n(bar.x), n(bar.y), n(bar.w), n(bar.h), col_css(semantic_color("systemBackground").unwrap().pick(env.dark))));
        let cy = bar_top + bar_h / 2.0;
        let mut lead_x = rect.x + 16.0;
        if !path.is_empty() && !meta.back_hidden {
            let br = Rect::new(lead_x, cy - 22.0, 44.0, 44.0);
            self.glass(br, ShapeK::Circle, &be);
            let c = col_css(semantic_color("primary").unwrap().pick(env.dark));
            self.op(format!("[\"I\",\"chevron.left\",{},{},20,20,{},600]", n(br.x + 12.0), n(br.y + 12.0), c));
            self.hit(br, Action::Pop(id.clone()));
            lead_x += 52.0;
        }
        let mut be2 = be.clone();
        be2.font = FontSpec::body();
        be2.axis = Some(Axis::H);
        for (pl, item) in meta.toolbar.iter() {
            if *pl == -1 {
                let s = self.size(item, P { w: None, h: None }, &be2);
                let pill = Rect::new(lead_x, cy - 22.0, (s.w + 28.0).max(44.0), 44.0);
                self.glass(pill, ShapeK::Capsule, &be2);
                self.place(item, Rect::new(pill.x + (pill.w - s.w) / 2.0, cy - s.h / 2.0, s.w, s.h), &be2);
                lead_x += pill.w + 8.0;
            }
        }
        let mut trail_x = rect.r() - 16.0;
        for (pl, item) in meta.toolbar.iter().rev() {
            if *pl == 1 {
                let s = self.size(item, P { w: None, h: None }, &be2);
                let pill = Rect::new(trail_x - (s.w + 28.0).max(44.0), cy - 22.0, (s.w + 28.0).max(44.0), 44.0);
                self.glass(pill, ShapeK::Capsule, &be2);
                self.place(item, Rect::new(pill.x + (pill.w - s.w) / 2.0, cy - s.h / 2.0, s.w, s.h), &be2);
                trail_x = pill.x - 8.0;
            }
        }
        if let Some((_, item)) = meta.toolbar.iter().find(|x| x.0 == 0) {
            let s = self.size(item, P { w: Some(trail_x - lead_x), h: Some(bar_h) }, &be2);
            self.place(item, Rect::new(rect.x + (rect.w - s.w) / 2.0, cy - s.h / 2.0, s.w, s.h), &be2);
        } else if let Some(t) = &meta.title {
            let mut te = be.clone();
            if large {
                te.font = FontSpec { size: 34.0, weight: 700, italic: false, design: 0 };
                let tv = Rc::new(View { k: VK::Text { s: t.clone(), lit: meta.title_lit, attrs: vec![] }, src: meta.title_src });
                let s = self.size(&tv, P { w: Some(rect.w - 32.0), h: None }, &te);
                self.place(&tv, Rect::new(rect.x + 16.0, bar_top + bar_h + 2.0, s.w, s.h), &te);
            } else {
                te.font = FontSpec { size: 17.0, weight: 600, italic: false, design: 0 };
                te.line_limit = Some(1);
                let tv = Rc::new(View { k: VK::Text { s: t.clone(), lit: meta.title_lit, attrs: vec![] }, src: meta.title_src });
                let maxw = rect.w - 2.0 * (lead_x - rect.x).max(rect.r() - trail_x);
                let s = self.size(&tv, P { w: Some(maxw.max(40.0)), h: None }, &te);
                self.place(&tv, Rect::new(rect.x + (rect.w - s.w) / 2.0, cy - s.h / 2.0, s.w, s.h), &te);
            }
        }
    }

    fn glass(&mut self, r: Rect, shape: ShapeK, env: &Env) {
        self.op("[\"SH\",\"rgba(0,0,0,0.10)\",14,0,4]".into());
        let c = if env.dark { Col::hex(0x2C2C2E, 0.92) } else { Col::hex(0xFFFFFF, 0.92) };
        self.fill(shape, r, &Paint::Solid(c), env);
        self.op("[\"P\"]".into());
        let bc = if env.dark { Col::hex(0xFFFFFF, 0.12) } else { Col::hex(0x000000, 0.06) };
        self.stroke(shape, r, &Paint::Solid(bc), 0.5, env);
    }

    fn place_tabs(&mut self, tabs: &[Rc<View>], selection: &Option<Value>, id: &Rc<str>, rect: Rect, env: &Env) {
        let rect = self.extend_safe(rect, env);
        struct T {
            title: String,
            icon: String,
            badge: Option<String>,
            tag: Option<Value>,
            search: bool,
        }
        let mut items: Vec<T> = vec![];
        for t in tabs {
            let mut cur = t.clone();
            let mut it = T { title: String::new(), icon: String::new(), badge: None, tag: None, search: false };
            loop {
                match &cur.k {
                    VK::Mod(c, m, _) => {
                        match m {
                            Mod::TabItem(lbl) => {
                                let (tt, ic) = label_parts(lbl);
                                it.title = tt;
                                it.icon = ic;
                            }
                            Mod::Badge(v) => {
                                it.badge = match v {
                                    Value::Int(0) | Value::Nil => None,
                                    other => Some(other.describe()),
                                }
                            }
                            Mod::Tag(Value::Sym(s)) if &**s == "__search" => it.search = true,
                            Mod::Tag(v) => {
                                if it.tag.is_none() {
                                    it.tag = Some(v.clone())
                                }
                            }
                            _ => {}
                        }
                        cur = c.clone();
                    }
                    _ => break,
                }
            }
            items.push(it);
        }
        let sel_key = format!("{}.__sel", id);
        let sel_val = match selection {
            Some(b) => Some(self.it.read_binding_v(b)),
            None => None,
        };
        let mut sel = 0usize;
        match &sel_val {
            Some(v) => {
                if let Some(i) = items.iter().position(|t| t.tag.as_ref().map(|x| values_eq(x, v)).unwrap_or(false)) {
                    sel = i;
                }
            }
            None => {
                sel = self.it.state.get(&sel_key).and_then(|v| v.as_i()).unwrap_or(0).max(0) as usize;
            }
        }
        if sel >= tabs.len() {
            sel = 0;
        }
        let bottom_in = env.full.b() - env.safe.b();
        let bar_h = 62.0;
        let bar_y = rect.b() - bottom_in.max(16.0) - bar_h + 12.0;
        let mut e = env.clone();
        e.full = rect;
        e.safe = Rect::new(rect.x, env.safe.y, rect.w, (bar_y - 6.0 - env.safe.y).max(0.0));
        self.tabbar_hidden = false;
        // snapshot outputs so we can redo the content pass if it hides the tab bar
        let snap = (self.ops.len(), self.nops, self.hits.len(), self.actions.len(), self.inputs.len(), self.scrolls.len(), self.elems.len());
        for pass in 0..2 {
            if let Some(t) = tabs.get(sel) {
                let mut ce = e.clone();
                if pass == 0 {
                    ce.safe.h = (bar_y - 6.0 - ce.safe.y).max(0.0);
                } else {
                    ce.safe = env.safe;
                }
                // content fills the whole area; its safe area excludes the floating bar
                let cr = Rect::new(rect.x, ce.safe.y, rect.w, ce.safe.h);
                let cs = self.size(t, P { w: Some(cr.w), h: Some(cr.h) }, &ce);
                self.place(t, align_in(cr, cs, Align::default()), &ce);
            }
            if !self.tabbar_hidden || pass == 1 {
                break;
            }
            self.ops.truncate(snap.0);
            self.nops = snap.1;
            self.hits.truncate(snap.2);
            self.actions.truncate(snap.3);
            self.inputs.truncate(snap.4);
            self.scrolls.truncate(snap.5);
            self.elems.truncate(snap.6);
        }
        if self.tabbar_hidden {
            self.tabbar_hidden = false;
            return;
        }
        let has_search = items.iter().any(|t| t.search);
        let reg: Vec<usize> = (0..items.len()).filter(|i| !items[*i].search).collect();
        let pill_r = rect.r() - 20.0 - if has_search { bar_h + 10.0 } else { 0.0 };
        let pill = Rect::new(rect.x + 20.0, bar_y, pill_r - rect.x - 20.0, bar_h);
        self.glass(pill, ShapeK::Capsule, env);
        let iw = (pill.w - 8.0) / reg.len().max(1) as f64;
        let tint = self.solid(&env.tint.clone(), env);
        let prim = semantic_color("primary").unwrap().pick(env.dark);
        for (k, &i) in reg.iter().enumerate() {
            let t = &items[i];
            let cell = Rect::new(pill.x + 4.0 + k as f64 * iw, pill.y + 4.0, iw, pill.h - 8.0);
            let on = i == sel;
            if on {
                let hc = if env.dark { Col::hex(0xFFFFFF, 0.12) } else { Col::hex(0x000000, 0.06) };
                self.fill(ShapeK::Capsule, cell, &Paint::Solid(hc), env);
            }
            let c = col_css(if on { tint } else { prim });
            let ic = if on && !t.icon.ends_with(".fill") && filled_variant(&t.icon) { format!("{}.fill", t.icon) } else { t.icon.clone() };
            self.op(format!("[\"I\",{},{},{},26,26,{},500]", jstr(&ic), n(cell.x + iw / 2.0 - 13.0), n(cell.y + 6.0), c));
            let f = FontSpec { size: 10.0, weight: 500, italic: false, design: 0 }.css(1.0);
            let tw = measure(&f, &t.title);
            self.op(format!("[\"T\",{},{},{},{},{}]", n(cell.x + (iw - tw) / 2.0), n(cell.y + 46.0), jstr(&f), c, jstr(&t.title)));
            if let Some(b) = &t.badge {
                let bf = FontSpec { size: 12.0, weight: 600, italic: false, design: 0 }.css(1.0);
                let bw = measure(&bf, b).max(8.0) + 10.0;
                let br = Rect::new(cell.x + iw / 2.0 + 6.0, cell.y + 1.0, bw.max(18.0), 18.0);
                self.fill(ShapeK::Capsule, br, &Paint::Solid(semantic_color("red").unwrap()), env);
                let tw = measure(&bf, b);
                self.op(format!("[\"T\",{},{},{},\"rgba(255,255,255,1)\",{}]", n(br.x + (br.w - tw) / 2.0), n(br.y + 13.0), jstr(&bf), jstr(b)));
            }
            let tag = t.tag.clone().unwrap_or(Value::Int(i as i64));
            self.hit(cell, Action::Tab(id.clone(), selection.clone(), tag, i));
        }
        if has_search {
            let i = items.iter().position(|t| t.search).unwrap();
            let sr = Rect::new(pill_r + 10.0, bar_y, bar_h, bar_h);
            self.glass(sr, ShapeK::Circle, env);
            let on = i == sel;
            let c = col_css(if on { tint } else { prim });
            self.op(format!("[\"I\",\"magnifyingglass\",{},{},26,26,{},500]", n(sr.x + 18.0), n(sr.y + 18.0), c));
            let t = &items[i];
            self.hit(sr, Action::Tab(id.clone(), selection.clone(), t.tag.clone().unwrap_or(Value::Int(i as i64)), i));
        }
    }
}

fn filled_variant(icon: &str) -> bool {
    matches!(
        icon,
        "person.crop.circle" | "phone" | "bubble.left.and.bubble.right" | "gearshape" | "house" | "person" | "message" | "bell" | "star" | "heart" | "bubble.left" | "person.2" | "folder" | "bookmark"
    )
}

fn label_parts(v: &Rc<View>) -> (String, String) {
    let mut title = String::new();
    let mut icon = String::new();
    fn walk(v: &Rc<View>, t: &mut String, i: &mut String) {
        match &v.k {
            VK::Label { title, icon } => {
                walk(title, t, i);
                walk(icon, t, i);
            }
            VK::Text { s, .. } => {
                if t.is_empty() {
                    *t = s.to_string()
                }
            }
            VK::Image { name, .. } => {
                if i.is_empty() {
                    *i = name.to_string()
                }
            }
            VK::Mod(c, _, _) => walk(c, t, i),
            VK::Stack { children, .. } | VK::Group(children) => {
                for c in children {
                    walk(c, t, i)
                }
            }
            _ => {}
        }
    }
    walk(v, &mut title, &mut icon);
    (title, icon)
}

struct NavMeta {
    title: Option<Rc<str>>,
    title_lit: Option<Span>,
    title_src: Span,
    inline: bool,
    toolbar: Vec<(i8, Rc<View>)>,
    hidden: bool,
    back_hidden: bool,
}

fn nav_meta(v: &Rc<View>) -> NavMeta {
    let mut m = NavMeta { title: None, title_lit: None, title_src: Span::default(), inline: false, toolbar: vec![], hidden: false, back_hidden: false };
    let mut inline_set = false;
    fn walk(v: &Rc<View>, m: &mut NavMeta, inline_set: &mut bool, depth: u32) {
        if depth > 12 {
            return;
        }
        match &v.k {
            VK::Mod(c, md, sp) => {
                match md {
                    Mod::NavTitle(t) => {
                        if m.title.is_none() {
                            m.title = Some(t.clone());
                            m.title_src = *sp;
                            // literal inside navigationTitle("...") starts after `("`
                            let s = sp.s as usize + "navigationTitle(\"".len() + 1;
                            m.title_lit = Some(Span::new(s, s + t.len()));
                        }
                    }
                    Mod::NavTitleInline(i) => {
                        if !*inline_set {
                            m.inline = *i;
                            *inline_set = true;
                        }
                    }
                    Mod::Toolbar(items) => {
                        if m.toolbar.is_empty() {
                            m.toolbar = items.clone();
                        }
                    }
                    Mod::BarHidden(h) => m.hidden = m.hidden || *h,
                    Mod::BackHidden => m.back_hidden = true,
                    _ => {}
                }
                walk(c, m, inline_set, depth + 1);
            }
            VK::Stack { children, .. } | VK::Group(children) => {
                for c in children {
                    walk(c, m, inline_set, depth + 1);
                }
            }
            VK::Scroll { child, .. } => walk(child, m, inline_set, depth + 1),
            VK::List { children, .. } => {
                for c in children.iter().take(3) {
                    walk(c, m, inline_set, depth + 1);
                }
            }
            _ => {}
        }
    }
    walk(v, &mut m, &mut inline_set, 0);
    m
}

fn layout_priority(v: &Rc<View>) -> f64 {
    let mut cur = v;
    loop {
        match &cur.k {
            VK::Mod(c, Mod::LayoutPriority(p), _) => {
                let _ = c;
                return *p;
            }
            VK::Mod(c, _, _) => cur = c,
            _ => return 0.0,
        }
    }
}

enum RowAct {
    Call(Value),
    Push(Value),
}

fn row_action(v: &Rc<View>) -> Option<RowAct> {
    let mut cur = v;
    loop {
        match &cur.k {
            VK::Mod(c, _, _) => cur = c,
            VK::Button { action, .. } => return Some(RowAct::Call(action.clone())),
            VK::NavLink { dest, .. } => return Some(RowAct::Push(dest.clone())),
            _ => return None,
        }
    }
}

fn is_link(v: &Rc<View>) -> bool {
    matches!(row_action(v), Some(RowAct::Push(_)))
}

fn is_fill_row(v: &Rc<View>) -> bool {
    let mut cur = v;
    loop {
        match &cur.k {
            VK::Mod(c, _, _) => cur = c,
            VK::Toggle { .. } | VK::TextField { .. } => return true,
            _ => return false,
        }
    }
}

fn row_meta(v: &Rc<View>) -> (Option<Edges>, Option<Rc<View>>) {
    let mut cur = v;
    let mut ins = None;
    let mut bg = None;
    loop {
        match &cur.k {
            VK::Mod(c, m, _) => {
                match m {
                    Mod::ListRowInsets(e) => {
                        if ins.is_none() {
                            ins = Some(e.unwrap_or(Edges { t: 11.0, l: 20.0, b: 11.0, r: 20.0 }))
                        }
                    }
                    Mod::ListRowBackground(b) => bg = Some(b.clone()),
                    _ => {}
                }
                cur = c;
            }
            _ => return (ins, bg),
        }
    }
}

fn row_sep(v: &Rc<View>) -> bool {
    let mut cur = v;
    loop {
        match &cur.k {
            VK::Mod(_, Mod::ListRowSeparator(false), _) => return false,
            VK::Mod(c, _, _) => cur = c,
            _ => return true,
        }
    }
}

pub fn align_in(r: Rect, s: Size, a: Align) -> Rect {
    let x = match a.h {
        -1 => r.x,
        1 => r.r() - s.w,
        _ => r.x + (r.w - s.w) / 2.0,
    };
    let y = match a.v {
        -1 => r.y,
        1 => r.b() - s.h,
        _ => r.y + (r.h - s.h) / 2.0,
    };
    Rect::new(x, y, s.w, s.h)
}

fn kind_name(k: &VK) -> &'static str {
    match k {
        VK::Text { .. } => "Text",
        VK::Image { .. } => "Image",
        VK::Shape { .. } => "Shape",
        VK::Spacer(_) => "Spacer",
        VK::Divider => "Divider",
        VK::Stack { axis: Axis::V, .. } => "VStack",
        VK::Stack { axis: Axis::H, .. } => "HStack",
        VK::Stack { axis: Axis::Z, .. } => "ZStack",
        VK::Grid { .. } => "Grid",
        VK::Group(_) => "Group",
        VK::Scroll { .. } => "ScrollView",
        VK::List { .. } => "List",
        VK::Section { .. } => "Section",
        VK::Button { .. } => "Button",
        VK::TextField { .. } => "TextField",
        VK::Toggle { .. } => "Toggle",
        VK::NavStack { .. } => "NavigationStack",
        VK::NavLink { .. } => "NavigationLink",
        VK::Tabs { .. } => "TabView",
        VK::Label { .. } => "Label",
        VK::Pushed { .. } => "View",
        VK::Mod(..) => "Modified",
        VK::Empty => "Empty",
    }
}

fn mod_name(m: &Mod) -> &'static str {
    match m {
        Mod::Padding(_) => "padding",
        Mod::Frame { .. } | Mod::FlexFrame { .. } => "frame",
        Mod::Background(..) => "background",
        Mod::Overlay(..) => "overlay",
        Mod::Font(_) => "font",
        Mod::FontWeight(_) => "fontWeight",
        Mod::Fg(_) => "foregroundStyle",
        Mod::Clip(_) => "clipShape",
        Mod::Opacity(_) => "opacity",
        Mod::Shadow(..) => "shadow",
        Mod::Offset(..) => "offset",
        Mod::OnTap(_) => "onTapGesture",
        _ => "modifier",
    }
}

impl Interp {
    pub fn read_binding_val(&mut self, b: &Value) -> String {
        match self.read_binding_v(b) {
            Value::Nil => String::new(),
            v => v.describe(),
        }
    }
    pub fn read_binding_v(&mut self, b: &Value) -> Value {
        match b {
            Value::Binding(bb) => {
                let bb = bb.clone();
                Interp::read_binding(self, &bb)
            }
            other => other.clone(),
        }
    }
}

