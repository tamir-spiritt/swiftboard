use crate::ast::*;
use crate::value::*;
use std::collections::HashMap;
use std::rc::Rc;

#[derive(Debug, Clone)]
pub struct RtErr {
    pub span: Span,
    pub msg: String,
}

pub type R<T> = Result<T, RtErr>;

pub fn err<T>(span: Span, msg: impl Into<String>) -> R<T> {
    Err(RtErr { span, msg: msg.into() })
}

pub enum Flow {
    Next,
    Ret(Value),
    Brk,
    Cont,
}

pub type Args = Vec<(Option<Rc<str>>, Value)>;

pub struct TypeInfo {
    pub name: Rc<str>,
    pub kind: TypeKind,
    pub props: Vec<Rc<Prop>>,
    pub funcs: Vec<Rc<Func>>,
    pub inits: Vec<Rc<Func>>,
    pub cases: Vec<Rc<EnumCase>>,
    pub conforms: Vec<Rc<str>>,
    pub raw_string: bool,
}

impl TypeInfo {
    pub fn is_view(&self) -> bool {
        self.conforms.iter().any(|c| &**c == "View" || &**c == "App" || &**c == "Scene")
    }
    pub fn prop(&self, n: &str) -> Option<&Rc<Prop>> {
        self.props.iter().find(|p| &*p.name == n && !p.is_static)
    }
    pub fn sprop(&self, n: &str) -> Option<&Rc<Prop>> {
        self.props.iter().find(|p| &*p.name == n && p.is_static)
    }
    pub fn func(&self, n: &str, is_static: bool) -> Option<&Rc<Func>> {
        self.funcs.iter().find(|f| &*f.name == n && f.is_static == is_static)
    }
}

pub fn has_attr(p: &Prop, a: &str) -> bool {
    p.attrs.iter().any(|x| &**x == a)
}

pub const BUILTIN_TYPES: &[&str] = &[
    "Text", "Image", "Label", "VStack", "HStack", "ZStack", "LazyVStack", "LazyHStack", "ScrollView", "List",
    "Section", "ForEach", "Group", "Spacer", "Divider", "Rectangle", "RoundedRectangle", "Circle", "Capsule",
    "Ellipse", "UnevenRoundedRectangle", "Color", "LinearGradient", "RadialGradient", "Gradient", "Button",
    "NavigationStack", "NavigationView", "NavigationLink", "TabView", "Tab", "TextField", "SecureField", "Toggle",
    "EmptyView", "AnyView", "ToolbarItem", "ToolbarItemGroup", "WindowGroup", "Font", "String", "Int", "Double",
    "Float", "CGFloat", "Bool", "UUID", "Date", "State", "Array", "Set", "EdgeInsets", "UnitPoint", "CGSize",
    "CGPoint", "Character", "ProgressView", "LazyVGrid", "LazyHGrid", "GridItem", "Angle", "ContentUnavailableView",
    "Dictionary", "ShapeStyle", "Material", "PlainButtonStyle", "BorderlessButtonStyle", "Calendar", "Edge",
    "Alignment", "HorizontalAlignment", "VerticalAlignment", "GeometryReader", "Menu", "Picker", "Stepper",
    "ViewThatFits", "UIColor", "Animation", "Form", "TextEditor", "NavigationSplitView", "LabeledContent", "Grid", "GridRow",
];

pub const BUILTIN_FNS: &[&str] = &[
    "min", "max", "abs", "print", "+", "*", "<", ">", "withAnimation", "stride", "round", "floor", "ceil", "sqrt", "zip", "pow",
];

pub struct Interp {
    pub types: HashMap<Rc<str>, Rc<TypeInfo>>,
    pub gfuncs: HashMap<Rc<str>, Rc<Func>>,
    pub gprops: HashMap<Rc<str>, Rc<Prop>>,
    pub gcache: HashMap<Rc<str>, Value>,
    pub scache: HashMap<String, Value>,
    pub globals: Rc<Scope>,
    pub view_ext: HashMap<Rc<str>, Rc<Func>>,
    pub previews: Vec<(Rc<str>, Rc<Closure>, Span)>,
    pub main: Option<Rc<str>>,
    pub state: HashMap<String, Value>,
    pub ui: HashMap<String, f64>,
    pub idpath: Vec<Rc<str>>,
    pub nav: Vec<Rc<str>>,
    pub dark: bool,
    pub steps: u64,
    pub depth: u32,
    pub warnings: Vec<(Span, String)>,
    pub uuid: u64,
    pub now: f64,
}

impl Interp {
    pub fn new(prog: Program) -> Interp {
        let mut it = Interp {
            types: HashMap::new(),
            gfuncs: HashMap::new(),
            gprops: HashMap::new(),
            gcache: HashMap::new(),
            scache: HashMap::new(),
            globals: Scope::new(None),
            view_ext: HashMap::new(),
            previews: vec![],
            main: prog.main.clone(),
            state: HashMap::new(),
            ui: HashMap::new(),
            idpath: vec![],
            nav: vec![],
            dark: false,
            steps: 0,
            depth: 0,
            warnings: vec![],
            uuid: 1,
            now: 0.0,
        };
        for td in prog.types {
            let name = td.name.clone();
            if td.kind == TypeKind::Extension && (&*name == "View" || &*name == "Shape") {
                for f in td.funcs {
                    it.view_ext.insert(f.name.clone(), f);
                }
                continue;
            }
            if td.kind == TypeKind::Protocol {
                continue;
            }
            let ti = it.types.remove(&name).map(|rc| Rc::try_unwrap(rc).ok()).flatten();
            let mut ti = ti.unwrap_or(TypeInfo {
                name: name.clone(),
                kind: td.kind,
                props: vec![],
                funcs: vec![],
                inits: vec![],
                cases: vec![],
                conforms: vec![],
                raw_string: false,
            });
            if td.kind != TypeKind::Extension {
                ti.kind = td.kind;
            }
            ti.props.extend(td.props.into_iter().map(Rc::new));
            ti.funcs.extend(td.funcs);
            ti.inits.extend(td.inits);
            ti.cases.extend(td.cases.into_iter().map(Rc::new));
            ti.conforms.extend(td.conforms);
            ti.raw_string |= td.raw_string;
            it.types.insert(name, Rc::new(ti));
        }
        for f in prog.funcs {
            it.gfuncs.insert(f.name.clone(), f);
        }
        for p in prog.globals {
            it.gprops.insert(p.name.clone(), Rc::new(p));
        }
        for p in prog.previews {
            it.previews.push((p.name, p.body, p.span));
        }
        it
    }

    pub fn tick(&mut self, span: Span) -> R<()> {
        self.steps += 1;
        if self.steps > 3_000_000 {
            return err(span, "execution limit reached (infinite loop?)");
        }
        Ok(())
    }

    pub fn is_type_name(&self, n: &str) -> bool {
        self.types.contains_key(n) || BUILTIN_TYPES.contains(&n)
    }

    // ---------- statements ----------

    pub fn run_body(&mut self, stmts: &[Stmt], sc: &Rc<Scope>) -> R<Value> {
        if stmts.len() == 1 {
            if let StmtK::Expr(e) = &stmts[0].k {
                return self.eval(e, sc);
            }
        }
        let mut col = vec![];
        match self.exec_block(stmts, sc, &mut col)? {
            Flow::Ret(v) => Ok(v),
            _ => Ok(match col.len() {
                0 => Value::Nil,
                1 => col.pop().unwrap(),
                _ => Value::Views(Rc::new(col)),
            }),
        }
    }

    pub fn exec_block(&mut self, stmts: &[Stmt], sc: &Rc<Scope>, col: &mut Vec<Value>) -> R<Flow> {
        for s in stmts {
            match self.exec_stmt(s, sc, col)? {
                Flow::Next => {}
                f => return Ok(f),
            }
        }
        Ok(Flow::Next)
    }

    pub fn is_viewish(&self, v: &Value) -> bool {
        match v {
            Value::View(_) | Value::Views(_) | Value::Paint(_) | Value::Shape(_) => true,
            Value::Struct(s) => self.types.get(&s.ty).map(|t| t.is_view()).unwrap_or(false),
            _ => false,
        }
    }

    fn cond_ok(&mut self, conds: &[Cond], sc: &Rc<Scope>) -> R<bool> {
        for c in conds {
            match c {
                Cond::Expr(e) => {
                    let v = self.eval(e, sc)?;
                    if !v.truthy() {
                        return Ok(false);
                    }
                }
                Cond::Let(n, e) => {
                    let v = self.eval(e, sc)?;
                    if matches!(v, Value::Nil) {
                        return Ok(false);
                    }
                    sc.def(n.clone(), v);
                }
            }
        }
        Ok(true)
    }

    pub fn exec_stmt(&mut self, s: &Stmt, sc: &Rc<Scope>, col: &mut Vec<Value>) -> R<Flow> {
        self.tick(s.span)?;
        match &s.k {
            StmtK::Expr(e) => {
                let v = self.eval(e, sc)?;
                if self.is_viewish(&v) {
                    col.push(v);
                }
            }
            StmtK::Let(n, init, _) => {
                let v = match init {
                    Some(e) => self.eval(e, sc)?,
                    None => Value::Nil,
                };
                sc.def(n.clone(), v);
            }
            StmtK::LetTuple(names, e) => {
                let v = self.eval(e, sc)?;
                if let Value::Tuple(t) = v {
                    for (i, n) in names.iter().enumerate() {
                        sc.def(n.clone(), t.get(i).map(|x| x.1.clone()).unwrap_or(Value::Nil));
                    }
                }
            }
            StmtK::Assign(lhs, op, rhs) => {
                let mut v = self.eval(rhs, sc)?;
                if let Some(op) = op {
                    let cur = self.eval(lhs, sc)?;
                    v = self.binop(op, &cur, &v, s.span)?;
                }
                self.assign(lhs, v, sc)?;
            }
            StmtK::If(conds, then, els) => {
                let inner = Scope::new(Some(sc.clone()));
                if self.cond_ok(conds, &inner)? {
                    return self.exec_block(then, &inner, col);
                } else if let Some(e) = els {
                    let inner = Scope::new(Some(sc.clone()));
                    return self.exec_block(e, &inner, col);
                }
            }
            StmtK::Guard(conds, els) => {
                if !self.cond_ok(conds, sc)? {
                    let inner = Scope::new(Some(sc.clone()));
                    return self.exec_block(els, &inner, col);
                }
            }
            StmtK::For(names, seq, body, wh) => {
                let seqv = self.eval(seq, sc)?;
                let items = self.iter_items(&seqv, seq.span)?;
                for it in items {
                    let inner = Scope::new(Some(sc.clone()));
                    if names.len() == 1 {
                        inner.def(names[0].clone(), it);
                    } else if let Value::Tuple(t) = &it {
                        for (i, n) in names.iter().enumerate() {
                            inner.def(n.clone(), t.get(i).map(|x| x.1.clone()).unwrap_or(Value::Nil));
                        }
                    }
                    if let Some(w) = wh {
                        if !self.eval(w, &inner)?.truthy() {
                            continue;
                        }
                    }
                    match self.exec_block(body, &inner, col)? {
                        Flow::Brk => break,
                        Flow::Ret(v) => return Ok(Flow::Ret(v)),
                        _ => {}
                    }
                }
            }
            StmtK::While(c, body) => loop {
                if !self.eval(c, sc)?.truthy() {
                    break;
                }
                let inner = Scope::new(Some(sc.clone()));
                match self.exec_block(body, &inner, col)? {
                    Flow::Brk => break,
                    Flow::Ret(v) => return Ok(Flow::Ret(v)),
                    _ => {}
                }
            },
            StmtK::Switch(subj, cases) => {
                let v = self.eval(subj, sc)?;
                for c in cases {
                    let inner = Scope::new(Some(sc.clone()));
                    let mut hit = c.pats.is_empty();
                    for p in &c.pats {
                        if self.pat_match(p, &v, &inner)? {
                            hit = true;
                            break;
                        }
                    }
                    if hit {
                        return match self.exec_block(&c.body, &inner, col)? {
                            Flow::Brk => Ok(Flow::Next),
                            f => Ok(f),
                        };
                    }
                }
            }
            StmtK::Return(e) => {
                let v = match e {
                    Some(e) => self.eval(e, sc)?,
                    None => Value::Nil,
                };
                return Ok(Flow::Ret(v));
            }
            StmtK::Break => return Ok(Flow::Brk),
            StmtK::Continue => return Ok(Flow::Cont),
            StmtK::Func(f) => {
                sc.def(f.name.clone(), Value::Fn(Rc::new(Callable::Func(f.clone(), sc.clone(), None))));
            }
            StmtK::Nop => {}
        }
        Ok(Flow::Next)
    }

    fn pat_match(&mut self, p: &Pattern, v: &Value, sc: &Rc<Scope>) -> R<bool> {
        Ok(match p {
            Pattern::Wildcard => true,
            Pattern::EnumCase(name, binds) => match v {
                Value::Enum(_, c, payload) if c == name => {
                    for (i, b) in binds.iter().enumerate() {
                        sc.def(b.clone(), payload.get(i).cloned().unwrap_or(Value::Nil));
                    }
                    true
                }
                Value::Sym(s) => s == name,
                _ => false,
            },
            Pattern::Expr(e) => {
                let pv = self.eval(e, sc)?;
                match (&pv, v) {
                    (Value::Range(a, b), _) => v.as_i().map(|x| x >= *a && x < *b).unwrap_or(false),
                    _ => values_eq(&pv, v),
                }
            }
        })
    }

    pub fn iter_items(&mut self, v: &Value, span: Span) -> R<Vec<Value>> {
        Ok(match v {
            Value::Array(a) => a.as_ref().clone(),
            Value::Range(a, b) => (*a..*b).map(Value::Int).collect(),
            Value::Dict(d) => d.iter().map(|(k, v)| Value::Tuple(Rc::new(vec![(Some("key".into()), k.clone()), (Some("value".into()), v.clone())]))).collect(),
            Value::Str(s) => s.chars().map(|c| Value::Str(Rc::from(c.to_string()))).collect(),
            Value::Nil => vec![],
            _ => return err(span, format!("cannot iterate over {}", v.type_name())),
        })
    }

    // ---------- assignment ----------

    pub fn assign(&mut self, lhs: &Expr, v: Value, sc: &Rc<Scope>) -> R<()> {
        match &lhs.k {
            ExprK::Ident(n) => {
                if &**n == "_" {
                    return Ok(());
                }
                if sc.set(n, v.clone()) {
                    return Ok(());
                }
                if let Some(selfv) = sc.get("self") {
                    // `_x = State(initialValue:)` inside init
                    let pname = if n.starts_with('_') { &n[1..] } else { &n[..] };
                    return self.set_self_prop(&selfv, pname, v, sc, lhs.span);
                }
                err(lhs.span, format!("cannot assign to '{}'", n))
            }
            ExprK::Member(base, name, _) => {
                if let ExprK::SelfRef = base.k {
                    let selfv = sc.get("self").unwrap_or(Value::Nil);
                    return self.set_self_prop(&selfv, name, v, sc, lhs.span);
                }
                let cur = self.eval(base, sc)?;
                if let Value::Binding(b) = &cur {
                    let inner = self.read_binding(b);
                    let nv = self.set_field(&inner, name, v, lhs.span)?;
                    self.write_binding(b, nv);
                    return Ok(());
                }
                let nv = self.set_field(&cur, name, v, lhs.span)?;
                self.assign(base, nv, sc)
            }
            ExprK::Index(base, args) => {
                let cur = self.eval(base, sc)?;
                let idx = match args.first() {
                    Some(a) => self.eval(&a.value, sc)?,
                    None => return err(lhs.span, "missing index"),
                };
                let nv = match cur {
                    Value::Array(mut a) => {
                        let i = idx.as_i().unwrap_or(-1);
                        if i < 0 || i as usize >= a.len() {
                            return err(lhs.span, "index out of range");
                        }
                        Rc::make_mut(&mut a)[i as usize] = v;
                        Value::Array(a)
                    }
                    Value::Dict(mut d) => {
                        let dm = Rc::make_mut(&mut d);
                        if let Some(slot) = dm.iter_mut().find(|(k, _)| values_eq(k, &idx)) {
                            slot.1 = v;
                        } else {
                            dm.push((idx, v));
                        }
                        Value::Dict(d)
                    }
                    _ => return err(lhs.span, "cannot subscript-assign"),
                };
                self.assign(base, nv, sc)
            }
            ExprK::ForceUnwrap(e) => self.assign(e, v, sc),
            _ => err(lhs.span, "cannot assign to this expression"),
        }
    }

    pub fn set_field(&mut self, cur: &Value, name: &str, v: Value, span: Span) -> R<Value> {
        match cur {
            Value::Struct(s) => {
                let mut ns = (**s).clone();
                if let Some(slot) = ns.fields.iter_mut().find(|(k, _)| &**k == name) {
                    slot.1 = v;
                } else {
                    ns.fields.push((Rc::from(name), v));
                }
                Ok(Value::Struct(Rc::new(ns)))
            }
            _ => err(span, format!("cannot set '{}' on {}", name, cur.type_name())),
        }
    }

    pub fn set_self_prop(&mut self, selfv: &Value, n: &str, v: Value, sc: &Rc<Scope>, span: Span) -> R<()> {
        if let Value::Struct(s) = selfv {
            if let Some(ti) = self.types.get(&s.ty).cloned() {
                if let Some(p) = ti.prop(n) {
                    if let Some(id) = &s.ident {
                        if has_attr(p, "State") || has_attr(p, "StateObject") || has_attr(p, "AppStorage") {
                            self.state.insert(format!("{}.{}", id, n), v);
                            return Ok(());
                        }
                    }
                    if has_attr(p, "Binding") {
                        if let Some((_, Value::Binding(b))) = s.fields.iter().find(|(k, _)| &**k == n) {
                            let b = b.clone();
                            self.write_binding(&b, v);
                            return Ok(());
                        }
                    }
                }
            }
            let ns = self.set_field(selfv, n, v, span)?;
            sc.set("self", ns);
            return Ok(());
        }
        err(span, format!("cannot assign to '{}'", n))
    }

    pub fn read_binding(&mut self, b: &BindingV) -> Value {
        match b {
            BindingV::State(k) => self.state.get(&**k).cloned().unwrap_or(Value::Nil),
            BindingV::Path(inner, path) => {
                let mut v = self.read_binding(inner);
                for p in path {
                    v = self.get_member(&v, p, Span::default()).unwrap_or(Value::Nil);
                }
                v
            }
            BindingV::Const(v) => v.clone(),
        }
    }

    pub fn write_binding(&mut self, b: &BindingV, v: Value) {
        match b {
            BindingV::State(k) => {
                self.state.insert(k.to_string(), v);
            }
            BindingV::Path(inner, path) => {
                let cur = self.read_binding(inner);
                let nv = self.set_path(&cur, path, v);
                self.write_binding(inner, nv);
            }
            BindingV::Const(_) => {}
        }
    }

    fn set_path(&mut self, cur: &Value, path: &[Rc<str>], v: Value) -> Value {
        if path.is_empty() {
            return v;
        }
        let child = self.get_member(cur, &path[0], Span::default()).unwrap_or(Value::Nil);
        let nchild = self.set_path(&child, &path[1..], v);
        self.set_field(cur, &path[0], nchild, Span::default()).unwrap_or(cur.clone())
    }

    fn make_binding(&mut self, n: &str, sc: &Rc<Scope>, span: Span) -> R<Value> {
        if let Some(Value::Struct(s)) = sc.get("self") {
            if let Some(ti) = self.types.get(&s.ty).cloned() {
                if let Some(p) = ti.prop(n) {
                    if has_attr(p, "Binding") {
                        if let Some((_, b @ Value::Binding(_))) = s.fields.iter().find(|(k, _)| &**k == n) {
                            return Ok(b.clone());
                        }
                    }
                    if let Some(id) = &s.ident {
                        return Ok(Value::Binding(Rc::new(BindingV::State(Rc::from(format!("{}.{}", id, n))))));
                    }
                }
            }
        }
        if let Some(v) = sc.get(n) {
            if let Value::Binding(_) = v {
                return Ok(v);
            }
            return Ok(Value::Binding(Rc::new(BindingV::Const(v))));
        }
        err(span, format!("cannot find '${}' in scope", n))
    }

    // ---------- expressions ----------

    pub fn eval(&mut self, e: &Expr, sc: &Rc<Scope>) -> R<Value> {
        match &e.k {
            ExprK::Int(n) => Ok(Value::Int(*n)),
            ExprK::Float(f) => Ok(Value::Double(*f)),
            ExprK::Bool(b) => Ok(Value::Bool(*b)),
            ExprK::Nil => Ok(Value::Nil),
            ExprK::Str(segs, _) => {
                if segs.len() == 1 {
                    if let StrSeg::Lit(s) = &segs[0] {
                        return Ok(Value::Str(s.clone()));
                    }
                }
                let mut out = String::new();
                for s in segs {
                    match s {
                        StrSeg::Lit(l) => out.push_str(l),
                        StrSeg::Code(c) => {
                            let v = self.eval(c, sc)?;
                            out.push_str(&v.describe());
                        }
                    }
                }
                Ok(Value::Str(Rc::from(out)))
            }
            ExprK::Ident(n) => self.lookup(n, sc, e.span),
            ExprK::SelfRef => sc.get("self").map(Ok).unwrap_or_else(|| err(e.span, "'self' is not available here")),
            ExprK::ImplicitMember(n) => self.implicit(n, e.span),
            ExprK::Member(base, name, opt) => {
                if let ExprK::Ident(t) = &base.k {
                    if self.is_type_name(t) && sc.get(t).is_none() {
                        return self.static_member(t, name, e.span);
                    }
                }
                let v = self.eval(base, sc)?;
                if *opt && matches!(v, Value::Nil) {
                    return Ok(Value::Nil);
                }
                self.get_member(&v, name, e.span)
            }
            ExprK::Call(callee, args, aspan) => self.eval_call(callee, args, *aspan, e.span, sc),
            ExprK::Index(base, args) => {
                let b = self.eval(base, sc)?;
                let i = match args.first() {
                    Some(a) => self.eval(&a.value, sc)?,
                    None => return err(e.span, "missing index"),
                };
                self.index(&b, &i, e.span)
            }
            ExprK::Unary(op, x) => {
                let v = self.eval(x, sc)?;
                match (*op, &v) {
                    ("-", Value::Int(i)) => Ok(Value::Int(-i)),
                    ("-", Value::Double(d)) => Ok(Value::Double(-d)),
                    ("!", Value::Bool(b)) => Ok(Value::Bool(!b)),
                    _ => err(e.span, format!("bad operand for {}: {}", op, v.type_name())),
                }
            }
            ExprK::Binary(op, a, b) => {
                match *op {
                    "&&" => {
                        let x = self.eval(a, sc)?;
                        if !x.truthy() {
                            return Ok(Value::Bool(false));
                        }
                        return Ok(Value::Bool(self.eval(b, sc)?.truthy()));
                    }
                    "||" => {
                        let x = self.eval(a, sc)?;
                        if x.truthy() {
                            return Ok(Value::Bool(true));
                        }
                        return Ok(Value::Bool(self.eval(b, sc)?.truthy()));
                    }
                    "??" => {
                        let x = self.eval(a, sc)?;
                        if !matches!(x, Value::Nil) {
                            return Ok(x);
                        }
                        return self.eval(b, sc);
                    }
                    _ => {}
                }
                let x = self.eval(a, sc)?;
                let y = self.eval(b, sc)?;
                self.binop(op, &x, &y, e.span)
            }
            ExprK::Ternary(c, a, b) => {
                if self.eval(c, sc)?.truthy() {
                    self.eval(a, sc)
                } else {
                    self.eval(b, sc)
                }
            }
            ExprK::Array(items) => {
                let mut out = Vec::with_capacity(items.len());
                for i in items {
                    out.push(self.eval(i, sc)?);
                }
                Ok(Value::Array(Rc::new(out)))
            }
            ExprK::Dict(pairs) => {
                let mut out = vec![];
                for (k, v) in pairs {
                    out.push((self.eval(k, sc)?, self.eval(v, sc)?));
                }
                Ok(Value::Dict(Rc::new(out)))
            }
            ExprK::Tuple(args) => {
                let mut out = vec![];
                for a in args {
                    out.push((a.label.clone(), self.eval(&a.value, sc)?));
                }
                Ok(Value::Tuple(Rc::new(out)))
            }
            ExprK::Closure(c) => Ok(Value::Fn(Rc::new(Callable::Closure(c.clone(), sc.clone())))),
            ExprK::KeyPath(p) => Ok(Value::KeyPath(Rc::new(p.clone()))),
            ExprK::ForceUnwrap(x) => {
                let v = self.eval(x, sc)?;
                if matches!(v, Value::Nil) {
                    return err(e.span, "unexpectedly found nil while unwrapping");
                }
                Ok(v)
            }
            ExprK::Cast(x, _) => self.eval(x, sc),
            ExprK::Is(x, t) => {
                let v = self.eval(x, sc)?;
                Ok(Value::Bool(v.type_name() == &**t))
            }
            ExprK::Binding(n) => self.make_binding(n, sc, e.span),
            ExprK::Type(_) => Ok(Value::Nil),
        }
    }

    // evaluate with an expected nominal type: `.case` resolves inside that type
    pub fn eval_typed(&mut self, e: &Expr, ty: Option<&Rc<str>>, sc: &Rc<Scope>) -> R<Value> {
        if let (ExprK::ImplicitMember(n), Some(t)) = (&e.k, ty) {
            if let Some(ti) = self.types.get(t).cloned() {
                if ti.cases.iter().any(|c| &c.name == n) || ti.sprop(n).is_some() {
                    return self.static_member(t, n, e.span);
                }
            }
        }
        self.eval(e, sc)
    }

    pub fn binop(&mut self, op: &str, x: &Value, y: &Value, span: Span) -> R<Value> {
        use Value::*;
        Ok(match (op, x, y) {
            ("+", Int(a), Int(b)) => Int(a.wrapping_add(*b)),
            ("-", Int(a), Int(b)) => Int(a.wrapping_sub(*b)),
            ("*", Int(a), Int(b)) => Int(a.wrapping_mul(*b)),
            ("/", Int(a), Int(b)) => {
                if *b == 0 {
                    return err(span, "division by zero");
                }
                Int(a / b)
            }
            ("%", Int(a), Int(b)) => {
                if *b == 0 {
                    return err(span, "division by zero");
                }
                Int(a % b)
            }
            ("<<", Int(a), Int(b)) => Int(a.wrapping_shl(*b as u32)),
            (">>", Int(a), Int(b)) => Int(a.wrapping_shr(*b as u32)),
            ("&", Int(a), Int(b)) => Int(a & b),
            ("|", Int(a), Int(b)) => Int(a | b),
            ("^", Int(a), Int(b)) => Int(a ^ b),
            ("+", Str(a), Str(b)) => Str(Rc::from(format!("{}{}", a, b))),
            ("+", Array(a), Array(b)) => {
                let mut v = a.as_ref().clone();
                v.extend(b.iter().cloned());
                Array(Rc::new(v))
            }
            ("+", View(_), View(_)) => {
                // Text concatenation
                let a = self.text_of(x);
                let b = self.text_of(y);
                return Ok(View(Rc::new(crate::value::View { k: VK::Text { s: Rc::from(format!("{}{}", a, b)), lit: None, attrs: vec![] }, src: span })));
            }
            ("..<", _, _) => Range(x.as_i().unwrap_or(0), y.as_i().unwrap_or(0)),
            ("...", _, _) => Range(x.as_i().unwrap_or(0), y.as_i().unwrap_or(0).saturating_add(1)),
            ("==", _, _) => Bool(values_eq(x, y)),
            ("!=", _, _) => Bool(!values_eq(x, y)),
            ("===", _, _) => Bool(values_eq(x, y)),
            ("!==", _, _) => Bool(!values_eq(x, y)),
            ("<" | ">" | "<=" | ">=", Str(a), Str(b)) => Bool(match op {
                "<" => a < b,
                ">" => a > b,
                "<=" => a <= b,
                _ => a >= b,
            }),
            ("+" | "-" | "*" | "/" | "%" | "<" | ">" | "<=" | ">=", _, _) => {
                let (Some(a), Some(b)) = (x.as_f(), y.as_f()) else {
                    return err(span, format!("binary '{}' cannot be applied to {} and {}", op, x.type_name(), y.type_name()));
                };
                match op {
                    "+" => Double(a + b),
                    "-" => Double(a - b),
                    "*" => Double(a * b),
                    "/" => Double(a / b),
                    "%" => Double(a % b),
                    "<" => Bool(a < b),
                    ">" => Bool(a > b),
                    "<=" => Bool(a <= b),
                    _ => Bool(a >= b),
                }
            }
            _ => return err(span, format!("binary '{}' cannot be applied to {} and {}", op, x.type_name(), y.type_name())),
        })
    }

    fn text_of(&self, v: &Value) -> String {
        if let Value::View(vw) = v {
            let mut cur = vw.clone();
            loop {
                match &cur.k {
                    VK::Text { s, .. } => return s.to_string(),
                    VK::Mod(c, _, _) => cur = c.clone(),
                    _ => return String::new(),
                }
            }
        }
        String::new()
    }

    pub fn index(&mut self, b: &Value, i: &Value, span: Span) -> R<Value> {
        match b {
            Value::Array(a) => match i {
                Value::Range(lo, hi) => {
                    let lo = (*lo).max(0) as usize;
                    let hi = (*hi as usize).min(a.len());
                    Ok(Value::Array(Rc::new(a.get(lo..hi).map(|s| s.to_vec()).unwrap_or_default())))
                }
                _ => {
                    let n = i.as_i().unwrap_or(-1);
                    if n < 0 || n as usize >= a.len() {
                        return err(span, format!("index {} out of range (count {})", n, a.len()));
                    }
                    Ok(a[n as usize].clone())
                }
            },
            Value::Dict(d) => Ok(d.iter().find(|(k, _)| values_eq(k, i)).map(|x| x.1.clone()).unwrap_or(Value::Nil)),
            Value::Str(s) => {
                let n = i.as_i().unwrap_or(0) as usize;
                Ok(s.chars().nth(n).map(|c| Value::Str(Rc::from(c.to_string()))).unwrap_or(Value::Nil))
            }
            _ => err(span, format!("cannot subscript {}", b.type_name())),
        }
    }

    pub fn lookup(&mut self, n: &str, sc: &Rc<Scope>, span: Span) -> R<Value> {
        if let Some(v) = sc.get(n) {
            return Ok(v);
        }
        if let Some(selfv) = sc.get("self") {
            if let Some(v) = self.self_member(&selfv, n, span)? {
                return Ok(v);
            }
        }
        if let Some(v) = self.gcache.get(n) {
            return Ok(v.clone());
        }
        if let Some(p) = self.gprops.get(n).cloned() {
            let v = match (&p.init, &p.getter) {
                (_, Some(g)) => {
                    let s = Scope::new(Some(self.globals.clone()));
                    return self.run_body(g, &s);
                }
                (Some(e), _) => {
                    let g = self.globals.clone();
                    self.eval(e, &g)?
                }
                _ => Value::Nil,
            };
            self.gcache.insert(Rc::from(n), v.clone());
            return Ok(v);
        }
        if let Some(f) = self.gfuncs.get(n) {
            return Ok(Value::Fn(Rc::new(Callable::Func(f.clone(), self.globals.clone(), None))));
        }
        if self.is_type_name(n) {
            return Ok(Value::Type(Rc::from(n)));
        }
        if BUILTIN_FNS.contains(&n) {
            return Ok(Value::Builtin(Rc::from(n)));
        }
        err(span, format!("cannot find '{}' in scope", n))
    }

    // members of the implicit self (fields, computed props, methods)
    fn self_member(&mut self, selfv: &Value, n: &str, span: Span) -> R<Option<Value>> {
        let ty = match selfv {
            Value::Struct(s) => s.ty.clone(),
            Value::Enum(t, _, _) => t.clone(),
            _ => return Ok(None),
        };
        let Some(ti) = self.types.get(&ty).cloned() else { return Ok(None) };
        if ti.prop(n).is_some() || ti.func(n, false).is_some() {
            return self.get_member(selfv, n, span).map(Some);
        }
        if let Value::Struct(s) = selfv {
            if s.fields.iter().any(|(k, _)| &**k == n) {
                return self.get_member(selfv, n, span).map(Some);
            }
        }
        if ti.sprop(n).is_some() || ti.func(n, true).is_some() {
            return self.static_member(&ty, n, span).map(Some);
        }
        Ok(None)
    }

    pub fn get_member(&mut self, v: &Value, n: &str, span: Span) -> R<Value> {
        match v {
            Value::Struct(s) => {
                let ti = self.types.get(&s.ty).cloned();
                if let Some(ti) = &ti {
                    if let Some(p) = ti.prop(n) {
                        if let Some(id) = &s.ident {
                            if has_attr(p, "State") || has_attr(p, "StateObject") || has_attr(p, "AppStorage") {
                                let key = format!("{}.{}", id, n);
                                if let Some(sv) = self.state.get(&key) {
                                    return Ok(sv.clone());
                                }
                            }
                        }
                        if let Some(g) = &p.getter {
                            let sc = Scope::new(Some(self.globals.clone()));
                            sc.def(Rc::from("self"), v.clone());
                            self.depth += 1;
                            if self.depth > 200 {
                                self.depth -= 1;
                                return err(span, "recursion too deep");
                            }
                            let r = self.run_body(g, &sc);
                            self.depth -= 1;
                            return r;
                        }
                    }
                }
                if let Some((_, fv)) = s.fields.iter().find(|(k, _)| &**k == n) {
                    if let Value::Binding(b) = fv {
                        let is_binding_prop = ti.as_ref().and_then(|t| t.prop(n)).map(|p| has_attr(p, "Binding")).unwrap_or(false);
                        if is_binding_prop {
                            let b = b.clone();
                            return Ok(self.read_binding(&b));
                        }
                    }
                    return Ok(fv.clone());
                }
                if let Some(ti) = &ti {
                    if let Some(f) = ti.func(n, false) {
                        return Ok(Value::Fn(Rc::new(Callable::Func(f.clone(), self.globals.clone(), Some(v.clone())))));
                    }
                    if ti.is_view() {
                        return Ok(Value::Method(Box::new(v.clone()), Rc::from(n)));
                    }
                }
                if n == "hashValue" {
                    return Ok(Value::Int(0));
                }
                err(span, format!("value of type '{}' has no member '{}'", s.ty, n))
            }
            Value::Enum(t, c, payload) => {
                if n == "rawValue" {
                    let ti = self.types.get(t).cloned();
                    if let Some(ti) = ti {
                        if let Some(ec) = ti.cases.iter().find(|x| &x.name == c) {
                            if let Some(r) = &ec.raw {
                                let g = self.globals.clone();
                                return self.eval(r, &g);
                            }
                            if ti.raw_string {
                                return Ok(Value::Str(c.clone()));
                            }
                            let idx = ti.cases.iter().position(|x| &x.name == c).unwrap_or(0);
                            return Ok(Value::Int(idx as i64));
                        }
                    }
                    return Ok(Value::Str(c.clone()));
                }
                if n == "id" {
                    if let Some(ti) = self.types.get(t).cloned() {
                        if ti.prop("id").is_none() {
                            return Ok(Value::Str(c.clone()));
                        }
                    }
                }
                let _ = payload;
                let ti = self.types.get(t).cloned();
                if let Some(ti) = ti {
                    if let Some(p) = ti.prop(n) {
                        if let Some(g) = &p.getter {
                            let sc = Scope::new(Some(self.globals.clone()));
                            sc.def(Rc::from("self"), v.clone());
                            return self.run_body(g, &sc);
                        }
                    }
                    if let Some(f) = ti.func(n, false) {
                        return Ok(Value::Fn(Rc::new(Callable::Func(f.clone(), self.globals.clone(), Some(v.clone())))));
                    }
                }
                err(span, format!("enum '{}' has no member '{}'", t, n))
            }
            Value::Binding(b) => {
                if n == "wrappedValue" {
                    let b = b.clone();
                    return Ok(self.read_binding(&b));
                }
                Ok(Value::Binding(Rc::new(BindingV::Path(Box::new((**b).clone()), vec![Rc::from(n)]))))
            }
            Value::Tuple(t) => {
                if let Ok(i) = n.parse::<usize>() {
                    return Ok(t.get(i).map(|x| x.1.clone()).unwrap_or(Value::Nil));
                }
                if let Some((_, v)) = t.iter().find(|(l, _)| l.as_deref() == Some(n)) {
                    return Ok(v.clone());
                }
                err(span, format!("tuple has no member '{}'", n))
            }
            Value::Type(t) => self.static_member(t, n, span),
            _ => crate::methods::builtin_prop(self, v, n, span),
        }
    }

    pub fn implicit(&mut self, n: &str, span: Span) -> R<Value> {
        // user statics / enum cases
        // prefer enum cases, then Color statics, then other statics (deterministic)
        let mut found: Option<(u8, Rc<str>)> = None;
        for (tn, ti) in self.types.iter() {
            let rank = if ti.cases.iter().any(|c| &*c.name == n) {
                3
            } else if ti.sprop(n).is_some() {
                if &**tn == "Color" { 2 } else { 1 }
            } else {
                0
            };
            if rank > 0 && found.as_ref().map(|f| rank > f.0 || (rank == f.0 && **tn < *f.1)).unwrap_or(true) {
                found = Some((rank, tn.clone()));
            }
        }
        let found = found.map(|f| f.1);
        if let Some(t) = found {
            return self.static_member(&t, n, span);
        }
        match n {
            "infinity" => Ok(Value::Double(f64::INFINITY)),
            "zero" => Ok(Value::Int(0)),
            "now" => Ok(Value::Double(self.now)),
            _ => Ok(Value::Sym(Rc::from(n))),
        }
    }

    pub fn static_member(&mut self, t: &str, n: &str, span: Span) -> R<Value> {
        if let Some(ti) = self.types.get(t).cloned() {
            if let Some(p) = ti.sprop(n) {
                let key = format!("{}.{}", t, n);
                if let Some(v) = self.scache.get(&key) {
                    return Ok(v.clone());
                }
                let g = Scope::new(Some(self.globals.clone()));
                let v = if let Some(gt) = &p.getter {
                    return self.run_body(gt, &g);
                } else if let Some(e) = &p.init {
                    self.eval(e, &g)?
                } else {
                    Value::Nil
                };
                self.scache.insert(key, v.clone());
                return Ok(v);
            }
            if let Some(c) = ti.cases.iter().find(|c| &*c.name == n) {
                return Ok(Value::Enum(ti.name.clone(), c.name.clone(), Rc::new(vec![])));
            }
            if n == "allCases" {
                let all = ti.cases.iter().map(|c| Value::Enum(ti.name.clone(), c.name.clone(), Rc::new(vec![]))).collect();
                return Ok(Value::Array(Rc::new(all)));
            }
            if let Some(f) = ti.func(n, true) {
                return Ok(Value::Fn(Rc::new(Callable::Func(f.clone(), self.globals.clone(), None))));
            }
            if n == "init" {
                return Ok(Value::Type(Rc::from(t)));
            }
        }
        crate::methods::builtin_static(self, t, n, span)
    }

    // ---------- calls ----------

    fn eval_args(&mut self, args: &[Arg], sc: &Rc<Scope>) -> R<Args> {
        let mut out = Vec::with_capacity(args.len());
        for a in args {
            out.push((a.label.clone(), self.eval(&a.value, sc)?));
        }
        Ok(out)
    }

    fn eval_call(&mut self, callee: &Expr, args: &[Arg], aspan: Span, span: Span, sc: &Rc<Scope>) -> R<Value> {
        self.tick(span)?;
        match &callee.k {
            ExprK::Ident(n) => {
                if sc.get(n).is_none() {
                    // method on implicit self
                    if let Some(selfv) = sc.get("self") {
                        if let Value::Struct(s) = &selfv {
                            if let Some(ti) = self.types.get(&s.ty).cloned() {
                                if ti.func(n, false).is_some() {
                                    let f = ti.func(n, false).unwrap().clone();
                                    let a = self.eval_args(args, sc)?;
                                    return self.call_func(&f, Some(selfv.clone()), a, span);
                                }
                            }
                        }
                    }
                    if !self.gfuncs.contains_key(n) && self.is_type_name(n) {
                        let a = self.eval_args(args, sc)?;
                        return self.construct(n, a, args, aspan, span);
                    }
                }
                let f = self.lookup(n, sc, callee.span)?;
                let a = self.eval_args(args, sc)?;
                self.call_value(&f, a, args, aspan, span)
            }
            ExprK::Member(base, name, opt) => {
                if let ExprK::Ident(t) = &base.k {
                    if self.is_type_name(t) && sc.get(t).is_none() {
                        let a = self.eval_args(args, sc)?;
                        if &**name == "init" {
                            return self.construct(t, a, args, aspan, span);
                        }
                        return self.static_call(t, name, a, args, aspan, span);
                    }
                }
                if crate::methods::is_mutating(name) && is_lvalue(base) {
                    let cur = self.eval(base, sc)?;
                    if *opt && matches!(cur, Value::Nil) {
                        return Ok(Value::Nil);
                    }
                    if crate::methods::mutating_applies(&cur, name) {
                        let a = self.eval_args(args, sc)?;
                        let (nv, ret) = crate::methods::mutate(self, &cur, name, a, span)?;
                        if let Value::Binding(b) = &cur {
                            let b = b.clone();
                            self.write_binding(&b, nv);
                        } else {
                            self.assign(base, nv, sc)?;
                        }
                        return Ok(ret);
                    }
                }
                let recv = self.eval(base, sc)?;
                if *opt && matches!(recv, Value::Nil) {
                    return Ok(Value::Nil);
                }
                let a = self.eval_args(args, sc)?;
                // modifier span starts at the `.` before the member name
                let dot = (callee.span.e as usize).saturating_sub(name.len() + 1) as u32;
                let mspan = Span { s: dot, e: aspan.e };
                self.call_method(&recv, name, a, args, mspan, span)
            }
            ExprK::ImplicitMember(n) => {
                let a = self.eval_args(args, sc)?;
                // user static funcs / enum payload cases
                let mut owner: Option<Rc<str>> = None;
                for (tn, ti) in self.types.iter() {
                    if ti.func(n, true).is_some() || ti.cases.iter().any(|c| &*c.name == &**n && c.assoc > 0) {
                        owner = Some(tn.clone());
                    }
                }
                if let Some(t) = owner {
                    return self.static_call(&t, n, a, args, aspan, span);
                }
                Ok(Value::SymCall(n.clone(), Rc::new(a)))
            }
            _ => {
                let f = self.eval(callee, sc)?;
                let a = self.eval_args(args, sc)?;
                self.call_value(&f, a, args, aspan, span)
            }
        }
    }

    pub fn call_value(&mut self, f: &Value, a: Args, exprs: &[Arg], aspan: Span, span: Span) -> R<Value> {
        match f {
            Value::Fn(c) => self.call_callable(c, a, span),
            Value::Type(t) => self.construct(t, a, exprs, aspan, span),
            Value::Builtin(n) => crate::methods::builtin_fn(self, n, a, span),
            Value::Method(recv, n) => self.call_method(recv, n, a, exprs, aspan, span),
            Value::Dismiss(nav) => {
                let key = format!("{}.__path", nav);
                if let Some(Value::Array(p)) = self.state.get(&key).cloned() {
                    let mut p = p.as_ref().clone();
                    p.pop();
                    self.state.insert(key, Value::Array(Rc::new(p)));
                }
                Ok(Value::Nil)
            }
            Value::Nil => Ok(Value::Nil),
            _ => err(span, format!("cannot call value of type {}", f.type_name())),
        }
    }

    pub fn call_fn(&mut self, f: &Value, a: Vec<Value>, span: Span) -> R<Value> {
        let a: Args = a.into_iter().map(|v| (None, v)).collect();
        match f {
            Value::Fn(c) => self.call_callable(c, a, span),
            Value::Builtin(n) => crate::methods::builtin_fn(self, n, a, span),
            Value::Nil => Ok(Value::Nil),
            _ => self.call_value(f, a, &[], span, span),
        }
    }

    pub fn call_callable(&mut self, c: &Callable, a: Args, span: Span) -> R<Value> {
        match c {
            Callable::Closure(cl, env) => {
                let sc = Scope::new(Some(env.clone()));
                if cl.params.is_empty() {
                    for (i, (_, v)) in a.into_iter().enumerate() {
                        sc.def(Rc::from(format!("${}", i)), v);
                    }
                } else if cl.params.len() > 1 && a.len() == 1 {
                    // destructure tuple argument
                    if let Value::Tuple(t) = &a[0].1 {
                        for (i, p) in cl.params.iter().enumerate() {
                            sc.def(p.clone(), t.get(i).map(|x| x.1.clone()).unwrap_or(Value::Nil));
                        }
                    }
                } else {
                    for (i, p) in cl.params.iter().enumerate() {
                        sc.def(p.clone(), a.get(i).map(|x| x.1.clone()).unwrap_or(Value::Nil));
                    }
                }
                self.depth += 1;
                if self.depth > 200 {
                    self.depth -= 1;
                    return err(span, "recursion too deep");
                }
                let r = self.run_body(&cl.body, &sc);
                self.depth -= 1;
                r
            }
            Callable::Func(f, env, selfv) => {
                let f = f.clone();
                let env = env.clone();
                let selfv = selfv.clone();
                self.call_func_in(&f, selfv, a, span, env)
            }
        }
    }

    pub fn call_func(&mut self, f: &Rc<Func>, selfv: Option<Value>, a: Args, span: Span) -> R<Value> {
        let g = self.globals.clone();
        self.call_func_in(f, selfv, a, span, g)
    }

    fn bind_params(&mut self, params: &[Param], a: Args, sc: &Rc<Scope>, span: Span, fname: &str) -> R<()> {
        let mut ai = 0;
        let mut a: Vec<Option<(Option<Rc<str>>, Value)>> = a.into_iter().map(Some).collect();
        for p in params {
            let mut val = None;
            // find matching arg
            if ai < a.len() {
                if let Some((lab, _)) = &a[ai] {
                    if lab.as_deref() == p.label.as_deref() {
                        val = a[ai].take().map(|x| x.1);
                        ai += 1;
                    }
                }
            }
            if val.is_none() {
                if let Some(pos) = a.iter().position(|x| x.as_ref().map(|(l, _)| l.as_deref() == p.label.as_deref()).unwrap_or(false)) {
                    val = a[pos].take().map(|x| x.1);
                }
            }
            if p.variadic {
                let mut items = vec![];
                if let Some(v) = val {
                    items.push(v);
                }
                while ai < a.len() {
                    if let Some((None, v)) = a[ai].take() {
                        items.push(v);
                    }
                    ai += 1;
                }
                sc.def(p.name.clone(), Value::Array(Rc::new(items)));
                continue;
            }
            let v = match val {
                Some(v) => v,
                None => match &p.default {
                    Some(d) => self.eval_typed(d, p.ty.as_ref(), sc)?,
                    None => return err(span, format!("missing argument '{}' in call to {}", p.label.as_deref().unwrap_or("_"), fname)),
                },
            };
            sc.def(p.name.clone(), v);
        }
        Ok(())
    }

    pub fn call_func_in(&mut self, f: &Rc<Func>, selfv: Option<Value>, a: Args, span: Span, env: Rc<Scope>) -> R<Value> {
        let sc = Scope::new(Some(env));
        if let Some(s) = selfv {
            sc.def(Rc::from("self"), s);
        }
        self.bind_params(&f.params, a, &sc, span, &f.name)?;
        self.depth += 1;
        if self.depth > 200 {
            self.depth -= 1;
            return err(span, "recursion too deep");
        }
        let r = self.run_body(&f.body, &sc);
        self.depth -= 1;
        r
    }

    pub fn construct(&mut self, t: &str, a: Args, exprs: &[Arg], aspan: Span, span: Span) -> R<Value> {
        let ti = match self.types.get(t).cloned() {
            Some(ti) if ti.kind != TypeKind::Extension || !BUILTIN_TYPES.contains(&t) => ti,
            _ => return crate::views::builtin_ctor(self, t, a, exprs, aspan, span),
        };
        if ti.kind == TypeKind::Enum {
            // init(rawValue:)
            if let Some((_, raw)) = a.first() {
                for c in &ti.cases {
                    let rv = self.get_member(&Value::Enum(ti.name.clone(), c.name.clone(), Rc::new(vec![])), "rawValue", span)?;
                    if values_eq(&rv, raw) {
                        return Ok(Value::Enum(ti.name.clone(), c.name.clone(), Rc::new(vec![])));
                    }
                }
            }
            return Ok(Value::Nil);
        }
        // default fields
        let mut fields = vec![];
        let g = Scope::new(Some(self.globals.clone()));
        for p in ti.props.iter() {
            if p.is_static || p.getter.is_some() {
                continue;
            }
            let v = match &p.init {
                Some(e) => self.eval_typed(e, p.ty.as_ref(), &g)?,
                None => Value::Nil,
            };
            fields.push((p.name.clone(), v));
        }
        let base = Value::Struct(Rc::new(StructV { ty: ti.name.clone(), fields, ident: None, ctor: span }));
        // explicit init?
        if !ti.inits.is_empty() {
            let labels: Vec<Option<&str>> = a.iter().map(|x| x.0.as_deref()).collect();
            let pick = ti
                .inits
                .iter()
                .find(|f| {
                    let req: Vec<Option<&str>> = f.params.iter().filter(|p| p.default.is_none()).map(|p| p.label.as_deref()).collect();
                    labels.len() >= req.len() && labels.len() <= f.params.len() && labels.iter().all(|l| f.params.iter().any(|p| p.label.as_deref() == *l))
                })
                .cloned();
            if let Some(f) = pick {
                let sc = Scope::new(Some(self.globals.clone()));
                sc.def(Rc::from("self"), base);
                self.bind_params(&f.params, a, &sc, span, "init")?;
                let mut col = vec![];
                self.exec_block(&f.body, &sc, &mut col)?;
                return Ok(sc.get("self").unwrap_or(Value::Nil));
            }
        }
        // memberwise
        let Value::Struct(s) = base else { unreachable!() };
        let mut s = (*s).clone();
        let stored: Vec<Rc<str>> = s.fields.iter().map(|f| f.0.clone()).collect();
        let mut pos = 0;
        for (lab, v) in a {
            let name = match lab {
                Some(l) => l,
                None => {
                    // unlabeled trailing closure goes to the first closure-typed field without value
                    let cand = stored.iter().skip(pos).find(|n| {
                        s.fields.iter().find(|f| &f.0 == *n).map(|f| matches!(f.1, Value::Nil)).unwrap_or(false)
                    });
                    match cand {
                        Some(c) => c.clone(),
                        None => return err(span, format!("extra argument in call to {}", t)),
                    }
                }
            };
            if let Some(i) = stored.iter().position(|n| *n == name) {
                pos = i + 1;
                s.fields[i].1 = v;
            } else {
                return err(span, format!("extra argument '{}' in call to {}", name, t));
            }
        }
        for p in ti.props.iter() {
            if p.is_static || p.getter.is_some() || p.init.is_some() || p.optional_type || !p.attrs.is_empty() {
                continue;
            }
            if let Some(f) = s.fields.iter().find(|f| f.0 == p.name) {
                if matches!(f.1, Value::Nil) {
                    return err(span, format!("missing argument '{}' in call to {}", p.name, t));
                }
            }
        }
        Ok(Value::Struct(Rc::new(s)))
    }

    pub fn static_call(&mut self, t: &str, n: &str, a: Args, exprs: &[Arg], aspan: Span, span: Span) -> R<Value> {
        if let Some(ti) = self.types.get(t).cloned() {
            if let Some(f) = ti.func(n, true) {
                let f = f.clone();
                return self.call_func(&f, None, a, span);
            }
            if let Some(c) = ti.cases.iter().find(|c| &*c.name == n) {
                return Ok(Value::Enum(ti.name.clone(), c.name.clone(), Rc::new(a.into_iter().map(|x| x.1).collect())));
            }
            if ti.sprop(n).is_some() {
                let v = self.static_member(t, n, span)?;
                return self.call_value(&v, a, exprs, aspan, span);
            }
        }
        crate::methods::builtin_static_call(self, t, n, a, exprs, aspan, span)
    }

    pub fn call_method(&mut self, recv: &Value, n: &str, a: Args, exprs: &[Arg], aspan: Span, span: Span) -> R<Value> {
        match recv {
            Value::Struct(s) => {
                if let Some(ti) = self.types.get(&s.ty).cloned() {
                    if let Some(f) = ti.func(n, false) {
                        let f = f.clone();
                        return self.call_func(&f, Some(recv.clone()), a, span);
                    }
                    // closure stored in a field
                    if let Some((_, fv)) = s.fields.iter().find(|(k, _)| &**k == n) {
                        let fv = fv.clone();
                        return self.call_value(&fv, a, exprs, aspan, span);
                    }
                    if ti.is_view() {
                        let v = self.to_view(recv, span)?;
                        return crate::views::modifier(self, Value::View(v), n, a, exprs, aspan, span);
                    }
                }
                err(span, format!("value of type '{}' has no member '{}'", s.ty, n))
            }
            Value::Enum(t, _, _) => {
                if let Some(ti) = self.types.get(t).cloned() {
                    if let Some(f) = ti.func(n, false) {
                        let f = f.clone();
                        return self.call_func(&f, Some(recv.clone()), a, span);
                    }
                }
                err(span, format!("enum '{}' has no method '{}'", t, n))
            }
            Value::View(_) | Value::Views(_) | Value::Shape(_) => crate::views::modifier(self, recv.clone(), n, a, exprs, aspan, span),
            Value::Fn(_) if n == "callAsFunction" => self.call_value(recv, a, exprs, aspan, span),
            _ => crate::methods::builtin_method(self, recv, n, a, exprs, aspan, span),
        }
    }

    // ---------- views ----------

    pub fn expand(&mut self, s: &Rc<StructV>, out: &mut Vec<Rc<View>>) -> R<()> {
        let ti = match self.types.get(&s.ty).cloned() {
            Some(t) => t,
            None => return err(s.ctor, format!("unknown view type {}", s.ty)),
        };
        let parent = self.idpath.last().cloned().unwrap_or_else(|| Rc::from(""));
        let ident: Rc<str> = Rc::from(format!("{}/{}@{}", parent, s.ty, s.ctor.s));
        let mut sv = (**s).clone();
        sv.ident = Some(ident.clone());
        for p in ti.props.iter() {
            if p.is_static {
                continue;
            }
            if has_attr(p, "State") || has_attr(p, "StateObject") || has_attr(p, "AppStorage") {
                let key = format!("{}.{}", ident, p.name);
                if !self.state.contains_key(&key) {
                    let v = sv.fields.iter().find(|f| f.0 == p.name).map(|f| f.1.clone()).unwrap_or(Value::Nil);
                    self.state.insert(key, v);
                }
            }
            if has_attr(p, "Environment") {
                let mut which = String::new();
                if let Some(ExprK::KeyPath(kp)) = p.attr_args.as_ref().map(|e| &e.k) {
                    which = kp.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(".");
                }
                let v = match which.as_str() {
                    "dismiss" => Value::Dismiss(self.nav.last().cloned().unwrap_or_else(|| Rc::from(""))),
                    "colorScheme" => Value::Sym(Rc::from(if self.dark { "dark" } else { "light" })),
                    _ => Value::Nil,
                };
                if let Some(f) = sv.fields.iter_mut().find(|f| f.0 == p.name) {
                    f.1 = v;
                } else {
                    sv.fields.push((p.name.clone(), v));
                }
            }
        }
        let body = ti.prop("body").and_then(|p| p.getter.as_ref()).map(|_| ());
        if body.is_none() {
            return err(s.ctor, format!("'{}' does not have a body", s.ty));
        }
        let selfv = Value::Struct(Rc::new(sv));
        self.idpath.push(ident);
        self.depth += 1;
        if self.depth > 120 {
            self.depth -= 1;
            self.idpath.pop();
            return err(s.ctor, "view nesting too deep");
        }
        let r = self.get_member(&selfv, "body", s.ctor);
        let r = r.and_then(|v| self.to_views(&v, out, s.ctor));
        self.depth -= 1;
        self.idpath.pop();
        r
    }

    pub fn to_views(&mut self, v: &Value, out: &mut Vec<Rc<View>>, span: Span) -> R<()> {
        match v {
            Value::View(vw) => {
                if let VK::Group(ch) = &vw.k {
                    out.extend(ch.iter().cloned());
                } else {
                    out.push(vw.clone());
                }
            }
            Value::Views(list) => {
                for x in list.iter() {
                    self.to_views(x, out, span)?;
                }
            }
            Value::Struct(s) => self.expand(s, out)?,
            Value::Paint(p) => out.push(Rc::new(View { k: VK::Shape { shape: ShapeK::Rect, fill: Some((**p).clone()), stroke: None, inset: 0.0 }, src: span })),
            Value::Shape(k) => out.push(Rc::new(View { k: VK::Shape { shape: *k, fill: None, stroke: None, inset: 0.0 }, src: span })),
            Value::Sym(_) | Value::SymCall(..) => {
                if let Some(p) = crate::views::to_paint(self, v) {
                    out.push(Rc::new(View { k: VK::Shape { shape: ShapeK::Rect, fill: Some(p), stroke: None, inset: 0.0 }, src: span }));
                } else {
                    return err(span, format!("'{}' is not a View", v.describe()));
                }
            }
            Value::Nil => {}
            Value::Fn(c) => {
                let c = c.clone();
                let r = self.call_callable(&c, vec![], span)?;
                self.to_views(&r, out, span)?;
            }
            Value::Array(a) => {
                for x in a.iter() {
                    self.to_views(x, out, span)?;
                }
            }
            _ => return err(span, format!("value of type {} is not a View", v.type_name())),
        }
        Ok(())
    }

    pub fn to_view(&mut self, v: &Value, span: Span) -> R<Rc<View>> {
        let mut out = vec![];
        self.to_views(v, &mut out, span)?;
        Ok(match out.len() {
            0 => Rc::new(View { k: VK::Empty, src: span }),
            1 => out.pop().unwrap(),
            _ => Rc::new(View { k: VK::Group(out), src: span }),
        })
    }

    pub fn new_id(&self, span: Span) -> Rc<str> {
        let parent = self.idpath.last().map(|s| &**s).unwrap_or("");
        Rc::from(format!("{}#{}", parent, span.s))
    }
}

pub fn is_lvalue(e: &Expr) -> bool {
    match &e.k {
        ExprK::Ident(_) => true,
        ExprK::Member(b, _, _) => matches!(b.k, ExprK::SelfRef) || is_lvalue(b),
        ExprK::Index(b, _) => is_lvalue(b),
        ExprK::ForceUnwrap(b) => is_lvalue(b),
        _ => false,
    }
}
