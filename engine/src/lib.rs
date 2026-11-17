pub mod ast;
pub mod interp;
pub mod layout;
pub mod lexer;
pub mod methods;
pub mod parser;
pub mod value;
pub mod views;

use interp::{Interp, RtErr};
use layout::{jstr, Action, Env, Lay, Rect, P};
use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;
use value::*;

pub struct Instance {
    pub src: String,
    pub interp: Option<Interp>,
    pub compile_err: Option<(usize, String)>,
    pub preview: String,
    pub w: f64,
    pub h: f64,
    pub top: f64,
    pub bottom: f64,
    pub dark: bool,
    pub actions: Vec<Action>,
    pub hits: Vec<(Rect, usize)>,
    pub inputs: Vec<layout::Input>,
    pub scrolls: Vec<layout::ScrollRegion>,
    pub focused: Option<(Rc<str>, Value, Option<Value>)>,
    pub saved_state: Option<(HashMap<String, Value>, HashMap<String, f64>)>,
    pub texts: Vec<(Rect, String)>,
}

impl Instance {
    pub fn new() -> Instance {
        Instance {
            src: String::new(),
            interp: None,
            compile_err: None,
            preview: String::new(),
            w: 402.0,
            h: 874.0,
            top: 62.0,
            bottom: 34.0,
            dark: false,
            actions: vec![],
            hits: vec![],
            inputs: vec![],
            scrolls: vec![],
            focused: None,
            saved_state: None,
            texts: vec![],
        }
    }

    pub fn set_source(&mut self, src: &str) -> String {
        self.src = src.to_string();
        // keep view state across edits
        let keep = self.interp.take().map(|i| (i.state, i.ui)).or(self.saved_state.take());
        match parser::parse_program(src) {
            Ok(prog) => {
                let mut it = Interp::new(prog);
                if let Some((s, u)) = keep {
                    it.state = s;
                    it.ui = u;
                }
                let previews: Vec<String> = it.previews.iter().map(|p| jstr(&p.0)).collect();
                let types: Vec<String> = it.types.values().filter(|t| t.is_view()).map(|t| jstr(&t.name)).collect();
                self.interp = Some(it);
                self.compile_err = None;
                format!("{{\"ok\":true,\"previews\":[{}],\"views\":[{}]}}", previews.join(","), types.join(","))
            }
            Err((pos, msg)) => {
                self.saved_state = keep;
                self.compile_err = Some((pos, msg.clone()));
                format!("{{\"ok\":false,\"error\":{{\"pos\":{},\"msg\":{}}}}}", pos, jstr(&msg))
            }
        }
    }

    fn root_value(it: &mut Interp, preview: &str) -> Result<Value, RtErr> {
        let pv = it.previews.iter().find(|p| &*p.0 == preview).or(it.previews.first()).map(|p| (p.1.clone(), p.2));
        if let Some((body, _)) = pv {
            let sc = Scope::new(Some(it.globals.clone()));
            return it.run_body(&body.body, &sc);
        }
        if let Some(m) = it.main.clone() {
            return it.construct(&m, vec![], &[], ast::Span::default(), ast::Span::default());
        }
        if it.types.contains_key("ContentView") {
            return it.construct("ContentView", vec![], &[], ast::Span::default(), ast::Span::default());
        }
        Err(RtErr { span: ast::Span::default(), msg: "No #Preview, @main App or ContentView found".into() })
    }

    pub fn render(&mut self) -> String {
        if let Some((pos, msg)) = &self.compile_err {
            return format!("{{\"error\":{{\"pos\":{},\"msg\":{},\"kind\":\"compile\"}}}}", pos, jstr(msg));
        }
        let Some(it) = self.interp.as_mut() else { return "{\"error\":{\"pos\":0,\"msg\":\"no source\"}}".into() };
        it.steps = 0;
        it.depth = 0;
        it.dark = self.dark;
        it.warnings.clear();
        it.idpath = vec![Rc::from(format!("root:{}", self.preview))];
        it.nav.clear();
        let root = Self::root_value(it, &self.preview).and_then(|v| it.to_view(&v, ast::Span::default()));
        let root = match root {
            Ok(r) => r,
            Err(e) => {
                return format!("{{\"error\":{{\"pos\":{},\"end\":{},\"msg\":{},\"kind\":\"runtime\"}}}}", e.span.s, e.span.e, jstr(&e.msg));
            }
        };
        let full = Rect::new(0.0, 0.0, self.w, self.h);
        let safe = Rect::new(0.0, self.top, self.w, self.h - self.top - self.bottom);
        let env = Env::root(self.dark, full, safe);
        let focused_id = self.focused.as_ref().map(|f| f.0.clone());
        let mut lay = Lay::new(it, full);
        lay.focused = focused_id;
        let bg = Paint::Solid(semantic_color("systemBackground").unwrap());
        let _ = bg;
        let s = lay.size(&root, P { w: Some(safe.w), h: Some(safe.h) }, &env);
        let r = layout::align_in(safe, s, Align::default());
        lay.place(&root, r, &env);
        let mut out = String::with_capacity(lay.ops.len() + 4096);
        out.push_str("{\"ops\":[");
        out.push_str(&lay.ops);
        out.push_str("],\"elems\":[");
        for (i, e) in lay.elems.iter().enumerate() {
            if i > 0 {
                out.push(',');
            }
            let mods: Vec<String> = e.mods.iter().map(|(sp, nm)| format!("[{},{},\"{}\"]", sp.s, sp.e, nm)).collect();
            let font = e.font.map(|f| format!("[{},{},{}]", f.size, f.weight, f.design)).unwrap_or("null".into());
            let col = e.color.map(|c| format!("[{:.3},{:.3},{:.3},{:.3}]", c[0], c[1], c[2], c[3])).unwrap_or("null".into());
            out.push_str(&format!(
                "[{:.2},{:.2},{:.2},{:.2},\"{}\",{},{},{},{},[{}],{},{},{},{}]",
                e.rect.x,
                e.rect.y,
                e.rect.w,
                e.rect.h,
                e.kind,
                e.src.s,
                e.src.e,
                e.lit.map(|l| l.s as i64).unwrap_or(-1),
                e.lit.map(|l| l.e as i64).unwrap_or(-1),
                mods.join(","),
                font,
                col,
                e.text.as_ref().map(|t| jstr(t)).unwrap_or("null".into()),
                e.depth
            ));
        }
        out.push_str("],\"errors\":[");
        let errs: Vec<String> = lay.errors.iter().map(|e| format!("{{\"pos\":{},\"msg\":{}}}", e.span.s, jstr(&e.msg))).collect();
        out.push_str(&errs.join(","));
        out.push_str("],\"inputs\":[");
        let ins: Vec<String> = lay
            .inputs
            .iter()
            .map(|i| format!("[{:.2},{:.2},{:.2},{:.2},{},{},{},{},{}]", i.rect.x, i.rect.y, i.rect.w, i.rect.h, jstr(&i.id), jstr(&i.font), i.color, i.multiline, jstr(&i.value)))
            .collect();
        out.push_str(&ins.join(","));
        out.push_str("],\"warnings\":[");
        let ws: Vec<String> = lay.it.warnings.iter().map(|(sp, m)| format!("{{\"pos\":{},\"msg\":{}}}", sp.s, jstr(m))).collect();
        out.push_str(&ws.join(","));
        out.push_str("]}");
        self.texts = lay.elems.iter().filter_map(|e| e.text.as_ref().map(|t| (e.rect, t.to_string()))).collect();
        self.actions = std::mem::take(&mut lay.actions);
        self.hits = std::mem::take(&mut lay.hits);
        self.inputs = std::mem::take(&mut lay.inputs);
        self.scrolls = std::mem::take(&mut lay.scrolls);
        out
    }

    pub fn tap(&mut self, x: f64, y: f64) -> String {
        let hit = self.hits.iter().rev().find(|(r, _)| r.contains(x, y)).map(|h| h.1);
        let Some(ai) = hit else {
            let had = self.focused.take().is_some();
            return format!("{{\"changed\":{}}}", had);
        };
        let Some(it) = self.interp.as_mut() else { return "{\"changed\":false}".into() };
        it.steps = 0;
        let mut focus = String::new();
        let res: Result<(), RtErr> = match &self.actions[ai] {
            Action::Call(v) => {
                let v = v.clone();
                self.focused = None;
                it.call_fn(&v, vec![], ast::Span::default()).map(|_| ())
            }
            Action::Push(nav, dest) => {
                let key = format!("{}.__path", nav);
                let mut p = match it.state.get(&key) {
                    Some(Value::Array(a)) => a.as_ref().clone(),
                    _ => vec![],
                };
                p.push(dest.clone());
                it.state.insert(key, Value::Array(Rc::new(p)));
                self.focused = None;
                Ok(())
            }
            Action::Pop(nav) => {
                let key = format!("{}.__path", nav);
                if let Some(Value::Array(a)) = it.state.get(&key).cloned() {
                    let mut p = a.as_ref().clone();
                    p.pop();
                    it.state.insert(key, Value::Array(Rc::new(p)));
                }
                self.focused = None;
                Ok(())
            }
            Action::Tab(id, sel, tag, idx) => {
                match sel {
                    Some(Value::Binding(b)) => {
                        let b = b.clone();
                        it.write_binding(&b, tag.clone());
                    }
                    _ => {
                        it.state.insert(format!("{}.__sel", id), Value::Int(*idx as i64));
                    }
                }
                self.focused = None;
                Ok(())
            }
            Action::Toggle(b) => {
                if let Value::Binding(bb) = b {
                    let bb = bb.clone();
                    let cur = it.read_binding(&bb).truthy();
                    it.write_binding(&bb, Value::Bool(!cur));
                }
                Ok(())
            }
            Action::Focus(i) => {
                if let Some(inp) = self.inputs.get(*i) {
                    self.focused = Some((inp.id.clone(), inp.binding.clone(), inp.submit.clone()));
                    focus = format!(
                        ",\"focus\":{{\"x\":{:.2},\"y\":{:.2},\"w\":{:.2},\"h\":{:.2},\"font\":{},\"color\":{},\"value\":{},\"placeholder\":{},\"multiline\":{},\"secure\":{}}}",
                        inp.rect.x,
                        inp.rect.y,
                        inp.rect.w,
                        inp.rect.h,
                        jstr(&inp.font),
                        inp.color,
                        jstr(&inp.value),
                        jstr(&inp.placeholder),
                        inp.multiline,
                        inp.secure
                    );
                }
                Ok(())
            }
        };
        match res {
            Ok(()) => format!("{{\"changed\":true{}}}", focus),
            Err(e) => format!("{{\"changed\":true,\"error\":{{\"pos\":{},\"msg\":{}}}}}", e.span.s, jstr(&e.msg)),
        }
    }

    pub fn input(&mut self, text: &str) {
        if let (Some((_, b, _)), Some(it)) = (&self.focused, self.interp.as_mut()) {
            if let Value::Binding(bb) = b {
                let bb = bb.clone();
                it.write_binding(&bb, Value::s(text));
            }
        }
    }

    pub fn submit(&mut self) -> String {
        let sub = self.focused.as_ref().and_then(|f| f.2.clone());
        if let (Some(s), Some(it)) = (sub, self.interp.as_mut()) {
            it.steps = 0;
            if let Err(e) = it.call_fn(&s, vec![], ast::Span::default()) {
                return format!("{{\"error\":{{\"pos\":{},\"msg\":{}}}}}", e.span.s, jstr(&e.msg));
            }
        }
        "{}".into()
    }

    pub fn scroll(&mut self, x: f64, y: f64, dx: f64, dy: f64) -> bool {
        let horizontal = dx.abs() > dy.abs();
        let reg = self
            .scrolls
            .iter()
            .rev()
            .find(|s| s.rect.contains(x, y) && s.horizontal == horizontal && s.max > 0.0)
            .or_else(|| self.scrolls.iter().rev().find(|s| s.rect.contains(x, y) && s.max > 0.0));
        let Some(r) = reg else { return false };
        let Some(it) = self.interp.as_mut() else { return false };
        let d = if r.horizontal { if horizontal { dx } else { dy } } else { dy };
        let key = r.id.to_string();
        let cur = it.ui.get(&key).cloned().unwrap_or(0.0);
        let nv = (cur + d).clamp(0.0, r.max);
        if (nv - cur).abs() < 0.01 {
            return false;
        }
        it.ui.insert(key, nv);
        let pin = format!("{}:pin", r.id);
        if it.ui.contains_key(&pin) {
            it.ui.insert(pin, if nv >= r.max - 1.0 { 1.0 } else { 0.0 });
        }
        true
    }

    pub fn reset(&mut self) {
        if let Some(it) = self.interp.as_mut() {
            it.state.clear();
            it.ui.clear();
        }
        self.saved_state = None;
        self.focused = None;
    }
}

// ---------------- wasm ABI ----------------

thread_local! {
    static INST: RefCell<HashMap<u32, Instance>> = RefCell::new(HashMap::new());
    static NEXT: RefCell<u32> = RefCell::new(1);
    static OUT: RefCell<Vec<u8>> = RefCell::new(Vec::new());
}

fn set_out(s: String) -> *const u8 {
    OUT.with(|o| {
        let mut o = o.borrow_mut();
        *o = s.into_bytes();
        o.as_ptr()
    })
}

unsafe fn read_str(p: *const u8, l: usize) -> String {
    if l == 0 {
        return String::new();
    }
    let s = std::slice::from_raw_parts(p, l);
    String::from_utf8_lossy(s).into_owned()
}

fn with<R>(id: u32, f: impl FnOnce(&mut Instance) -> R, d: R) -> R {
    INST.with(|m| match m.borrow_mut().get_mut(&id) {
        Some(i) => f(i),
        None => d,
    })
}

#[no_mangle]
pub extern "C" fn sb_alloc(len: usize) -> *mut u8 {
    let mut v = Vec::<u8>::with_capacity(len.max(1));
    let p = v.as_mut_ptr();
    std::mem::forget(v);
    p
}

#[no_mangle]
pub unsafe extern "C" fn sb_free(p: *mut u8, len: usize) {
    drop(Vec::from_raw_parts(p, 0, len.max(1)));
}

#[no_mangle]
pub extern "C" fn sb_out_len() -> usize {
    OUT.with(|o| o.borrow().len())
}

#[no_mangle]
pub extern "C" fn sb_create() -> u32 {
    let id = NEXT.with(|n| {
        let mut n = n.borrow_mut();
        let id = *n;
        *n += 1;
        id
    });
    INST.with(|m| m.borrow_mut().insert(id, Instance::new()));
    id
}

#[no_mangle]
pub extern "C" fn sb_destroy(id: u32) {
    INST.with(|m| m.borrow_mut().remove(&id));
}

#[no_mangle]
pub unsafe extern "C" fn sb_set_source(id: u32, p: *const u8, l: usize) -> *const u8 {
    let src = read_str(p, l);
    let r = with(id, |i| i.set_source(&src), "{}".into());
    set_out(r)
}

#[no_mangle]
pub unsafe extern "C" fn sb_config(id: u32, w: f64, h: f64, top: f64, bottom: f64, dark: u32, p: *const u8, l: usize) {
    let pv = read_str(p, l);
    with(
        id,
        |i| {
            i.w = w;
            i.h = h;
            i.top = top;
            i.bottom = bottom;
            i.dark = dark != 0;
            i.preview = pv;
        },
        (),
    )
}

#[no_mangle]
pub extern "C" fn sb_render(id: u32) -> *const u8 {
    let r = with(id, |i| i.render(), "{}".into());
    set_out(r)
}

#[no_mangle]
pub extern "C" fn sb_tap(id: u32, x: f64, y: f64) -> *const u8 {
    let r = with(id, |i| i.tap(x, y), "{}".into());
    set_out(r)
}

#[no_mangle]
pub extern "C" fn sb_scroll(id: u32, x: f64, y: f64, dx: f64, dy: f64) -> u32 {
    with(id, |i| i.scroll(x, y, dx, dy) as u32, 0)
}

#[no_mangle]
pub unsafe extern "C" fn sb_input(id: u32, p: *const u8, l: usize) {
    let s = read_str(p, l);
    with(id, |i| i.input(&s), ())
}

#[no_mangle]
pub extern "C" fn sb_submit(id: u32) -> *const u8 {
    let r = with(id, |i| i.submit(), "{}".into());
    set_out(r)
}

#[no_mangle]
pub extern "C" fn sb_blur(id: u32) {
    with(id, |i| i.focused = None, ())
}

#[no_mangle]
pub extern "C" fn sb_reset(id: u32) {
    with(id, |i| i.reset(), ())
}

// copy state from one instance to another (used when branching a frame)
#[no_mangle]
pub extern "C" fn sb_clone_state(from: u32, to: u32) {
    INST.with(|m| {
        let mut m = m.borrow_mut();
        let st = m.get(&from).and_then(|i| i.interp.as_ref().map(|it| (it.state.clone(), it.ui.clone())));
        if let (Some(st), Some(dst)) = (st, m.get_mut(&to)) {
            match dst.interp.as_mut() {
                Some(it) => {
                    it.state = st.0;
                    it.ui = st.1;
                }
                None => dst.saved_state = Some(st),
            }
        }
    })
}
