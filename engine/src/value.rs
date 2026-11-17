use crate::ast::{Closure, Func, Span};
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Col {
    pub l: [f32; 4],
    pub d: [f32; 4],
}

impl Col {
    pub fn rgb(r: f64, g: f64, b: f64, a: f64) -> Col {
        let c = [r as f32, g as f32, b as f32, a as f32];
        Col { l: c, d: c }
    }
    pub fn hex(h: u32, a: f64) -> Col {
        Col::rgb(((h >> 16) & 255) as f64 / 255.0, ((h >> 8) & 255) as f64 / 255.0, (h & 255) as f64 / 255.0, a)
    }
    pub fn dyn_hex(l: u32, la: f64, d: u32, da: f64) -> Col {
        Col { l: Col::hex(l, la).l, d: Col::hex(d, da).l }
    }
    pub fn with_alpha(mut self, a: f64) -> Col {
        self.l[3] *= a as f32;
        self.d[3] *= a as f32;
        self
    }
    pub fn pick(&self, dark: bool) -> [f32; 4] {
        if dark {
            self.d
        } else {
            self.l
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum Paint {
    Solid(Col),
    Linear(Vec<(Col, f64)>, (f64, f64), (f64, f64)),
    Radial(Vec<(Col, f64)>, f64, f64),
    Material(f64),
    Tint,
}

impl Paint {
    pub fn opacity(&self, a: f64) -> Paint {
        match self {
            Paint::Solid(c) => Paint::Solid(c.with_alpha(a)),
            Paint::Linear(s, p, q) => Paint::Linear(s.iter().map(|(c, o)| (c.with_alpha(a), *o)).collect(), *p, *q),
            Paint::Radial(s, r0, r1) => Paint::Radial(s.iter().map(|(c, o)| (c.with_alpha(a), *o)).collect(), *r0, *r1),
            Paint::Material(m) => Paint::Material(m * a),
            Paint::Tint => Paint::Tint,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct FontSpec {
    pub size: f64,
    pub weight: u16,
    pub italic: bool,
    pub design: u8, // 0 default 1 rounded 2 mono 3 serif
}

impl FontSpec {
    pub fn body() -> FontSpec {
        FontSpec { size: 17.0, weight: 400, italic: false, design: 0 }
    }
    pub fn named(n: &str) -> Option<FontSpec> {
        let (s, w) = match n {
            "largeTitle" => (34.0, 400),
            "title" => (28.0, 400),
            "title2" => (22.0, 400),
            "title3" => (20.0, 400),
            "headline" => (17.0, 600),
            "body" => (17.0, 400),
            "callout" => (16.0, 400),
            "subheadline" => (15.0, 400),
            "footnote" => (13.0, 400),
            "caption" => (12.0, 400),
            "caption2" => (11.0, 400),
            _ => return None,
        };
        Some(FontSpec { size: s, weight: w, italic: false, design: 0 })
    }
    pub fn css(&self, scale: f64) -> String {
        let fam = match self.design {
            1 => "\"SF Pro Rounded\", ui-rounded, Inter, system-ui, sans-serif",
            2 => "\"SF Mono\", ui-monospace, Menlo, monospace",
            3 => "\"New York\", ui-serif, Georgia, serif",
            _ => "-apple-system, \"SF Pro Text\", Inter, system-ui, sans-serif",
        };
        format!("{}{} {}px {}", if self.italic { "italic " } else { "" }, self.weight, fmtf(self.size * scale), fam)
    }
}

pub fn weight_named(n: &str) -> Option<u16> {
    Some(match n {
        "ultraLight" => 100,
        "thin" => 200,
        "light" => 300,
        "regular" => 400,
        "medium" => 500,
        "semibold" => 600,
        "bold" => 700,
        "heavy" => 800,
        "black" => 900,
        _ => return None,
    })
}

pub fn fmtf(f: f64) -> String {
    if (f - f.round()).abs() < 1e-6 {
        format!("{}", f.round() as i64)
    } else {
        format!("{:.2}", f)
    }
}

pub fn semantic_color(n: &str) -> Option<Col> {
    Some(match n {
        "red" => Col::dyn_hex(0xFF3B30, 1.0, 0xFF453A, 1.0),
        "orange" => Col::dyn_hex(0xFF9500, 1.0, 0xFF9F0A, 1.0),
        "yellow" => Col::dyn_hex(0xFFCC00, 1.0, 0xFFD60A, 1.0),
        "green" => Col::dyn_hex(0x34C759, 1.0, 0x30D158, 1.0),
        "mint" => Col::dyn_hex(0x00C7BE, 1.0, 0x63E6E2, 1.0),
        "teal" => Col::dyn_hex(0x30B0C7, 1.0, 0x40C8E0, 1.0),
        "cyan" => Col::dyn_hex(0x32ADE6, 1.0, 0x64D2FF, 1.0),
        "blue" | "accentColor" => Col::dyn_hex(0x007AFF, 1.0, 0x0A84FF, 1.0),
        "indigo" => Col::dyn_hex(0x5856D6, 1.0, 0x5E5CE6, 1.0),
        "purple" => Col::dyn_hex(0xAF52DE, 1.0, 0xBF5AF2, 1.0),
        "pink" => Col::dyn_hex(0xFF2D55, 1.0, 0xFF375F, 1.0),
        "brown" => Col::dyn_hex(0xA2845E, 1.0, 0xAC8E68, 1.0),
        "gray" => Col::dyn_hex(0x8E8E93, 1.0, 0x8E8E93, 1.0),
        "black" => Col::hex(0x000000, 1.0),
        "white" => Col::hex(0xFFFFFF, 1.0),
        "clear" => Col::hex(0x000000, 0.0),
        "primary" | "label" => Col::dyn_hex(0x000000, 1.0, 0xFFFFFF, 1.0),
        "secondary" | "secondaryLabel" => Col::dyn_hex(0x3C3C43, 0.6, 0xEBEBF5, 0.6),
        "tertiary" | "tertiaryLabel" => Col::dyn_hex(0x3C3C43, 0.3, 0xEBEBF5, 0.3),
        "quaternary" | "quaternaryLabel" => Col::dyn_hex(0x3C3C43, 0.18, 0xEBEBF5, 0.16),
        "systemBackground" | "background" => Col::dyn_hex(0xFFFFFF, 1.0, 0x000000, 1.0),
        "secondarySystemBackground" => Col::dyn_hex(0xF2F2F7, 1.0, 0x1C1C1E, 1.0),
        "tertiarySystemBackground" => Col::dyn_hex(0xFFFFFF, 1.0, 0x2C2C2E, 1.0),
        "systemGroupedBackground" => Col::dyn_hex(0xF2F2F7, 1.0, 0x000000, 1.0),
        "secondarySystemGroupedBackground" => Col::dyn_hex(0xFFFFFF, 1.0, 0x1C1C1E, 1.0),
        "systemFill" => Col::dyn_hex(0x787880, 0.2, 0x787880, 0.36),
        "secondarySystemFill" => Col::dyn_hex(0x787880, 0.16, 0x787880, 0.32),
        "tertiarySystemFill" => Col::dyn_hex(0x767680, 0.12, 0x767680, 0.24),
        "quaternarySystemFill" => Col::dyn_hex(0x747480, 0.08, 0x767680, 0.18),
        "separator" => Col::dyn_hex(0x3C3C43, 0.29, 0x545458, 0.6),
        "systemGray" => Col::hex(0x8E8E93, 1.0),
        "systemGray2" => Col::dyn_hex(0xAEAEB2, 1.0, 0x636366, 1.0),
        "systemGray3" => Col::dyn_hex(0xC7C7CC, 1.0, 0x48484A, 1.0),
        "systemGray4" => Col::dyn_hex(0xD1D1D6, 1.0, 0x3A3A3C, 1.0),
        "systemGray5" => Col::dyn_hex(0xE5E5EA, 1.0, 0x2C2C2E, 1.0),
        "systemGray6" => Col::dyn_hex(0xF2F2F7, 1.0, 0x1C1C1E, 1.0),
        "systemBlue" => Col::dyn_hex(0x007AFF, 1.0, 0x0A84FF, 1.0),
        "systemRed" => Col::dyn_hex(0xFF3B30, 1.0, 0xFF453A, 1.0),
        "systemGreen" => Col::dyn_hex(0x34C759, 1.0, 0x30D158, 1.0),
        _ => return None,
    })
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ShapeK {
    Rect,
    Round(f64),
    Circle,
    Capsule,
    Ellipse,
    Uneven([f64; 4]), // tl tr br bl
}

#[derive(Clone, Copy, Debug, PartialEq, Default)]
pub struct Align {
    pub h: i8, // -1 leading 0 center 1 trailing
    pub v: i8, // -1 top 0 center 1 bottom
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Axis {
    H,
    V,
    Z,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Edges {
    pub t: f64,
    pub l: f64,
    pub b: f64,
    pub r: f64,
}

#[derive(Clone, Debug)]
pub enum Mod {
    Padding(Edges),
    Frame { w: Option<f64>, h: Option<f64>, align: Align },
    FlexFrame { min_w: Option<f64>, max_w: Option<f64>, min_h: Option<f64>, max_h: Option<f64>, ideal_w: Option<f64>, ideal_h: Option<f64>, align: Align },
    Background(Rc<View>, Align, bool), // view, alignment, is shape style (extends into safe area)
    Overlay(Rc<View>, Align),
    Font(FontSpec),
    FontWeight(u16),
    FontSize(f64),
    Italic,
    Design(u8),
    Fg(Paint),
    Tint(Paint),
    Clip(ShapeK),
    Opacity(f64),
    Offset(f64, f64),
    Shadow(Col, f64, f64, f64),
    OnTap(Value),
    OnSubmit(Value),
    IgnoresSafeArea,
    LineLimit(Option<u32>),
    TextAlign(i8),
    Scheme(bool),
    TabItem(Rc<View>),
    Badge(Value),
    Tag(Value),
    NavTitle(Rc<str>),
    NavTitleInline(bool),
    Toolbar(Vec<(i8, Rc<View>)>), // placement -1 leading 1 trailing 0 principal 2 bottom
    BarHidden(bool),
    BackHidden,
    FixedSize(bool, bool),
    LayoutPriority(f64),
    ScrollBottom,
    Border(Paint, f64),
    StrokeOverlay(ShapeK, Paint, f64),
    Rotation(f64),
    Scale(f64),
    PlainButton,
    Strikethrough,
    Underline,
    Monospaced,
    TextCase(bool),
    Kerning(f64),
    Hidden,
    Disabled(bool),
    ListRowInsets(Option<Edges>),
    ListRowSeparator(bool),
    ListRowBackground(Rc<View>),
    Blur(f64),
    Inset(bool, Rc<View>),
    Ignored,
}

#[derive(Debug)]
pub struct View {
    pub k: VK,
    pub src: Span,
}

#[derive(Debug)]
pub enum VK {
    Text { s: Rc<str>, lit: Option<Span>, attrs: Vec<(Rc<str>, Option<FontSpec>, Option<Paint>, bool)> },
    Image { name: Rc<str>, system: bool, resizable: bool, fit: Option<bool>, render_orig: bool },
    Shape { shape: ShapeK, fill: Option<Paint>, stroke: Option<(Paint, f64)>, inset: f64 },
    Spacer(f64),
    Divider,
    Stack { axis: Axis, align: Align, spacing: Option<f64>, children: Vec<Rc<View>>, lazy: bool },
    Grid { cols: usize, spacing: f64, children: Vec<Rc<View>> },
    Group(Vec<Rc<View>>),
    Scroll { axis: Axis, child: Rc<View>, id: Rc<str>, indicators: bool },
    List { children: Vec<Rc<View>>, id: Rc<str>, grouped: bool },
    Section { header: Option<Rc<View>>, footer: Option<Rc<View>>, children: Vec<Rc<View>> },
    Button { action: Value, label: Rc<View>, role_destructive: bool },
    TextField { placeholder: Rc<str>, binding: Value, id: Rc<str>, secure: bool, multiline: bool },
    Toggle { binding: Value, label: Rc<View> },
    NavStack { root: Rc<View>, id: Rc<str> },
    NavLink { dest: Value, label: Rc<View> },
    Tabs { tabs: Vec<Rc<View>>, selection: Option<Value>, id: Rc<str> },
    Label { title: Rc<View>, icon: Rc<View> },
    Pushed { view: Rc<View>, nav: Rc<str> },
    Mod(Rc<View>, Mod, Span),
    Empty,
}

pub struct Scope {
    pub vars: RefCell<Vec<(Rc<str>, Value)>>,
    pub parent: Option<Rc<Scope>>,
}

impl Scope {
    pub fn new(parent: Option<Rc<Scope>>) -> Rc<Scope> {
        Rc::new(Scope { vars: RefCell::new(vec![]), parent })
    }
    pub fn get(&self, n: &str) -> Option<Value> {
        for (k, v) in self.vars.borrow().iter().rev() {
            if &**k == n {
                return Some(v.clone());
            }
        }
        self.parent.as_ref().and_then(|p| p.get(n))
    }
    pub fn set(&self, n: &str, v: Value) -> bool {
        {
            let mut vars = self.vars.borrow_mut();
            for (k, slot) in vars.iter_mut().rev() {
                if &**k == n {
                    *slot = v;
                    return true;
                }
            }
        }
        match &self.parent {
            Some(p) => p.set(n, v),
            None => false,
        }
    }
    pub fn def(&self, n: Rc<str>, v: Value) {
        self.vars.borrow_mut().push((n, v));
    }
}

#[derive(Debug, Clone)]
pub struct StructV {
    pub ty: Rc<str>,
    pub fields: Vec<(Rc<str>, Value)>,
    pub ident: Option<Rc<str>>,
    pub ctor: Span,
}

#[derive(Clone)]
pub enum Callable {
    Closure(Rc<Closure>, Rc<Scope>),
    Func(Rc<Func>, Rc<Scope>, Option<Value>), // func, defining scope, bound self
}

#[derive(Debug, Clone)]
pub enum BindingV {
    State(Rc<str>),             // full key ident.name
    Path(Box<BindingV>, Vec<Rc<str>>), // nested member path
    Const(Value),
}

#[derive(Clone)]
pub enum Value {
    Nil,
    Bool(bool),
    Int(i64),
    Double(f64),
    Str(Rc<str>),
    Array(Rc<Vec<Value>>),
    Dict(Rc<Vec<(Value, Value)>>),
    Tuple(Rc<Vec<(Option<Rc<str>>, Value)>>),
    Struct(Rc<StructV>),
    Enum(Rc<str>, Rc<str>, Rc<Vec<Value>>),
    Fn(Rc<Callable>),
    View(Rc<View>),
    Views(Rc<Vec<Value>>),
    Paint(Rc<Paint>),
    Font(FontSpec),
    Sym(Rc<str>),
    SymCall(Rc<str>, Rc<Vec<(Option<Rc<str>>, Value)>>),
    Type(Rc<str>),
    Binding(Rc<BindingV>),
    KeyPath(Rc<Vec<Rc<str>>>),
    Builtin(Rc<str>),
    Method(Box<Value>, Rc<str>),
    Dismiss(Rc<str>),
    Range(i64, i64),
    Shape(ShapeK),
}

impl std::fmt::Debug for Value {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.describe())
    }
}

impl std::fmt::Debug for Callable {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "<fn>")
    }
}

impl Value {
    pub fn s(s: &str) -> Value {
        Value::Str(Rc::from(s))
    }
    pub fn type_name(&self) -> &str {
        match self {
            Value::Nil => "nil",
            Value::Bool(_) => "Bool",
            Value::Int(_) => "Int",
            Value::Double(_) => "Double",
            Value::Str(_) => "String",
            Value::Array(_) => "Array",
            Value::Dict(_) => "Dictionary",
            Value::Tuple(_) => "Tuple",
            Value::Struct(s) => &s.ty,
            Value::Enum(t, _, _) => t,
            Value::Fn(_) => "Function",
            Value::View(_) | Value::Views(_) => "View",
            Value::Paint(_) => "Color",
            Value::Font(_) => "Font",
            Value::Sym(_) | Value::SymCall(..) => "member",
            Value::Type(_) => "Type",
            Value::Binding(_) => "Binding",
            Value::KeyPath(_) => "KeyPath",
            Value::Builtin(_) | Value::Method(..) => "Function",
            Value::Dismiss(_) => "DismissAction",
            Value::Range(..) => "Range",
            Value::Shape(_) => "Shape",
        }
    }
    pub fn describe(&self) -> String {
        match self {
            Value::Nil => "nil".into(),
            Value::Bool(b) => b.to_string(),
            Value::Int(i) => i.to_string(),
            Value::Double(d) => {
                if d.fract() == 0.0 && d.abs() < 1e15 {
                    format!("{:.1}", d)
                } else {
                    let s = format!("{}", d);
                    s
                }
            }
            Value::Str(s) => s.to_string(),
            Value::Array(a) => format!("[{}]", a.iter().map(|v| v.debug_lit()).collect::<Vec<_>>().join(", ")),
            Value::Tuple(t) => format!("({})", t.iter().map(|(_, v)| v.debug_lit()).collect::<Vec<_>>().join(", ")),
            Value::Struct(s) => format!(
                "{}({})",
                s.ty,
                s.fields.iter().map(|(k, v)| format!("{}: {}", k, v.debug_lit())).collect::<Vec<_>>().join(", ")
            ),
            Value::Enum(_, c, p) => {
                if p.is_empty() {
                    c.to_string()
                } else {
                    format!("{}({})", c, p.iter().map(|v| v.debug_lit()).collect::<Vec<_>>().join(", "))
                }
            }
            Value::Sym(s) => s.to_string(),
            Value::Range(a, b) => format!("{}..<{}", a, b),
            other => format!("<{}>", other.type_name()),
        }
    }
    fn debug_lit(&self) -> String {
        match self {
            Value::Str(s) => format!("\"{}\"", s),
            o => o.describe(),
        }
    }
    pub fn truthy(&self) -> bool {
        matches!(self, Value::Bool(true))
    }
    pub fn as_f(&self) -> Option<f64> {
        match self {
            Value::Int(i) => Some(*i as f64),
            Value::Double(d) => Some(*d),
            _ => None,
        }
    }
    pub fn as_i(&self) -> Option<i64> {
        match self {
            Value::Int(i) => Some(*i),
            Value::Double(d) => Some(*d as i64),
            _ => None,
        }
    }
    pub fn as_str(&self) -> Option<Rc<str>> {
        match self {
            Value::Str(s) => Some(s.clone()),
            _ => None,
        }
    }
    pub fn sym(&self) -> Option<&str> {
        match self {
            Value::Sym(s) => Some(s),
            Value::Enum(_, c, _) => Some(c),
            _ => None,
        }
    }
}

pub fn values_eq(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::Nil, Value::Nil) => true,
        (Value::Bool(x), Value::Bool(y)) => x == y,
        (Value::Int(x), Value::Int(y)) => x == y,
        (Value::Int(_), Value::Double(_)) | (Value::Double(_), Value::Int(_)) | (Value::Double(_), Value::Double(_)) => {
            a.as_f() == b.as_f()
        }
        (Value::Str(x), Value::Str(y)) => x == y,
        (Value::Array(x), Value::Array(y)) => x.len() == y.len() && x.iter().zip(y.iter()).all(|(p, q)| values_eq(p, q)),
        (Value::Tuple(x), Value::Tuple(y)) => x.len() == y.len() && x.iter().zip(y.iter()).all(|(p, q)| values_eq(&p.1, &q.1)),
        (Value::Struct(x), Value::Struct(y)) => {
            x.ty == y.ty && x.fields.len() == y.fields.len() && x.fields.iter().zip(y.fields.iter()).all(|(p, q)| values_eq(&p.1, &q.1))
        }
        (Value::Enum(_, c1, p1), Value::Enum(_, c2, p2)) => c1 == c2 && p1.len() == p2.len() && p1.iter().zip(p2.iter()).all(|(p, q)| values_eq(p, q)),
        (Value::Enum(_, c, _), Value::Sym(s)) | (Value::Sym(s), Value::Enum(_, c, _)) => c == s,
        (Value::Sym(x), Value::Sym(y)) => x == y,
        (Value::Paint(x), Value::Paint(y)) => x == y,
        (Value::Font(x), Value::Font(y)) => x == y,
        _ => false,
    }
}
