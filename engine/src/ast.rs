use std::rc::Rc;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Span {
    pub s: u32,
    pub e: u32,
}

impl Span {
    pub fn new(s: usize, e: usize) -> Span {
        Span { s: s as u32, e: e as u32 }
    }
    pub fn to(self, o: Span) -> Span {
        Span { s: self.s.min(o.s), e: self.e.max(o.e) }
    }
}

#[derive(Debug)]
pub struct Arg {
    pub label: Option<Rc<str>>,
    pub value: Expr,
}

#[derive(Debug)]
pub enum StrSeg {
    Lit(Rc<str>),
    Code(Expr),
}

#[derive(Debug)]
pub struct Expr {
    pub k: ExprK,
    pub span: Span,
}

#[derive(Debug)]
pub enum ExprK {
    Int(i64),
    Float(f64),
    Str(Vec<StrSeg>, Span), // inner literal span (without quotes)
    Bool(bool),
    Nil,
    Ident(Rc<str>),
    SelfRef,
    ImplicitMember(Rc<str>),
    Member(Box<Expr>, Rc<str>, bool), // base, name, optional chaining
    Call(Box<Expr>, Vec<Arg>, Span), // callee, args, args span (incl parens/closures)
    Index(Box<Expr>, Vec<Arg>),
    Unary(&'static str, Box<Expr>),
    Binary(&'static str, Box<Expr>, Box<Expr>),
    Ternary(Box<Expr>, Box<Expr>, Box<Expr>),
    Array(Vec<Expr>),
    Dict(Vec<(Expr, Expr)>),
    Tuple(Vec<Arg>),
    Closure(Rc<Closure>),
    KeyPath(Vec<Rc<str>>),
    ForceUnwrap(Box<Expr>),
    Cast(Box<Expr>, bool), // optional cast?
    Is(Box<Expr>, Rc<str>),
    Binding(Rc<str>), // $name
    Type(Rc<str>),    // explicit type expression we don't model (e.g. String.self)
}

#[derive(Debug)]
pub struct Closure {
    pub params: Vec<Rc<str>>,
    pub body: Vec<Stmt>,
    pub span: Span,
}

#[derive(Debug)]
pub enum Pattern {
    Expr(Expr),
    EnumCase(Rc<str>, Vec<Rc<str>>), // .case(let a, let b)
    Wildcard,
}

#[derive(Debug)]
pub struct Case {
    pub pats: Vec<Pattern>, // empty = default
    pub body: Vec<Stmt>,
}

#[derive(Debug)]
pub enum Cond {
    Expr(Expr),
    Let(Rc<str>, Expr),
}

#[derive(Debug)]
pub struct Stmt {
    pub k: StmtK,
    pub span: Span,
}

#[derive(Debug)]
pub enum StmtK {
    Expr(Expr),
    Let(Rc<str>, Option<Expr>, bool), // name, init, mutable
    LetTuple(Vec<Rc<str>>, Expr),
    Assign(Expr, Option<&'static str>, Expr),
    If(Vec<Cond>, Vec<Stmt>, Option<Vec<Stmt>>),
    Guard(Vec<Cond>, Vec<Stmt>),
    For(Vec<Rc<str>>, Expr, Vec<Stmt>, Option<Expr>),
    While(Expr, Vec<Stmt>),
    Switch(Expr, Vec<Case>),
    Return(Option<Expr>),
    Break,
    Continue,
    Func(Rc<Func>),
    Nop,
}

#[derive(Debug)]
pub struct Param {
    pub label: Option<Rc<str>>, // external label (None = _)
    pub name: Rc<str>,
    pub default: Option<Expr>,
    pub variadic: bool,
    pub ty: Option<Rc<str>>,
}

#[derive(Debug)]
pub struct Func {
    pub name: Rc<str>,
    pub params: Vec<Param>,
    pub body: Vec<Stmt>,
    pub is_static: bool,
    pub span: Span,
}

#[derive(Debug)]
pub struct Prop {
    pub name: Rc<str>,
    pub attrs: Vec<Rc<str>>,
    pub attr_args: Option<Expr>,
    pub is_static: bool,
    pub mutable: bool,
    pub init: Option<Expr>,
    pub getter: Option<Vec<Stmt>>, // computed property
    pub has_type: bool,
    pub optional_type: bool,
    pub ty: Option<Rc<str>>,
    pub span: Span,
}

#[derive(Debug)]
pub struct EnumCase {
    pub name: Rc<str>,
    pub raw: Option<Expr>,
    pub assoc: usize,
}

#[derive(Debug, Default)]
pub struct TypeDecl {
    pub name: Rc<str>,
    pub kind: TypeKind,
    pub props: Vec<Prop>,
    pub funcs: Vec<Rc<Func>>,
    pub inits: Vec<Rc<Func>>,
    pub cases: Vec<EnumCase>,
    pub conforms: Vec<Rc<str>>,
    pub raw_string: bool,
    pub span: Span,
}

#[derive(Debug, Default, Clone, Copy, PartialEq)]
pub enum TypeKind {
    #[default]
    Struct,
    Class,
    Enum,
    Extension,
    Protocol,
}

#[derive(Debug)]
pub struct Preview {
    pub name: Rc<str>,
    pub body: Rc<Closure>,
    pub span: Span,
}

#[derive(Debug, Default)]
pub struct Program {
    pub types: Vec<TypeDecl>,
    pub funcs: Vec<Rc<Func>>,
    pub globals: Vec<Prop>,
    pub previews: Vec<Preview>,
    pub main: Option<Rc<str>>,
}
