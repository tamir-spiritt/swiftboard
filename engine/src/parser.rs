use crate::ast::*;
use crate::lexer::{lex, StrPart, Tok, Token};
use std::rc::Rc;

pub struct Parser {
    t: Vec<Token>,
    p: usize,
    no_trailing: bool,
}

pub type PResult<T> = Result<T, (usize, String)>;

const KEYWORDS: &[&str] = &[
    "let", "var", "if", "else", "guard", "for", "in", "while", "switch", "case", "default", "return",
    "break", "continue", "func", "struct", "class", "enum", "extension", "protocol", "import", "init",
    "where", "do", "catch", "defer", "repeat", "fallthrough", "throw",
];

fn rc(s: &str) -> Rc<str> {
    Rc::from(s)
}

pub fn parse_program(src: &str) -> PResult<Program> {
    let toks = lex(src, 0)?;
    let mut p = Parser { t: toks, p: 0, no_trailing: false };
    p.program()
}

pub fn parse_expr_at(src: &str, base: usize) -> PResult<Expr> {
    let toks = lex(src, base)?;
    let mut p = Parser { t: toks, p: 0, no_trailing: false };
    let e = p.expr()?;
    if !matches!(p.peek().tok, Tok::Eof) {
        return Err((p.peek().start, "unexpected token in interpolation".into()));
    }
    Ok(e)
}

impl Parser {
    fn peek(&self) -> &Token {
        &self.t[self.p.min(self.t.len() - 1)]
    }
    fn at(&self, n: usize) -> &Token {
        &self.t[(self.p + n).min(self.t.len() - 1)]
    }
    fn bump(&mut self) -> Token {
        let t = self.peek().clone();
        if self.p < self.t.len() - 1 {
            self.p += 1;
        }
        t
    }
    fn is_p(&self, s: &str) -> bool {
        matches!(&self.peek().tok, Tok::Punct(p) if *p == s)
    }
    fn is_p_at(&self, n: usize, s: &str) -> bool {
        matches!(&self.at(n).tok, Tok::Punct(p) if *p == s)
    }
    fn is_id(&self, s: &str) -> bool {
        matches!(&self.peek().tok, Tok::Ident(i) if i == s)
    }
    fn is_id_at(&self, n: usize, s: &str) -> bool {
        matches!(&self.at(n).tok, Tok::Ident(i) if i == s)
    }
    fn eat_p(&mut self, s: &str) -> bool {
        if self.is_p(s) {
            self.bump();
            true
        } else {
            false
        }
    }
    fn eat_id(&mut self, s: &str) -> bool {
        if self.is_id(s) {
            self.bump();
            true
        } else {
            false
        }
    }
    fn err<T>(&self, msg: &str) -> PResult<T> {
        let t = self.peek();
        let found = match &t.tok {
            Tok::Ident(s) => format!("'{}'", s),
            Tok::Punct(p) => format!("'{}'", p),
            Tok::Eof => "end of file".into(),
            Tok::Str(_) => "string".into(),
            _ => "number".into(),
        };
        Err((t.start, format!("{} (found {})", msg, found)))
    }
    fn expect_p(&mut self, s: &str) -> PResult<Token> {
        if self.is_p(s) {
            Ok(self.bump())
        } else {
            self.err(&format!("expected '{}'", s))
        }
    }
    fn ident(&mut self) -> PResult<Rc<str>> {
        match &self.peek().tok {
            Tok::Ident(s) => {
                let s = rc(s);
                self.bump();
                Ok(s)
            }
            _ => self.err("expected identifier"),
        }
    }
    fn prev_end(&self) -> usize {
        if self.p == 0 {
            0
        } else {
            self.t[self.p - 1].end
        }
    }

    fn skip_balanced(&mut self, open: &str, close: &str) -> PResult<()> {
        self.expect_p(open)?;
        let mut d = 1;
        while d > 0 {
            if matches!(self.peek().tok, Tok::Eof) {
                return self.err(&format!("unbalanced '{}'", open));
            }
            if self.is_p(open) {
                d += 1;
            } else if self.is_p(close) {
                d -= 1;
            }
            self.bump();
        }
        Ok(())
    }

    // simple nominal type name starting at token index (e.g. `AppTab`, `Color`), None for others
    fn type_name_at(&self, i: usize) -> Option<Rc<str>> {
        match &self.t[i].tok {
            Tok::Ident(n) if n != "some" && n != "any" => Some(rc(n)),
            _ => None,
        }
    }

    fn skip_generic(&mut self) -> PResult<()> {
        let mut d: i32 = 0;
        loop {
            match &self.peek().tok {
                Tok::Punct("<") => d += 1,
                Tok::Punct("<<") => d += 2,
                Tok::Punct(">") => d -= 1,
                Tok::Punct(">>") => d -= 2,
                Tok::Eof => return self.err("unbalanced '<'"),
                _ => {}
            }
            self.bump();
            if d <= 0 {
                return Ok(());
            }
        }
    }

    fn skip_attrs(&mut self) -> PResult<Vec<(Rc<str>, Option<Expr>)>> {
        let mut out = vec![];
        while self.is_p("@") {
            self.bump();
            let name = self.ident()?;
            let mut arg = None;
            if self.is_p("(") && !self.peek().sp_before {
                self.bump();
                if !self.is_p(")") {
                    let mut first = None;
                    loop {
                        if matches!(self.peek().tok, Tok::Ident(_)) && self.is_p_at(1, ":") {
                            self.bump();
                            self.bump();
                        }
                        let e = self.expr()?;
                        if first.is_none() {
                            first = Some(e);
                        }
                        if !self.eat_p(",") {
                            break;
                        }
                    }
                    arg = first;
                }
                self.expect_p(")")?;
            }
            out.push((name, arg));
        }
        Ok(out)
    }

    fn skip_mods(&mut self) -> bool {
        let mut is_static = false;
        loop {
            let t = &self.peek().tok;
            if let Tok::Ident(s) = t {
                match s.as_str() {
                    "private" | "fileprivate" | "public" | "internal" | "open" => {
                        self.bump();
                        if self.is_p("(") {
                            let _ = self.skip_balanced("(", ")");
                        }
                    }
                    "final" | "mutating" | "nonmutating" | "override" | "lazy" | "weak" | "unowned"
                    | "nonisolated" | "required" | "convenience" | "indirect" | "dynamic" | "optional" => {
                        self.bump();
                    }
                    "static" => {
                        self.bump();
                        is_static = true;
                    }
                    "class" if matches!(&self.at(1).tok, Tok::Ident(n) if n=="func"||n=="var"||n=="let") => {
                        self.bump();
                        is_static = true;
                    }
                    _ => return is_static,
                }
            } else {
                return is_static;
            }
        }
    }

    // Skip a type expression. Returns whether it is optional.
    fn skip_type(&mut self) -> PResult<bool> {
        let mut opt = false;
        while self.is_p("@") {
            self.skip_attrs()?;
        }
        while self.is_id("some") || self.is_id("any") || self.is_id("inout") || self.is_id("borrowing") || self.is_id("consuming") {
            self.bump();
        }
        if self.is_p("(") {
            self.skip_balanced("(", ")")?;
            if self.is_id("async") {
                self.bump();
            }
            if self.is_id("throws") {
                self.bump();
            }
            if self.eat_p("->") {
                self.skip_type()?;
            }
        } else if self.is_p("[") {
            self.skip_balanced("[", "]")?;
        } else {
            self.ident()?;
            loop {
                if self.is_p("<") && !self.peek().sp_before {
                    self.skip_generic()?;
                }
                if self.is_p(".") && matches!(self.at(1).tok, Tok::Ident(_)) {
                    self.bump();
                    self.bump();
                    continue;
                }
                break;
            }
        }
        loop {
            if (self.is_p("?") || self.is_p("!")) && !self.peek().sp_before {
                self.bump();
                opt = true;
            } else if self.is_p("...") {
                self.bump();
            } else if self.is_p("&") {
                self.bump();
                self.skip_type()?;
            } else {
                break;
            }
        }
        Ok(opt)
    }

    fn program(&mut self) -> PResult<Program> {
        let mut prog = Program::default();
        loop {
            if matches!(self.peek().tok, Tok::Eof) {
                break;
            }
            if self.eat_p(";") {
                continue;
            }
            if self.is_p("#") && self.is_id_at(1, "Preview") {
                let start = self.bump().start;
                self.bump();
                let mut name: Rc<str> = rc("Preview");
                if self.is_p("(") {
                    self.bump();
                    let mut first = true;
                    while !self.is_p(")") {
                        if matches!(self.peek().tok, Tok::Ident(_)) && self.is_p_at(1, ":") {
                            self.bump();
                            self.bump();
                            self.expr()?;
                        } else {
                            let e = self.expr()?;
                            if first {
                                if let ExprK::Str(segs, _) = &e.k {
                                    if let Some(StrSeg::Lit(s)) = segs.first() {
                                        name = s.clone();
                                    }
                                }
                            }
                        }
                        first = false;
                        if !self.eat_p(",") {
                            break;
                        }
                    }
                    self.expect_p(")")?;
                }
                let body = self.closure()?;
                let end = self.prev_end();
                prog.previews.push(Preview { name, body, span: Span::new(start, end) });
                continue;
            }
            let attrs = self.skip_attrs()?;
            let is_main = attrs.iter().any(|a| &*a.0 == "main");
            self.skip_mods();
            if self.is_id("import") {
                self.bump();
                while !self.peek().nl_before || self.is_p(".") {
                    if matches!(self.peek().tok, Tok::Eof) {
                        break;
                    }
                    self.bump();
                }
                continue;
            }
            if self.is_id("typealias") {
                self.skip_line();
                continue;
            }
            if let Some(kind) = self.type_kind() {
                let mut nested = vec![];
                let td = self.type_decl(kind, &mut nested)?;
                if is_main {
                    prog.main = Some(td.name.clone());
                }
                prog.types.push(td);
                prog.types.extend(nested);
                continue;
            }
            if self.is_id("func") {
                let f = self.func(false)?;
                prog.funcs.push(Rc::new(f));
                continue;
            }
            if self.is_id("let") || self.is_id("var") {
                let pr = self.prop(vec![], None, false)?;
                prog.globals.push(pr);
                continue;
            }
            return self.err("expected declaration");
        }
        Ok(prog)
    }

    fn skip_line(&mut self) {
        self.bump();
        while !self.peek().nl_before {
            if matches!(self.peek().tok, Tok::Eof) {
                break;
            }
            self.bump();
        }
    }

    fn type_kind(&self) -> Option<TypeKind> {
        match &self.peek().tok {
            Tok::Ident(s) => match s.as_str() {
                "struct" => Some(TypeKind::Struct),
                "class" => Some(TypeKind::Class),
                "actor" => Some(TypeKind::Class),
                "enum" => Some(TypeKind::Enum),
                "extension" => Some(TypeKind::Extension),
                "protocol" => Some(TypeKind::Protocol),
                _ => None,
            },
            _ => None,
        }
    }

    fn type_decl(&mut self, kind: TypeKind, nested: &mut Vec<TypeDecl>) -> PResult<TypeDecl> {
        let start = self.bump().start;
        let mut name = self.ident()?;
        while self.is_p(".") {
            self.bump();
            name = self.ident()?;
        }
        let mut td = TypeDecl { name, kind, span: Span::new(start, start), ..Default::default() };
        if self.is_p("<") {
            self.skip_balanced("<", ">")?;
        }
        if self.eat_p(":") {
            loop {
                let s = self.p;
                self.skip_type()?;
                if let Tok::Ident(n) = &self.t[s].tok {
                    let n = rc(n);
                    if &*n == "String" {
                        td.raw_string = true;
                    }
                    td.conforms.push(n);
                }
                if !self.eat_p(",") {
                    break;
                }
            }
        }
        if self.is_id("where") {
            while !self.is_p("{") {
                if matches!(self.peek().tok, Tok::Eof) {
                    break;
                }
                self.bump();
            }
        }
        self.expect_p("{")?;
        while !self.is_p("}") {
            if matches!(self.peek().tok, Tok::Eof) {
                return self.err("expected '}'");
            }
            if self.eat_p(";") {
                continue;
            }
            if self.is_p("#") {
                // #if etc: skip line
                self.skip_line();
                continue;
            }
            let attrs = self.skip_attrs()?;
            let is_static = self.skip_mods();
            if let Some(k) = self.type_kind() {
                if !(k == TypeKind::Class && (self.is_id_at(1, "func") || self.is_id_at(1, "var"))) {
                    let mut more = vec![];
                    let inner = self.type_decl(k, &mut more)?;
                    nested.push(inner);
                    nested.extend(more);
                    continue;
                }
            }
            if self.is_id("case") {
                self.bump();
                loop {
                    let n = self.ident()?;
                    let mut assoc = 0;
                    if self.is_p("(") {
                        // count associated values
                        self.bump();
                        let mut d = 1;
                        assoc = 1;
                        while d > 0 {
                            if self.is_p("(") {
                                d += 1;
                            } else if self.is_p(")") {
                                d -= 1;
                            } else if self.is_p(",") && d == 1 {
                                assoc += 1;
                            }
                            if matches!(self.peek().tok, Tok::Eof) {
                                return self.err("unbalanced");
                            }
                            self.bump();
                        }
                    }
                    let raw = if self.eat_p("=") { Some(self.expr()?) } else { None };
                    td.cases.push(EnumCase { name: n, raw, assoc });
                    if !self.eat_p(",") {
                        break;
                    }
                }
                continue;
            }
            if self.is_id("var") || self.is_id("let") {
                let a: Vec<Rc<str>> = attrs.iter().map(|a| a.0.clone()).collect();
                let arg = attrs.into_iter().find_map(|a| a.1);
                let pr = self.prop(a, arg, is_static)?;
                td.props.push(pr);
                continue;
            }
            if self.is_id("func") {
                let f = self.func(is_static)?;
                td.funcs.push(Rc::new(f));
                continue;
            }
            if self.is_id("init") {
                let s = self.bump().start;
                if self.is_p("?") || self.is_p("!") {
                    self.bump();
                }
                let params = self.params()?;
                self.skip_func_tail()?;
                let body = if self.is_p("{") { self.block()? } else { vec![] };
                td.inits.push(Rc::new(Func { name: rc("init"), params, body, is_static: false, span: Span::new(s, self.prev_end()) }));
                continue;
            }
            if self.is_id("typealias") || self.is_id("associatedtype") {
                self.skip_line();
                continue;
            }
            if self.is_id("subscript") || self.is_id("deinit") {
                self.bump();
                while !self.is_p("{") {
                    self.bump();
                }
                self.skip_balanced("{", "}")?;
                continue;
            }
            return self.err("expected member declaration");
        }
        let end = self.bump().end;
        td.span = Span::new(start, end);
        Ok(td)
    }

    fn skip_func_tail(&mut self) -> PResult<()> {
        loop {
            if self.is_id("async") || self.is_id("throws") || self.is_id("rethrows") {
                self.bump();
            } else if self.eat_p("->") {
                self.skip_type()?;
            } else if self.is_id("where") {
                while !self.is_p("{") && !matches!(self.peek().tok, Tok::Eof) && !self.peek().nl_before {
                    self.bump();
                }
            } else {
                return Ok(());
            }
        }
    }

    fn params(&mut self) -> PResult<Vec<Param>> {
        self.expect_p("(")?;
        let mut out = vec![];
        while !self.is_p(")") {
            self.skip_attrs()?;
            let first = self.ident()?;
            let (label, name) = if let Tok::Ident(second) = &self.peek().tok {
                let second = rc(second);
                self.bump();
                (if &*first == "_" { None } else { Some(first) }, second)
            } else {
                (Some(first.clone()), first)
            };
            self.expect_p(":")?;
            let ts = self.p;
            self.skip_type()?;
            let variadic = self.t[ts..self.p].iter().any(|t| matches!(t.tok, Tok::Punct("...")));
            let ty = self.type_name_at(ts);
            let default = if self.eat_p("=") { Some(self.expr()?) } else { None };
            out.push(Param { label, name, default, variadic, ty });
            if !self.eat_p(",") {
                break;
            }
        }
        self.expect_p(")")?;
        Ok(out)
    }

    fn func(&mut self, is_static: bool) -> PResult<Func> {
        let s = self.bump().start; // func
        let name = match &self.peek().tok {
            Tok::Ident(n) => rc(n),
            Tok::Punct(p) => rc(p),
            _ => return self.err("expected function name"),
        };
        self.bump();
        if self.is_p("<") {
            self.skip_balanced("<", ">")?;
        }
        let params = self.params()?;
        self.skip_func_tail()?;
        let body = if self.is_p("{") { self.block()? } else { vec![] };
        Ok(Func { name, params, body, is_static, span: Span::new(s, self.prev_end()) })
    }

    fn prop(&mut self, attrs: Vec<Rc<str>>, attr_args: Option<Expr>, is_static: bool) -> PResult<Prop> {
        let s = self.peek().start;
        let mutable = self.is_id("var");
        self.bump();
        let name = self.ident()?;
        let mut has_type = false;
        let mut optional_type = false;
        let mut ty = None;
        if self.eat_p(":") {
            has_type = true;
            let ts = self.p;
            optional_type = self.skip_type()?;
            ty = self.type_name_at(ts);
        }
        let mut init = None;
        let mut getter = None;
        if self.eat_p("=") {
            init = Some(self.expr()?);
        }
        if self.is_p("{") && !self.peek().nl_before || (self.is_p("{") && init.is_none()) {
            // computed or observers
            let save = self.p;
            self.bump();
            if self.is_id("get") || self.is_id("set") || self.is_id("didSet") || self.is_id("willSet") {
                let mut g = None;
                while !self.is_p("}") {
                    let which = self.ident()?;
                    if self.is_p("(") {
                        self.skip_balanced("(", ")")?;
                    }
                    if self.is_p("{") {
                        let b = self.block()?;
                        if &*which == "get" {
                            g = Some(b);
                        }
                    }
                }
                self.bump();
                getter = g;
            } else {
                self.p = save;
                getter = Some(self.block()?);
            }
        }
        Ok(Prop { name, attrs, attr_args, is_static, mutable, init, getter, has_type, optional_type, ty, span: Span::new(s, self.prev_end()) })
    }

    pub fn block(&mut self) -> PResult<Vec<Stmt>> {
        self.expect_p("{")?;
        let saved = self.no_trailing;
        self.no_trailing = false;
        let mut out = vec![];
        while !self.is_p("}") {
            if matches!(self.peek().tok, Tok::Eof) {
                return self.err("expected '}'");
            }
            if self.eat_p(";") {
                continue;
            }
            out.push(self.stmt()?);
        }
        self.bump();
        self.no_trailing = saved;
        Ok(out)
    }

    fn conds(&mut self) -> PResult<Vec<Cond>> {
        let saved = self.no_trailing;
        self.no_trailing = true;
        let mut out = vec![];
        loop {
            if self.is_id("let") || self.is_id("var") {
                self.bump();
                let name = self.ident()?;
                if self.eat_p(":") {
                    self.skip_type()?;
                }
                if self.eat_p("=") {
                    out.push(Cond::Let(name, self.expr()?));
                } else {
                    let sp = self.t[self.p - 1].start;
                    let e = Expr { k: ExprK::Ident(name.clone()), span: Span::new(sp, sp) };
                    out.push(Cond::Let(name, e));
                }
            } else {
                out.push(Cond::Expr(self.expr()?));
            }
            if !self.eat_p(",") {
                break;
            }
        }
        self.no_trailing = saved;
        Ok(out)
    }

    fn stmt(&mut self) -> PResult<Stmt> {
        let start = self.peek().start;
        let k = self.stmt_k()?;
        Ok(Stmt { k, span: Span::new(start, self.prev_end()) })
    }

    fn stmt_k(&mut self) -> PResult<StmtK> {
        if self.is_p("@") {
            self.skip_attrs()?;
        }
        if let Tok::Ident(kw) = &self.peek().tok {
            match kw.as_str() {
                "let" | "var" => {
                    let mutable = kw == "var";
                    self.bump();
                    if self.is_p("(") {
                        self.bump();
                        let mut names = vec![];
                        while !self.is_p(")") {
                            names.push(self.ident()?);
                            if !self.eat_p(",") {
                                break;
                            }
                        }
                        self.expect_p(")")?;
                        self.expect_p("=")?;
                        return Ok(StmtK::LetTuple(names, self.expr()?));
                    }
                    let name = self.ident()?;
                    if self.eat_p(":") {
                        self.skip_type()?;
                    }
                    let init = if self.eat_p("=") { Some(self.expr()?) } else { None };
                    return Ok(StmtK::Let(name, init, mutable));
                }
                "if" => return self.if_stmt(),
                "guard" => {
                    self.bump();
                    let c = self.conds()?;
                    if !self.eat_id("else") {
                        return self.err("expected 'else'");
                    }
                    let b = self.block()?;
                    return Ok(StmtK::Guard(c, b));
                }
                "for" => {
                    self.bump();
                    let mut names = vec![];
                    if self.eat_id("case") {}
                    if self.eat_p("(") {
                        while !self.is_p(")") {
                            names.push(self.ident()?);
                            if !self.eat_p(",") {
                                break;
                            }
                        }
                        self.expect_p(")")?;
                    } else {
                        names.push(self.ident()?);
                    }
                    if !self.eat_id("in") {
                        return self.err("expected 'in'");
                    }
                    let saved = self.no_trailing;
                    self.no_trailing = true;
                    let seq = self.expr()?;
                    let wh = if self.eat_id("where") { Some(self.expr()?) } else { None };
                    self.no_trailing = saved;
                    let b = self.block()?;
                    return Ok(StmtK::For(names, seq, b, wh));
                }
                "while" => {
                    self.bump();
                    let saved = self.no_trailing;
                    self.no_trailing = true;
                    let c = self.expr()?;
                    self.no_trailing = saved;
                    let b = self.block()?;
                    return Ok(StmtK::While(c, b));
                }
                "switch" => return self.switch(),
                "return" => {
                    let t = self.bump();
                    let _ = t;
                    if self.is_p("}") || self.peek().nl_before || self.is_p(";") {
                        return Ok(StmtK::Return(None));
                    }
                    return Ok(StmtK::Return(Some(self.expr()?)));
                }
                "break" => {
                    self.bump();
                    return Ok(StmtK::Break);
                }
                "continue" => {
                    self.bump();
                    return Ok(StmtK::Continue);
                }
                "fallthrough" => {
                    self.bump();
                    return Ok(StmtK::Nop);
                }
                "func" => {
                    let f = self.func(false)?;
                    return Ok(StmtK::Func(Rc::new(f)));
                }
                "defer" => {
                    self.bump();
                    self.block()?;
                    return Ok(StmtK::Nop);
                }
                "do" => {
                    self.bump();
                    let b = self.block()?;
                    while self.eat_id("catch") {
                        while !self.is_p("{") {
                            self.bump();
                        }
                        self.block()?;
                    }
                    return Ok(StmtK::If(vec![], b, None));
                }
                "throw" => {
                    self.bump();
                    self.expr()?;
                    return Ok(StmtK::Return(None));
                }
                _ => {}
            }
        }
        let e = self.expr()?;
        for op in ["=", "+=", "-=", "*=", "/="] {
            if self.is_p(op) {
                self.bump();
                let rhs = self.expr()?;
                let o = match op {
                    "+=" => Some("+"),
                    "-=" => Some("-"),
                    "*=" => Some("*"),
                    "/=" => Some("/"),
                    _ => None,
                };
                return Ok(StmtK::Assign(e, o, rhs));
            }
        }
        Ok(StmtK::Expr(e))
    }

    fn if_stmt(&mut self) -> PResult<StmtK> {
        self.bump(); // if
        let c = self.conds()?;
        let b = self.block()?;
        let mut els = None;
        if self.is_id("else") {
            self.bump();
            if self.is_id("if") {
                let st = self.peek().start;
                let k = self.if_stmt()?;
                els = Some(vec![Stmt { k, span: Span::new(st, self.prev_end()) }]);
            } else {
                els = Some(self.block()?);
            }
        }
        Ok(StmtK::If(c, b, els))
    }

    fn switch(&mut self) -> PResult<StmtK> {
        self.bump();
        let saved = self.no_trailing;
        self.no_trailing = true;
        let subj = self.expr()?;
        self.no_trailing = saved;
        self.expect_p("{")?;
        let mut cases = vec![];
        while !self.is_p("}") {
            let mut pats = vec![];
            if self.eat_id("default") {
            } else if self.eat_id("case") {
                loop {
                    pats.push(self.pattern()?);
                    if !self.eat_p(",") {
                        break;
                    }
                }
                if self.is_id("where") {
                    self.bump();
                    self.expr()?;
                }
            } else {
                return self.err("expected 'case' or 'default'");
            }
            self.expect_p(":")?;
            let mut body = vec![];
            while !self.is_p("}") && !self.is_id("case") && !self.is_id("default") {
                if self.eat_p(";") {
                    continue;
                }
                body.push(self.stmt()?);
            }
            cases.push(Case { pats, body });
        }
        self.bump();
        Ok(StmtK::Switch(subj, cases))
    }

    fn pattern(&mut self) -> PResult<Pattern> {
        let mut let_all = false;
        if self.is_id("let") || self.is_id("var") {
            self.bump();
            let_all = true;
        }
        if self.is_id("_") {
            self.bump();
            return Ok(Pattern::Wildcard);
        }
        if self.is_p(".") && matches!(self.at(1).tok, Tok::Ident(_)) {
            self.bump();
            let name = self.ident()?;
            let mut binds = vec![];
            if self.is_p("(") && !self.peek().sp_before {
                self.bump();
                while !self.is_p(")") {
                    if self.is_id("let") || self.is_id("var") {
                        self.bump();
                    }
                    if matches!(self.peek().tok, Tok::Ident(_)) && self.is_p_at(1, ":") {
                        self.bump();
                        self.bump();
                    }
                    binds.push(self.ident()?);
                    if !self.eat_p(",") {
                        break;
                    }
                }
                self.expect_p(")")?;
            }
            let _ = let_all;
            return Ok(Pattern::EnumCase(name, binds));
        }
        let saved = self.no_trailing;
        self.no_trailing = true;
        let e = self.expr()?;
        self.no_trailing = saved;
        Ok(Pattern::Expr(e))
    }

    // ---------- expressions ----------

    pub fn expr(&mut self) -> PResult<Expr> {
        let c = self.binary(0)?;
        if self.is_p("?") && self.peek().sp_before {
            self.bump();
            let a = self.expr()?;
            self.expect_p(":")?;
            let b = self.expr()?;
            let span = c.span.to(b.span);
            return Ok(Expr { k: ExprK::Ternary(Box::new(c), Box::new(a), Box::new(b)), span });
        }
        Ok(c)
    }

    fn binop(&self) -> Option<(&'static str, u8)> {
        let t = self.peek();
        if let Tok::Punct(p) = &t.tok {
            let prec = match *p {
                "||" => 1,
                "&&" => 2,
                "==" | "!=" | "<" | ">" | "<=" | ">=" | "===" | "!==" => 3,
                "??" => 4,
                "..." | "..<" => 6,
                "+" | "-" | "|" | "^" => 7,
                "*" | "/" | "%" | "&" => 8,
                "<<" | ">>" => 9,
                _ => return None,
            };
            // a line starting with '-' or a prefix-looking operator begins a new statement
            if t.nl_before && (*p == "-" || *p == "&") {
                return None;
            }
            // unary prefix operator form: "a -b" (space before, none after) is not binary
            if t.sp_before && !self.at(1).sp_before && (*p == "-" || *p == "&") {
                return None;
            }
            return Some((p, prec));
        }
        if let Tok::Ident(s) = &t.tok {
            if (s == "as" || s == "is") && !t.nl_before {
                return Some(if s == "as" { ("as", 5) } else { ("is", 5) });
            }
        }
        None
    }

    fn binary(&mut self, min: u8) -> PResult<Expr> {
        let mut lhs = self.unary()?;
        loop {
            let Some((op, prec)) = self.binop() else { break };
            if prec < min {
                break;
            }
            self.bump();
            if op == "as" {
                let opt = if self.is_p("?") || self.is_p("!") {
                    let q = self.is_p("?");
                    self.bump();
                    q
                } else {
                    false
                };
                self.skip_type()?;
                let span = lhs.span;
                lhs = Expr { k: ExprK::Cast(Box::new(lhs), opt), span: Span::new(span.s as usize, self.prev_end()) };
                continue;
            }
            if op == "is" {
                let s = self.p;
                self.skip_type()?;
                let tn = if let Tok::Ident(n) = &self.t[s].tok { rc(n) } else { rc("?") };
                let span = lhs.span;
                lhs = Expr { k: ExprK::Is(Box::new(lhs), tn), span: Span::new(span.s as usize, self.prev_end()) };
                continue;
            }
            // range "a..." open-ended
            if (op == "...") && (self.is_p(")") || self.is_p("]") || self.is_p(",")) {
                let span = lhs.span;
                let rhs = Expr { k: ExprK::Int(i64::MAX / 4), span };
                lhs = Expr { k: ExprK::Binary(op, Box::new(lhs), Box::new(rhs)), span };
                continue;
            }
            let next_min = if op == "??" { prec } else { prec + 1 };
            let rhs = self.binary(next_min)?;
            let span = lhs.span.to(rhs.span);
            lhs = Expr { k: ExprK::Binary(op, Box::new(lhs), Box::new(rhs)), span };
        }
        Ok(lhs)
    }

    fn unary(&mut self) -> PResult<Expr> {
        while self.is_id("try") || self.is_id("await") {
            self.bump();
            if (self.is_p("?") || self.is_p("!")) && !self.peek().sp_before {
                self.bump();
            }
        }
        let t = self.peek().clone();
        if let Tok::Punct(p) = &t.tok {
            if matches!(*p, "-" | "!" | "+" | "~" | "&") {
                self.bump();
                let e = self.unary()?;
                let span = Span::new(t.start, e.span.e as usize);
                if *p == "&" || *p == "+" {
                    return Ok(e);
                }
                // fold negative literals
                if *p == "-" {
                    match e.k {
                        ExprK::Int(n) => return Ok(Expr { k: ExprK::Int(-n), span }),
                        ExprK::Float(f) => return Ok(Expr { k: ExprK::Float(-f), span }),
                        _ => {}
                    }
                }
                let op: &'static str = if *p == "-" { "-" } else if *p == "!" { "!" } else { "~" };
                return Ok(Expr { k: ExprK::Unary(op, Box::new(e)), span });
            }
        }
        let prim = self.primary()?;
        self.postfix(prim)
    }

    fn args(&mut self, close: &str) -> PResult<Vec<Arg>> {
        let saved = self.no_trailing;
        self.no_trailing = false;
        let mut out = vec![];
        while !self.is_p(close) {
            let mut label = None;
            if let Tok::Ident(n) = &self.peek().tok {
                if self.is_p_at(1, ":") && !(self.is_p_at(2, ":")) {
                    label = Some(rc(n));
                    self.bump();
                    self.bump();
                }
            }
            // operator references like `+` in reduce(0, +)
            if let Tok::Punct(p) = self.peek().tok.clone() {
                if matches!(p, "+" | "*" | "<" | ">") && (self.is_p_at(1, ",") || self.is_p_at(1, ")")) {
                    let t = self.bump();
                    out.push(Arg { label, value: Expr { k: ExprK::Ident(rc(p)), span: Span::new(t.start, t.end) } });
                    if !self.eat_p(",") {
                        break;
                    }
                    continue;
                }
            }
            let value = self.expr()?;
            out.push(Arg { label, value });
            if !self.eat_p(",") {
                break;
            }
        }
        self.expect_p(close)?;
        self.no_trailing = saved;
        Ok(out)
    }

    fn trailing_ok(&self) -> bool {
        self.is_p("{") && !self.no_trailing && !self.peek().nl_before
    }

    fn postfix(&mut self, mut e: Expr) -> PResult<Expr> {
        loop {
            let t = self.peek().clone();
            match &t.tok {
                Tok::Punct(".") => {
                    match &self.at(1).tok {
                        Tok::Ident(n) => {
                            let n = rc(n);
                            self.bump();
                            let nt = self.bump();
                            if &*n == "self" {
                                continue;
                            }
                            let span = Span::new(e.span.s as usize, nt.end);
                            e = Expr { k: ExprK::Member(Box::new(e), n, false), span };
                        }
                        Tok::Int(i) => {
                            let n = rc(&i.to_string());
                            self.bump();
                            let nt = self.bump();
                            let span = Span::new(e.span.s as usize, nt.end);
                            e = Expr { k: ExprK::Member(Box::new(e), n, false), span };
                        }
                        Tok::Float(f) => {
                            // tuple.0.1 lexed as float; rare, treat as first index
                            let n = rc(&(f.trunc() as i64).to_string());
                            self.bump();
                            let nt = self.bump();
                            let span = Span::new(e.span.s as usize, nt.end);
                            e = Expr { k: ExprK::Member(Box::new(e), n, false), span };
                        }
                        _ => return self.err("expected member name"),
                    }
                }
                Tok::Punct("?") if !t.sp_before => {
                    if self.is_p_at(1, ".") {
                        self.bump();
                        self.bump();
                        let nt = self.peek().clone();
                        let n = self.ident()?;
                        let span = Span::new(e.span.s as usize, nt.end);
                        e = Expr { k: ExprK::Member(Box::new(e), n, true), span };
                    } else if self.is_p_at(1, "[") || self.is_p_at(1, "(") {
                        self.bump();
                    } else {
                        // `x?` alone (e.g. inside patterns); ignore
                        self.bump();
                    }
                }
                Tok::Punct("!") if !t.sp_before => {
                    self.bump();
                    let span = Span::new(e.span.s as usize, t.end);
                    e = Expr { k: ExprK::ForceUnwrap(Box::new(e)), span };
                }
                Tok::Punct("(") if !t.nl_before => {
                    self.bump();
                    let mut args = self.args(")")?;
                    let mut end = self.prev_end();
                    self.trailing_closures(&mut args, &mut end)?;
                    let span = Span::new(e.span.s as usize, end);
                    let aspan = Span::new(t.start, end);
                    e = Expr { k: ExprK::Call(Box::new(e), args, aspan), span };
                }
                Tok::Punct("[") if !t.nl_before && !t.sp_before => {
                    self.bump();
                    let args = self.args("]")?;
                    let span = Span::new(e.span.s as usize, self.prev_end());
                    e = Expr { k: ExprK::Index(Box::new(e), args), span };
                }
                Tok::Punct("{") if self.trailing_ok() => {
                    let mut args = vec![];
                    let mut end = self.prev_end();
                    self.trailing_closures(&mut args, &mut end)?;
                    let span = Span::new(e.span.s as usize, end);
                    let aspan = Span::new(t.start, end);
                    e = Expr { k: ExprK::Call(Box::new(e), args, aspan), span };
                }
                _ => break,
            }
        }
        Ok(e)
    }

    fn trailing_closures(&mut self, args: &mut Vec<Arg>, end: &mut usize) -> PResult<()> {
        if self.trailing_ok() {
            let c = self.closure()?;
            let span = c.span;
            args.push(Arg { label: None, value: Expr { k: ExprK::Closure(c), span } });
            *end = self.prev_end();
            loop {
                if let Tok::Ident(n) = &self.peek().tok {
                    if self.is_p_at(1, ":") && self.is_p_at(2, "{") && !self.no_trailing {
                        let label = rc(n);
                        self.bump();
                        self.bump();
                        let c = self.closure()?;
                        let span = c.span;
                        args.push(Arg { label: Some(label), value: Expr { k: ExprK::Closure(c), span } });
                        *end = self.prev_end();
                        continue;
                    }
                }
                break;
            }
        }
        Ok(())
    }

    fn closure(&mut self) -> PResult<Rc<Closure>> {
        let start = self.expect_p("{")?.start;
        let saved = self.no_trailing;
        self.no_trailing = false;
        // capture list
        if self.is_p("[") {
            let save = self.p;
            let mut i = self.p;
            let mut d = 0;
            loop {
                match &self.t[i].tok {
                    Tok::Punct("[") => d += 1,
                    Tok::Punct("]") => {
                        d -= 1;
                        if d == 0 {
                            break;
                        }
                    }
                    Tok::Eof => break,
                    _ => {}
                }
                i += 1;
            }
            // capture list only if followed by params or `in`
            let after = i + 1;
            let mut j = after;
            let mut sig = false;
            while j < self.t.len() {
                match &self.t[j].tok {
                    Tok::Ident(s) if s == "in" => {
                        sig = true;
                        break;
                    }
                    Tok::Ident(_) | Tok::Punct(",") | Tok::Punct("(") | Tok::Punct(")") => j += 1,
                    _ => break,
                }
            }
            if sig {
                self.p = after;
            } else {
                self.p = save;
            }
        }
        let mut params = vec![];
        if let Some(n) = self.sig_len() {
            let end = self.p + n;
            let mut i = self.p;
            let mut depth = 0;
            let mut after_colon = false;
            while i < end {
                match &self.t[i].tok {
                    Tok::Punct("(") => {
                        depth += 1;
                        after_colon = false
                    }
                    Tok::Punct(")") => depth -= 1,
                    Tok::Punct(",") => after_colon = false,
                    Tok::Punct(":") => after_colon = true,
                    Tok::Punct("->") => break,
                    Tok::Ident(s) => {
                        if !after_colon && depth <= 1 {
                            // in `(a b: T)` second ident is the name; keep last before ':' or ','
                            let next_is_ident = matches!(self.t[i + 1].tok, Tok::Ident(_)) && !matches!(&self.t[i+1].tok, Tok::Ident(x) if x == "in");
                            if !next_is_ident {
                                params.push(rc(s));
                            }
                        }
                    }
                    _ => {}
                }
                i += 1;
            }
            self.p = end + 1; // skip `in`
        }
        let mut body = vec![];
        while !self.is_p("}") {
            if matches!(self.peek().tok, Tok::Eof) {
                return self.err("expected '}' to close closure");
            }
            if self.eat_p(";") {
                continue;
            }
            body.push(self.stmt()?);
        }
        let end = self.bump().end;
        self.no_trailing = saved;
        Ok(Rc::new(Closure { params, body, span: Span::new(start, end) }))
    }

    // if the tokens at p form `params in`, return number of tokens before `in`
    fn sig_len(&self) -> Option<usize> {
        let mut i = self.p;
        let mut d = 0;
        loop {
            match &self.t[i].tok {
                Tok::Ident(s) if s == "in" && d == 0 => {
                    if i == self.p {
                        return None;
                    }
                    return Some(i - self.p);
                }
                Tok::Ident(s) if KEYWORDS.contains(&s.as_str()) && s != "_" => return None,
                Tok::Ident(_) => {}
                Tok::Punct(p) => match *p {
                    "(" | "[" | "<" => d += 1,
                    ")" | "]" | ">" => {
                        if d == 0 {
                            return None;
                        }
                        d -= 1
                    }
                    "," | ":" | "->" | "." | "?" | "!" | "@" => {}
                    _ => return None,
                },
                _ => return None,
            }
            if i > self.p && self.t[i].nl_before && d == 0 {
                return None;
            }
            i += 1;
        }
    }

    fn primary(&mut self) -> PResult<Expr> {
        let t = self.peek().clone();
        let sp = Span::new(t.start, t.end);
        match &t.tok {
            Tok::Int(n) => {
                self.bump();
                Ok(Expr { k: ExprK::Int(*n), span: sp })
            }
            Tok::Float(f) => {
                self.bump();
                Ok(Expr { k: ExprK::Float(*f), span: sp })
            }
            Tok::Str(parts) => {
                self.bump();
                let mut segs = vec![];
                for p in parts {
                    match p {
                        StrPart::Lit(s) => segs.push(StrSeg::Lit(rc(s))),
                        StrPart::Code(code, base) => segs.push(StrSeg::Code(parse_expr_at(code, *base)?)),
                    }
                }
                let inner = Span::new(t.start + 1, t.end.saturating_sub(1));
                Ok(Expr { k: ExprK::Str(segs, inner), span: sp })
            }
            Tok::Ident(name) => {
                let name = name.clone();
                self.bump();
                let k = match name.as_str() {
                    "true" => ExprK::Bool(true),
                    "false" => ExprK::Bool(false),
                    "nil" => ExprK::Nil,
                    "self" => ExprK::SelfRef,
                    _ if name.starts_with('$') && name.len() > 1 && !name.as_bytes()[1].is_ascii_digit() => {
                        ExprK::Binding(rc(&name[1..]))
                    }
                    _ => ExprK::Ident(rc(&name)),
                };
                Ok(Expr { k, span: sp })
            }
            Tok::Punct(".") => {
                self.bump();
                let nt = self.peek().clone();
                let n = self.ident()?;
                Ok(Expr { k: ExprK::ImplicitMember(n), span: Span::new(t.start, nt.end) })
            }
            Tok::Punct("(") => {
                self.bump();
                let args = self.args(")")?;
                let span = Span::new(t.start, self.prev_end());
                if args.len() == 1 && args[0].label.is_none() {
                    let mut a = args.into_iter().next().unwrap().value;
                    a.span = span;
                    return Ok(a);
                }
                Ok(Expr { k: ExprK::Tuple(args), span })
            }
            Tok::Punct("[") => {
                self.bump();
                let saved = self.no_trailing;
                self.no_trailing = false;
                if self.is_p(":") {
                    self.bump();
                    self.expect_p("]")?;
                    self.no_trailing = saved;
                    return Ok(Expr { k: ExprK::Dict(vec![]), span: Span::new(t.start, self.prev_end()) });
                }
                let mut items = vec![];
                let mut pairs = vec![];
                while !self.is_p("]") {
                    let a = self.expr()?;
                    if self.eat_p(":") {
                        let b = self.expr()?;
                        pairs.push((a, b));
                    } else {
                        items.push(a);
                    }
                    if !self.eat_p(",") {
                        break;
                    }
                }
                self.expect_p("]")?;
                self.no_trailing = saved;
                let span = Span::new(t.start, self.prev_end());
                if !pairs.is_empty() {
                    return Ok(Expr { k: ExprK::Dict(pairs), span });
                }
                Ok(Expr { k: ExprK::Array(items), span })
            }
            Tok::Punct("{") => {
                let c = self.closure()?;
                let span = c.span;
                Ok(Expr { k: ExprK::Closure(c), span })
            }
            Tok::Punct("\\") => {
                self.bump();
                let mut path = vec![];
                if let Tok::Ident(_) = &self.peek().tok {
                    self.bump(); // root type
                }
                while self.is_p(".") {
                    self.bump();
                    path.push(self.ident()?);
                }
                Ok(Expr { k: ExprK::KeyPath(path), span: Span::new(t.start, self.prev_end()) })
            }
            Tok::Punct("#") => {
                self.bump();
                let n = self.ident()?;
                if self.is_p("(") {
                    self.skip_balanced("(", ")")?;
                }
                Ok(Expr { k: ExprK::Type(n), span: sp })
            }
            _ => self.err("expected expression"),
        }
    }
}
